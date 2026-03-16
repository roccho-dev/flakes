const std = @import("std");
const hq = @import("hq");

const spec_fixture = @embedFile("fixtures/spec.json");

pub fn tmpRoot(allocator: std.mem.Allocator, label: []const u8, tmp: *std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, label });
}

pub fn writeSpecFixture(io: std.Io, path: []const u8) !void {
    const dir_path = std.fs.path.dirname(path).?;
    try hq.common.ensureDirPath(io, dir_path);
    try hq.common.writeFile(io, path, spec_fixture);
}

pub fn countRows(db: *hq.sqlite.Db, sql: []const u8) !i64 {
    var stmt = try db.prepare(sql);
    defer stmt.finalize();

    const step = try stmt.step();
    try std.testing.expectEqual(hq.sqlite.Step.row, step);
    return try stmt.columnInt64(0);
}
