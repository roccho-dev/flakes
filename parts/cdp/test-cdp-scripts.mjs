import * as std from 'qjs:std';
import * as os from 'qjs:os';

import { CdpError } from "./chromium-cdp.lib.mjs";

let passed = 0;
let failed = 0;

function assert(cond, msg) {
  if (cond) {
    passed++;
    std.out.puts(`  PASS: ${msg}\n`);
  } else {
    failed++;
    std.out.puts(`  FAIL: ${msg}\n`);
  }
}

std.out.puts("=== CDP Scripts Integration Tests ===\n");

const testCases = [
  {
    script: "chromium-cdp.read-thread.mjs",
    args: ["--help"],
    expectHelp: true,
  },
  {
    script: "chromium-cdp.send-chatgpt.mjs",
    args: ["--help"],
    expectHelp: true,
  },
];

for (const tc of testCases) {
  std.out.puts(`\nTesting: ${tc.script} ${tc.args.join(" ")}\n`);
  
  const stdoutPipe = os.pipe();
  const stderrPipe = os.pipe();
  
  if (stdoutPipe === null || stderrPipe === null) {
    failed++;
    std.out.puts(`  FAIL: os.pipe() failed\n`);
    continue;
  }
  
  const [stdoutReadFd, stdoutWriteFd] = stdoutPipe;
  const [stderrReadFd, stderrWriteFd] = stderrPipe;
  
  const rc = os.exec(["qjs", "--std", "-m", tc.script, ...tc.args], {
    block: true,
    usePath: true,
    stdout: stdoutWriteFd,
    stderr: stderrWriteFd,
  });
  
  os.close(stdoutWriteFd);
  os.close(stderrWriteFd);
  
  const outFile = std.fdopen(stdoutReadFd, "r");
  const errFile = std.fdopen(stderrReadFd, "r");
  
  if (outFile === null || errFile === null) {
    failed++;
    std.out.puts(`  FAIL: std.fdopen() failed\n`);
    continue;
  }
  
  const stdoutText = outFile.readAsString();
  const stderrText = errFile.readAsString();
  
  outFile.close();
  errFile.close();
  
  if (tc.expectHelp) {
    if (rc === 2 && stderrText.includes("usage:")) {
      passed++;
      std.out.puts(`  PASS: ${tc.script} returns usage on --help\n`);
    } else {
      failed++;
      std.out.puts(`  FAIL: ${tc.script} did not return usage on --help\n`);
      std.out.puts(`    rc=${rc}, stderr=${stderrText.slice(0, 200)}\n`);
    }
  }
}

std.out.puts("\n=== CdpError JSON Output Test ===\n");

const testErr = new CdpError("TEST_CODE", "Test message", null, "Test hint");
const jsonOut = JSON.stringify(testErr.toJSON());

try {
  const parsed = JSON.parse(jsonOut);
  if (parsed.ok === false && parsed.code === "TEST_CODE" && parsed.docRef.includes("TEST_CODE")) {
    passed++;
    std.out.puts("  PASS: CdpError JSON output is valid\n");
  } else {
    failed++;
    std.out.puts("  FAIL: CdpError JSON output invalid\n");
  }
} catch (e) {
  failed++;
  std.out.puts(`  FAIL: JSON parse error: ${e}\n`);
}

std.out.puts("\n=== Summary ===\n");
std.out.puts(`Passed: ${passed}\n`);
std.out.puts(`Failed: ${failed}\n`);

if (failed > 0) {
  std.exit(1);
}
