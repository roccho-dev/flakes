const std = @import("std");
const hq = @import("hq");
const cdp = @import("cdp");

const playbook_md = @embedFile("../docs/chatgpt_playbook.md");

const Runtime = struct {
    gpa: std.mem.Allocator,
    threaded: std.Io.Threaded,
    io: std.Io,
    environ_map: std.process.Environ.Map,

    pub fn init(minimal: std.process.Init.Minimal) !@This() {
        const gpa = std.heap.c_allocator;
        var threaded: std.Io.Threaded = .init(gpa, .{
            .argv0 = .init(minimal.args),
            .environ = minimal.environ,
        });
        errdefer threaded.deinit();

        var environ_map = try std.process.Environ.createMap(minimal.environ, gpa);
        errdefer environ_map.deinit();

        return .{
            .gpa = gpa,
            .threaded = threaded,
            .io = threaded.io(),
            .environ_map = environ_map,
        };
    }

    pub fn deinit(self: *@This()) void {
        self.environ_map.deinit();
        self.threaded.deinit();
    }
};

fn usage() []const u8 {
    return
        \\hq: Zig single-binary HQ
        \\
        \\Usage:
        \\  hq playbook
        \\  hq init [--runRoot PATH]
        \\  hq doctor [--runRoot PATH]
        \\  hq status --runRoot PATH --wsUrl WS_URL --url CHAT_URL
        \\  hq send --runRoot PATH --wsUrl WS_URL --url CHAT_URL (--prompt TEXT | --promptFile PATH) [--upload PATH]
        \\  hq collect --runRoot PATH --wsUrl WS_URL --url CHAT_URL [--downloadDir PATH]
        \\  hq ui read --wsUrl WS_URL --url CHAT_URL
        \\  hq ui get --wsUrl WS_URL --url CHAT_URL --outDir PATH
        \\  hq queue status --runRoot PATH
        \\  hq batch preflight --spec PATH
        \\  hq batch apply --runRoot PATH --spec PATH
        \\  hq batch run --runRoot PATH --spec PATH
        \\  hq batch doctor --runRoot PATH --spec PATH
        \\  hq selftest chrome --runRoot PATH [--chrome PATH] [--port N]
        \\  hq cdp version
        \\
        \\Common flags:
        \\  --quiet   Disable the mental model banner (stderr)
    ;
}

fn flagTrue(parsed: *const hq.common.ParsedArgs, name: []const u8) bool {
    const v = parsed.get(name) orelse return false;
    if (std.mem.eql(u8, v, "0") or std.mem.eql(u8, v, "false")) return false;
    return true;
}

fn emitMentalModelBanner(io: std.Io, parsed: *const hq.common.ParsedArgs, cmd: []const u8) void {
    if (flagTrue(parsed, "quiet")) return;
    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) return;
    if (std.mem.eql(u8, cmd, "playbook")) return;
    if (std.mem.eql(u8, cmd, "__manual_fixture")) return;
    if (std.mem.eql(u8, cmd, "cdp") and parsed.positionals.items.len > 0 and std.mem.eql(u8, parsed.positionals.items[0], "version")) return;

    var buffer: [1024]u8 = undefined;
    var writer = std.Io.File.stderr().writer(io, &buffer);
    writer.interface.writeAll("HQ mental model: run `hq playbook`\n") catch {};
    writer.interface.writeAll("Thread status: qjs --std -m parts/chromedevtoolprotocol/chromium-cdp.hq-threads.mjs --statusOnly\n") catch {};
    writer.interface.writeAll("Worker replies must include: MODEL_CONFIRMATION: Pro=YES | MODEL=<exact UI label>\n") catch {};
    writer.interface.writeAll("(Disable this banner with --quiet)\n") catch {};
    writer.interface.flush() catch {};
}

fn writeStdoutText(io: std.Io, text: []const u8) !void {
    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.writeAll(text);
    if (text.len == 0 or text[text.len - 1] != '\n') try writer.interface.writeAll("\n");
    try writer.interface.flush();
}

fn writeJson(io: std.Io, value: anytype) !void {
    const out = try std.json.Stringify.valueAlloc(std.heap.page_allocator, value, .{ .whitespace = .indent_2 });
    defer std.heap.page_allocator.free(out);

    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    try writer.interface.writeAll(out);
    try writer.interface.writeAll("\n");
    try writer.interface.flush();
}

