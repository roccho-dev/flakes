const std = @import("std");
const common = @import("common.zig");
const queue = @import("queue.zig");
const sqlite = @import("sqlite.zig");

pub const PreflightResult = struct {
    ok: bool,
    error_count: usize,
};

pub const ApplyResult = struct {
    ok: bool,
    batch_id: []const u8,
    team_count: usize,
    lock_path: []const u8,
};

pub const RunResult = struct {
    ok: bool,
    jobs_enqueued: usize,
    jobs_done: usize,
};

pub const DoctorResult = struct {
    ok: bool,
    lock_exists: bool,
    team_root_count: usize,
};

fn now() i64 {
    return common.nowUnixSeconds();
}

fn parseSpec(allocator: std.mem.Allocator, raw: []const u8) !std.json.Parsed(std.json.Value) {
    return std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
}

pub fn preflight(io: std.Io, allocator: std.mem.Allocator, spec_path: []const u8) !PreflightResult {
    const raw = try common.readFileAlloc(io, allocator, spec_path, 1024 * 1024);
    defer allocator.free(raw);

    const parsed = parseSpec(allocator, raw) catch return .{ .ok = false, .error_count = 1 };
    defer parsed.deinit();

    const value = parsed.value;
    if (value != .object) return .{ .ok = false, .error_count = 1 };

    var errors: usize = 0;
    if (value.object.get("schema_version") == null) errors += 1;
    if (value.object.get("batch_id") == null) errors += 1;
    if (value.object.get("teams") == null) errors += 1;
    if (value.object.get("jobs") == null) errors += 1;

    return .{ .ok = errors == 0, .error_count = errors };
}

fn specBatchId(value: std.json.Value) ![]const u8 {
    if (value != .object) return error.InvalidSpec;
    const batch_value = value.object.get("batch_id") orelse return error.InvalidSpec;
    if (batch_value != .string) return error.InvalidSpec;
    return batch_value.string;
}

fn specTeams(value: std.json.Value) !std.json.Array {
    if (value != .object) return error.InvalidSpec;
    const teams_value = value.object.get("teams") orelse return error.InvalidSpec;
    if (teams_value != .array) return error.InvalidSpec;
    return teams_value.array;
}

fn specJobs(value: std.json.Value) !std.json.Array {
    if (value != .object) return error.InvalidSpec;
    const jobs_value = value.object.get("jobs") orelse return error.InvalidSpec;
    if (jobs_value != .array) return error.InvalidSpec;
    return jobs_value.array;
}

pub fn apply(io: std.Io, allocator: std.mem.Allocator, batch_base: []const u8, spec_path: []const u8) !ApplyResult {
    const raw = try common.readFileAlloc(io, allocator, spec_path, 1024 * 1024);
    defer allocator.free(raw);

    const parsed = try parseSpec(allocator, raw);
    defer parsed.deinit();

    const batch_id = try allocator.dupe(u8, try specBatchId(parsed.value));
    errdefer allocator.free(batch_id);

    try common.ensureDirPath(io, batch_base);
    var db = try sqlite.openRunDb(io, allocator, batch_base);
    defer db.close();

    const teams = try specTeams(parsed.value);

    var delete_stmt = try db.prepare(
        "DELETE FROM batch_team_roots WHERE batch_base = ? AND spec_path = ?"
    );
    defer delete_stmt.finalize();
    try delete_stmt.bindText(1, batch_base);
    try delete_stmt.bindText(2, spec_path);
    _ = try delete_stmt.step();

    var insert_team_stmt = try db.prepare(
        "INSERT OR REPLACE INTO batch_team_roots (batch_base, spec_path, team_id, run_root) VALUES (?, ?, ?, ?)"
    );
    defer insert_team_stmt.finalize();

    for (teams.items) |team| {
        if (team != .object) continue;
        const team_value = team.object.get("team_id") orelse continue;
        if (team_value != .string) continue;

        const run_root = try std.fmt.allocPrint(
            allocator,
            "{s}/batches/{s}/{s}",
            .{ batch_base, batch_id, team_value.string },
        );
        defer allocator.free(run_root);
        try queue.ensureLayout(io, allocator, run_root);

        insert_team_stmt.reset();
        try insert_team_stmt.bindText(1, batch_base);
        try insert_team_stmt.bindText(2, spec_path);
        try insert_team_stmt.bindText(3, team_value.string);
        try insert_team_stmt.bindText(4, run_root);
        _ = try insert_team_stmt.step();
    }

    var lock_stmt = try db.prepare(
        "INSERT OR REPLACE INTO batch_locks (batch_base, spec_path, batch_id, team_count, created_at) VALUES (?, ?, ?, ?, ?)"
    );
    defer lock_stmt.finalize();
    try lock_stmt.bindText(1, batch_base);
    try lock_stmt.bindText(2, spec_path);
    try lock_stmt.bindText(3, batch_id);
    try lock_stmt.bindInt64(4, @intCast(teams.items.len));
    try lock_stmt.bindInt64(5, now());
    _ = try lock_stmt.step();

    return .{
        .ok = true,
        .batch_id = batch_id,
        .team_count = teams.items.len,
        .lock_path = try sqlite.dbPathAlloc(allocator, batch_base),
    };
}

