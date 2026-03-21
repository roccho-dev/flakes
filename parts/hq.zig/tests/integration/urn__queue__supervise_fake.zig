const std = @import("std");
const hq = @import("hq");
const support = @import("support");

fn run(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !void {
    try hq.queue.enqueue(io, allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result-a.json",
        .task = "ship first",
    });
    try hq.queue.enqueue(io, allocator, run_root, .{
        .team_id = "teamA",
        .job_id = "job-2",
        .role = "ceo",
        .deliverable = "result-b.json",
        .task = "ship second",
    });

    const status = try hq.queue.superviseFake(io, allocator, run_root);
    try support.expectEqual(usize, 0, status.pending);
    try support.expectEqual(usize, 2, status.done);
}

test "queue.superviseFake drains all pending sqlite jobs" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "queue-supervise-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try run(std.testing.io, std.testing.allocator, run_root);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const run_root = try support.runtimeRoot(runtime.allocator, "queue-supervise-root");
    defer support.cleanupRoot(runtime.io, runtime.allocator, run_root);

    try run(runtime.io, runtime.allocator, run_root);
}
