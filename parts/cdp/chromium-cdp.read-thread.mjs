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
//   qjs --std -m parts/cdp/chromium-cdp.read-thread.mjs \
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
    "usage: qjs --std -m chromium-cdp.read-thread.mjs --url <url> \\\n" +
    "  [--id <targetId>] [--addr 127.0.0.1] [--port 9222] \\\n" +
    "  [--waitMs 8000] [--pollMs 250] [--tail 12] [--markers m1,m2] \\\n" +
    "  [--poll-scope <scope>] \\\n" +
    "  [--poll-success-condition <cond>] \\\n" +
    "  [--poll-interval-min <ms>] [--poll-interval-max <ms>] \\\n" +
    "  [--poll-jitter] \\\n" +
    "  [--poll-cap-tries <n>] [--poll-cap-duration <ms>] \\\n" +
    "  [--poll-no-stop-cloudflare] [--poll-no-stop-login] \\\n" +
    "  [--poll-no-stop-ratelimit] [--poll-no-stop-sessionlost] \\\n" +
    "  [--poll-no-report]\n" +
    "\n" +
    "Polling contracts (polling_contracts.md):\n" +
    "  POLL_SCOPE           = --poll-scope (default: thread_read)\n" +
    "  POLL_SUCCESS_COND    = --poll-success-condition\n" +
    "  POLL_INTERVAL       = --poll-interval-min/max (default: 2000-5000ms)\n" +
    "  POLL_JITTER         = --poll-jitter (random per iteration)\n" +
    "  POLL_CAP_TRIES      = --poll-cap-tries (default: 8)\n" +
    "  POLL_CAP_DURATION   = --poll-cap-duration (default: 300000ms)\n" +
    "  POLL_STOP_COND      = cloudflare/login/ratelimit/sessionlost (default: all true)\n" +
    "  POLL_REPORT_CONTRACT= --poll-no-report to disable\n" +
    "\n" +
    "Success conditions: stop_button_gone|has_prompt|complete|has_messages\n",
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
    pollScope: "thread_read",
    pollSuccessCondition: null,
    pollIntervalMin: 2000,
    pollIntervalMax: 5000,
    pollJitter: false,
    pollCapTries: 8,
    pollCapDurationMs: 300000,
    pollStopCloudflare: true,
    pollStopLogin: true,
    pollStopRatelimit: true,
    pollStopSessionlost: true,
    pollStopTabdrift: false,
    pollReportContract: true,
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
    else if (a === "--poll-scope" && i + 1 < argv.length) out.pollScope = argv[++i];
    else if (a === "--poll-success-condition" && i + 1 < argv.length) out.pollSuccessCondition = argv[++i];
    else if (a === "--poll-interval-min" && i + 1 < argv.length) out.pollIntervalMin = Number(argv[++i]) || out.pollIntervalMin;
    else if (a === "--poll-interval-max" && i + 1 < argv.length) out.pollIntervalMax = Number(argv[++i]) || out.pollIntervalMax;
    else if (a === "--poll-jitter") out.pollJitter = true;
    else if (a === "--poll-cap-tries" && i + 1 < argv.length) out.pollCapTries = Number(argv[++i]) || out.pollCapTries;
    else if (a === "--poll-cap-duration" && i + 1 < argv.length) out.pollCapDurationMs = Number(argv[++i]) || out.pollCapDurationMs;
    else if (a === "--poll-no-stop-cloudflare") out.pollStopCloudflare = false;
    else if (a === "--poll-no-stop-login") out.pollStopLogin = false;
    else if (a === "--poll-no-stop-ratelimit") out.pollStopRatelimit = false;
    else if (a === "--poll-no-stop-sessionlost") out.pollStopSessionlost = false;
    else if (a === "--poll-no-stop-tabdrift") out.pollStopTabdrift = false;
    else if (a === "--poll-no-report") out.pollReportContract = false;
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
      const m = msgs.find((x) => m.text.includes(marker));
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

    const stopButton = !!document.querySelector(
      "button[data-testid='stop-button'], button[aria-label='Stop generating'], button[aria-label='Stop']"
    );

    const title = document.title || "";
    const bodyText = (document.body ? document.body.innerText : "").slice(0, 500);
    const isCloudflare = title.includes("Just a moment") || bodyText.includes("Cloudflare");
    const isLoginRequired = bodyText.includes("login") && bodyText.includes("Sign in");
    const isRatelimit = bodyText.includes("rate limit") || bodyText.includes("too many requests");

    return {
      href: location.href,
      title: document.title,
      readyState: document.readyState,
      msgCount: msgs.length,
      hasPrompt: !!document.querySelector("#prompt-textarea"),
      hits,
      last,
      waiting,
      stopButton,
      cloudflare: isCloudflare,
      loginRequired: isLoginRequired,
      rateLimit: isRatelimit,
    };
  })()`;
}

function detectStopCondition(value, args) {
  if (!value) return { stopped: false, reason: null };

  if (args.pollStopCloudflare && value.cloudflare) {
    return { stopped: true, reason: "cloudflare_challenge" };
  }
  if (args.pollStopLogin && value.loginRequired) {
    return { stopped: true, reason: "login_required" };
  }
  if (args.pollStopRatelimit && value.rateLimit) {
    return { stopped: true, reason: "rate_limit" };
  }
  if (args.pollStopSessionlost && value.msgCount === 0 && value.readyState === "complete") {
    return { stopped: true, reason: "session_lost" };
  }

  return { stopped: false, reason: null };
}

function checkSuccessCondition(value, condition) {
  if (!condition || !value) return true;
  if (condition === "stop_button_gone") return !value.stopButton;
  if (condition === "has_prompt") return !!value.hasPrompt;
  if (condition === "complete") return value.readyState === "complete";
  if (condition === "has_messages") return value.msgCount > 0;
  return true;
}

function jitterSleep(minMs, maxMs, useJitter) {
  let interval;
  if (useJitter) {
    interval = minMs + Math.random() * (maxMs - minMs);
  } else {
    interval = (minMs + maxMs) / 2;
  }
  sleepMs(interval);
  return interval;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  cdpVersion(args.addr, args.port);

  const targets = cdpList(args.addr, args.port);
  const target = pickTarget(targets, args);
  const wsUrl = target.webSocketDebuggerUrl;

  try {
    cdpCall(wsUrl, { id: 10, method: "Page.bringToFront", params: {} }, 30000);
  } catch {
    // ignore
  }

  const expr = buildExpr(args.markers, args.tail);
  const startTime = os.now();
  const deadline = startTime + args.pollCapDurationMs;
  let tries = 0;
  let value = null;
  let stopReason = null;
  let lastInterval = 0;

  while (true) {
    tries++;

    const resp = cdpEvaluate(wsUrl, expr, {
      id: 2,
      returnByValue: true,
      awaitPromise: false,
      timeoutMs: 60000,
    });
    value = resp?.result?.result?.value;

    const stopCond = detectStopCondition(value, args);
    if (stopCond.stopped) {
      stopReason = stopCond.reason;
      break;
    }

    const success = checkSuccessCondition(value, args.pollSuccessCondition);
    if (success && value && (value.msgCount > 0 || value.hasPrompt)) {
      stopReason = "success";
      break;
    }

    if (tries >= args.pollCapTries) {
      stopReason = "cap_tries";
      break;
    }

    if (os.now() >= deadline) {
      stopReason = "cap_duration";
      break;
    }

    lastInterval = jitterSleep(args.pollIntervalMin, args.pollIntervalMax, args.pollJitter);
  }

  if (args.pollReportContract) {
    const result = {
      poll_result: stopReason,
      poll_scope: args.pollScope,
      poll_success_condition: args.pollSuccessCondition,
      tries: tries,
      total_duration_ms: Math.trunc(os.now() - startTime),
      last_interval_ms: Math.trunc(lastInterval),
      last_observed_state: value || null,
      stop_reason_or_success: stopReason,
    };
    std.out.puts(JSON.stringify(result, null, 2) + "\n");
  } else {
    std.out.puts(JSON.stringify(value, null, 2) + "\n");
  }
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