pub fn run(io: std.Io, allocator: std.mem.Allocator, batch_base: []const u8, spec_path: []const u8) !RunResult {
    const applied = try apply(io, allocator, batch_base, spec_path);
    defer {
        allocator.free(applied.batch_id);
        allocator.free(applied.lock_path);
    }

    const raw = try common.readFileAlloc(io, allocator, spec_path, 1024 * 1024);
    defer allocator.free(raw);

    const parsed = try parseSpec(allocator, raw);
    defer parsed.deinit();

    const jobs = try specJobs(parsed.value);
    var jobs_done: usize = 0;

    for (jobs.items) |job_value| {
        if (job_value != .object) continue;
        const obj = job_value.object;
        const team_id = obj.get("team_id").?.string;
        const job_id = obj.get("job_id").?.string;
        const role = obj.get("role").?.string;
        const deliverable = obj.get("deliverable").?.string;
        const task = obj.get("task").?.string;

        const run_root = try std.fmt.allocPrint(
            allocator,
            "{s}/batches/{s}/{s}",
            .{ batch_base, applied.batch_id, team_id },
        );
        defer allocator.free(run_root);

        try queue.enqueue(io, allocator, run_root, .{
            .team_id = team_id,
            .job_id = job_id,
            .role = role,
            .deliverable = deliverable,
            .task = task,
        });
        jobs_done += try queue.dispatchFake(io, allocator, run_root);
    }

    return .{
        .ok = true,
        .jobs_enqueued = jobs.items.len,
        .jobs_done = jobs_done,
    };
}

pub fn doctor(io: std.Io, allocator: std.mem.Allocator, batch_base: []const u8, spec_path: []const u8) !DoctorResult {
    const raw = try common.readFileAlloc(io, allocator, spec_path, 1024 * 1024);
    defer allocator.free(raw);

    const parsed = try parseSpec(allocator, raw);
    defer parsed.deinit();

    const batch_id = try specBatchId(parsed.value);
    const teams = try specTeams(parsed.value);

    var db = try sqlite.openRunDb(io, allocator, batch_base);
    defer db.close();

    var stmt = try db.prepare(
        "SELECT COUNT(*) FROM batch_locks WHERE batch_base = ? AND spec_path = ? AND batch_id = ?"
    );
    defer stmt.finalize();
    try stmt.bindText(1, batch_base);
    try stmt.bindText(2, spec_path);
    try stmt.bindText(3, batch_id);
    const lock_exists = switch (try stmt.step()) {
        .row => (try stmt.columnInt64(0)) > 0,
        .done => false,
    };

    var team_root_count: usize = 0;
    for (teams.items) |team| {
        if (team != .object) continue;
        const team_id = team.object.get("team_id") orelse continue;
        if (team_id != .string) continue;
        const run_root = try std.fmt.allocPrint(
            allocator,
            "{s}/batches/{s}/{s}",
            .{ batch_base, batch_id, team_id.string },
        );
        defer allocator.free(run_root);
        const db_path = try sqlite.dbPathAlloc(allocator, run_root);
        defer allocator.free(db_path);
        if (common.exists(io, run_root) and common.exists(io, db_path)) team_root_count += 1;
    }

    return .{
        .ok = lock_exists and team_root_count == teams.items.len,
        .lock_exists = lock_exists,
        .team_root_count = team_root_count,
    };
}
