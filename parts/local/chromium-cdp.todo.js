/*
TODO(sample): Drive Chromium CDP without Node.js.

Why:
- flakes-local provides `chromium-cdp` (launch chromium with remote debugging)
- We sometimes want to read/post to a webapp (e.g. a ChatGPT session) but Node.js is not allowed.

Approach used here:
- Use Chrome's HTTP endpoints to create/close a tab:
  - PUT /json/new?<url>
  - PUT /json/close/<id>
- Use `websocat` as the WebSocket transport for CDP messages.
- Use `qjs` (quickjs-ng) as the orchestrator (JSON build/parse).

Prereqs:
  nix develop .#chromium-cdp
  chromium-cdp about:blank &
  export HQ_CHROME_ADDR=127.0.0.1 HQ_CHROME_PORT=9223

Run:
  qjs --std chromium-cdp.todo.js --expr '1+1'

Notes:
- This script intentionally avoids polling external services.
- It is a minimal proof-of-concept; extend as needed.
*/

"use strict";

function usage() {
  std.err.puts(
    "usage: qjs --std chromium-cdp.todo.js [--addr 127.0.0.1] [--port 9222] [--url about:blank] --expr <js>\n",
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    addr: std.getenv("HQ_CHROME_ADDR") || "127.0.0.1",
    port: std.getenv("HQ_CHROME_PORT") || "9222",
    url: "about:blank",
    expr: null,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--addr" && i + 1 < argv.length) {
      out.addr = argv[++i];
    } else if (a === "--port" && i + 1 < argv.length) {
      out.port = argv[++i];
    } else if (a === "--url" && i + 1 < argv.length) {
      out.url = argv[++i];
    } else if (a === "--expr" && i + 1 < argv.length) {
      out.expr = argv[++i];
    } else if (a === "-h" || a === "--help") {
      usage();
      return null;
    } else {
      std.err.puts(`unknown arg: ${a}\n`);
      usage();
      return null;
    }
  }

  if (!out.expr) {
    std.err.puts("missing: --expr\n");
    usage();
    return null;
  }

  return out;
}

function tmpPath(prefix) {
  return `/tmp/${prefix}_${os.getpid()}_${os.now()}`;
}

function runToString(args, stdinText) {
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

    const rc = os.exec(args, opts);
    if (rc !== 0) {
      throw new Error(`command failed rc=${rc}: ${args.join(" ")}`);
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

function httpPutJson(addr, port, path) {
  const url = `http://${addr}:${port}${path}`;
  const out = runToString(["curl", "-sS", "-X", "PUT", url]);
  return JSON.parse(out);
}

function main(argv) {
  const args = parseArgs(argv);
  if (!args) return 2;

  // Create a new target/tab and get the page-level websocket URL.
  const target = httpPutJson(args.addr, args.port, `/json/new?${encodeURIComponent(args.url)}`);
  if (!target.webSocketDebuggerUrl || !target.id) {
    throw new Error("/json/new response missing fields");
  }

  // Send a single CDP command and receive its response.
  const req = {
    id: 1,
    method: "Runtime.evaluate",
    params: {
      expression: args.expr,
      returnByValue: true,
      awaitPromise: true,
    },
  };
  const respText = runToString(["websocat", "-1", "-t", target.webSocketDebuggerUrl], JSON.stringify(req) + "\n");
  const resp = JSON.parse(respText);

  // Best-effort cleanup.
  try {
    httpPutJson(args.addr, args.port, `/json/close/${encodeURIComponent(target.id)}`);
  } catch {
    // ignore
  }

  // Print a small, stable output.
  const value = resp?.result?.result?.value;
  std.out.puts(JSON.stringify({ value }, null, 2) + "\n");
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
