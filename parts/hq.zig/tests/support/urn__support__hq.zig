const std = @import("std");
const hq = @import("hq");

const spec_fixture = @embedFile("fixtures/spec.json");

pub const Runtime = struct {
    allocator: std.mem.Allocator,
    threaded: std.Io.Threaded,
    io: std.Io,

    pub fn init(minimal: std.process.Init.Minimal) !@This() {
        const allocator = std.heap.c_allocator;
        var threaded: std.Io.Threaded = .init(allocator, .{
            .argv0 = .init(minimal.args),
            .environ = minimal.environ,
        });
        errdefer threaded.deinit();

        return .{
            .allocator = allocator,
            .threaded = threaded,
            .io = threaded.io(),
        };
    }

    pub fn deinit(self: *@This()) void {
        self.threaded.deinit();
    }
};

pub fn tmpRoot(allocator: std.mem.Allocator, label: []const u8, tmp: *std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, label });
}

pub fn runtimeRoot(allocator: std.mem.Allocator, label: []const u8) ![]u8 {
    var tv: std.c.timeval = undefined;
    const rc = std.c.gettimeofday(&tv, null);
    if (rc != 0) return error.ClockUnavailable;

    return std.fmt.allocPrint(allocator, ".zig-cache/runtime/{d}-{d}-{s}", .{
        tv.sec,
        tv.usec,
        label,
    });
}

pub fn cleanupRoot(io: std.Io, allocator: std.mem.Allocator, path: []u8) void {
    hq.common.deleteTreeIfExists(io, path);
    allocator.free(path);
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
    if (step != hq.sqlite.Step.row) return error.ExpectedRow;
    return try stmt.columnInt64(0);
}

pub fn expect(ok: bool) !void {
    if (!ok) return error.ExpectFailed;
}

pub fn expectEqual(comptime T: type, expected: T, actual: T) !void {
    if (expected != actual) return error.ExpectEqualFailed;
}

pub fn expectDeepEqual(expected: anytype, actual: @TypeOf(expected)) !void {
    if (!std.meta.eql(expected, actual)) return error.ExpectEqualFailed;
}

pub fn expectEqualStrings(expected: []const u8, actual: []const u8) !void {
    if (!std.mem.eql(u8, expected, actual)) return error.ExpectEqualFailed;
}
