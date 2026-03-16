const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "queue.dispatchFake writes artifact and marks sqlite job done" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "queue-dispatch-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try hq.queue.enqueue(std.testing.io, std.testing.allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result.json",
        .task = "ship it",
    });

    try std.testing.expectEqual(@as(usize, 1), try hq.queue.dispatchFake(std.testing.io, std.testing.allocator, run_root));

    const artifact_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/artifacts/result.json", .{run_root});
    defer std.testing.allocator.free(artifact_file);
    const done_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/queue/done/job-1.json", .{run_root});
    defer std.testing.allocator.free(done_file);

    try std.testing.expect(hq.common.exists(std.testing.io, artifact_file));
    try std.testing.expect(!hq.common.exists(std.testing.io, done_file));

    var db = try hq.sqlite.openRunDb(std.testing.io, std.testing.allocator, run_root);
    defer db.close();
    try std.testing.expectEqual(@as(i64, 1), try support.countRows(&db, "SELECT COUNT(*) FROM queue_jobs WHERE state = 'done'"));
}
