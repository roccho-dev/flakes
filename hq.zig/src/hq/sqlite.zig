const std = @import("std");
const common = @import("common.zig");

const c = @cImport({
    @cInclude("sqlite3.h");
});

pub const Step = enum {
    row,
    done,
};

pub const Db = struct {
    allocator: std.mem.Allocator,
    handle: *c.sqlite3,

    const Self = @This();

    pub fn close(self: *Self) void {
        _ = c.sqlite3_close_v2(self.handle);
        self.* = undefined;
    }

    pub fn exec(self: *Self, sql: []const u8) !void {
        var err_msg: ?[*:0]u8 = null;
        const rc = c.sqlite3_exec(self.handle, sql.ptr, null, null, @ptrCast(&err_msg));
        defer if (err_msg) |ptr| c.sqlite3_free(ptr);
        if (rc != c.SQLITE_OK) return makeError(rc, err_msg);
    }

    pub fn prepare(self: *Self, sql: []const u8) !Stmt {
        var stmt_ptr: ?*c.sqlite3_stmt = null;
        const rc = c.sqlite3_prepare_v2(self.handle, sql.ptr, @intCast(sql.len), &stmt_ptr, null);
        if (rc != c.SQLITE_OK or stmt_ptr == null) return makeDbError(self.handle, rc);
        return .{
            .db = self,
            .handle = stmt_ptr.?,
        };
    }

    pub fn lastInsertRowId(self: *Self) i64 {
        return c.sqlite3_last_insert_rowid(self.handle);
    }
};

pub const Stmt = struct {
    db: *Db,
    handle: *c.sqlite3_stmt,

    const Self = @This();
    const transient = @as(c.sqlite3_destructor_type, @ptrFromInt(~@as(usize, 0)));

    pub fn finalize(self: *Self) void {
        _ = c.sqlite3_finalize(self.handle);
        self.* = undefined;
    }

    pub fn reset(self: *Self) void {
        _ = c.sqlite3_reset(self.handle);
        _ = c.sqlite3_clear_bindings(self.handle);
    }

    pub fn bindText(self: *Self, index: c_int, value: []const u8) !void {
        const rc = c.sqlite3_bind_text(self.handle, index, value.ptr, @intCast(value.len), transient);
        if (rc != c.SQLITE_OK) return makeDbError(self.db.handle, rc);
    }

    pub fn bindInt64(self: *Self, index: c_int, value: i64) !void {
        const rc = c.sqlite3_bind_int64(self.handle, index, value);
        if (rc != c.SQLITE_OK) return makeDbError(self.db.handle, rc);
    }

    pub fn bindBool(self: *Self, index: c_int, value: bool) !void {
        try self.bindInt64(index, if (value) 1 else 0);
    }

    pub fn bindNull(self: *Self, index: c_int) !void {
        const rc = c.sqlite3_bind_null(self.handle, index);
        if (rc != c.SQLITE_OK) return makeDbError(self.db.handle, rc);
    }

    pub fn step(self: *Self) !Step {
        const rc = c.sqlite3_step(self.handle);
        return switch (rc) {
            c.SQLITE_ROW => .row,
            c.SQLITE_DONE => .done,
            else => makeDbError(self.db.handle, rc),
        };
    }

    pub fn columnInt64(self: *Self, index: c_int) !i64 {
        if (c.sqlite3_column_type(self.handle, index) == c.SQLITE_NULL) return error.NullColumn;
        return c.sqlite3_column_int64(self.handle, index);
    }

    pub fn columnBool(self: *Self, index: c_int) !bool {
        return (try self.columnInt64(index)) != 0;
    }

    pub fn columnTextAlloc(self: *Self, allocator: std.mem.Allocator, index: c_int) ![]u8 {
        if (c.sqlite3_column_type(self.handle, index) == c.SQLITE_NULL) return allocator.alloc(u8, 0);
        const ptr = c.sqlite3_column_text(self.handle, index) orelse return allocator.alloc(u8, 0);
        const len: usize = @intCast(c.sqlite3_column_bytes(self.handle, index));
        const bytes: [*]const u8 = @ptrCast(ptr);
        return allocator.dupe(u8, bytes[0..len]);
    }
};

pub fn dbPathAlloc(allocator: std.mem.Allocator, run_root: []const u8) ![]u8 {
    return std.fmt.allocPrint(allocator, "{s}/hq.sqlite", .{run_root});
}

