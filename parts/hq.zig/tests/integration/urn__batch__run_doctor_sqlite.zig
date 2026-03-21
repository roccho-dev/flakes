const std = @import("std");
const hq = @import("hq");
const support = @import("support");

fn run(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, spec_path: []const u8) !void {
    try support.writeSpecFixture(io, spec_path);

    const batch_run = try hq.batch.run(io, allocator, run_root, spec_path);
    try support.expect(batch_run.ok);
    try support.expectEqual(usize, 1, batch_run.jobs_enqueued);
    try support.expectEqual(usize, 1, batch_run.jobs_done);

    const doctor = try hq.batch.doctor(io, allocator, run_root, spec_path);
    try support.expect(doctor.ok);
    try support.expect(doctor.lock_exists);
    try support.expectEqual(usize, 1, doctor.team_root_count);

    const artifact = try std.fmt.allocPrint(allocator, "{s}/batches/example-001/teamA/artifacts/teamA_orders.json", .{run_root});
    defer allocator.free(artifact);
    try support.expect(hq.common.exists(io, artifact));

    var db = try hq.sqlite.openRunDb(io, allocator, run_root);
    defer db.close();
    try support.expectEqual(i64, 1, try support.countRows(&db, "SELECT COUNT(*) FROM batch_locks"));
}

test "batch.run and doctor keep sqlite lock state and materialize deliverable artifact" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try support.tmpRoot(std.testing.allocator, "batch-run-root", &tmp);
    defer std.testing.allocator.free(run_root);
    const spec_path = try support.tmpRoot(std.testing.allocator, "specs/spec.json", &tmp);
    defer std.testing.allocator.free(spec_path);

    try run(std.testing.io, std.testing.allocator, run_root, spec_path);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const root = try support.runtimeRoot(runtime.allocator, "batch-run");
    defer support.cleanupRoot(runtime.io, runtime.allocator, root);
    const run_root = try std.fmt.allocPrint(runtime.allocator, "{s}/run", .{root});
    defer runtime.allocator.free(run_root);
    const spec_path = try std.fmt.allocPrint(runtime.allocator, "{s}/specs/spec.json", .{root});
    defer runtime.allocator.free(spec_path);

    try run(runtime.io, runtime.allocator, run_root, spec_path);
}