pub const UiGetManifest = struct {
    manifest_version: u32 = 1,
    ok: bool = true,
    url: []const u8,
    model_confirmation: []const u8,
    model_pro: []const u8,
    model_label: []const u8,
    out_dir: []const u8,
    patch: []const u8,
    test_report: []const u8,
    checklist: []const u8,
    worker_block: []const u8,
    meta: []const u8,
};

pub fn ensureUiGetOutDirEmpty(io: std.Io, out_dir: []const u8) !void {
    try hq.common.ensureDirPath(io, out_dir);
    const entries = try hq.common.countEntries(io, out_dir);
    if (entries != 0) return error.OutDirNotEmpty;
}

pub fn writeUiGetManifestAtomic(io: std.Io, allocator: std.mem.Allocator, out_dir: []const u8, manifest: UiGetManifest) ![]u8 {
    const manifest_path = try std.fmt.allocPrint(allocator, "{s}/MANIFEST.json", .{out_dir});
    errdefer allocator.free(manifest_path);
    const tmp_path = try std.fmt.allocPrint(allocator, "{s}/MANIFEST.json.tmp", .{out_dir});
    defer allocator.free(tmp_path);

    const raw = try std.json.Stringify.valueAlloc(allocator, .{
        .manifest_version = manifest.manifest_version,
        .ok = manifest.ok,
        .url = manifest.url,
        .model_confirmation = manifest.model_confirmation,
        .model_pro = manifest.model_pro,
        .model_label = manifest.model_label,
        .outDir = manifest.out_dir,
        .patch = manifest.patch,
        .test_report = manifest.test_report,
        .checklist = manifest.checklist,
        .worker_block = manifest.worker_block,
        .meta = manifest.meta,
    }, .{ .whitespace = .indent_2 });
    defer allocator.free(raw);

    // Write last + atomically so consumers can watch for MANIFEST.json.
    try hq.common.writeFile(io, tmp_path, raw);
    try hq.common.rename(io, tmp_path, manifest_path);
    return manifest_path;
}

fn emitUsageAndExit() noreturn {
    std.debug.print("{s}\n", .{usage()});
    std.process.exit(2);
}

fn requireFlag(parsed: *const hq.common.ParsedArgs, name: []const u8) []const u8 {
    return parsed.get(name) orelse {
        std.debug.print("Missing --{s}\n", .{name});
        std.process.exit(2);
    };
}

fn emitManualAndExit(io: std.Io, gpa: std.mem.Allocator, issue: hq.manual.ManualInterventionRequired) noreturn {
    const raw = issue.stringifyAlloc(gpa) catch {
        std.debug.print("failed to stringify ManualInterventionRequired\n", .{});
        std.process.exit(1);
    };
    defer gpa.free(raw);

    var buffer: [4096]u8 = undefined;
    var writer = std.Io.File.stdout().writer(io, &buffer);
    writer.interface.writeAll(raw) catch {};
    writer.interface.writeAll("\n") catch {};
    writer.interface.flush() catch {};
    std.process.exit(hq.manual.exit_code);
}

