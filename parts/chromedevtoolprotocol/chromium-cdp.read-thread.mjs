// Read a ChatGPT thread (or any page) via CDP, without jq/node.
//
// NOTE
// - This script reads an *existing* open tab. Open the target URL in
//   Chromium (logged-in) first.
//
// TODO(opencode): Robustness improvements
// - This script can capture *partial* assistant messages if the UI is still
//   streaming when sampled (stop button present) or if DOM virtualization
//   temporarily swaps message nodes.
// - Consider adding:
//   - generating detection + wait: check for stop button and support
//     `--waitForIdleMs` to wait until it disappears.
//   - stability polling: sample the last assistant message text until it is
//     unchanged for N polls (or a small settle window).
//   - optional full snapshot: return {head, tail, len} for the last assistant
//     message (not only the preview).
// - Incident 2026-03-14: a reliable direct snapshot was obtained via CDP with
//   this expression (example):
//     (() => {
//       const nodes = Array.from(document.querySelectorAll('main [data-message-author-role="assistant"]'));
//       const t = nodes.length ? (nodes[nodes.length - 1].innerText || '') : '';
//       return { count: nodes.length, len: t.length, head: t.slice(0, 200), tail: t.slice(-400) };
//     })()
// - Also note: the current `hits` logic finds the *first* message containing a
//   marker. For "latest verdict" style markers, it may be better to find the
//   last matching message.
//
// Usage:
//   nix shell .#chromium-cdp-tools
//   chromium-cdp "https://chatgpt.com" &
//   export HQ_CHROME_ADDR=127.0.0.1 HQ_CHROME_PORT=9222
//   qjs --std -m parts/chromedevtoolprotocol/chromium-cdp.read-thread.mjs \
//     --url "https://chatgpt.com/c/<thread>" --tail 30 --waitMs 8000

import {
  cdpCall,
  cdpEvaluate,
  cdpList,
  cdpVersion,
  getDefaultAddr,
  getDefaultPort,
  sleepMs,
} from "./chromium-cdp.lib.mjs";

function usage() {
  std.err.puts(
    "usage: qjs --std -m chromium-cdp.read-thread.mjs --url <url> [--id <targetId>] [--addr 127.0.0.1] [--port 9222] [--waitMs 8000] [--pollMs 250] [--tail 12] [--markers m1,m2]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    id: null,
    waitMs: 8000,
    pollMs: 250,
    tail: 12,
    markers: [],
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--id" && i + 1 < argv.length) out.id = argv[++i];
    else if (a === "--waitMs" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--pollMs" && i + 1 < argv.length) out.pollMs = Number(argv[++i]) || out.pollMs;
    else if (a === "--tail" && i + 1 < argv.length) out.tail = Number(argv[++i]) || out.tail;
    else if (a === "--markers" && i + 1 < argv.length)
      out.markers = String(argv[++i] || "")
        .split(",")
        .map((s) => s.trim())
        .filter((s) => s.length);
    else if (a === "-h" || a === "--help") return null;
    else {
      std.err.puts(`unknown arg: ${a}\n`);
      return null;
    }
  }

  if (!out.url) return null;
  return out;
}

function extractConversationId(url) {
  const m = String(url || "").match(/\/c\/([0-9a-fA-F-]{16,})/);
  return m ? m[1] : null;
}

function pickTarget(targets, args) {
  const pages = (targets || []).filter((t) => t && t.type === "page" && t.webSocketDebuggerUrl);

  if (args.id) {
    const t = pages.find((x) => String(x.id || "") === String(args.id));
    if (!t) throw new Error(`target not found by --id: ${args.id}`);
    return t;
  }

  const url = String(args.url || "");
  let cands = pages.filter((t) => String(t.url || "") === url);

  if (cands.length === 0) {
    cands = pages.filter((t) => String(t.url || "").startsWith(url));
  }

  if (cands.length === 0) {
    const cid = extractConversationId(url);
    if (cid) cands = pages.filter((t) => String(t.url || "").includes(cid));
  }

  if (cands.length === 1) return cands[0];

  const preview = pages.map((t) => ({ id: t.id, title: t.title, url: t.url }));
  const msg =
    cands.length === 0
      ? "no matching page target found; open the URL in Chromium and retry"
      : "multiple matching page targets; pass --id to disambiguate";
  throw new Error(`${msg}:\n${JSON.stringify(preview, null, 2)}`);
}

function buildExpr(markers, tail) {
  const markersJson = JSON.stringify(markers);
  const tailN = Math.max(1, Number(tail) || 12);
  return `(() => {
    const markers = ${markersJson};
    const nodes = Array.from(document.querySelectorAll("main [data-message-author-role]"));
    const msgs = nodes
      .map((n, i) => ({
        idx: i,
        role: n.getAttribute("data-message-author-role") || "",
        text: (n.innerText || "").trim(),
      }))
      .filter((m) => m.text.length);

    const hits = [];
    for (const marker of markers) {
      const m = msgs.find((x) => x.text.includes(marker));
      if (m) {
        hits.push({
          marker,
          idx: m.idx,
          role: m.role,
          preview: m.text.slice(0, 300).replace(/\\n/g, " "),
        });
      }
    }

    const last = msgs.slice(-${tailN}).map((m) => ({
      idx: m.idx,
      role: m.role,
      preview: m.text.slice(0, 800).replace(/\\n/g, " "),
    }));

    const waiting = (() => {
      if (!markers || markers.length === 0) return null;
      if (!msgs.length) return null;
      const lastMsg = msgs[msgs.length - 1];
      if (!lastMsg || lastMsg.role !== "assistant") return null;
      for (const marker of markers) {
        if (marker && lastMsg.text.includes(marker)) {
          return {
            marker,
            idx: lastMsg.idx,
            role: lastMsg.role,
            preview: lastMsg.text.slice(0, 300).replace(/\\n/g, " "),
          };
        }
      }
      return null;
    })();

    return {
      href: location.href,
      title: document.title,
      readyState: document.readyState,
      msgCount: msgs.length,
      hasPrompt: !!document.querySelector("#prompt-textarea"),
      hits,
      last,
      waiting,
    };
  })()`;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  // Ensure CDP is up.
  cdpVersion(args.addr, args.port);

  const targets = cdpList(args.addr, args.port);
  const target = pickTarget(targets, args);
  const wsUrl = target.webSocketDebuggerUrl;

  // Best-effort: activate.
  try {
    cdpCall(wsUrl, { id: 10, method: "Page.bringToFront", params: {} }, 30000);
  } catch {
    // ignore
  }

  const expr = buildExpr(args.markers, args.tail);
  const timeoutMs = Math.max(30000, Number(args.waitMs) + 30000);
  const pollMs = Math.max(50, Number(args.pollMs) || 250);
  const deadline = os.now() + Math.max(0, Number(args.waitMs) || 0);

  let value = null;
  while (true) {
    const resp = cdpEvaluate(wsUrl, expr, {
      id: 2,
      returnByValue: true,
      awaitPromise: false,
      timeoutMs,
    });
    value = resp?.result?.result?.value;

    const ok =
      value &&
      ((value.msgCount && value.msgCount > 0) || value.hasPrompt || value.readyState === "complete" || value.readyState === "interactive");

    if (ok) break;
    if (os.now() >= deadline) break;
    sleepMs(pollMs);
  }

  std.out.puts(JSON.stringify(value, null, 2) + "\n");
  std.out.flush();
  return 0;
}

try {
  std.exit(main(scriptArgs));
} catch (e) {
  std.err.puts(String(e && e.stack ? e.stack : e) + "\n");
  std.err.flush();
  std.exit(1);
}
