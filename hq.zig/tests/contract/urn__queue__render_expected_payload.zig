const std = @import("std");
const hq = @import("hq");

test "queue.renderExpectedPayload remains machine readable JSON" {
    const raw = try hq.queue.renderExpectedPayload(std.testing.allocator, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result.json",
        .task = "ship it",
    });
    defer std.testing.allocator.free(raw);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, raw, .{});
    defer parsed.deinit();

    try std.testing.expect(parsed.value == .object);
    try std.testing.expectEqualStrings("job-1", parsed.value.object.get("job_id").?.string);
    try std.testing.expectEqualStrings("result.json", parsed.value.object.get("deliverable").?.string);
    try std.testing.expect(parsed.value.object.get("ok").?.bool);
}
