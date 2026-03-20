// Upload a local file into an existing ChatGPT thread composer via CDP.
//
// What this does
// - Open or reuse a ChatGPT thread tab
// - Locate the composer-owned file input
// - Attach a local file path via DOM.setFileInputFiles
// - Optionally send a user message so the upload becomes a thread turn
//
// Runtime: quickjs-ng (qjs) with --std

import {
  cdpCall,
  cdpEvaluate,
  cdpList,
  cdpNew,
  cdpVersion,
  getDefaultAddr,
  getDefaultPort,
  sleepMs,
} from "./chromium-cdp.lib.mjs";

function usage() {
  std.err.puts(
    "usage: qjs --std -m chromium-cdp.upload-chatgpt-file.mjs --url <thread-url> --file <path> [--text <s> | --text-file <path>] [--id <targetId>] [--outPath <file>] [--addr 127.0.0.1] [--port 9222] [--waitMs 800] [--timeoutMs 180000]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    id: null,
    file: null,
    text: null,
    textFile: null,
    outPath: null,
    waitMs: 800,
    timeoutMs: 180000,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--id" && i + 1 < argv.length) out.id = argv[++i];
    else if (a === "--file" && i + 1 < argv.length) out.file = argv[++i];
    else if (a === "--text" && i + 1 < argv.length) out.text = argv[++i];
    else if (a === "--text-file" && i + 1 < argv.length) out.textFile = argv[++i];
    else if (a === "--outPath" && i + 1 < argv.length) out.outPath = argv[++i];
    else if (a === "--waitMs" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--timeoutMs" && i + 1 < argv.length) out.timeoutMs = Number(argv[++i]) || out.timeoutMs;
    else if (a === "-h" || a === "--help") return null;
    else return null;
  }

  if (!out.url) return null;
  if (!out.file) return null;
  if (out.text && out.textFile) return null;
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
  const msg = cands.length === 0
    ? "no matching page target found; open the thread in Chromium and retry"
    : "multiple matching page targets; pass --id to disambiguate";
  throw new Error(`${msg}:\n${JSON.stringify(preview, null, 2)}`);
}

function openOrFind(args, url) {
  const targets = cdpList(args.addr, args.port);
  const found = pickTarget(targets, { ...args, url, id: null });
  return found || cdpNew(args.addr, args.port, url);
}

function locateComposerExpr() {
  return `(() => {
    const q = (s, root) => {
      try { return (root || document).querySelector(s); } catch { return null; }
    };
    const pick = (...sels) => {
      for (const s of sels) {
        const el = q(s);
        if (el) return el;
      }
      return null;
    };
    const info = (el) => {
      if (!el) return null;
      try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch {}
      const r = el.getBoundingClientRect();
      const tag = String(el.tagName || '');
      const aria = String(el.getAttribute('aria-label') || '');
      const testid = String(el.getAttribute('data-testid') || '');
      const role = String(el.getAttribute('role') || '');
      const id = String(el.id || '');
      const disabled = !!el.disabled;
      let valueLen = 0;
      try {
        if (tag === 'TEXTAREA' || tag === 'INPUT') valueLen = String(el.value || '').length;
        else valueLen = String(el.innerText || '').length;
      } catch {}
      return {
        tag, id, aria, testid, role, disabled, valueLen,
        rect: { x: r.x, y: r.y, width: r.width, height: r.height },
        center: { x: r.x + r.width / 2, y: r.y + r.height / 2 },
        contentEditable: !!el.isContentEditable,
      };
    };
    const prompt = pick('#prompt-textarea', 'textarea#prompt-textarea', 'form textarea', 'form [contenteditable="true"]');
    const send = pick(
      'button[data-testid="send-button"]',
      'button[aria-label="Send prompt"]',
      'button[aria-label="Send message"]',
      'button[aria-label="Send"]',
      'button[aria-label="送信"]'
    ) || (prompt && prompt.closest && prompt.closest('form') ? prompt.closest('form').querySelector('button[type="submit"]') : null);
    const stop = pick(
      'button[data-testid="stop-button"]',
      'button[aria-label="Stop generating"]',
      'button[aria-label="Stop streaming"]',
      'button[aria-label="Stop"]',
      'button[aria-label="停止"]'
    );
    const plus = pick('button[data-testid="composer-plus-btn"]');
    return {
      href: location.href,
      title: document.title,
      readyState: document.readyState,
      prompt: info(prompt),
      send: info(send),
      stop: info(stop),
      plus: info(plus),
      ok: !!prompt,
    };
  })()`;
}

function markFileInputExpr(marker) {
  const mk = JSON.stringify(String(marker || ""));
  return `(() => {
    const marker = ${mk};
    const inputs = Array.from(document.querySelectorAll('input[type="file"]'));
    for (const i of inputs) {
      try { i.removeAttribute('data-hq-file-upload-target'); } catch {}
    }
    const preferred = inputs.find((i) => String(i.getAttribute('accept') || '') === '') || (inputs.length ? inputs[0] : null);
    if (!preferred) return { ok: false, reason: 'file_input_not_found', count: inputs.length };
    try { preferred.setAttribute('data-hq-file-upload-target', marker); } catch (_) {}
    const r = preferred.getBoundingClientRect();
    return {
      ok: true,
      count: inputs.length,
      accept: String(preferred.getAttribute('accept') || ''),
      multiple: !!preferred.multiple,
      rect: { x: r.x, y: r.y, width: r.width, height: r.height },
    };
  })()`;
}

function waitForFileVisibleExpr(fileName, timeoutMs) {
  const name = JSON.stringify(String(fileName || ""));
  const ms = Number(timeoutMs) || 0;
  return `(() => new Promise((resolve) => {
    const fileName = ${name};
    const timeoutMs = ${ms};
    const pageHasName = () => {
      const t = document.body ? String(document.body.innerText || '') : '';
      return t.includes(fileName);
    };
    if (pageHasName()) return resolve({ ok: true, waited_ms: 0 });
    let done = false;
    const start = Date.now();
    const finish = (v) => {
      if (done) return;
      done = true;
      try { mo.disconnect(); } catch (_) {}
      resolve(v);
    };
    const mo = new MutationObserver(() => {
      if (pageHasName()) finish({ ok: true, waited_ms: Date.now() - start });
    });
    try { mo.observe(document.documentElement, { subtree: true, childList: true, attributes: true, characterData: true }); } catch (_) {}
    setTimeout(() => finish({ ok: pageHasName(), waited_ms: Date.now() - start }), timeoutMs);
  }))()`;
}

function attachTextFileExpr(fileName, fileText) {
  const name = JSON.stringify(String(fileName || ""));
  const text = JSON.stringify(String(fileText || ""));
  return `(() => {
    const fileName = ${name};
    const fileText = ${text};
    const inputs = Array.from(document.querySelectorAll('input[type="file"]'));
    const input = inputs.find((i) => String(i.getAttribute('accept') || '') === '') || (inputs.length ? inputs[0] : null);
    if (!input) return { ok: false, reason: 'file_input_not_found', count: inputs.length };
    try { input.value = ''; } catch (_) {}
    const dt = new DataTransfer();
    dt.items.add(new File([fileText], fileName, { type: 'text/plain' }));
    try { input.files = dt.files; } catch (e) { return { ok: false, reason: 'assign_failed', error: String(e) }; }
    try { input.dispatchEvent(new Event('input', { bubbles: true })); } catch (_) {}
    try { input.dispatchEvent(new Event('change', { bubbles: true })); } catch (_) {}
    const names = input.files ? Array.from(input.files).map((f) => String(f && f.name ? f.name : '')) : [];
    return { ok: true, names };
  })()`;
}

function promptLenExpr() {
  return `(() => {
    const el = document.querySelector('#prompt-textarea') || document.querySelector('form textarea') || document.querySelector('form [contenteditable="true"]');
    if (!el) return { ok: false, reason: 'prompt_not_found' };
    const tag = String(el.tagName || '');
    const value = (tag === 'TEXTAREA' || tag === 'INPUT') ? String(el.value || '') : String(el.innerText || '');
    return { ok: true, len: value.length };
  })()`;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  cdpVersion(args.addr, args.port);

  const filePath = String(args.file || "");
  const fileName = filePath.split("/").pop() || filePath;
  const fileText = String(std.loadFile(filePath) || "");
  const text = args.textFile ? String(std.loadFile(args.textFile) || "") : String(args.text || "");

  const targets = cdpList(args.addr, args.port);
  const target = pickTarget(targets, args);
  const wsUrl = target.webSocketDebuggerUrl;

  let nextId = 1;
  const call = (method, params, timeoutMs) => {
    const req = { id: nextId++, method, params: params || {} };
    return cdpCall(wsUrl, req, timeoutMs || 60000);
  };
  const evalByValue = (expression, timeoutMs, awaitPromise) => {
    const resp = cdpEvaluate(wsUrl, expression, {
      id: nextId++,
      returnByValue: true,
      awaitPromise: !!awaitPromise,
      timeoutMs: timeoutMs || 60000,
    });
    return resp && resp.result && resp.result.result ? resp.result.result.value : null;
  };
  const mouseClick = (x, y) => {
    const pt = { x: Number(x) || 0, y: Number(y) || 0, button: "left", clickCount: 1 };
    call("Input.dispatchMouseEvent", { type: "mouseMoved", x: pt.x, y: pt.y });
    call("Input.dispatchMouseEvent", { type: "mousePressed", ...pt });
    call("Input.dispatchMouseEvent", { type: "mouseReleased", ...pt });
  };
  const keyTap = (key, code, vk, modifiers) => {
    const base = { key, code, windowsVirtualKeyCode: vk, nativeVirtualKeyCode: vk, modifiers: modifiers || 0 };
    call("Input.dispatchKeyEvent", { type: "keyDown", ...base });
    call("Input.dispatchKeyEvent", { type: "keyUp", ...base });
  };

  try { call("Page.bringToFront", {}); } catch {}
  sleepMs(args.waitMs);

  const before = evalByValue(locateComposerExpr(), 60000, false);
  if (!before || !before.ok) throw new Error("thread composer not found");
  if (before.stop) throw new Error("thread is generating; wait until idle and retry");

  const marker = `hq-upload-${Date.now()}`;
  const marked = evalByValue(markFileInputExpr(marker), 60000, false);
  if (!marked || !marked.ok) throw new Error("failed to mark composer file input: " + JSON.stringify(marked));

  const root = call("DOM.getDocument", { depth: 1 }, 60000);
  const rootId = root && root.result && root.result.root ? root.result.root.nodeId : 0;
  if (!rootId) throw new Error("DOM.getDocument returned no root node");

  let q = call("DOM.querySelector", { nodeId: rootId, selector: `input[data-hq-file-upload-target="${marker}"]` }, 60000);
  let nodeId = q && q.result ? q.result.nodeId : 0;
  if (!nodeId) {
    q = call("DOM.querySelector", { nodeId: rootId, selector: 'input[type="file"][accept=""]' }, 60000);
    nodeId = q && q.result ? q.result.nodeId : 0;
  }
  let upload = null;
  if (nodeId) {
    call("DOM.setFileInputFiles", { nodeId, files: [filePath] }, 60000);
    upload = { ok: true, mode: "dom_setFileInputFiles", nodeId };
  } else {
    const fallback = evalByValue(attachTextFileExpr(fileName, fileText), 60000, false);
    if (!fallback || !fallback.ok) {
      throw new Error("could not attach file via DOM or text fallback: " + JSON.stringify(fallback));
    }
    upload = { ...fallback, mode: "datatransfer_text_fallback" };
  }

  const uploaded = evalByValue(waitForFileVisibleExpr(fileName, args.timeoutMs), args.timeoutMs + 10000, true);

  let send = null;
  let afterType = null;
  if (text.length) {
    mouseClick(before.prompt.center.x, before.prompt.center.y);
    sleepMs(50);
    try {
      keyTap("a", "KeyA", 65, 2);
      keyTap("Backspace", "Backspace", 8, 0);
    } catch {}
    const chunkSize = 800;
    for (let i = 0; i < text.length; i += chunkSize) {
      call("Input.insertText", { text: text.slice(i, i + chunkSize) }, 60000);
    }
    afterType = evalByValue(locateComposerExpr(), 60000, false);
    if (afterType && afterType.send && afterType.send.disabled) {
      const start = Date.now();
      let last = afterType;
      while (Date.now() - start < 15000) {
        sleepMs(500);
        last = evalByValue(locateComposerExpr(), 60000, false) || last;
        if (last && last.send && !last.send.disabled) {
          afterType = last;
          break;
        }
      }
    }
    if (afterType && afterType.send && !afterType.send.disabled) {
      mouseClick(afterType.send.center.x, afterType.send.center.y);
      send = { how: "click_send" };
    } else {
      keyTap("Enter", "Enter", 13, 0);
      send = { how: "enter" };
    }
    sleepMs(500);
  }

  const after = evalByValue(promptLenExpr(), 30000, false);
  const result = {
    ok: true,
    target: { id: target.id, url: target.url, title: target.title },
    file: { path: filePath, name: fileName },
    before,
    mark: marked,
    attach: upload,
    upload: uploaded,
    afterType,
    send,
    after,
  };

  const out = JSON.stringify(result, null, 2) + "\n";
  if (args.outPath) std.writeFile(args.outPath, out);
  std.out.puts(out);
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
