// Collect file-chip artifacts from a Project Source created via "Add to project sources".
//
// What this does
// - Open the Project's Sources page
// - Scan the newest Sources entries
// - For each entry, open it and check whether it contains a marker string
// - When found, download the requested file chips from that promoted turn
//
// Runtime: quickjs-ng (qjs) with --std
//
// Example
//   nix shell .#chromium-cdp-tools
//   qjs --std -m parts/chromedevtoolprotocol/chromium-cdp.project-sources-collect-files.mjs \
//     --projectUrl "https://chatgpt.com/g/g-p-<project>/project" \
//     --needle "SOURCE_ID: worktree-foo-001" \
//     --outDir /tmp/hq_sources_collect \
//     --name PATCH.diff \
//     --name repo.bundle \
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
    "usage: qjs --std -m chromium-cdp.project-sources-collect-files.mjs --projectUrl <.../project> --needle <s> --outDir <dir> [--name <file> ... | --all | --findOnly] [--limit 25] [--downloadsDir <dir>] [--force] [--addr 127.0.0.1] [--port 9222] [--waitMs 800] [--timeoutMs 240000] [--pollMs 200]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    projectUrl: null,
    needle: null,
    outDir: null,
    downloadsDir: null,
    names: [],
    all: false,
    findOnly: false,
    reuseExisting: true,
    limit: 25,
    waitMs: 800,
    timeoutMs: 240000,
    pollMs: 200,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--projectUrl" && i + 1 < argv.length) out.projectUrl = argv[++i];
    else if (a === "--needle" && i + 1 < argv.length) out.needle = argv[++i];
    else if (a === "--outDir" && i + 1 < argv.length) out.outDir = argv[++i];
    else if (a === "--downloadsDir" && i + 1 < argv.length) out.downloadsDir = argv[++i];
    else if (a === "--name" && i + 1 < argv.length) out.names.push(argv[++i]);
    else if (a === "--all") out.all = true;
    else if (a === "--findOnly") out.findOnly = true;
    else if (a === "--force") out.reuseExisting = false;
    else if (a === "--limit" && i + 1 < argv.length) out.limit = Number(argv[++i]) || out.limit;
    else if (a === "--waitMs" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--timeoutMs" && i + 1 < argv.length) out.timeoutMs = Number(argv[++i]) || out.timeoutMs;
    else if (a === "--pollMs" && i + 1 < argv.length) out.pollMs = Number(argv[++i]) || out.pollMs;
    else if (a === "-h" || a === "--help") return null;
    else return null;
  }

  if (!out.projectUrl) return null;
  if (!out.needle) return null;
  if (!out.outDir) return null;

  if (!out.downloadsDir) {
    const home = String(std.getenv("HOME") || "");
    out.downloadsDir = home ? `${home}/Downloads` : "./Downloads";
  }

  if (!out.findOnly && !out.all && (!out.names || out.names.length === 0)) {
    // Make it explicit: either specify names/--all, or opt into --findOnly.
    return null;
  }

  return out;
}

function ensureDir(path) {
  const rc = os.exec(["mkdir", "-p", String(path || "")], { block: true, stdout: 2, stderr: 2 });
  if (rc !== 0) throw new Error(`mkdir -p failed rc=${rc}: ${path}`);
}

function joinPath(a, b) {
  const left = String(a || "");
  const right = String(b || "");
  if (!left) return right;
  if (!right) return left;
  if (left.endsWith("/")) return left + (right.startsWith("/") ? right.slice(1) : right);
  return left + (right.startsWith("/") ? right : "/" + right);
}

function escapeRegex(text) {
  return String(text || "").replace(/[.*+?^${}()|[\]\\]/g, "\\$&");
}

