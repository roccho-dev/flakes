const std = @import("std");
const hq = @import("hq");

test "cli manual fixture remains machine readable with fixed exit code" {
    const issue = hq.selftest.manualFixtureIssue();
    const raw = try issue.stringifyAlloc(std.testing.allocator);
    defer std.testing.allocator.free(raw);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, raw, .{});
    defer parsed.deinit();

    try std.testing.expectEqual(@as(i64, hq.manual.exit_code), parsed.value.object.get("exit_code").?.integer);
    try std.testing.expectEqualStrings("ManualInterventionRequired", parsed.value.object.get("error").?.string);
    try std.testing.expectEqualStrings("send", parsed.value.object.get("step").?.string);
    try std.testing.expect(parsed.value.object.get("manual_steps").?.array.items.len >= 2);
}
