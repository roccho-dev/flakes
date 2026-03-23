// chrome-profile-bootstrap.mjs
// Headful Chrome bootstrap for ChatGPT login
//
// Usage:
//   nix shell .#chromium-cdp-tools
//   qjs --std -m parts/cdp/chrome-profile-bootstrap.mjs --action start
//   qjs --std -m parts/cdp/chrome-profile-bootstrap.mjs --action verify
//   qjs --std -m parts/cdp/chrome-profile-bootstrap.mjs --action login-complete
//   qjs --std -m parts/cdp/chrome-profile-bootstrap.mjs --action stop
//   qjs --std -m parts/cdp/chrome-profile-bootstrap.mjs --action publish

import * as std from 'qjs:std';
import * as os from 'qjs:os';
import {
  cdpVersion,
  cdpList,
  cdpNew,
  cdpClose,
  detectLoginState,
  waitForLogin,
  isHeadlessMode,
  getChromeProfileDir,
} from "./chromium-cdp.lib.mjs";

const DEFAULT_PORT = 9223;
const DEFAULT_ADDR = "127.0.0.1";

function usage() {
  std.err.puts(
    "usage: qjs --std -m chrome-profile-bootstrap.mjs --action <start|verify|login-complete|stop|publish> \\\n" +
    "  [--addr <addr>] [--port <port>] \\\n" +
    "  [--profile-dir <path>] \\\n" +
    "  [--headless] \\\n" +
    "  [--url <url>] \\\n" +
    "  [--wait-timeout-ms <ms>]\n" +
    "\n" +
    "Actions:\n" +
    "  start         Start headful Chrome with Xvfb + VNC\n" +
    "  verify        Verify Chrome is running and CDP is healthy\n" +
    "  login-complete Check if ChatGPT login is complete\n" +
    "  stop          Stop Chrome\n" +
    "  publish       Copy seed profile to published snapshot\n" +
    "\n" +
    "Environment:\n" +
    "  HQ_CHROME_ADDR           CDP address (default: 127.0.0.1)\n" +
    "  HQ_CHROME_PORT           CDP port (default: 9223)\n" +
    "  HQ_CHROME_PROFILE_DIR    Profile directory\n" +
    "  HQ_CHROME_HEADLESS       Set to 1 for headless mode\n" +
    "\n" +
    "Profile paths:\n" +
    "  Seed:       $HQ_CHROME_PROFILE_DIR or ~/.secret/hq/chromium-cdp-profile-140\n" +
    "  Published:  ~/.secret/hq/chromium-cdp-profile.snapshot\n"
  );
  std.err.flush();
}

function parseArgs(argv) {
  const out = {
    action: null,
    addr: std.getenv("HQ_CHROME_ADDR") || DEFAULT_ADDR,
    port: Number(std.getenv("HQ_CHROME_PORT") || String(DEFAULT_PORT)),
    profileDir: null,
    headless: std.getenv("HQ_CHROME_HEADLESS") === "1",
    url: "https://chatgpt.com/",
    waitTimeoutMs: 120000,
  };

  for (let i = 1; i < argv.length; i++) {
    const a = argv[i];
    if (a === "--action" && i + 1 < argv.length) out.action = argv[++i];
    else if (a === "--addr" && i + 1 < argv.length) out.addr = argv[++i];
    else if (a === "--port" && i + 1 < argv.length) out.port = Number(argv[++i]) || out.port;
    else if (a === "--profile-dir" && i + 1 < argv.length) out.profileDir = argv[++i];
    else if (a === "--headless") out.headless = true;
    else if (a === "--url" && i + 1 < argv.length) out.url = argv[++i];
    else if (a === "--wait-timeout-ms" && i + 1 < argv.length) out.waitTimeoutMs = Number(argv[++i]) || out.waitTimeoutMs;
    else if (a === "-h" || a === "--help") return null;
    else {
      std.err.puts(`unknown arg: ${a}\n`);
      return null;
    }
  }

  if (!out.action) return null;
  return out;
}

function getProfileDir(args) {
  if (args.profileDir) return args.profileDir;
  const envProfile = std.getenv("HQ_CHROME_PROFILE_DIR");
  if (envProfile) return envProfile;
  return std.getenv("HOME") + "/.secret/hq/chromium-cdp-profile-140";
}

