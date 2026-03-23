// ChatGPT search and thread reader via CDP.
// Usage:
//   qjs --std -m chromium-cdp.search-chatgpt.mjs --help
//   qjs --std -m chromium-cdp.search-chatgpt.mjs --search "query" [--target-id ID] [--addr ADDR] [--port PORT]
//   qjs --std -m chromium-cdp.search-chatgpt.mjs --read URL [--target-id ID] [--addr ADDR] [--port PORT]

import { cdpCall, cdpList, cdpNew, cdpEvaluate, sleepMs, getDefaultAddr, getDefaultPort } from "./chromium-cdp.lib.mjs";

const SEARCH_INPUT_SELECTORS = [
  "input[placeholder='Search chats...']",
  "input[type='search']",
  "form input",
];

const MSG_SELECTOR = "[data-message-author-role]";
const THREAD_LINK_SELECTOR = "a[href*='/c/']";

function evalByValue(wsUrl, expression, timeoutMs) {
  const result = cdpEvaluate(wsUrl, expression, { returnByValue: true, timeoutMs: timeoutMs || 15000 });
  return result?.result?.result?.value;
}

function clickElement(wsUrl, x, y) {
  cdpCall(wsUrl, { id: 99, method: "Input.dispatchMouseEvent", params: { type: "mouseMoved", x, y } }, 3000);
  cdpCall(wsUrl, { id: 100, method: "Input.dispatchMouseEvent", params: { type: "mousePressed", x, y, button: "left", clickCount: 1 } }, 3000);
  cdpCall(wsUrl, { id: 101, method: "Input.dispatchMouseEvent", params: { type: "mouseReleased", x, y, button: "left", clickCount: 1 } }, 3000);
}

function sendKey(wsUrl, key, code, modifiers) {
  modifiers = modifiers || 0;
  cdpCall(wsUrl, { id: 102, method: "Input.dispatchKeyEvent", params: { type: "keyDown", key, code, windowsVirtualKeyCode: 0, nativeVirtualKeyCode: 0, modifiers } }, 3000);
  cdpCall(wsUrl, { id: 103, method: "Input.dispatchKeyEvent", params: { type: "keyUp", key, code, windowsVirtualKeyCode: 0, nativeVirtualKeyCode: 0, modifiers } }, 3000);
}

function sendText(wsUrl, text) {
  cdpCall(wsUrl, { id: 104, method: "Input.insertText", params: { text } }, 5000);
}

function openSearchDialog(wsUrl) {
  sendKey(wsUrl, "k", "KeyK", 2);
  sleepMs(800);
  return { ok: true };
}

function search(wsUrl, query) {
  openSearchDialog(wsUrl);
  sleepMs(500);
  
  sendKey(wsUrl, "a", "KeyA", 2);
  sleepMs(100);
  sendText(wsUrl, query);
  sleepMs(1000);
  sendKey(wsUrl, "Enter", "Enter");
  sleepMs(3000);
  return { ok: true };
}

function getSearchResults(wsUrl) {
  const code = "Array.from(document.querySelectorAll('" + THREAD_LINK_SELECTOR + "')).map(a => ({ href: a.href, title: a.textContent ? a.textContent.trim().slice(0, 200) : '' }))";
  return evalByValue(wsUrl, code, 10000) || [];
}

function getMessages(wsUrl, maxCount) {
  maxCount = maxCount || 200;
  const code = "Array.from(document.querySelectorAll('" + MSG_SELECTOR + "')).slice(0," + maxCount + ").map((el, i) => ({ idx: i, role: el.getAttribute('data-message-author-role'), text: (el.innerText || '').slice(0, 5000) }))";
  return evalByValue(wsUrl, code, 15000) || [];
}

function waitForThreadLoad(wsUrl, timeoutMs) {
  timeoutMs = timeoutMs || 30000;
  const start = Date.now();
  while (Date.now() - start < timeoutMs) {
    const state = evalByValue(wsUrl, "({ readyState: document.readyState, msgCount: document.querySelectorAll('" + MSG_SELECTOR + "').length, href: location.href })", 5000);
    if (state && state.readyState === "complete" && state.msgCount > 0) {
      return { ok: true, msgCount: state.msgCount, href: state.href };
    }
    sleepMs(2000);
  }
  return { ok: false, reason: "timeout" };
}

function findTargetByUrl(addr, port, url) {
  const targets = cdpList(addr, port);
  if (!targets || !Array.isArray(targets)) return null;
  return targets.find(t => t.url === url || (t.url && t.url.includes(url.split("/").pop())));
}

