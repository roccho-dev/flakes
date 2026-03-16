const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "batch.run and doctor keep sqlite lock state and materialize deliverable artifact" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "batch-run-root", &tmp);
    defer std.testing.allocator.free(run_root);
    const spec_path = try support.tmpRoot(std.testing.allocator, "specs/spec.json", &tmp);
    defer std.testing.allocator.free(spec_path);
    try support.writeSpecFixture(std.testing.io, spec_path);

    const run = try hq.batch.run(std.testing.io, std.testing.allocator, run_root, spec_path);
    try std.testing.expect(run.ok);
    try std.testing.expectEqual(@as(usize, 1), run.jobs_enqueued);
    try std.testing.expectEqual(@as(usize, 1), run.jobs_done);

    const doctor = try hq.batch.doctor(std.testing.io, std.testing.allocator, run_root, spec_path);
    try std.testing.expect(doctor.ok);
    try std.testing.expect(doctor.lock_exists);
    try std.testing.expectEqual(@as(usize, 1), doctor.team_root_count);

    const artifact = try std.fmt.allocPrint(std.testing.allocator, "{s}/batches/example-001/teamA/artifacts/teamA_orders.json", .{run_root});
    defer std.testing.allocator.free(artifact);
    try std.testing.expect(hq.common.exists(std.testing.io, artifact));

    var db = try hq.sqlite.openRunDb(std.testing.io, std.testing.allocator, run_root);
    defer db.close();
    try std.testing.expectEqual(@as(i64, 1), try support.countRows(&db, "SELECT COUNT(*) FROM batch_locks"));
}
