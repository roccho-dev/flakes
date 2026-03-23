import { saveCdpResults } from '/home/nixos/repos/flakes/parts/cdp/cdp-results-to-sqlite.mjs';

const results = {
  url: 'https://chatgpt.com/c/test',
  title: 'Test',
  last_seen_ws_url: 'ws://127.0.0.1:9222/devtools/page/TEST',
  messages: [
    { role: 'assistant', content: 'Test message 1' }
  ]
};
const ret = saveCdpResults(results);
std.out.puts(JSON.stringify(ret));