function findOrCreateTarget(addr, port, url) {
  const existing = findTargetByUrl(addr, port, url);
  if (existing) {
    return { ok: true, target: existing, created: false };
  }

  try {
    const newTarget = cdpNew(addr, port, url);
    if (newTarget && newTarget.id) {
      return { ok: true, target: newTarget, created: true };
    }
  } catch (e) {}

  try {
    const blank = cdpNew(addr, port, "about:blank");
    if (blank && blank.id) {
      const wsUrl = blank.webSocketDebuggerUrl;
      cdpCall(wsUrl, { id: 1, method: "Page.navigate", params: { url } }, 30000);
      return { ok: true, target: { id: blank.id, url: url, webSocketDebuggerUrl: wsUrl }, created: true };
    }
  } catch (e) {}

  return { ok: false, reason: "cannot_create_target" };
}

function parseArgs(argv) {
  const args = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    targetId: null,
    search: null,
    read: null,
    readTail: null,
    help: false,
  };

  for (let i = 0; i < argv.length; i++) {
    const arg = argv[i];
    if (arg === "--help" || arg === "-h") args.help = true;
    else if (arg === "--addr" && argv[i + 1]) args.addr = argv[++i];
    else if (arg === "--port" && argv[i + 1]) args.port = Number(argv[++i]);
    else if (arg === "--target-id" && argv[i + 1]) args.targetId = argv[++i];
    else if (arg === "--search" && argv[i + 1]) args.search = argv[++i];
    else if (arg === "--read" && argv[i + 1]) args.read = argv[++i];
    else if (arg === "--tail" && argv[i + 1]) args.readTail = Number(argv[++i]);
  }
  return args;
}

function main(argv) {
  const args = parseArgs(argv);

  if (args.help) {
    std.out.puts("ChatGPT Search and Thread Reader via CDP\n\nUsage:\n  qjs --std -m chromium-cdp.search-chatgpt.mjs --search QUERY [--addr ADDR] [--port PORT]\n  qjs --std -m chromium-cdp.search-chatgpt.mjs --read URL [--tail N] [--addr ADDR] [--port PORT]\n  qjs --std -m chromium-cdp.search-chatgpt.mjs --help\n\nOptions:\n  --addr ADDR    CDP address (default: 127.0.0.1)\n  --port PORT    CDP port (default: 9222)\n  --target-id ID  Use specific CDP target\n  --search QUERY  Search ChatGPT chats\n  --read URL      Read thread at URL\n  --tail N        Show last N messages\n");
    return 0;
  }

  if (!args.search && !args.read) {
    std.err.puts("Error: specify --search or --read\n");
    return 1;
  }

  let wsUrl = null;
  let target = null;

  if (args.targetId) {
    const targets = cdpList(args.addr, args.port);
    if (targets && Array.isArray(targets)) {
      target = targets.find(t => t.id === args.targetId);
    }
    if (!target) {
      std.err.puts("Error: target " + args.targetId + " not found\n");
      return 1;
    }
    wsUrl = target.webSocketDebuggerUrl;
  }

  if (args.search) {
    if (!wsUrl) {
      const result = findOrCreateTarget(args.addr, args.port, "https://chatgpt.com/");
      if (!result.ok) {
        std.err.puts("Error: cannot find or create ChatGPT tab\n");
        return 1;
      }
      target = result.target;
      wsUrl = target.webSocketDebuggerUrl;
      sleepMs(3000);
    }

    const result = search(wsUrl, args.search);
    if (!result.ok) {
      std.err.puts("Search failed: " + result.reason + "\n");
      return 1;
    }

    const results = getSearchResults(wsUrl);
    std.out.puts(JSON.stringify({
      query: args.search,
      target: target ? target.id : null,
      results: results,
    }, null, 2) + "\n");
  }

  if (args.read) {
    if (!wsUrl) {
      const result = findOrCreateTarget(args.addr, args.port, args.read);
      if (!result.ok) {
        std.err.puts("Error: cannot open thread: " + result.reason + "\n");
        return 1;
      }
      target = result.target;
      wsUrl = target.webSocketDebuggerUrl;

      waitForThreadLoad(wsUrl);
    }

    const msgs = getMessages(wsUrl, args.readTail || 200);
    const outputMsgs = args.readTail ? msgs.slice(-args.readTail) : msgs;
    
    std.out.puts(JSON.stringify({
      url: args.read,
      target: target ? target.id : null,
      msgCount: msgs.length,
      messages: outputMsgs,
    }, null, 2) + "\n");
  }

  return 0;
}

std.exit(main(scriptArgs));
