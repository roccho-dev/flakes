const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "queue.superviseFake drains all pending sqlite jobs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "queue-supervise-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try hq.queue.enqueue(std.testing.io, std.testing.allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result-a.json",
        .task = "ship first",
    });
    try hq.queue.enqueue(std.testing.io, std.testing.allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-2",
        .role = "ceo",
        .deliverable = "result-b.json",
        .task = "ship second",
    });

    const status = try hq.queue.superviseFake(std.testing.io, std.testing.allocator, run_root);
    try std.testing.expectEqual(@as(usize, 0), status.pending);
    try std.testing.expectEqual(@as(usize, 2), status.done);
}