function buildDownloadedNameRegex(name) {
  const s = String(name || "");
  const dot = s.lastIndexOf(".");
  const base = dot >= 0 ? s.slice(0, dot) : s;
  const ext = dot >= 0 ? s.slice(dot) : "";
  const pattern = "^" + escapeRegex(base) + "( \\([0-9]+\\))?" + escapeRegex(ext) + "$";
  return new RegExp(pattern);
}

function osTuple(result, op) {
  if (Array.isArray(result) && result.length >= 2) {
    const v = result[0];
    const err = result[1];
    if (err && Number(err) !== 0) throw new Error(`${op} errno=${err}`);
    return v;
  }
  return result;
}

function listDir(dir) {
  const v = osTuple(os.readdir(dir), `readdir(${dir})`);
  if (!Array.isArray(v)) throw new Error(`unexpected readdir result for ${dir}`);
  return v;
}

function tryStat(path) {
  try {
    const v = osTuple(os.stat(path), `stat(${path})`);
    if (!v || typeof v !== "object") return null;
    return v;
  } catch {
    return null;
  }
}

function listMatchingFiles(dir, nameRegex) {
  const names = listDir(dir);
  const out = [];
  for (const n of names) {
    if (!n || n === "." || n === "..") continue;
    if (!nameRegex.test(n)) continue;
    const p = joinPath(dir, n);
    const st = tryStat(p);
    if (!st) continue;
    out.push({ name: n, path: p, size: Number(st.size) || 0, mtime: Number(st.mtime) || 0 });
  }
  out.sort((a, b) => (b.mtime - a.mtime) || (b.size - a.size));
  return out;
}

function copyFile(src, dest) {
  const rc = os.exec(["cp", "-f", src, dest], { block: true, stdout: 2, stderr: 2 });
  if (rc !== 0) throw new Error(`cp failed rc=${rc}: ${src} -> ${dest}`);
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
  call("Input.dispatchMouseEvent", { type: "mouseMoved", x: pt.x, y: pt.y });
  call("Input.dispatchMouseEvent", { type: "mousePressed", ...pt });
  call("Input.dispatchMouseEvent", { type: "mouseReleased", ...pt });
}

function normalizeProjectSourcesUrl(projectUrl) {
  const u = String(projectUrl || "");
  if (!u) return u;
  if (u.includes("tab=sources")) return u;
  if (u.includes("?")) return u + "&tab=sources";
  return u + "?tab=sources";
}

function listSourcesEntriesExpr(limit) {
  const lim = Math.max(1, Math.min(200, Number(limit) || 25));
  return `(() => {
    const limit = ${lim};
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    const yearRx = /\\b(19|20)\\d{2}\\b/;
    const btns = Array.from(document.querySelectorAll('button')).filter(isVisible);
    const out = [];
    for (const b of btns) {
      const t = String(b.innerText || '').trim();
      if (!t) continue;
      if (!yearRx.test(t)) continue;
      // Exclude obvious non-rows.
      if (t === 'Newest' || t === 'All' || t === 'Add sources') continue;
      const r = b.getBoundingClientRect();
      if (r.width < 120 || r.height < 28) continue;
      // Require "cursor" hint if present.
      const cls = String(b.className || '');
      if (cls && !cls.includes('cursor')) continue;
      const lines = t.split('\\n').map((s) => String(s || '').trim()).filter((s) => s.length);
      const label = lines.length ? lines[0] : t;
      const date = lines.length >= 2 ? lines[lines.length - 1] : '';

       // Click target: the label span (more reliable than button center).
       let clickX = r.left + Math.min(96, Math.max(24, r.width * 0.25));
       let clickY = r.top + r.height / 2;
       try {
         const kids = Array.from(b.querySelectorAll('span,div,p')).filter(isVisible);
         for (const el of kids) {
           const txt = String(el.innerText || '').trim();
           if (txt !== label) continue;
           const kr = el.getBoundingClientRect();
           if (kr.width < 10 || kr.height < 10) continue;
           clickX = kr.left + kr.width / 2;
           clickY = kr.top + kr.height / 2;
           break;
         }
       } catch (_) {
         // ignore
       }

      out.push({
        label,
        date,
        text: t,
        x: r.left + r.width / 2,
        y: r.top + r.height / 2,
        click_x: clickX,
        click_y: clickY,
        w: r.width,
        h: r.height,
      });
    }
    out.sort((a, b) => (a.y - b.y) || (a.x - b.x));
    return { ok: true, entry_count: out.length, entries: out.slice(0, limit) };
  })()`;
}