function getSnapshotPath() {
  const env = std.getenv("HQ_CHROME_PUBLISHED_SNAPSHOT");
  if (env) return env;
  return std.getenv("HOME") + "/.secret/hq/chromium-cdp-profile.snapshot";
}

function actionStart(args) {
  const profileDir = getProfileDir(args);

  std.out.puts(JSON.stringify({
    action: "start",
    mode: args.headless ? "headless" : "headful",
    profile_dir: profileDir,
    addr: args.addr,
    port: args.port,
    note: "Start Chrome manually using: systemd-run --user --unit chrome-login-9223 ..."
  }) + "\n");

  return { ok: true, requires_manual_start: true };
}

function actionVerify(args) {
  try {
    const version = cdpVersion(args.addr, args.port);
    const targets = cdpList(args.addr, args.port);
    return {
      ok: true,
      cdp_healthy: true,
      version,
      target_count: targets.length,
    };
  } catch (e) {
    return {
      ok: false,
      cdp_healthy: false,
      error: String(e && e.message ? e.message : e),
    };
  }
}

function actionLoginComplete(args) {
  const targets = cdpList(args.addr, args.port);
  const chatgptTabs = targets.filter(t =>
    t.type === "page" &&
    (t.url.includes("chatgpt.com") || t.url.includes("chat.openai.com"))
  );

  if (chatgptTabs.length === 0) {
    return {
      ok: false,
      login_complete: false,
      reason: "no_chatgpt_tab",
      instruction: "Open https://chatgpt.com in Chrome first",
    };
  }

  const wsUrl = chatgptTabs[0].webSocketDebuggerUrl;
  const state = detectLoginState(wsUrl);

  if (!state) {
    return {
      ok: false,
      login_complete: false,
      reason: "detection_failed",
    };
  }

  if (state.cloudflare) {
    return {
      ok: false,
      login_complete: false,
      reason: "cloudflare_challenge",
      state,
    };
  }

  if (state.login_page) {
    return {
      ok: false,
      login_complete: false,
      reason: "not_logged_in",
      state,
    };
  }

  if (state.logged_in) {
    return {
      ok: true,
      login_complete: true,
      state,
    };
  }

  return {
    ok: false,
    login_complete: false,
    reason: "unknown_state",
    state,
  };
}

function actionStop(args) {
  const targets = cdpList(args.addr, args.port);
  const closed = [];

  for (const target of targets) {
    if (target.type === "page") {
      try {
        cdpClose(args.addr, args.port, target.id);
        closed.push(target.id);
      } catch {
        // ignore
      }
    }
  }

  return {
    ok: true,
    closed_tabs: closed.length,
    tab_ids: closed,
  };
}

function actionPublish(args) {
  const profileDir = getProfileDir(args);
  const snapshotPath = getSnapshotPath();

  const copyCmd = [
    "cp", "-r", "-p",
    profileDir,
    snapshotPath,
  ];

  try {
    const rc = os.exec(copyCmd, { block: true });
    if (rc !== 0) {
      throw new Error(`cp failed with rc=${rc}`);
    }
  } catch (e) {
    return {
      ok: false,
      action: "publish",
      error: String(e && e.message ? e.message : e),
      profile_dir: profileDir,
      snapshot_path: snapshotPath,
    };
  }

  return {
    ok: true,
    action: "publish",
    profile_dir: profileDir,
    snapshot_path: snapshotPath,
  };
}

export function main(argv = scriptArgs.slice(1)) {
  const args = parseArgs(argv);
  if (!args) {
    usage();
    return 2;
  }

  let result;
  switch (args.action) {
    case "start":
      result = actionStart(args);
      break;
    case "verify":
      result = actionVerify(args);
      break;
    case "login-complete":
      result = actionLoginComplete(args);
      break;
    case "stop":
      result = actionStop(args);
      break;
    case "publish":
      result = actionPublish(args);
      break;
    default:
      std.err.puts(`unknown action: ${args.action}\n`);
      usage();
      return 2;
  }

  std.out.puts(JSON.stringify(result, null, 2) + "\n");
  return result.ok ? 0 : 1;
}

if (import.meta.main) {
  std.exit(main(scriptArgs.slice(1)));
}
