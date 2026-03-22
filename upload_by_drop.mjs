// upload_by_drop.mjs - Upload file via CDP Input.dispatchDragEvent
// Usage: qjs --std -m upload_by_drop.mjs --url <thread-url> --file <zip-path>
//
// This implements the D2 approach: drag-and-drop simulation without needing nodeId
// Based on GPT consultation: https://chatgpt.com/c/69bfb435-73e8-83ab-af8b-3a5f85243502

import {
  cdpCall,
  cdpEvaluate,
  cdpList,
  getDefaultAddr,
  getDefaultPort,
  sleepMs,
} from "./parts/cdp/chromium-cdp.lib.mjs";

function usage() {
  std.err.puts(
    "usage: qjs --std -m upload_by_drop.mjs --url <thread-url> --file <path> [--id <targetId>] [--addr 127.0.0.1] [--port 9222]\n",
  );
  std.exit(2);
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    id: null,
    file: null,
  };
  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--id" && i + 1 < argv.length) out.id = argv[++i];
    else if (a === "--file" && i + 1 < argv.length) out.file = argv[++i];
    else if (a === "-h" || a === "--help") return null;
  }
  if (!out.url || !out.file) return null;
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
  if (cands.length === 0) cands = pages.filter((t) => String(t.url || "").startsWith(url));
  if (cands.length === 0) {
    const cid = extractConversationId(url);
    if (cid) cands = pages.filter((t) => String(t.url || "").includes(cid));
  }
  if (cands.length === 1) return cands[0];
  const preview = pages.map((t) => ({ id: t.id, title: t.title, url: t.url }));
  throw new Error(`${cands.length === 0 ? "no" : "multiple"} matching page targets: ${JSON.stringify(preview, null, 2)}`);
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  const filePath = String(args.file || "");
  const fileName = filePath.split("/").pop() || filePath;

  const targets = cdpList(args.addr, args.port);
  const target = pickTarget(targets, args);
  const wsUrl = target.webSocketDebuggerUrl;

  let nextId = 1;
  const call = (method, params, timeoutMs) => {
    const req = { id: nextId++, method, params: params || {} };
    return cdpCall(wsUrl, req, timeoutMs || 60000);
  };
  const evalByValue = (expression, timeoutMs) => {
    const resp = cdpEvaluate(wsUrl, expression, {
      id: nextId++,
      returnByValue: true,
      awaitPromise: false,
      timeoutMs: timeoutMs || 60000,
    });
    return resp && resp.result && resp.result.result ? resp.result.result.value : null;
  };

  try {
    call("Page.bringToFront", {});
    sleepMs(500);

    // Step 1: Get drop point coordinates from the composer
    const dropPt = evalByValue(
      `(() => {
        const el = document.querySelector('#prompt-textarea')?.closest('form') ||
                   document.querySelector('[data-testid="composer"]') ||
                   document.querySelector('main') ||
                   document.body;
        const r = el.getBoundingClientRect();
        return {
          x: Math.round(r.left + r.width / 2),
          y: Math.round(r.top + r.height / 2),
          width: Math.round(r.width),
          height: Math.round(r.height)
        };
      })()`,
      10000,
    );

    if (!dropPt || typeof dropPt.x !== "number" || typeof dropPt.y !== "number") {
      throw new Error("failed to get drop point coordinates");
    }

    std.out.puts(`Drop point: (${dropPt.x}, ${dropPt.y})\n`);

    // Step 2: Dispatch drag events with file
    const dragData = {
      items: [],
      files: [filePath],
      dragOperationsMask: 1,
    };

    std.out.puts("Dispatching dragEnter...\n");
    call("Input.dispatchDragEvent", {
      type: "dragEnter",
      x: dropPt.x,
      y: dropPt.y,
      data: dragData,
    });
    sleepMs(100);

    std.out.puts("Dispatching dragOver...\n");
    call("Input.dispatchDragEvent", {
      type: "dragOver",
      x: dropPt.x,
      y: dropPt.y,
      data: dragData,
    });
    sleepMs(100);

    std.out.puts("Dispatching drop...\n");
    call("Input.dispatchDragEvent", {
      type: "drop",
      x: dropPt.x,
      y: dropPt.y,
      data: dragData,
    });
    sleepMs(500);

    // Step 3: Verify attachment
    const after = evalByValue(
      `(() => {
        const input = document.getElementById('upload-files');
        const names = input && input.files ? Array.from(input.files).map(f => f.name) : [];
        const chips = Array.from(document.querySelectorAll('[aria-label]'))
          .map(e => e.getAttribute('aria-label'))
          .filter(Boolean)
          .filter(l => l.includes('.zip') || l.includes('.tar'))
          .slice(0, 10);
        return { names, chips, inputFound: !!input };
      })()`,
      10000,
    );

    const result = {
      ok: true,
      target: { id: target.id, url: target.url },
      file: { path: filePath, name: fileName },
      dropPoint: dropPt,
      after: after,
    };

    std.out.puts(JSON.stringify(result, null, 2) + "\n");

    // Check if file was attached
    const attached =
      (after && after.names && after.names.includes(fileName)) ||
      (after && after.chips && after.chips.some(c => c.includes(fileName)));

    if (attached) {
      std.out.puts(`SUCCESS: File "${fileName}" appears to be attached\n`);
    } else {
      std.out.puts(`UNCERTAIN: File attachment could not be verified. Input found: ${after?.inputFound}, names: ${JSON.stringify(after?.names)}, chips: ${JSON.stringify(after?.chips)}\n`);
    }

    return attached ? 0 : 1;
  } catch (e) {
    std.err.puts(String(e && e.stack ? e.stack : e) + "\n");
    return 1;
  }
}

try {
  std.exit(main(scriptArgs));
} catch (e) {
  std.err.puts(String(e && e.stack ? e.stack : e) + "\n");
  std.exit(1);
}