const std = @import("std");
const hq = @import("hq");
const support = @import("support");

fn run(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !void {
    try hq.queue.ensureLayout(io, allocator, run_root);

    const db_path = try hq.sqlite.dbPathAlloc(allocator, run_root);
    defer allocator.free(db_path);
    const instructions_dir = try std.fmt.allocPrint(allocator, "{s}/instructions", .{run_root});
    defer allocator.free(instructions_dir);
    const artifacts_dir = try std.fmt.allocPrint(allocator, "{s}/artifacts", .{run_root});
    defer allocator.free(artifacts_dir);
    const pending_dir = try std.fmt.allocPrint(allocator, "{s}/queue/pending", .{run_root});
    defer allocator.free(pending_dir);
    const lock_dir = try std.fmt.allocPrint(allocator, "{s}/batches/_locks", .{run_root});
    defer allocator.free(lock_dir);

    try support.expect(hq.common.exists(io, db_path));
    try support.expect(hq.common.exists(io, instructions_dir));
    try support.expect(hq.common.exists(io, artifacts_dir));
    try support.expect(!hq.common.exists(io, pending_dir));
    try support.expect(!hq.common.exists(io, lock_dir));
}

test "queue.ensureLayout creates sqlite only state" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "sqlite-layout-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try run(std.testing.io, std.testing.allocator, run_root);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const run_root = try support.runtimeRoot(runtime.allocator, "sqlite-layout-root");
    defer support.cleanupRoot(runtime.io, runtime.allocator, run_root);

    try run(runtime.io, runtime.allocator, run_root);
}
