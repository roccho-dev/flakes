const std = @import("std");

pub const ArgPair = struct {
    key: []const u8,
    value: []const u8,
};

pub const ParsedArgs = struct {
    allocator: std.mem.Allocator,
    flags: std.ArrayList(ArgPair) = .empty,
    positionals: std.ArrayList([]const u8) = .empty,

    pub fn init(allocator: std.mem.Allocator) ParsedArgs {
        return .{
            .allocator = allocator,
        };
    }

    pub fn deinit(self: *ParsedArgs) void {
        for (self.flags.items) |item| {
            self.allocator.free(item.key);
            self.allocator.free(item.value);
        }
        self.flags.deinit(self.allocator);

        for (self.positionals.items) |item| self.allocator.free(item);
        self.positionals.deinit(self.allocator);
    }

    pub fn put(self: *ParsedArgs, key: []const u8, value: []const u8) !void {
        try self.flags.append(self.allocator, .{
            .key = try self.allocator.dupe(u8, key),
            .value = try self.allocator.dupe(u8, value),
        });
    }

    pub fn addPositional(self: *ParsedArgs, value: []const u8) !void {
        try self.positionals.append(self.allocator, try self.allocator.dupe(u8, value));
    }

    pub fn get(self: *const ParsedArgs, key: []const u8) ?[]const u8 {
        var i: usize = self.flags.items.len;
        while (i > 0) : (i -= 1) {
            const item = self.flags.items[i - 1];
            if (std.mem.eql(u8, item.key, key)) return item.value;
        }
        return null;
    }
};

pub fn parseArgs(allocator: std.mem.Allocator, argv: []const []const u8) !ParsedArgs {
    var parsed = ParsedArgs.init(allocator);
    errdefer parsed.deinit();

    var i: usize = 0;
    while (i < argv.len) : (i += 1) {
        const arg = argv[i];
        if (!std.mem.startsWith(u8, arg, "--")) {
            try parsed.addPositional(arg);
            continue;
        }

        const body = arg[2..];
        if (std.mem.indexOfScalar(u8, body, '=')) |eq| {
            try parsed.put(body[0..eq], body[eq + 1 ..]);
            continue;
        }

        const next_is_value = i + 1 < argv.len and !std.mem.startsWith(u8, argv[i + 1], "--");
        if (next_is_value) {
            try parsed.put(body, argv[i + 1]);
            i += 1;
        } else {
            try parsed.put(body, "true");
        }
    }

    return parsed;
}

pub fn defaultRunRoot(allocator: std.mem.Allocator, home: []const u8) ![]const u8 {
    return std.fmt.allocPrint(allocator, "{s}/.hq", .{home});
}

pub fn resolveRunRoot(
    allocator: std.mem.Allocator,
    args: *const ParsedArgs,
    home_override: ?[]const u8,
) ![]const u8 {
    if (args.get("runRoot")) |value| return allocator.dupe(u8, value);
    const home = home_override orelse return error.MissingHome;
    return defaultRunRoot(allocator, home);
}

pub fn ensureDirPath(io: std.Io, path: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    var dir = try cwd.createDirPathOpen(io, path, .{});
    dir.close(io);
}

pub fn writeFile(io: std.Io, path: []const u8, data: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    try cwd.writeFile(io, .{
        .sub_path = path,
        .data = data,
    });
}

pub fn exists(io: std.Io, path: []const u8) bool {
    const cwd = std.Io.Dir.cwd();
    cwd.access(io, path, .{}) catch return false;
    return true;
}

pub fn readFileAlloc(io: std.Io, allocator: std.mem.Allocator, path: []const u8, max_bytes: usize) ![]u8 {
    const cwd = std.Io.Dir.cwd();
    return cwd.readFileAlloc(io, path, allocator, .limited(max_bytes));
}

pub fn rename(io: std.Io, old_path: []const u8, new_path: []const u8) !void {
    const cwd = std.Io.Dir.cwd();
    try std.Io.Dir.rename(cwd, old_path, cwd, new_path, io);
}

pub fn deleteTreeIfExists(io: std.Io, path: []const u8) void {
    const cwd = std.Io.Dir.cwd();
    cwd.deleteTree(io, path) catch {};
}

pub fn countEntries(io: std.Io, path: []const u8) !usize {
    const cwd = std.Io.Dir.cwd();
    var dir = try cwd.openDir(io, path, .{ .iterate = true });
    defer dir.close(io);

    var iter = dir.iterate();
    var count: usize = 0;
    while (try iter.next(io)) |_| count += 1;
    return count;
}

pub fn basename(path: []const u8) []const u8 {
    return std.fs.path.basename(path);
}


pub fn nowUnixSeconds() i64 {
    var tv: std.c.timeval = undefined;
    const rc = std.c.gettimeofday(&tv, null);
    if (rc != 0) return 0;
    return @intCast(tv.sec);
}
