import * as std from 'qjs:std';
import * as os from 'qjs:os';

export function testOsOpen(path, flags) {
  std.out.puts('testOsOpen called\n');
  std.out.puts('O_WRONLY=' + os.O_WRONLY + '\n');
  const fd = os.open(path, flags, 0o600);
  return fd;
}