function scrollToBottomExpr() {
  return `(() => {
    try {
      const cands = Array.from(document.querySelectorAll("main, body, [data-testid*='scroll' i], [class*='scroll' i]"))
        .filter((el) => el && el.scrollHeight && el.clientHeight && el.scrollHeight > el.clientHeight);
      cands.sort((a, b) => (b.scrollHeight - b.clientHeight) - (a.scrollHeight - a.clientHeight));
      const el = cands[0] || null;
      if (el) el.scrollTop = el.scrollHeight;
      try { window.scrollTo(0, document.body.scrollHeight); } catch (_) {}
      return true;
    } catch (_) {
      return false;
    }
  })()`;
}

function pageContainsNeedleExpr(needle) {
  const n = JSON.stringify(String(needle || ""));
  return `(() => {
    const needle = ${n};
    if (!needle) return { ok: false, has: false, has_role: false, has_body: false };
    const nodes = Array.from(document.querySelectorAll('[data-message-author-role="assistant"],[data-message-author-role="user"]'));
    for (let i = nodes.length - 1; i >= 0; i--) {
      const el = nodes[i];
      const txt = String(el && (el.textContent || el.innerText || '') || '');
      if (txt.includes(needle)) return { ok: true, has: true, has_role: true, has_body: true };
    }
    const body = document.body ? String(document.body.innerText || '') : '';
    const hasBody = !!(body && body.includes(needle));
    return { ok: true, has: false, has_role: false, has_body: hasBody };
  })()`;
}

function waitForNeedle(project, needle, timeoutMs, pollMs) {
  const timeout = Math.max(0, Number(timeoutMs) || 0);
  const poll = Math.max(50, Number(pollMs) || 200);
  const deadline = Date.now() + timeout;
  let last = null;
  while (Date.now() < deadline) {
    // Ensure the promoted turn is actually materialized (Chat UI is virtualized).
    try { project.evalValue(scrollToBottomExpr(), { timeoutMs: 60000 }); } catch {}
    sleepMs(250);
    last = project.evalValue(pageContainsNeedleExpr(needle), { timeoutMs: 60000 });
    // Avoid SPA stale-content false positives: require a match inside a role turn.
    if (last && last.ok && last.has_role) return { ok: true, timed_out: false, last };
    sleepMs(poll);
  }
  return { ok: false, timed_out: true, last };
}

function locateChipInNeedleTurnExpr(needle, name) {
  const n = JSON.stringify(String(needle || ""));
  const nm = JSON.stringify(String(name || ""));
  return `(() => {
    const needle = ${n};
    const name = ${nm};
    const norm = (s) => String(s || '').trim();
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    if (!needle || !name) return { ok: false, reason: 'missing_args' };

    const nodes = Array.from(document.querySelectorAll('[data-message-author-role="assistant"],[data-message-author-role="user"]'));
    let hit = null;
    for (let i = nodes.length - 1; i >= 0; i--) {
      const el = nodes[i];
      const txt = String(el && (el.textContent || el.innerText || '') || '');
      if (txt.includes(needle)) { hit = el; break; }
    }
    if (!hit) return { ok: false, reason: 'needle_turn_not_found' };
    const turn = hit.closest('[data-testid^="conversation-turn-"]');
    if (!turn) return { ok: false, reason: 'turn_container_not_found' };
    try { turn.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    const buttons = Array.from(turn.querySelectorAll('button')).filter(isVisible);
    let b =
      buttons.find((x) => norm(x.innerText) === name) ||
      buttons.find((x) => norm(x.getAttribute('aria-label')) === name) ||
      buttons.find((x) => norm(x.getAttribute('title')) === name) ||
      buttons.find((x) => norm(x.innerText).includes(name));
    if (!b) return { ok: false, reason: 'chip_not_found_in_turn' };
    try { b.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    const r = b.getBoundingClientRect();
    return { ok: true, x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height };
  })()`;
}

