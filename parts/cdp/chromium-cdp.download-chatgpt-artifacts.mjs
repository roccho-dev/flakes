// Download ChatGPT file-chip artifacts via CDP (no jq/node).
//
// Why this exists
// - ChatGPT "file chips" (e.g. qjs_orchestrator_project.zip) are often rendered
//   as <button> elements without a direct <a download> link.
// - In practice, clicking the chip triggers a browser download into the
//   browser's configured downloads directory, but CDP Browser.downloadProgress
//   events may not fire reliably.
// - This script makes downloads reproducible by:
//     (1) finding + trusted-clicking the chip in the target tab
//     (2) watching the filesystem for the new file to appear
//     (3) copying/moving it into an output directory with a stable name
//
// Typical flow:
//   nix shell .#chromium-cdp-tools
//   chromium-cdp "https://chatgpt.com" &
//   # Login manually and open the target thread URL in that browser.
//   export HQ_CHROME_ADDR=127.0.0.1 HQ_CHROME_PORT=9222
//   qjs --std -m parts/cdp/chromium-cdp.download-chatgpt-artifacts.mjs \
//     --url "https://chatgpt.com/c/<thread>" \
//     --outDir /tmp/artifacts \
//     --name qjs_orchestrator_project.zip \
//     --name qjs_orchestrator_test_report.txt

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
    "usage: qjs --std -m chromium-cdp.download-chatgpt-artifacts.mjs --url <thread-url> --outDir <dir> --name <file> [--name <file> ...] [--addr 127.0.0.1] [--port 9222] [--id <targetId>] [--downloadsDir <dir>] [--timeoutMs 120000] [--pollMs 200] [--waitMs 0] [--afterClickMs 200] [--move] [--force]\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: getDefaultAddr(),
    port: getDefaultPort(),
    url: null,
    id: null,
    outDir: null,
    downloadsDir: null,
    names: [],
    timeoutMs: 120000,
    pollMs: 200,
    waitMs: 0,
    afterClickMs: 200,
    mode: "copy", // copy|move
    reuseExisting: true,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--id" && i + 1 < argv.length) out.id = argv[++i];
    else if (a === "--outDir" && i + 1 < argv.length) out.outDir = argv[++i];
    else if (a === "--downloadsDir" && i + 1 < argv.length) out.downloadsDir = argv[++i];
    else if (a === "--name" && i + 1 < argv.length) out.names.push(argv[++i]);
    else if (a === "--timeoutMs" && i + 1 < argv.length) out.timeoutMs = Number(argv[++i]) || out.timeoutMs;
    else if (a === "--pollMs" && i + 1 < argv.length) out.pollMs = Number(argv[++i]) || out.pollMs;
    else if (a === "--waitMs" && i + 1 < argv.length) out.waitMs = Number(argv[++i]) || out.waitMs;
    else if (a === "--afterClickMs" && i + 1 < argv.length) out.afterClickMs = Number(argv[++i]) || out.afterClickMs;
    else if (a === "--move") out.mode = "move";
    else if (a === "--force") out.reuseExisting = false;
    else if (a === "-h" || a === "--help") return null;
    else {
      std.err.puts(`unknown arg: ${a}\n`);
      return null;
    }
  }

  if (!out.url) return null;
  if (!out.outDir) return null;
  if (!out.names.length) return null;
  if (!out.downloadsDir) {
    const home = String(std.getenv("HOME") || "");
    out.downloadsDir = home ? `${home}/Downloads` : "./Downloads";
  }

  return out;
}

function extractConversationId(url) {
  const m = String(url || "").match(/\/c\/([0-9a-fA-F-]{16,})/);
  return m ? m[1] : null;
}

function pickTarget(targets, args) {
  const pages = (targets || []).filter((t) => t && t.type === "page" && t.webSocketDebuggerUrl);

  const scoreByNames = (wsUrl) => {
    const names = Array.isArray(args.names) ? args.names.map((s) => String(s || "")) : [];
    const namesJson = JSON.stringify(names.slice(0, 32));
    const expr = `(() => {
      const names = ${namesJson};
      const norm = (s) => String(s || "").trim();
      const btns = Array.from(document.querySelectorAll('button'));
      let score = 0;
      for (const name of names) {
        if (!name) continue;
        const hit = btns.some((b) => {
          const t = norm(b.innerText);
          const a = norm(b.getAttribute('aria-label'));
          const tt = norm(b.getAttribute('title'));
          return t === name || a === name || tt === name || t.includes(name) || a.includes(name) || tt.includes(name);
        });
        if (hit) score++;
      }
      const text = document.body ? (document.body.innerText || '') : '';
      return { ok: true, score, text_len: text.length, ready: document.readyState };
    })()`;

    try {
      const resp = cdpEvaluate(wsUrl, expr, { id: 1, returnByValue: true, awaitPromise: false, timeoutMs: 5000 });
      const value = resp?.result?.result?.value;
      if (value && typeof value === 'object' && value.ok === true) return value;
    } catch {
      // ignore
    }
    return { ok: false, score: 0, text_len: 0, ready: null };
  };

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

  if (cands.length >= 2) {
    // Prefer the tab that actually contains the requested file chips.
    const scored = cands.map((t) => ({ t, s: scoreByNames(t.webSocketDebuggerUrl) }));
    scored.sort((a, b) => (Number(b.s.score) - Number(a.s.score)) || (Number(b.s.text_len) - Number(a.s.text_len)));
    return scored[0].t;
  }

  const preview = pages.map((t) => ({ id: t.id, title: t.title, url: t.url }));
  throw new Error(
    `no matching page target found; open the thread in Chromium and retry:\n${JSON.stringify(preview, null, 2)}`,
  );
}

