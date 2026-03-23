// ESM helpers for driving Chromium CDP without jq/node.
// Runtime: quickjs-ng (qjs) with `--std` (provides global `std` and `os`).

function tmpPath(prefix) {
  return `/tmp/${prefix}_${os.getpid()}_${os.now()}`;
}

export function runToString(argv, stdinText) {
  const outPath = tmpPath("cdp_out") + ".txt";
  let inPath = null;
  let inFd = null;

  const outFd = os.open(outPath, os.O_WRONLY | os.O_CREAT | os.O_TRUNC, 0o600);
  try {
    const opts = { block: true, stdout: outFd, stderr: 2 };
    if (stdinText !== undefined && stdinText !== null) {
      inPath = tmpPath("cdp_in") + ".txt";
      std.writeFile(inPath, stdinText);
      inFd = os.open(inPath, os.O_RDONLY, 0);
      opts.stdin = inFd;
    }

    const rc = os.exec(argv, opts);
    if (rc !== 0) {
      throw new Error(`command failed rc=${rc}: ${argv.join(" ")}`);
    }
  } finally {
    os.close(outFd);
    if (inFd !== null) os.close(inFd);
  }

  const out = std.loadFile(outPath) || "";
  os.remove(outPath);
  if (inPath) os.remove(inPath);
  return out;
}

export function sleepMs(ms) {
  if (ms <= 0) return;
  os.sleep(ms / 1000);
}

export function getDefaultAddr() {
  return std.getenv("HQ_CHROME_ADDR") || "127.0.0.1";
}

export function getDefaultPort() {
  return Number(std.getenv("HQ_CHROME_PORT") || "9222") || 9222;
}

export function cdpBridgeJson(args) {
  const out = runToString(["cdp-bridge", ...args]);
  return JSON.parse(out);
}

export function cdpVersion(addr, port) {
  return cdpBridgeJson(["version", "--addr", addr, "--port", String(port)]);
}

export function cdpWsUrl(addr, port) {
  return runToString(["cdp-bridge", "wsurl", "--addr", addr, "--port", String(port)]).trim();
}

export function cdpList(addr, port) {
  return cdpBridgeJson(["list", "--addr", addr, "--port", String(port)]);
}

export function cdpNew(addr, port, url) {
  return cdpBridgeJson(["new", "--addr", addr, "--port", String(port), "--url", url]);
}

export function cdpClose(addr, port, id) {
  return cdpBridgeJson(["close", "--addr", addr, "--port", String(port), "--id", id]);
}

export function cdpCall(wsUrl, reqObj, timeoutMs) {
  const argv = ["call", "--ws", wsUrl, "--req", JSON.stringify(reqObj)];
  if (timeoutMs !== undefined && timeoutMs !== null) {
    argv.push("--timeout-ms", String(timeoutMs));
  }
  return cdpBridgeJson(argv);
}

export function cdpEvaluate(wsUrl, expression, opts) {
  const o = opts || {};
  const req = {
    id: o.id || 1,
    method: "Runtime.evaluate",
    params: {
      expression,
      returnByValue: o.returnByValue !== false,
      awaitPromise: o.awaitPromise === true,
    },
  };
  return cdpCall(wsUrl, req, o.timeoutMs || 60000);
}

export function isHeadlessMode() {
  return std.getenv("HQ_CHROME_HEADLESS") === "1";
}

export function getChromeProfileDir() {
  return std.getenv("HQ_CHROME_PROFILE_DIR") || (std.getenv("HOME") + "/.secret/hq/chromium-cdp-profile");
}

export function detectLoginState(wsUrl) {
  const expr = `(() => {
    const body = document.body ? document.body.innerText.slice(0, 1000) : "";
    const title = document.title || "";
    const hasChatGPTLoggedIn = !!document.querySelector("[data-testid='conversations-list']") ||
                               !!document.querySelector("nav[aria-label='Main navigation']");
    const isCloudflare = title.includes("Just a moment") || body.includes("Cloudflare");
    const isLoginPage = body.includes("Sign in") || body.includes("login") || title.includes("Log in");
    return {
      logged_in: hasChatGPTLoggedIn,
      cloudflare: isCloudflare,
      login_page: isLoginPage,
      title: document.title,
      url: location.href,
    };
  })()`;

  try {
    const resp = cdpEvaluate(wsUrl, expr, { timeoutMs: 30000 });
    return resp?.result?.result?.value || null;
  } catch {
    return null;
  }
}

export function waitForLogin(wsUrl, opts) {
  const o = opts || {};
  const intervalMin = o.intervalMin || 2000;
  const intervalMax = o.intervalMax || 5000;
  const maxTries = o.maxTries || 30;
  const maxDurationMs = o.maxDurationMs || 120000;

  const startTime = os.now();
  const deadline = startTime + maxDurationMs;

  for (let i = 0; i < maxTries; i++) {
    const state = detectLoginState(wsUrl);
    if (state && state.logged_in && !state.cloudflare && !state.login_page) {
      return { ok: true, state, tries: i + 1 };
    }
    if (os.now() >= deadline) break;
    const interval = intervalMin + Math.random() * (intervalMax - intervalMin);
    sleepMs(interval);
  }

  const finalState = detectLoginState(wsUrl);
  return {
    ok: false,
    state: finalState,
    tries: maxTries,
    reason: finalState?.cloudflare ? "cloudflare" :
            finalState?.login_page ? "login_required" : "timeout"
  };
}