pub fn openRunDb(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !Db {
    try common.ensureDirPath(io, run_root);

    const db_path = try dbPathAlloc(allocator, run_root);
    defer allocator.free(db_path);

    const db_path_z = try allocator.dupeZ(u8, db_path);
    defer allocator.free(db_path_z);

    var handle: ?*c.sqlite3 = null;
    const flags = c.SQLITE_OPEN_READWRITE | c.SQLITE_OPEN_CREATE | c.SQLITE_OPEN_FULLMUTEX;
    const rc = c.sqlite3_open_v2(db_path_z.ptr, &handle, flags, null);
    if (rc != c.SQLITE_OK or handle == null) return makeDbError(handle, rc);

    var db = Db{
        .allocator = allocator,
        .handle = handle.?,
    };
    errdefer db.close();

    _ = c.sqlite3_busy_timeout(db.handle, 5_000);
    try db.exec("PRAGMA journal_mode=WAL;");
    try db.exec("PRAGMA synchronous=NORMAL;");
    try db.exec("PRAGMA foreign_keys=ON;");
    try initSchema(&db);

    return db;
}

pub fn initSchema(db: *Db) !void {
    try db.exec(
        "CREATE TABLE IF NOT EXISTS sessions (" ++
            "url TEXT PRIMARY KEY," ++
            "ws_url TEXT NOT NULL," ++
            "ready_to_collect INTEGER NOT NULL DEFAULT 0," ++
            "last_download_count INTEGER NOT NULL DEFAULT 0," ++
            "last_textarea_found INTEGER NOT NULL DEFAULT 0," ++
            "last_upload_input_found INTEGER NOT NULL DEFAULT 0," ++
            "last_send_button_found INTEGER NOT NULL DEFAULT 0," ++
            "last_send_enabled INTEGER NOT NULL DEFAULT 0," ++
            "last_attachment_count INTEGER NOT NULL DEFAULT 0," ++
            "last_assistant_message_count INTEGER NOT NULL DEFAULT 0," ++
            "last_login_elements_found INTEGER NOT NULL DEFAULT 0," ++
            "last_captcha_found INTEGER NOT NULL DEFAULT 0," ++
            "last_blocked_indicators INTEGER NOT NULL DEFAULT 0," ++
            "last_prompt TEXT," ++
            "last_download_dir TEXT," ++
            "last_error_json TEXT," ++
            "send_count INTEGER NOT NULL DEFAULT 0," ++
            "collect_count INTEGER NOT NULL DEFAULT 0," ++
            "updated_at INTEGER NOT NULL" ++
        ");" ++
        "CREATE TABLE IF NOT EXISTS queue_jobs (" ++
            "run_root TEXT NOT NULL," ++
            "job_id TEXT NOT NULL," ++
            "team_id TEXT NOT NULL," ++
            "role TEXT NOT NULL," ++
            "deliverable TEXT NOT NULL," ++
            "task TEXT NOT NULL," ++
            "prompt TEXT NOT NULL," ++
            "state TEXT NOT NULL," ++
            "created_at INTEGER NOT NULL," ++
            "updated_at INTEGER NOT NULL," ++
            "PRIMARY KEY(run_root, job_id)" ++
        ");" ++
        "CREATE TABLE IF NOT EXISTS batch_locks (" ++
            "batch_base TEXT NOT NULL," ++
            "spec_path TEXT NOT NULL," ++
            "batch_id TEXT NOT NULL," ++
            "team_count INTEGER NOT NULL," ++
            "created_at INTEGER NOT NULL," ++
            "PRIMARY KEY(batch_base, spec_path)" ++
        ");" ++
        "CREATE TABLE IF NOT EXISTS batch_team_roots (" ++
            "batch_base TEXT NOT NULL," ++
            "spec_path TEXT NOT NULL," ++
            "team_id TEXT NOT NULL," ++
            "run_root TEXT NOT NULL," ++
            "PRIMARY KEY(batch_base, spec_path, team_id)" ++
        ");"
    );
}

fn makeError(rc: c_int, err_msg: ?[*:0]u8) anyerror {
    if (err_msg) |ptr| {
        std.log.err("sqlite exec failed rc={} msg={s}", .{ rc, std.mem.span(ptr) });
    }
    return mapSqliteError(rc);
}

fn makeDbError(handle: ?*c.sqlite3, rc: c_int) anyerror {
    if (handle) |db| {
        const msg = c.sqlite3_errmsg(db);
        if (msg != null) {
            std.log.err("sqlite failed rc={} msg={s}", .{ rc, std.mem.span(msg) });
        }
    }
    return mapSqliteError(rc);
}

fn mapSqliteError(rc: c_int) anyerror {
    return switch (rc) {
        c.SQLITE_BUSY => error.SqliteBusy,
        c.SQLITE_LOCKED => error.SqliteLocked,
        c.SQLITE_READONLY => error.SqliteReadonly,
        c.SQLITE_IOERR => error.SqliteIo,
        c.SQLITE_CONSTRAINT => error.SqliteConstraint,
        c.SQLITE_CORRUPT => error.SqliteCorrupt,
        c.SQLITE_NOTADB => error.SqliteNotADatabase,
        else => error.SqliteFailure,
    };
}
