import { cdpCall, cdpEvaluate, cdpList, cdpVersion } from "./chromium-cdp.lib.mjs";

const addr = "127.0.0.1";
const port = 9222;
const targetId = "F092B35456F9A4F8FFCD04D880CD2173";

cdpVersion(addr, port);
const targets = cdpList(addr, port);
const target = targets.find(t => t.id === targetId);
if (!target) throw new Error("target not found: " + targetId);

const wsUrl = target.webSocketDebuggerUrl;

const expr = `(() => {
  const nodes = Array.from(document.querySelectorAll("main [data-message-author-role]"));
  const msgs = nodes.map((n, i) => ({
    idx: i,
    role: n.getAttribute("data-message-author-role") || "",
    text: (n.innerText || "").trim()
  })).filter(m => m.text.length);
  return msgs.slice(-5);
})()`;

const resp = cdpEvaluate(wsUrl, expr, {
  id: 2,
  returnByValue: true,
  awaitPromise: false,
  timeoutMs: 60000,
});

const value = resp?.result?.result?.value;
std.out.puts(JSON.stringify(value, null, 2) + "\n");
std.out.flush();
