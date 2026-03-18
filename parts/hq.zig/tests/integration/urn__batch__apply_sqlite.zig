const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "batch.apply stores sqlite lock and team roots without JSON lock files" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "batch-apply-root", &tmp);
    defer std.testing.allocator.free(run_root);
    const spec_path = try support.tmpRoot(std.testing.allocator, "specs/spec.json", &tmp);
    defer std.testing.allocator.free(spec_path);
    try support.writeSpecFixture(std.testing.io, spec_path);

    const applied = try hq.batch.apply(std.testing.io, std.testing.allocator, run_root, spec_path);
    defer {
        std.testing.allocator.free(applied.batch_id);
        std.testing.allocator.free(applied.lock_path);
    }

    try std.testing.expect(applied.ok);
    try std.testing.expectEqualStrings("example-001", applied.batch_id);
    try std.testing.expect(hq.common.exists(std.testing.io, applied.lock_path));

    const lock_json = try std.fmt.allocPrint(std.testing.allocator, "{s}/batches/_locks/{s}.lock.json", .{ run_root, hq.common.basename(spec_path) });
    defer std.testing.allocator.free(lock_json);
    try std.testing.expect(!hq.common.exists(std.testing.io, lock_json));

    var db = try hq.sqlite.openRunDb(std.testing.io, std.testing.allocator, run_root);
    defer db.close();
    try std.testing.expectEqual(@as(i64, 1), try support.countRows(&db, "SELECT COUNT(*) FROM batch_locks"));
    try std.testing.expectEqual(@as(i64, 1), try support.countRows(&db, "SELECT COUNT(*) FROM batch_team_roots"));
}
