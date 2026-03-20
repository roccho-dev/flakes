const std = @import("std");
const hq = @import("hq");
const support = @import("support");

test "batch.preflight keeps required spec keys as contract" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const spec_path = try support.tmpRoot(std.testing.allocator, "specs/spec.json", &tmp);
    defer std.testing.allocator.free(spec_path);
    try support.writeSpecFixture(std.testing.io, spec_path);

    const pre = try hq.batch.preflight(std.testing.io, std.testing.allocator, spec_path);
    try std.testing.expect(pre.ok);
    try std.testing.expectEqual(@as(usize, 0), pre.error_count);

    const broken_path = try support.tmpRoot(std.testing.allocator, "specs/broken.json", &tmp);
    defer std.testing.allocator.free(broken_path);
    const broken =
        \\{
        \\  "schema_version": 1,
        \\  "batch_id": "broken"
        \\}
    ;
    try hq.common.ensureDirPath(std.testing.io, std.fs.path.dirname(broken_path).?);
    try hq.common.writeFile(std.testing.io, broken_path, broken);

    const invalid = try hq.batch.preflight(std.testing.io, std.testing.allocator, broken_path);
    try std.testing.expect(!invalid.ok);
    try std.testing.expectEqual(@as(usize, 2), invalid.error_count);
}
