const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "queue.enqueue persists instruction file and pending sqlite row" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "queue-enqueue-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try hq.queue.enqueue(std.testing.io, std.testing.allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result.json",
        .task = "ship it",
    });

    const instruction_file = try std.fmt.allocPrint(std.testing.allocator, "{s}/instructions/job-1.txt", .{run_root});
    defer std.testing.allocator.free(instruction_file);
    try std.testing.expect(hq.common.exists(std.testing.io, instruction_file));

    var db = try hq.sqlite.openRunDb(std.testing.io, std.testing.allocator, run_root);
    defer db.close();
    try std.testing.expectEqual(@as(i64, 1), try support.countRows(&db, "SELECT COUNT(*) FROM queue_jobs WHERE state = 'pending'"));
}
