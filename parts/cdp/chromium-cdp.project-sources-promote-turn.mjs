// Promote an assistant turn to Project Sources (Add to project sources).
//
// Why this exists
// - In the "threads as git worktrees" workflow, we want a deterministic way to
//   publish a specific worker answer into the project's shared Sources.
// - This promotes the *turn* (and any file chips attached to that turn) into
//   Project Sources. The file itself does not become a standalone Source row;
//   it remains downloadable from the promoted turn.
//
// Runtime: quickjs-ng (qjs) with --std
//
// Example
//   nix shell .#chromium-cdp-tools
//   qjs --std -m parts/cdp/chromium-cdp.project-sources-promote-turn.mjs \
//     --url "https://chatgpt.com/g/g-p-<project>/c/<thread>" \
//     --needle "SOURCE_ID: worktree-foo-001" \
//     --port 9223

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
    "usage: qjs --std -m chromium-cdp.project-sources-promote-turn.mjs --url <thread-url> [--needle <s>] [--latest] [--addr 127.0.0.1] [--port 9222] [--waitMs 800] [--timeoutMs 180000]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    needle: null,
    latest: false,
    waitMs: 800,
    timeoutMs: 180000,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--needle" && i + 1 < argv.length) out.needle = argv[++i];
    else if (a === "--latest") out.latest = true;
    else if (a === "--waitMs" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--timeoutMs" && i + 1 < argv.length) out.timeoutMs = Number(argv[++i]) || out.timeoutMs;
    else if (a === "-h" || a === "--help") return null;
    else return null;
  }

  if (!out.url) return null;
  if (!out.latest && !out.needle) {
    // Default is explicit needle, unless --latest is set.
    return null;
  }
  return out;
}

function extractConversationId(url) {
  const m = String(url || "").match(/\/c\/([0-9a-fA-F-]{16,})/);
  return m ? m[1] : null;
}

function pickTargetByUrl(targets, url) {
  const pages = (targets || []).filter((t) => t && t.type === "page" && t.webSocketDebuggerUrl);
  const u = String(url || "");
  let cands = pages.filter((t) => String(t.url || "") === u);
  if (cands.length === 0) cands = pages.filter((t) => String(t.url || "").startsWith(u));
  if (cands.length === 0) {
    const cid = extractConversationId(u);
    if (cid) cands = pages.filter((t) => String(t.url || "").includes(cid));
  }
  return cands.length ? cands[cands.length - 1] : null;
}

function openOrFind(args, url) {
  const found = pickTargetByUrl(cdpList(args.addr, args.port), url);
  return found || cdpNew(args.addr, args.port, url);
}

function mkCaller(wsUrl) {
  let nextId = 1;
  const shouldRetry = (e) => String(e || "").includes("WouldBlock");
  const withRetry = (fn) => {
    let last = null;
    for (let i = 0; i < 4; i++) {
      try {
        return fn();
      } catch (e) {
        last = e;
        if (!shouldRetry(e) || i === 3) throw e;
        sleepMs(150 + i * 200);
      }
    }
    throw last || new Error("retry failed");
  };
  const call = (method, params, timeoutMs) => {
    const req = { id: nextId++, method, params: params || {} };
    return withRetry(() => cdpCall(wsUrl, req, timeoutMs || 60000));
  };
  const evalValue = (expression, opts) => {
    const o = opts || {};
    const resp = withRetry(() => cdpEvaluate(wsUrl, expression, {
      id: nextId++,
      returnByValue: true,
      awaitPromise: !!o.awaitPromise,
      timeoutMs: o.timeoutMs || 60000,
    }));
    return resp && resp.result && resp.result.result ? resp.result.result.value : null;
  };
  return { call, evalValue };
}

function mouseClick(call, x, y) {
  const pt = { x: Number(x) || 0, y: Number(y) || 0, button: "left", clickCount: 1 };
  call("Input.dispatchMouseEvent", { type: "mouseMoved", x: pt.x, y: pt.y, button: "none" });
  call("Input.dispatchMouseEvent", { type: "mousePressed", ...pt });
  call("Input.dispatchMouseEvent", { type: "mouseReleased", ...pt });
}

function assistantSnapshotExpr(needle, latest) {
  const n = JSON.stringify(String(needle || ""));
  const l = latest ? "true" : "false";
  return `(() => {
    const needle = ${n};
    const latest = ${l};
    const stopSel = 'button[data-testid="stop-button"],button[aria-label="Stop generating"],button[aria-label="Stop streaming"],button[aria-label="Stop"],button[aria-label="停止"]';
    const generating = !!document.querySelector(stopSel);
    const assistants = Array.from(document.querySelectorAll('[data-message-author-role="assistant"]'));

    let matchText = '';
    for (let i = assistants.length - 1; i >= 0; i--) {
      const el = assistants[i];
      const txt = el ? String(el.textContent || el.innerText || '') : '';
      if (latest) {
        if (txt && txt.trim().length) { matchText = txt; break; }
      } else {
        if (needle && txt.includes(needle)) { matchText = txt; break; }
      }
    }

    const tailMax = 4096;
    const tail = matchText.length > tailMax ? matchText.slice(matchText.length - tailMax) : matchText;
    const has = latest ? !!matchText : (needle ? matchText.includes(needle) : false);
    return { generating, assistant_count: assistants.length, has, match_tail: tail };
  })()`;
}

