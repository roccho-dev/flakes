// ESM helpers for driving Chromium CDP without jq/node.
// Runtime: quickjs-ng (qjs) with `--std` (provides global `std` and `os`).

const DOC_BASE = "cdp://docs/cdp-errors.md";

export class CdpError extends Error {
  constructor(code, detail, docRef, hint) {
    super(detail);
    this.name = "CdpError";
    this.code = code;
    this.detail = detail;
    this.docRef = docRef || `${DOC_BASE}#${code}`;
    this.hint = hint;
    this.ok = false;
  }

  toJSON() {
    return {
      ok: false,
      code: this.code,
      detail: this.message,
      docRef: this.docRef,
      hint: this.hint || null,
    };
  }
}

export function cdpError(code, detail, hint) {
  return new CdpError(code, detail, null, hint);
}

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

function curlJson(url) {
  const out = runToString(["curl", "-s", "-f", url]);
  return JSON.parse(out);
}

export function preflightCheck(addr, port, targetUrl, opts) {
  const o = opts || {};
  const waitMs = o.waitMs || 8000;
  const timeoutMs = o.timeoutMs || 60000;

  // Step 1: Browser running? (using cdp-bridge which is available in nix shell)
  try {
    cdpBridgeJson(["version", "--addr", addr, "--port", String(port)]);
  } catch (err) {
    return {
      ok: false,
      error: cdpError(
        "BROWSER_NOT_RUNNING",
        `Chrome not responding at ${addr}:${port}`,
        "Start Chromium: chromium-cdp"
      ),
    };
  }

  // Step 2: CDP available? (using cdp-bridge list)
  let targets;
  try {
    targets = cdpBridgeJson(["list", "--addr", addr, "--port", String(port)]);
  } catch (err) {
    return {
      ok: false,
      error: cdpError(
        "CDP_UNAVAILABLE",
        `CDP endpoint not responding at ${addr}:${port}`,
        "Restart Chromium: pkill chromium; chromium-cdp"
      ),
    };
  }

  // Step 3: Target tab found?
  const pages = (targets || []).filter(t => t && t.type === "page" && t.webSocketDebuggerUrl);
  const url = String(targetUrl || "");

  let tab = null;
  if (url) {
    tab = pages.find(t => String(t.url || "") === url);
    if (!tab) {
      tab = pages.find(t => String(t.url || "").startsWith(url));
    }
    if (!tab) {
      const cid = url.match(/\/c\/([0-9a-fA-F-]{16,})/);
      if (cid) {
        tab = pages.find(t => String(t.url || "").includes(cid[1]));
      }
    }
  }

  if (!tab && pages.length > 0) {
    tab = pages[0];
  }

  if (!tab) {
    return {
      ok: false,
      error: cdpError(
        "TARGET_NOT_FOUND",
        `No tab found for URL: ${targetUrl}`,
        `Open tab: cdp-bridge new --url "${targetUrl}"`
      ),
    };
  }

  if (!tab.webSocketDebuggerUrl) {
    return {
      ok: false,
      error: cdpError(
        "TAB_NOT_CONNECTED",
        `Tab found but WebSocket URL is invalid for: ${tab.url || targetUrl}`,
        "Close stale tab and reopen: cdp-bridge close --id <id>; cdp-bridge new --url <url>"
      ),
    };
  }

  // Step 4: Login required?
  try {
    const loginCheck = cdpEvaluate(tab.webSocketDebuggerUrl, `
      (() => {
        const form = document.querySelector('form[action*="login"]');
        const url = window.location.href;
        return { hasLoginForm: !!form, url: url };
      })()
    `, { id: 999, timeoutMs });

    if (loginCheck && loginCheck.result && loginCheck.result.result) {
      const val = loginCheck.result.result.value;
      if (val && val.hasLoginForm) {
        return {
          ok: false,
          error: cdpError(
            "LOGIN_REQUIRED",
            "ChatGPT login required. Login form detected.",
            "Open chatgpt.com, login manually (one-time), then retry"
          ),
        };
      }
    }
  } catch (_) {
    // Login check optional, continue
  }

  // Step 5: Page loaded?
  const deadline = os.now() + waitMs;
  while (os.now() < deadline) {
    try {
      const readyCheck = cdpEvaluate(tab.webSocketDebuggerUrl, `
        (() => {
          return { readyState: document.readyState, title: document.title };
        })()
      `, { id: 998, timeoutMs: 5000 });

      if (readyCheck && readyCheck.result && readyCheck.result.result) {
        const val = readyCheck.result.result.value;
        if (val && val.readyState === "complete") {
          // Step 6: Still generating?
          try {
            const genCheck = cdpEvaluate(tab.webSocketDebuggerUrl, `
              (() => {
                const stop = document.querySelector('button[data-testid="stop-button"], button[aria-label*="Stop"]');
                return { generating: !!stop };
              })()
            `, { id: 997, timeoutMs: 5000 });

            if (genCheck && genCheck.result && genCheck.result.result) {
              const genVal = genCheck.result.result.value;
              if (genVal && genVal.generating) {
                return {
                  ok: false,
                  error: cdpError(
                    "GENERATING",
                    "GPT is still generating a response. Stop button visible.",
                    "Wait for generation to complete or click stop, then retry"
                  ),
                };
              }
            }
          } catch (_) {
            // Generating check optional
          }

          return {
            ok: true,
            tab,
            wsUrl: tab.webSocketDebuggerUrl,
          };
        }
      }
    } catch (_) {
      // Continue waiting
    }
    sleepMs(250);
  }

  return {
    ok: false,
    error: cdpError(
      "PAGE_LOADING",
      `Page still loading after ${waitMs}ms for: ${targetUrl}`,
      `Increase wait time: --waitMs ${waitMs * 2}`
    ),
  };
}
