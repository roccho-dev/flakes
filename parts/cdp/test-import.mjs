import * as std from 'qjs:std';
import * as os from 'qjs:os';
import { testOsOpen } from './test-os.mjs';

const path = '/tmp/test_qjs_' + os.getpid();
const flags = os.O_WRONLY | os.O_CREAT | os.O_TRUNC;
std.out.puts('flags=' + flags + '\n');
const fd = testOsOpen(path, flags);
os.close(fd);
os.remove(path);
std.out.puts('Success\n');
