import { saveCdpResults } from './cdp-results-to-sqlite.mjs';

const results = {
  url: 'https://chatgpt.com/c/69b62ea2-267c-83a6-ab04-49fcef266c3f',
  title: 'QuickJS-ng FFIとZig Test',
  last_seen_ws_url: 'ws://127.0.0.1:9222/devtools/page/TEST123',
  messages: [
    { role: 'assistant', content: 'Test message 1' },
    { role: 'user', content: 'Test message 2' },
    { role: 'assistant', content: 'Test message 3' }
  ]
};
const ret = saveCdpResults(results);
std.out.puts(JSON.stringify(ret));