function waitForAssistant(thread, needle, latest, timeoutMs) {
  const timeout = Math.max(0, Number(timeoutMs) || 0);
  const start = Date.now();
  let last = null;
  while (Date.now() - start < timeout) {
    last = thread.evalValue(assistantSnapshotExpr(needle, latest), { timeoutMs: 60000 }) || null;
    if (last && !last.generating && last.has) return { ok: true, timed_out: false, last };
    sleepMs(700);
  }
  return { ok: false, timed_out: true, last };
}

function clickPromoteTurnExpr(needle, latest, timeoutMs) {
  const n = JSON.stringify(String(needle || ""));
  const l = latest ? "true" : "false";
  const ms = Math.max(0, Number(timeoutMs) || 0);
  return `(() => new Promise((resolve) => {
    const needle = ${n};
    const latest = ${l};
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    const assistants = Array.from(document.querySelectorAll('[data-message-author-role="assistant"]'));
    const pickAssistant = () => {
      for (let i = assistants.length - 1; i >= 0; i--) {
        const el = assistants[i];
        const txt = String(el && (el.textContent || el.innerText || '') || '');
        if (latest) {
          if (txt.trim().length) return el;
        } else {
          if (needle && txt.includes(needle)) return el;
        }
      }
      return null;
    };
    const a = pickAssistant();
    if (!a) return resolve({ ok: false, reason: 'assistant_not_found' });
    const turn = a.closest('[data-testid^="conversation-turn-"]');
    const btn = turn ? turn.querySelector('button[data-testid="project-save-turn-action-button"]') : null;
    if (!btn) return resolve({ ok: false, reason: 'promote_button_not_found' });
    const aria0 = String(btn.getAttribute('aria-label') || '');
    if (aria0.includes('Remove from project sources')) {
      return resolve({ ok: true, already: true, aria: aria0, turn_testid: turn ? String(turn.getAttribute('data-testid') || '') : '' });
    }

    // Collect file chips visible in the same turn.
    const chips = [];
    if (turn) {
      const btns = Array.from(turn.querySelectorAll('button')).filter(isVisible);
      for (const b of btns) {
        const t = String(b.innerText || '').trim();
        if (!t) continue;
        if (t.length > 180) continue;
        if (!t.includes('.')) continue;
        // Heuristic: typical artifact extensions.
        const low = t.toLowerCase();
        if (!(low.endsWith('.txt') || low.endsWith('.diff') || low.endsWith('.patch') || low.endsWith('.zip') || low.endsWith('.json') || low.endsWith('.md'))) continue;
        chips.push(t);
      }
    }

    try { btn.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    try { btn.click(); } catch (_) {}

    let done = false;
    const start = Date.now();
    const finish = (timedOut) => {
      if (done) return;
      done = true;
      try { mo.disconnect(); } catch (_) {}
      const aria = String(btn.getAttribute('aria-label') || '');
      resolve({
        ok: !timedOut && aria.includes('Remove from project sources'),
        timed_out: !!timedOut,
        waited_ms: Date.now() - start,
        aria,
        aria_before: aria0,
        turn_testid: turn ? String(turn.getAttribute('data-testid') || '') : '',
        file_chips: chips,
      });
    };

    const mo = new MutationObserver(() => {
      const aria = String(btn.getAttribute('aria-label') || '');
      if (aria.includes('Remove from project sources')) finish(false);
    });
    try { mo.observe(btn, { attributes: true, attributeFilter: ['aria-label'] }); } catch (_) {}
    setTimeout(() => finish(true), ${ms});
  }))()`;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  cdpVersion(args.addr, args.port);
  const target = openOrFind(args, args.url);
  const thread = mkCaller(target.webSocketDebuggerUrl);
  try { thread.call("Page.bringToFront", {}); } catch {}
  sleepMs(args.waitMs);

  const waited = waitForAssistant(thread, args.needle, args.latest, args.timeoutMs);
  const promote = thread.evalValue(clickPromoteTurnExpr(args.needle, args.latest, 60000), {
    awaitPromise: true,
    timeoutMs: 70000,
  });

  const ok = !!(waited && waited.ok) && !!(promote && promote.ok);
  const result = {
    ok,
    addr: args.addr,
    port: args.port,
    url: args.url,
    needle: args.needle,
    latest: !!args.latest,
    target: { id: target.id, title: target.title, url: target.url },
    waited,
    promote,
  };

  std.out.puts(JSON.stringify(result, null, 2) + "\n");
  std.out.flush();
  return ok ? 0 : 1;
}

try {
  std.exit(main(scriptArgs));
} catch (e) {
  std.err.puts(String(e) + "\n");
  if (e && e.stack) std.err.puts(String(e.stack) + "\n");
  std.err.flush();
  std.exit(1);
}
