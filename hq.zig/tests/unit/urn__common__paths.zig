const std = @import("std");
const hq = @import("hq");

test "common.defaultRunRoot and resolveRunRoot honor explicit flag before HOME" {
    const default_root = try hq.common.defaultRunRoot(std.testing.allocator, "/tmp/hq-home");
    defer std.testing.allocator.free(default_root);
    try std.testing.expectEqualStrings("/tmp/hq-home/.hq", default_root);

    const argv = [_][]const u8{"--runRoot", "/tmp/override"};
    var parsed = try hq.common.parseArgs(std.testing.allocator, &argv);
    defer parsed.deinit();

    const resolved = try hq.common.resolveRunRoot(std.testing.allocator, &parsed, "/tmp/ignored-home");
    defer std.testing.allocator.free(resolved);
    try std.testing.expectEqualStrings("/tmp/override", resolved);
}

test "common.resolveRunRoot errors when HOME is unavailable" {
    var parsed = try hq.common.parseArgs(std.testing.allocator, &[_][]const u8{});
    defer parsed.deinit();

    try std.testing.expectError(error.MissingHome, hq.common.resolveRunRoot(std.testing.allocator, &parsed, null));
}