fn readPrompt(io: std.Io, gpa: std.mem.Allocator, parsed: *const hq.common.ParsedArgs) ![]u8 {
    if (parsed.get("prompt")) |value| return gpa.dupe(u8, value);
    if (parsed.get("promptFile")) |path| return hq.common.readFileAlloc(io, gpa, path, 1024 * 1024);
    return error.MissingPrompt;
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try Runtime.init(minimal);
    defer runtime.deinit();

    const gpa = runtime.gpa;
    const io = runtime.io;

    var iter = try std.process.Args.Iterator.initAllocator(minimal.args, gpa);
    defer iter.deinit();

    var argv: std.ArrayList([]const u8) = .empty;
    defer argv.deinit(gpa);

    while (iter.next()) |arg_z| {
        const arg: []const u8 = arg_z[0..arg_z.len];
        try argv.append(gpa, try gpa.dupe(u8, arg));
    }
    defer for (argv.items) |item| gpa.free(item);

    if (argv.items.len <= 1) emitUsageAndExit();

    const exe_path = argv.items[0];
    const cmd = argv.items[1];
    const parsed = try hq.common.parseArgs(gpa, argv.items[2..]);
    defer {
        var mut = parsed;
        mut.deinit();
    }

    if (std.mem.eql(u8, cmd, "help") or std.mem.eql(u8, cmd, "--help") or std.mem.eql(u8, cmd, "-h")) {
        std.debug.print("{s}\n", .{usage()});
        return;
    }

    if (std.mem.eql(u8, cmd, "playbook")) {
        try writeStdoutText(io, playbook_md);
        return;
    }

    emitMentalModelBanner(io, &parsed, cmd);

    if (std.mem.eql(u8, cmd, "__manual_fixture")) {
        emitManualAndExit(io, gpa, hq.selftest.manualFixtureIssue());
    }

    if (std.mem.eql(u8, cmd, "cdp")) {
        if (parsed.positionals.items.len > 0 and std.mem.eql(u8, parsed.positionals.items[0], "version")) {
            try writeJson(io, .{ .module = "chromedevtoolprotocol.zig", .version = cdp.version });
            return;
        }
        emitUsageAndExit();
    }

    if (std.mem.eql(u8, cmd, "init")) {
        const run_root = try hq.common.resolveRunRoot(gpa, &parsed, runtime.environ_map.get("HOME"));
        defer gpa.free(run_root);

        try hq.common.ensureDirPath(io, run_root);
        var db = try hq.sqlite.openRunDb(io, gpa, run_root);
        defer db.close();

        const template_dir = try std.fmt.allocPrint(gpa, "{s}/templates", .{run_root});
        defer gpa.free(template_dir);
        const template_path = try std.fmt.allocPrint(gpa, "{s}/batch.hq.yaml", .{template_dir});
        defer gpa.free(template_path);
        const db_path = try hq.sqlite.dbPathAlloc(gpa, run_root);
        defer gpa.free(db_path);

        try hq.common.ensureDirPath(io, template_dir);
        if (!hq.common.exists(io, template_path)) {
            const template =
                \\{
                \\  "schema_version": 1,
                \\  "batch_id": "example-001",
                \\  "teams": [
                \\    { "team_id": "teamA", "sessions": { "ceo": "https://chatgpt.com/c/<id>" } }
                \\  ],
                \\  "jobs": [
                \\    {
                \\      "team_id": "teamA",
                \\      "job_id": "CEO-ORDERS",
                \\      "role": "ceo",
                \\      "deliverable": "teamA_orders.json",
                \\      "task": "目的に向けて jobs[] を発行せよ"
                \\    }
                \\  ]
                \\}
            ;
            try hq.common.writeFile(io, template_path, template);
        }

        try writeJson(io, .{ .ok = true, .runRoot = run_root, .db = db_path, .template = template_path });
        return;
    }

    if (std.mem.eql(u8, cmd, "doctor")) {
        const run_root = try hq.common.resolveRunRoot(gpa, &parsed, runtime.environ_map.get("HOME"));
        defer gpa.free(run_root);
        const db_path = try hq.sqlite.dbPathAlloc(gpa, run_root);
        defer gpa.free(db_path);
        try writeJson(io, .{
            .ok = hq.common.exists(io, run_root) and hq.common.exists(io, db_path),
            .runRoot = run_root,
            .db = db_path,
            .cdpModule = cdp.version,
        });
        return;
    }

    if (std.mem.eql(u8, cmd, "status")) {
        const run_root = requireFlag(&parsed, "runRoot");
        const ws_url = requireFlag(&parsed, "wsUrl");
        const url = requireFlag(&parsed, "url");
        const outcome = try hq.adapter.status(io, gpa, run_root, ws_url, url);
        switch (outcome) {
            .ok => |result| try writeJson(io, .{
                .ok = true,
                .url = result.url,
                .ready_to_collect = result.ready_to_collect,
                .observed = result.observed,
            }),
            .manual => |issue| emitManualAndExit(io, gpa, issue),
        }
        return;
    }

    if (std.mem.eql(u8, cmd, "send")) {
        const run_root = requireFlag(&parsed, "runRoot");
        const ws_url = requireFlag(&parsed, "wsUrl");
        const url = requireFlag(&parsed, "url");
        const upload_path = parsed.get("upload");
        const prompt = readPrompt(io, gpa, &parsed) catch |err| switch (err) {
            error.MissingPrompt => {
                std.debug.print("Missing --prompt or --promptFile\n", .{});
                std.process.exit(2);
            },
            else => return err,
        };
        defer gpa.free(prompt);

        const outcome = try hq.adapter.send(io, gpa, run_root, ws_url, url, prompt, upload_path);
        switch (outcome) {
            .ok => |result| try writeJson(io, .{ .ok = true, .url = result.url, .observed = result.observed }),
            .manual => |issue| emitManualAndExit(io, gpa, issue),
        }
        return;
    }

    if (std.mem.eql(u8, cmd, "collect")) {
        const run_root = requireFlag(&parsed, "runRoot");
        const ws_url = requireFlag(&parsed, "wsUrl");
        const url = requireFlag(&parsed, "url");
        const download_dir = parsed.get("downloadDir") orelse blk: {
            break :blk try std.fmt.allocPrint(gpa, "{s}/downloads", .{run_root});
        };
        defer if (parsed.get("downloadDir") == null) gpa.free(download_dir);

        const outcome = try hq.adapter.collect(io, gpa, run_root, ws_url, url, download_dir);
        switch (outcome) {
            .ok => |result| try writeJson(io, .{
                .ok = true,
                .url = result.url,
                .download_dir = result.download_dir,
                .downloaded_files = result.downloaded_files,
                .observed = result.observed,
            }),
            .manual => |issue| emitManualAndExit(io, gpa, issue),
        }
        return;
    }

    if (std.mem.eql(u8, cmd, "ui")) {
        if (parsed.positionals.items.len == 0) emitUsageAndExit();
        const sub = parsed.positionals.items[0];
        const ws_url = requireFlag(&parsed, "wsUrl");
        const url = requireFlag(&parsed, "url");

        var automation = try hq.adapter.Automation.connectForUrl(gpa, io, ws_url, url);
        defer automation.deinit();
        try automation.ensureAtUrl(url);

        if (std.mem.eql(u8, sub, "read")) {
            const raw = try automation.uiReadOnCurrentPage();
            defer gpa.free(raw);
            const parsed_json = try std.json.parseFromSlice(std.json.Value, gpa, raw, .{});
            defer parsed_json.deinit();
            try writeJson(io, parsed_json.value);
            return;
        }

        if (std.mem.eql(u8, sub, "get")) {
            const out_dir = requireFlag(&parsed, "outDir");
            ensureUiGetOutDirEmpty(io, out_dir) catch |err| switch (err) {
                error.OutDirNotEmpty => {
                    std.debug.print("outDir is not empty: {s}\n", .{out_dir});
                    std.process.exit(2);
                },
                else => return err,
            };

            const outcome = try automation.uiGetWorkerBlockOnCurrentPage(url);
            switch (outcome) {
                .manual => |issue| emitManualAndExit(io, gpa, issue),
                .ok => |payload| {
                    defer {
                        gpa.free(payload.url);
                        gpa.free(payload.model_confirmation_line);
                        gpa.free(payload.model_pro);
                        gpa.free(payload.model_label);
                        gpa.free(payload.worker_block_raw);
                        gpa.free(payload.patch);
                        gpa.free(payload.test_report);
                        gpa.free(payload.checklist);
                        gpa.free(payload.errors);
                    }

                    const patch_path = try std.fmt.allocPrint(gpa, "{s}/PATCH.diff", .{out_dir});
                    defer gpa.free(patch_path);
                    const report_path = try std.fmt.allocPrint(gpa, "{s}/TEST_REPORT_worker", .{out_dir});
                    defer gpa.free(report_path);
                    const checklist_path = try std.fmt.allocPrint(gpa, "{s}/CHECKLIST", .{out_dir});
                    defer gpa.free(checklist_path);
                    const block_path = try std.fmt.allocPrint(gpa, "{s}/WORKER_BLOCK", .{out_dir});
                    defer gpa.free(block_path);
                    const meta_path = try std.fmt.allocPrint(gpa, "{s}/ui_get.json", .{out_dir});
                    defer gpa.free(meta_path);

                    try hq.common.writeFile(io, patch_path, payload.patch);
                    try hq.common.writeFile(io, report_path, payload.test_report);
                    try hq.common.writeFile(io, checklist_path, payload.checklist);
                    try hq.common.writeFile(io, block_path, payload.worker_block_raw);

                    const meta = try std.json.Stringify.valueAlloc(gpa, .{
                        .ok = true,
                        .url = payload.url,
                        .model_confirmation = payload.model_confirmation_line,
                        .model_pro = payload.model_pro,
                        .model_label = payload.model_label,
                        .errors = payload.errors,
                    }, .{ .whitespace = .indent_2 });
                    defer gpa.free(meta);
                    try hq.common.writeFile(io, meta_path, meta);

                    const manifest_path = try writeUiGetManifestAtomic(io, gpa, out_dir, .{
                        .url = payload.url,
                        .model_confirmation = payload.model_confirmation_line,
                        .model_pro = payload.model_pro,
                        .model_label = payload.model_label,
                        .out_dir = out_dir,
                        .patch = patch_path,
                        .test_report = report_path,
                        .checklist = checklist_path,
                        .worker_block = block_path,
                        .meta = meta_path,
                    });
                    defer gpa.free(manifest_path);

                    try writeJson(io, .{
                        .ok = true,
                        .url = payload.url,
                        .model_confirmation = payload.model_confirmation_line,
                        .model_pro = payload.model_pro,
                        .model_label = payload.model_label,
                        .outDir = out_dir,
                        .patch = patch_path,
                        .test_report = report_path,
                        .checklist = checklist_path,
                        .worker_block = block_path,
                        .meta = meta_path,
                        .manifest = manifest_path,
                    });
                    return;
                },
            }
        }

        emitUsageAndExit();
    }

    if (std.mem.eql(u8, cmd, "queue")) {
        if (parsed.positionals.items.len == 0) emitUsageAndExit();
        const sub = parsed.positionals.items[0];
        const run_root = requireFlag(&parsed, "runRoot");

        if (std.mem.eql(u8, sub, "status")) {
            const s = try hq.queue.status(io, gpa, run_root);
            try writeJson(io, .{ .pending = s.pending, .running = s.running, .done = s.done, .failed = s.failed });
            return;
        }
        emitUsageAndExit();
    }

    if (std.mem.eql(u8, cmd, "batch")) {
        if (parsed.positionals.items.len == 0) emitUsageAndExit();
        const sub = parsed.positionals.items[0];
        const spec = requireFlag(&parsed, "spec");

        if (std.mem.eql(u8, sub, "preflight")) {
            const res = try hq.batch.preflight(io, gpa, spec);
            try writeJson(io, res);
            return;
        }

        const run_root = requireFlag(&parsed, "runRoot");
        if (std.mem.eql(u8, sub, "apply")) {
            const res = try hq.batch.apply(io, gpa, run_root, spec);
            defer {
                gpa.free(res.batch_id);
                gpa.free(res.lock_path);
            }
            try writeJson(io, .{ .ok = res.ok, .batch_id = res.batch_id, .team_count = res.team_count, .db = res.lock_path });
            return;
        }
        if (std.mem.eql(u8, sub, "run")) {
            const res = try hq.batch.run(io, gpa, run_root, spec);
            try writeJson(io, res);
            return;
        }
        if (std.mem.eql(u8, sub, "doctor")) {
            const res = try hq.batch.doctor(io, gpa, run_root, spec);
            try writeJson(io, res);
            return;
        }
        emitUsageAndExit();
    }

    if (std.mem.eql(u8, cmd, "selftest")) {
        if (parsed.positionals.items.len == 0) emitUsageAndExit();
        const sub = parsed.positionals.items[0];
        if (!std.mem.eql(u8, sub, "chrome")) emitUsageAndExit();

        const run_root = requireFlag(&parsed, "runRoot");
        const port: u16 = if (parsed.get("port")) |value|
            std.fmt.parseInt(u16, value, 10) catch {
                std.debug.print("Invalid --port\n", .{});
                std.process.exit(2);
            }
        else
            19_921;

        const result = hq.selftest.runChrome(io, gpa, .{
            .run_root = run_root,
            .exe_path = exe_path,
            .chrome_path = parsed.get("chrome"),
            .port = port,
        }) catch |run_err| {
            try writeJson(io, .{ .ok = false, .reason = @errorName(run_err) });
            std.process.exit(1);
        };
        try writeJson(io, result);
        if (!result.ok) std.process.exit(1);
        return;
    }

    emitUsageAndExit();
}
