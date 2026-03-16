const std = @import("std");
const cdp = @import("cdp");

test "serializeCommand preserves flat session attach contract" {
    const raw = try cdp.protocol.serializeCommand(
        std.testing.allocator,
        7,
        "Target.attachToTarget",
        .{
            .target_id = "target-123",
            .flatten = true,
        },
        null,
    );
    defer std.testing.allocator.free(raw);

    try std.testing.expect(std.mem.indexOf(u8, raw, "\"method\":\"Target.attachToTarget\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, raw, "\"targetId\":\"target-123\"") != null);
    try std.testing.expect(std.mem.indexOf(u8, raw, "\"flatten\":true") != null);
}

test "serializeCommand includes session id when present" {
    const raw = try cdp.protocol.serializeCommand(
        std.testing.allocator,
        8,
        "Runtime.evaluate",
        .{
            .expression = "document.title",
        },
        "session-abc",
    );
    defer std.testing.allocator.free(raw);

    try std.testing.expect(std.mem.indexOf(u8, raw, "\"sessionId\":\"session-abc\"") != null);
}
