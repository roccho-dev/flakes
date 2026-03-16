// Send a message in an existing ChatGPT tab via CDP (no jq/node).
//
// Typical flow:
//   nix shell .#chromium-cdp-tools
//   chromium-cdp "https://chatgpt.com" &
//   # Login manually, open the target thread URL in that browser.
//   export HQ_CHROME_ADDR=127.0.0.1 HQ_CHROME_PORT=9222
//   qjs --std -m parts/chromedevtoolprotocol/chromium-cdp.send-chatgpt.mjs \
//     --url "https://chatgpt.com/c/<thread>" --text-file /tmp/handoff.txt

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
    "usage: qjs --std -m chromium-cdp.send-chatgpt.mjs --url <thread-url> (--text <s> | --text-file <path>) [--addr 127.0.0.1] [--port 9222] [--wait-ms 0] [--id <targetId>]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    id: null,
    waitMs: 0,
    text: null,
    textFile: null,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--id" && i + 1 < argv.length) out.id = argv[++i];
    else if (a === "--wait-ms" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--text" && i + 1 < argv.length) out.text = argv[++i];
    else if (a === "--text-file" && i + 1 < argv.length) out.textFile = argv[++i];
    else if (a === "-h" || a === "--help") return null;
    else {
      std.err.puts(`unknown arg: ${a}\n`);
      return null;
    }
  }

  if (!out.url) return null;
  if (!out.text && !out.textFile) return null;
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

  if (cands.length === 0) {
    cands = pages.filter((t) => String(t.url || "").startsWith(url));
  }

  if (cands.length === 0) {
    const cid = extractConversationId(url);
    if (cid) cands = pages.filter((t) => String(t.url || "").includes(cid));
  }

  if (cands.length === 1) return cands[0];

  // Avoid sending to the wrong tab.
  const preview = pages.map((t) => ({ id: t.id, title: t.title, url: t.url }));
  const msg =
    cands.length === 0
      ? "no matching page target found; open the thread in Chromium and retry"
      : "multiple matching page targets; pass --id to disambiguate";
  throw new Error(`${msg}:\n${JSON.stringify(preview, null, 2)}`);
}

function locateComposerExpr() {
  return `(() => {
    const out = {
      href: location.href,
      title: document.title,
      readyState: document.readyState,
    };

    const pick = (...sels) => {
      for (const s of sels) {
        try {
          const el = document.querySelector(s);
          if (el) return el;
        } catch {}
      }
      return null;
    };

    const info = (el) => {
      if (!el) return null;
      try { el.scrollIntoView({ block: "center", inline: "center" }); } catch {}
      const r = el.getBoundingClientRect();
      const tag = String(el.tagName || "");
      const aria = String(el.getAttribute("aria-label") || "");
      const testid = String(el.getAttribute("data-testid") || "");
      const role = String(el.getAttribute("role") || "");
      const id = String(el.id || "");
      const disabled = !!el.disabled;
      const rect = { x: r.x, y: r.y, width: r.width, height: r.height };
      const center = { x: r.x + r.width / 2, y: r.y + r.height / 2 };
      let valueLen = 0;
      try {
        if (tag === "TEXTAREA" || tag === "INPUT") valueLen = String(el.value || "").length;
        else valueLen = String(el.innerText || "").length;
      } catch {}
      return { tag, id, aria, testid, role, disabled, valueLen, rect, center, contentEditable: !!el.isContentEditable };
    };

    const prompt = pick(
      "#prompt-textarea",
      "textarea#prompt-textarea",
      "textarea[data-testid='prompt-textarea']",
      "form textarea",
      "form [contenteditable='true']"
    );

    const send =
      pick(
        "button[data-testid='send-button']",
        "button[aria-label='Send prompt']",
        "button[aria-label='Send message']",
        "button[aria-label='Send']",
        "button[aria-label='送信']"
      ) ||
      (prompt && prompt.closest && prompt.closest("form")
        ? prompt.closest("form").querySelector("button[type='submit']")
        : null);

    const stop = pick(
      "button[data-testid='stop-button']",
      "button[aria-label='Stop generating']",
      "button[aria-label='Stop']",
      "button[aria-label='停止']"
    );

    out.prompt = info(prompt);
    out.send = info(send);
    out.stop = info(stop);
    out.ok = !!out.prompt;
    if (!out.ok) out.reason = "prompt_not_found";
    return out;
  })()`;
}

