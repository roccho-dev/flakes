const std = @import("std");
const cdp = @import("cdp");

fn freeArgs(args: []const []const u8, allocator: std.mem.Allocator) void {
    for (args[1..]) |arg| allocator.free(arg);
    allocator.free(args);
}

test "validateLaunchOptions requires explicit user data dir" {
    const opts = cdp.LaunchOptions{
        .allocator = std.testing.allocator,
        .io = undefined,
        .port = 9222,
        .user_data_dir = null,
    };

    try std.testing.expectError(error.MissingUserDataDir, cdp.validateLaunchOptions(opts));
}

test "validateLaunchOptions requires non zero port" {
    const opts = cdp.LaunchOptions{
        .allocator = std.testing.allocator,
        .io = undefined,
        .port = 0,
        .user_data_dir = "/tmp/hq-cdp-contract",
    };

    try std.testing.expectError(error.MissingPort, cdp.validateLaunchOptions(opts));
}

test "buildChromeArgs carries discovery critical switches" {
    const opts = cdp.LaunchOptions{
        .allocator = std.testing.allocator,
        .io = undefined,
        .port = 9338,
        .user_data_dir = "/tmp/hq-cdp-contract",
        .no_sandbox = true,
    };

    const args = try cdp.buildChromeArgs(opts, std.testing.allocator);
    defer freeArgs(args, std.testing.allocator);

    var joined: std.ArrayList(u8) = .empty;
    defer joined.deinit(std.testing.allocator);
    for (args) |arg| {
        try joined.appendSlice(std.testing.allocator, arg);
        try joined.append(std.testing.allocator, '\n');
    }

    try std.testing.expect(std.mem.indexOf(u8, joined.items, "--remote-debugging-port=9338") != null);
    try std.testing.expect(std.mem.indexOf(u8, joined.items, "--user-data-dir=/tmp/hq-cdp-contract") != null);
    try std.testing.expect(std.mem.indexOf(u8, joined.items, "--headless=new") != null);
    try std.testing.expect(std.mem.indexOf(u8, joined.items, "--no-sandbox") != null);
}