function ensureDir(path) {
  const rc = os.exec(["mkdir", "-p", path], { block: true, stdout: 2, stderr: 2 });
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
  // quickjs-ng os.* often returns [value, errno]
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

function statPath(path) {
  const v = osTuple(os.stat(path), `stat(${path})`);
  if (!v || typeof v !== "object") throw new Error(`unexpected stat result for ${path}`);
  return v;
}

function tryStat(path) {
  try {
    return statPath(path);
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

function moveFile(src, dest) {
  const rc = os.rename(src, dest);
  if (rc !== 0) {
    // Fallback to copy+remove.
    copyFile(src, dest);
    os.remove(src);
  }
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

function locateFileChipExpr(name) {
  const nameJson = JSON.stringify(String(name || ""));
  return `(() => {
    const name = ${nameJson};
    const norm = (s) => String(s || "").trim();
    const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== "none" && getComputedStyle(el).visibility !== "hidden";

    const buttons = Array.from(document.querySelectorAll("button")).filter(isVisible);
    let el =
      buttons.find((b) => norm(b.innerText) === name) ||
      buttons.find((b) => norm(b.getAttribute("aria-label")) === name) ||
      buttons.find((b) => norm(b.getAttribute("title")) === name) ||
      buttons.find((b) => norm(b.innerText).includes(name));

    if (!el) return { ok: false, reason: "not_found" };
    try { el.scrollIntoView({ block: "center", inline: "center" }); } catch (_) {}
    const r = el.getBoundingClientRect();
    return { ok: true, x: r.left + r.width / 2, y: r.top + r.height / 2, w: r.width, h: r.height };
  })()`;
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  ensureDir(args.outDir);
  ensureDir(args.downloadsDir);

  // Ensure CDP is reachable.
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
    call("Input.dispatchMouseEvent", { type: "mouseMoved", x: pt.x, y: pt.y, button: "none" });
    call("Input.dispatchMouseEvent", { type: "mousePressed", ...pt });
    call("Input.dispatchMouseEvent", { type: "mouseReleased", ...pt });
  };

  try {
    call("Page.bringToFront", {});
  } catch {
    // ignore
  }
  sleepMs(args.waitMs);

  const results = [];
  for (const name of args.names) {
    const row = { name: String(name || ""), ok: false };
    try {
      // Ensure the latest turns are visible.
      evalByValue(scrollToBottomExpr(), 60000);
      sleepMs(250);
      evalByValue(scrollToBottomExpr(), 60000);
      sleepMs(250);

      const nameRegex = buildDownloadedNameRegex(row.name);
      const existing = listMatchingFiles(args.downloadsDir, nameRegex);
      if (args.reuseExisting && existing.length > 0) {
        const pick = existing.find((x) => x.name === row.name) || existing[0];
        const dest = joinPath(args.outDir, row.name);
        // Reuse mode is always a copy (do not delete operator's Downloads).
        copyFile(pick.path, dest);
        row.ok = true;
        row.reused_existing = true;
        row.downloads_src = pick.path;
        row.out_path = dest;
        row.bytes = pick.size;
        results.push(row);
        continue;
      }

      const baselineSet = new Set(existing.map((x) => x.name));

      const loc = evalByValue(locateFileChipExpr(row.name), 60000);
      if (!loc || !loc.ok) {
        row.error = "chip_not_found";
        results.push(row);
        continue;
      }

      const startMs = Date.now();
      mouseClick(loc.x, loc.y);
      sleepMs(args.afterClickMs);

      const deadline = Date.now() + args.timeoutMs;
      let downloaded = null;
      while (Date.now() < deadline) {
        const cands = listMatchingFiles(args.downloadsDir, nameRegex)
          .filter((f) => !baselineSet.has(f.name))
          .filter((f) => f.mtime >= startMs - 1000)
          .filter((f) => !String(f.name).endsWith(".crdownload"));

        if (cands.length > 0) {
          const pick = cands[0];
          // If Chrome uses a .crdownload sibling, wait until it's gone.
          if (tryStat(pick.path + ".crdownload")) {
            sleepMs(args.pollMs);
            continue;
          }

          // Wait for size stability.
          const st1 = tryStat(pick.path);
          sleepMs(200);
          const st2 = tryStat(pick.path);
          if (st1 && st2 && Number(st1.size) === Number(st2.size)) {
            downloaded = pick;
            break;
          }
        }

        sleepMs(args.pollMs);
      }

      if (!downloaded) {
        row.error = "download_timeout";
        results.push(row);
        continue;
      }

      const dest = joinPath(args.outDir, row.name);
      if (args.mode === "move") moveFile(downloaded.path, dest);
      else copyFile(downloaded.path, dest);

      row.ok = true;
      row.downloads_src = downloaded.path;
      row.out_path = dest;
      row.bytes = downloaded.size;
    } catch (e) {
      row.error = String(e && e.message ? e.message : e);
    }
    results.push(row);
  }

  const allOk = results.every((r) => r.ok);
  std.out.puts(
    JSON.stringify(
      {
        url: args.url,
        outDir: args.outDir,
        downloadsDir: args.downloadsDir,
        target: { id: target.id, title: target.title, url: target.url },
        mode: args.mode,
        results,
      },
      null,
      2,
    ) + "\n",
  );
  std.out.flush();
  return allOk ? 0 : 1;
}

std.exit(main(scriptArgs));