function locateFileChipExpr(name) {
  const nameJson = JSON.stringify(String(name || ""));
  return `(() => {
    const name = ${nameJson};
    const norm = (s) => String(s || '').trim();
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== "none" && getComputedStyle(el).visibility !== "hidden";
    const buttons = Array.from(document.querySelectorAll('button')).filter(isVisible);
    let el =
      buttons.find((b) => norm(b.innerText) === name) ||
      buttons.find((b) => norm(b.getAttribute('aria-label')) === name) ||
      buttons.find((b) => norm(b.getAttribute('title')) === name) ||
      buttons.find((b) => norm(b.innerText).includes(name));
    if (!el) return { ok: false, reason: 'not_found' };
    try { el.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    const r = el.getBoundingClientRect();
    return { ok: true, x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height };
  })()`;
}

function listAllFileChipsExpr() {
  return `(() => {
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    const btns = Array.from(document.querySelectorAll('button')).filter(isVisible);
    const out = [];
    for (const b of btns) {
      const t = String(b.innerText || '').trim();
      if (!t) continue;
      if (t.length > 180) continue;
      if (!t.includes('.')) continue;
      const low = t.toLowerCase();
      if (!(low.endsWith('.txt') || low.endsWith('.diff') || low.endsWith('.patch') || low.endsWith('.zip') || low.endsWith('.json') || low.endsWith('.md'))) continue;
      out.push(t);
    }
    // Preserve visual order by DOM order; dedupe.
    const uniq = [];
    const seen = new Set();
    for (const s of out) {
      if (seen.has(s)) continue;
      seen.add(s);
      uniq.push(s);
    }
    return { ok: true, names: uniq };
  })()`;
}

function downloadOne(project, needle, fileName, downloadsDir, outDir, timeoutMs, pollMs, reuseExisting) {
  const name = String(fileName || "");
  const nameRx = buildDownloadedNameRegex(name);
  const existing = listMatchingFiles(downloadsDir, nameRx);

  if (reuseExisting && existing.length > 0) {
    const pick = existing.find((x) => x.name === name) || existing[0];
    const dest = joinPath(outDir, name);
    copyFile(pick.path, dest);
    return { name, ok: true, reused_existing: true, downloads_src: pick.path, out_path: dest, bytes: pick.size };
  }

  const baselineSet = new Set(existing.map((x) => x.name));

  // Downloads are often blocked from background tabs.
  try { project.call("Page.bringToFront", {}); } catch {}
  sleepMs(100);

  // Make sure the requested turn is actually rendered.
  try { project.evalValue(scrollToBottomExpr(), { timeoutMs: 60000 }); } catch {}
  sleepMs(250);
  try { project.evalValue(scrollToBottomExpr(), { timeoutMs: 60000 }); } catch {}
  sleepMs(250);

  let loc = null;
  if (needle) {
    loc = project.evalValue(locateChipInNeedleTurnExpr(needle, name), { timeoutMs: 60000 });
  }
  if (!loc || !loc.ok) {
    loc = project.evalValue(locateFileChipExpr(name), { timeoutMs: 60000 });
  }
  if (!loc || !loc.ok) {
    return { name, ok: false, error: "chip_not_found", locator: loc };
  }

  const startMs = Date.now();
  mouseClick(project.call, loc.x, loc.y);
  sleepMs(250);

  const deadline = Date.now() + Math.max(0, Number(timeoutMs) || 0);
  let downloaded = null;
  while (Date.now() < deadline) {
    const cands = listMatchingFiles(downloadsDir, nameRx)
      .filter((f) => !baselineSet.has(f.name))
      .filter((f) => f.mtime >= startMs - 1000)
      .filter((f) => !String(f.name).endsWith(".crdownload"));
    if (cands.length > 0) {
      const pick = cands[0];
      if (tryStat(pick.path + ".crdownload")) {
        sleepMs(pollMs);
        continue;
      }
      const st1 = tryStat(pick.path);
      sleepMs(200);
      const st2 = tryStat(pick.path);
      if (st1 && st2 && Number(st1.size) === Number(st2.size)) {
        downloaded = pick;
        break;
      }
    }
    sleepMs(pollMs);
  }

  if (!downloaded) {
    // Debug: check for any in-progress crdownload sibling.
    const maybeCr = (() => {
      const cands = listMatchingFiles(downloadsDir, nameRx);
      const pick = cands.length ? cands[0] : null;
      if (!pick) return null;
      if (tryStat(pick.path + ".crdownload")) return pick.path + ".crdownload";
      return null;
    })();
    return {
      name,
      ok: false,
      error: "download_timeout",
      locator: loc,
      baseline_count: existing.length,
      baseline_names: existing.slice(0, 5).map((x) => x.name),
      saw_crdownload: maybeCr,
    };
  }

  const dest = joinPath(outDir, name);
  copyFile(downloaded.path, dest);
  return { name, ok: true, downloads_src: downloaded.path, out_path: dest, bytes: downloaded.size };
}

