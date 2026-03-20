const std = @import("std");
const common = @import("common.zig");
const chatgpt = @import("chatgpt.zig");
const sqlite = @import("sqlite.zig");

pub const Job = struct {
    team_id: []const u8,
    job_id: []const u8,
    role: []const u8,
    deliverable: []const u8,
    task: []const u8,
};

pub const QueueStatus = struct {
    pending: usize,
    running: usize,
    done: usize,
    failed: usize,
};

fn now() i64 {
    return common.nowUnixSeconds();
}

pub fn ensureLayout(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !void {
    const paths = [_][]const u8{
        try std.fmt.allocPrint(allocator, "{s}/instructions", .{run_root}),
        try std.fmt.allocPrint(allocator, "{s}/artifacts", .{run_root}),
    };
    defer for (paths) |p| allocator.free(p);

    try common.ensureDirPath(io, run_root);
    for (paths) |p| try common.ensureDirPath(io, p);

    var db = try sqlite.openRunDb(io, allocator, run_root);
    defer db.close();
}

pub fn renderExpectedPayload(allocator: std.mem.Allocator, job: Job) ![]u8 {
    return std.json.Stringify.valueAlloc(allocator, .{
        .ok = true,
        .team_id = job.team_id,
        .job_id = job.job_id,
        .role = job.role,
        .deliverable = job.deliverable,
        .task = job.task,
    }, .{ .whitespace = .indent_2 });
}

pub fn enqueue(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, job: Job) !void {
    try ensureLayout(io, allocator, run_root);

    const instruction_path = try std.fmt.allocPrint(
        allocator,
        "{s}/instructions/{s}.txt",
        .{ run_root, job.job_id },
    );
    defer allocator.free(instruction_path);
    try common.writeFile(io, instruction_path, job.task);

    const prompt = try chatgpt.buildDispatchPrompt(allocator, job.task, job.deliverable, true);
    defer allocator.free(prompt);

    var db = try sqlite.openRunDb(io, allocator, run_root);
    defer db.close();

    var stmt = try db.prepare(
        "INSERT INTO queue_jobs (run_root, job_id, team_id, role, deliverable, task, prompt, state, created_at, updated_at) " ++
            "VALUES (?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?) " ++
            "ON CONFLICT(run_root, job_id) DO UPDATE SET " ++
            "team_id=excluded.team_id, role=excluded.role, deliverable=excluded.deliverable, task=excluded.task, prompt=excluded.prompt, state='pending', updated_at=excluded.updated_at"
    );
    defer stmt.finalize();

    const ts = now();
    try stmt.bindText(1, run_root);
    try stmt.bindText(2, job.job_id);
    try stmt.bindText(3, job.team_id);
    try stmt.bindText(4, job.role);
    try stmt.bindText(5, job.deliverable);
    try stmt.bindText(6, job.task);
    try stmt.bindText(7, prompt);
    try stmt.bindInt64(8, ts);
    try stmt.bindInt64(9, ts);
    _ = try stmt.step();
}

pub fn status(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !QueueStatus {
    var db = try sqlite.openRunDb(io, allocator, run_root);
    defer db.close();

    return .{
        .pending = try countByState(&db, run_root, "pending"),
        .running = try countByState(&db, run_root, "running"),
        .done = try countByState(&db, run_root, "done"),
        .failed = try countByState(&db, run_root, "failed"),
    };
}

fn countByState(db: *sqlite.Db, run_root: []const u8, state: []const u8) !usize {
    var stmt = try db.prepare(
        "SELECT COUNT(*) FROM queue_jobs WHERE run_root = ? AND state = ?"
    );
    defer stmt.finalize();

    try stmt.bindText(1, run_root);
    try stmt.bindText(2, state);
    const step = try stmt.step();
    if (step != .row) return 0;
    return @intCast(try stmt.columnInt64(0));
}

pub fn dispatchFake(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !usize {
    var db = try sqlite.openRunDb(io, allocator, run_root);
    defer db.close();

    var stmt = try db.prepare(
        "SELECT team_id, job_id, role, deliverable, task " ++
            "FROM queue_jobs WHERE run_root = ? AND state = 'pending' ORDER BY created_at, job_id"
    );
    defer stmt.finalize();
    try stmt.bindText(1, run_root);

    var jobs: std.ArrayList(Job) = .empty;
    defer {
        for (jobs.items) |job| {
            allocator.free(job.team_id);
            allocator.free(job.job_id);
            allocator.free(job.role);
            allocator.free(job.deliverable);
            allocator.free(job.task);
        }
        jobs.deinit(allocator);
    }

    while (true) {
        switch (try stmt.step()) {
            .row => {
                try jobs.append(allocator, .{
                    .team_id = try stmt.columnTextAlloc(allocator, 0),
                    .job_id = try stmt.columnTextAlloc(allocator, 1),
                    .role = try stmt.columnTextAlloc(allocator, 2),
                    .deliverable = try stmt.columnTextAlloc(allocator, 3),
                    .task = try stmt.columnTextAlloc(allocator, 4),
                });
            },
            .done => break,
        }
    }

    var update_stmt = try db.prepare(
        "UPDATE queue_jobs SET state = ?, updated_at = ? WHERE run_root = ? AND job_id = ?"
    );
    defer update_stmt.finalize();

    var processed: usize = 0;
    for (jobs.items) |job| {
        const artifact_payload = try renderExpectedPayload(allocator, job);
        defer allocator.free(artifact_payload);

        const artifact_path = try std.fmt.allocPrint(
            allocator,
            "{s}/artifacts/{s}",
            .{ run_root, job.deliverable },
        );
        defer allocator.free(artifact_path);
        try common.writeFile(io, artifact_path, artifact_payload);

        update_stmt.reset();
        try update_stmt.bindText(1, "done");
        try update_stmt.bindInt64(2, now());
        try update_stmt.bindText(3, run_root);
        try update_stmt.bindText(4, job.job_id);
        _ = try update_stmt.step();
        processed += 1;
    }

    return processed;
}

pub fn superviseFake(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8) !QueueStatus {
    while (true) {
        const processed = try dispatchFake(io, allocator, run_root);
        if (processed == 0) break;
    }
    return status(io, allocator, run_root);
}
