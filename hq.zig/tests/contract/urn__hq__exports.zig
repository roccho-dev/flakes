const std = @import("std");
const hq = @import("hq");
const cdp = @import("cdp");

test "hq root exports sqlite selftest and cdp DOM Input" {
    _ = hq.sqlite;
    _ = hq.selftest;

    var dom: cdp.DOM = undefined;
    _ = &dom;
    var input: cdp.Input = undefined;
    _ = &input;

    try std.testing.expect(cdp.version.len > 0);
}
