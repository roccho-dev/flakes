const std = @import("std");
const hq = @import("hq");

test "common.parseArgs preserves positionals and last value wins" {
    const argv = [_][]const u8{
        "batch",
        "run",
        "--runRoot",
        "/tmp/a",
        "--spec=/tmp/spec.json",
        "--runRoot=/tmp/b",
    };
    var parsed = try hq.common.parseArgs(std.testing.allocator, &argv);
    defer parsed.deinit();

    try std.testing.expectEqual(@as(usize, 2), parsed.positionals.items.len);
    try std.testing.expectEqualStrings("batch", parsed.positionals.items[0]);
    try std.testing.expectEqualStrings("run", parsed.positionals.items[1]);
    try std.testing.expectEqualStrings("/tmp/b", parsed.get("runRoot").?);
    try std.testing.expectEqualStrings("/tmp/spec.json", parsed.get("spec").?);
}