function promptLenExpr() {
  return `(() => {
    const el = document.querySelector("#prompt-textarea") || document.querySelector("textarea[data-testid='prompt-textarea']") || document.querySelector("form textarea") || document.querySelector("form [contenteditable='true']");
    if (!el) return { ok: false, reason: "prompt_not_found" };
    const tag = String(el.tagName || "");
    let value = "";
    if (tag === "TEXTAREA" || tag === "INPUT") value = String(el.value || "");
    else value = String(el.innerText || "");
    return { ok: true, len: value.length };
  })()`;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  const text = args.textFile ? String(std.loadFile(args.textFile) || "") : String(args.text || "");
  if (!text.length) {
    throw new Error("text is empty");
  }

  // Ensure CDP is up.
  cdpVersion(args.addr, args.port);

  const targets = cdpList(args.addr, args.port);
  const target = pickTarget(targets, args);
  const wsUrl = target.webSocketDebuggerUrl;

  let nextId = 1;
  const call = (method, params, timeoutMs) => {
    const req = { id: nextId++, method, params };
    return cdpCall(wsUrl, req, timeoutMs || 60000);
  };

  const evalByValue = (expression, timeoutMs) => {
    const resp = cdpEvaluate(wsUrl, expression, {
      id: nextId++,
      returnByValue: true,
      awaitPromise: false,
      timeoutMs: timeoutMs || 60000,
    });
    return resp?.result?.result?.value;
  };

  const mouseClick = (x, y) => {
    const pt = { x: Number(x) || 0, y: Number(y) || 0, button: "left", clickCount: 1 };
    call("Input.dispatchMouseEvent", { type: "mouseMoved", x: pt.x, y: pt.y });
    call("Input.dispatchMouseEvent", { type: "mousePressed", ...pt });
    call("Input.dispatchMouseEvent", { type: "mouseReleased", ...pt });
  };

  const keyTap = (key, code, vk, modifiers) => {
    const base = {
      key,
      code,
      windowsVirtualKeyCode: vk,
      nativeVirtualKeyCode: vk,
      modifiers: modifiers || 0,
    };
    call("Input.dispatchKeyEvent", { type: "keyDown", ...base });
    call("Input.dispatchKeyEvent", { type: "keyUp", ...base });
  };

  // Bring to front and give the user-configurable initial settle time.
  try {
    call("Page.bringToFront", {});
  } catch {
    // ignore
  }
  sleepMs(args.waitMs);

  const before = evalByValue(locateComposerExpr(), 60000);
  if (!before || !before.ok) {
    std.out.puts(JSON.stringify({ target: { id: target.id, url: target.url, title: target.title }, before }, null, 2) + "\n");
    std.out.flush();
    throw new Error("prompt not found; open the thread in Chromium (logged in) and retry");
  }
  if (before.stop) {
    throw new Error("page is generating; wait until idle (no stop button) and retry");
  }

  // Focus prompt via a real click.
  mouseClick(before.prompt.center.x, before.prompt.center.y);
  sleepMs(50);

  // Best-effort clear: Ctrl+A then Backspace.
  // Modifiers bitfield: Alt=1, Ctrl=2, Meta=4, Shift=8.
  try {
    keyTap("a", "KeyA", 65, 2);
    keyTap("Backspace", "Backspace", 8, 0);
  } catch {
    // ignore
  }

  // Type text in chunks to avoid huge argv payloads.
  const chunkSize = 800;
  for (let i = 0; i < text.length; i += chunkSize) {
    const chunk = text.slice(i, i + chunkSize);
    call("Input.insertText", { text: chunk });
  }

  // Re-locate send button after typing (DOM may update).
  const afterType = evalByValue(locateComposerExpr(), 60000);

  let sendHow = "unknown";
  if (afterType && afterType.send && !afterType.send.disabled) {
    mouseClick(afterType.send.center.x, afterType.send.center.y);
    sendHow = "click_send";
  } else {
    // Fallback: press Enter.
    keyTap("Enter", "Enter", 13, 0);
    sendHow = "enter";
  }

  // One-shot confirmation: prompt should clear shortly after sending.
  sleepMs(500);
  const after = evalByValue(promptLenExpr(), 30000);

  std.out.puts(
    JSON.stringify(
      {
        target: { id: target.id, url: target.url, title: target.title },
        before,
        afterType,
        send: { how: sendHow },
        after,
      },
      null,
      2,
    ) + "\n",
  );
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