function gotoSources(project, sourcesUrl, timeoutMs) {
  const url = String(sourcesUrl || "");
  const timeout = Math.max(0, Number(timeoutMs) || 0);
  const start = Date.now();
  while (Date.now() - start < timeout) {
    const href = project.evalValue("(() => location.href)()", { timeoutMs: 60000 });
    if (href && String(href).startsWith(url)) return { ok: true, href };
    // Try history jump.
    const hist = project.call("Page.getNavigationHistory", {}, 60000);
    const entries = (hist && hist.result && hist.result.entries) ? hist.result.entries : [];
    let best = null;
    for (let i = entries.length - 1; i >= 0; i--) {
      const e = entries[i];
      if (e && e.url && String(e.url).startsWith(url)) { best = e; break; }
    }
    if (best && best.id) {
      project.call("Page.navigateToHistoryEntry", { entryId: best.id }, 60000);
      sleepMs(1200);
      continue;
    }
    // Fallback: navigate directly.
    project.call("Page.navigate", { url }, 60000);
    sleepMs(2000);
  }
  return { ok: false, href: project.evalValue("(() => location.href)()", { timeoutMs: 60000 }) };
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  ensureDir(args.outDir);
  if (!args.findOnly) ensureDir(args.downloadsDir);

  cdpVersion(args.addr, args.port);
  const sourcesUrl = normalizeProjectSourcesUrl(args.projectUrl);
  const target = openOrFind(args, sourcesUrl);
  const project = mkCaller(target.webSocketDebuggerUrl);
  try { project.call("Page.bringToFront", {}); } catch {}
  sleepMs(args.waitMs);

  // Ensure we're on the sources page.
  gotoSources(project, sourcesUrl, 60000);

  const tried = [];
  const triedKeys = new Set();
  let sourceUrl = null;

  const scanStart = Date.now();
  const scanDeadline = Date.now() + Math.max(0, Number(args.timeoutMs) || 0);
  while (Date.now() < scanDeadline) {
    gotoSources(project, sourcesUrl, 60000);
    const listing = project.evalValue(listSourcesEntriesExpr(args.limit), { timeoutMs: 60000 });
    const entries = listing && listing.entries ? listing.entries : [];
    if (!entries.length) {
      sleepMs(800);
      continue;
    }

    let pick = null;
    let pickKey = null;
    for (const e of entries) {
      if (!e || !e.x || !e.y) continue;
      const ky = (e && e.y !== undefined && e.y !== null) ? String(Math.round(Number(e.y) || 0)) : "0";
      const key = `${e.label}@@${e.date}@@${ky}`;
      if (triedKeys.has(key)) continue;
      pick = e;
      pickKey = key;
      break;
    }

    if (!pick) break;
    triedKeys.add(pickKey);

    const cx = (pick.click_x !== undefined && pick.click_x !== null) ? pick.click_x : pick.x;
    const cy = (pick.click_y !== undefined && pick.click_y !== null) ? pick.click_y : pick.y;
    mouseClick(project.call, cx, cy);
    sleepMs(Math.max(900, args.waitMs));

    // Wait for navigation away from sources.
    const navStart = Date.now();
    let href = null;
    while (Date.now() - navStart < 20000) {
      href = project.evalValue("(() => location.href)()", { timeoutMs: 60000 });
      if (href && !String(href).startsWith(sourcesUrl)) break;
      sleepMs(300);
    }

    // Force the opened page to materialize its DOM (avoid SPA stale-content false positives).
    if (href && !String(href).startsWith(sourcesUrl)) {
      try { project.call("Page.reload", { ignoreCache: true }, 60000); } catch {}
      sleepMs(2500);
    }

    const has = waitForNeedle(project, args.needle, 20000, args.pollMs);
    const matched = !!(has && has.ok);
    tried.push({
      key: pickKey,
      label: pick.label,
      date: pick.date,
      opened_href: href,
      matched,
      needle_check: has,
    });

    if (matched && href) {
      sourceUrl = String(href);
      break;
    }

    // Go back to sources and continue.
    gotoSources(project, sourcesUrl, 60000);
    sleepMs(Math.max(600, args.waitMs));
  }

  const found = !!sourceUrl;

  let downloadNames = [];
  let chips = null;
  if (found && (args.all || args.findOnly)) {
    const chipsRes = project.evalValue(listAllFileChipsExpr(), { timeoutMs: 60000 });
    downloadNames = (chipsRes && chipsRes.ok && Array.isArray(chipsRes.names)) ? chipsRes.names : [];
    chips = { ok: !!(chipsRes && chipsRes.ok), names: downloadNames };
  } else {
    downloadNames = (args.names || []).map((s) => String(s || "")).filter((s) => !!s);
  }

  const downloads = [];
  if (!args.findOnly && found && downloadNames.length > 0) {
    // Re-open the matched source URL so we download from a fresh, consistent view.
    try { project.call("Page.navigate", { url: sourceUrl }, 60000); } catch {}
    sleepMs(Math.max(1200, args.waitMs));
    try { project.call("Page.reload", { ignoreCache: true }, 60000); } catch {}
    sleepMs(2000);

    for (const name of downloadNames) {
      downloads.push(
        downloadOne(project, args.needle, name, args.downloadsDir, args.outDir, args.timeoutMs, args.pollMs, args.reuseExisting),
      );
    }
  }

  const ok = args.findOnly
    ? found
    : (found && downloads.length > 0 && downloads.every((d) => d && d.ok));

  const result = {
    ok,
    addr: args.addr,
    port: args.port,
    projectUrl: args.projectUrl,
    sourcesUrl,
    needle: args.needle,
    target: { id: target.id, title: target.title, url: target.url },
    scan: {
      started_ms: scanStart,
      elapsed_ms: Date.now() - scanStart,
      limit: args.limit,
      tried,
      found,
      source_url: sourceUrl,
    },
    requested: {
      all: !!args.all,
      findOnly: !!args.findOnly,
      names: args.names,
    },
    chips,
    downloadsDir: args.findOnly ? null : args.downloadsDir,
    outDir: args.outDir,
    downloads,
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
