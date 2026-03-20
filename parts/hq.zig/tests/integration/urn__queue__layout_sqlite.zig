const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "queue.ensureLayout creates sqlite only state" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "sqlite-layout-root", &tmp);
    defer std.testing.allocator.free(run_root);

    try hq.queue.ensureLayout(std.testing.io, std.testing.allocator, run_root);

    const db_path = try hq.sqlite.dbPathAlloc(std.testing.allocator, run_root);
    defer std.testing.allocator.free(db_path);
    const instructions_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/instructions", .{run_root});
    defer std.testing.allocator.free(instructions_dir);
    const artifacts_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/artifacts", .{run_root});
    defer std.testing.allocator.free(artifacts_dir);
    const pending_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/queue/pending", .{run_root});
    defer std.testing.allocator.free(pending_dir);
    const lock_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/batches/_locks", .{run_root});
    defer std.testing.allocator.free(lock_dir);

    try std.testing.expect(hq.common.exists(std.testing.io, db_path));
    try std.testing.expect(hq.common.exists(std.testing.io, instructions_dir));
    try std.testing.expect(hq.common.exists(std.testing.io, artifacts_dir));
    try std.testing.expect(!hq.common.exists(std.testing.io, pending_dir));
    try std.testing.expect(!hq.common.exists(std.testing.io, lock_dir));
}
