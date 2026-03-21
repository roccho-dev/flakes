const std = @import("std");
const hq = @import("hq");
const support = @import("support");

fn run(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, spec_path: []const u8) !void {
    try support.writeSpecFixture(io, spec_path);

    const applied = try hq.batch.apply(io, allocator, run_root, spec_path);
    defer {
        allocator.free(applied.batch_id);
        allocator.free(applied.lock_path);
    }

    try support.expect(applied.ok);
    try support.expectEqualStrings("example-001", applied.batch_id);
    try support.expect(hq.common.exists(io, applied.lock_path));

    const lock_json = try std.fmt.allocPrint(allocator, "{s}/batches/_locks/{s}.lock.json", .{ run_root, hq.common.basename(spec_path) });
    defer allocator.free(lock_json);
    try support.expect(!hq.common.exists(io, lock_json));

    var db = try hq.sqlite.openRunDb(io, allocator, run_root);
    defer db.close();
    try support.expectEqual(i64, 1, try support.countRows(&db, "SELECT COUNT(*) FROM batch_locks"));
    try support.expectEqual(i64, 1, try support.countRows(&db, "SELECT COUNT(*) FROM batch_team_roots"));
}

test "batch.apply stores sqlite lock and team roots without JSON lock files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "batch-apply-root", &tmp);
    defer std.testing.allocator.free(run_root);
    const spec_path = try support.tmpRoot(std.testing.allocator, "specs/spec.json", &tmp);
    defer std.testing.allocator.free(spec_path);

    try run(std.testing.io, std.testing.allocator, run_root, spec_path);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const root = try support.runtimeRoot(runtime.allocator, "batch-apply");
    defer support.cleanupRoot(runtime.io, runtime.allocator, root);
    const run_root = try std.fmt.allocPrint(runtime.allocator, "{s}/run", .{root});
    defer runtime.allocator.free(run_root);
    const spec_path = try std.fmt.allocPrint(runtime.allocator, "{s}/specs/spec.json", .{root});
    defer runtime.allocator.free(spec_path);

    try run(runtime.io, runtime.allocator, run_root, spec_path);
}
