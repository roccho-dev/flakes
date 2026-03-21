const std = @import("std");
const hq = @import("hq");
const support = @import("support");

fn run(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !void {
    try hq.queue.enqueue(io, allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result.json",
        .task = "ship it",
    });

    const instruction_file = try std.fmt.allocPrint(allocator, "{s}/instructions/job-1.txt", .{run_root});
    defer allocator.free(instruction_file);
    try support.expect(hq.common.exists(io, instruction_file));

    var db = try hq.sqlite.openRunDb(io, allocator, run_root);
    defer db.close();
    try support.expectEqual(i64, 1, try support.countRows(&db, "SELECT COUNT(*) FROM queue_jobs WHERE state = 'pending'"));
}

test "queue.enqueue persists instruction file and pending sqlite row" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "queue-enqueue-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try run(std.testing.io, std.testing.allocator, run_root);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const run_root = try support.runtimeRoot(runtime.allocator, "queue-enqueue-root");
    defer support.cleanupRoot(runtime.io, runtime.allocator, run_root);

    try run(runtime.io, runtime.allocator, run_root);
}
