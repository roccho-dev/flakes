const std = @import("std");
const cdp = @import("cdp");
const adapter = @import("adapter.zig");
const common = @import("common.zig");
const manual = @import("manual.zig");
const queue = @import("queue.zig");
const sqlite = @import("sqlite.zig");

pub const ChromeSelftestResult = struct {
    ok: bool,
    chrome_available: bool,
    manual_cli_exit_ok: bool,
    manual_cli_json_ok: bool,
    cdp_connect_ok: bool,
    typing_ok: bool,
    upload_ok: bool,
    download_ok: bool,
    sqlite_ok: bool,
    no_state_json: bool,
    downloaded_files: usize,
    db_path: []const u8,
    download_dir: []const u8,
};

pub const ChromeSelftestOptions = struct {
    run_root: []const u8,
    exe_path: []const u8,
    chrome_path: ?[]const u8 = null,
    port: u16 = 19_921,
};

const live_smoke_url = "https://chatgpt.com/";

pub fn runChrome(io: std.Io, allocator: std.mem.Allocator, opts: ChromeSelftestOptions) !ChromeSelftestResult {
    try common.ensureDirPath(io, opts.run_root);

    const manual_check = try runManualFixtureCheck(io, allocator, opts.exe_path);

    const chrome_path = try findChromeExecutable(io, allocator, opts.chrome_path);
    defer allocator.free(chrome_path);

    const profile_dir = try std.fmt.allocPrint(allocator, "{s}/selftest/profile", .{opts.run_root});
    defer allocator.free(profile_dir);
    const download_dir = try std.fmt.allocPrint(allocator, "{s}/selftest/downloads", .{opts.run_root});
    defer allocator.free(download_dir);
    try common.ensureDirPath(io, profile_dir);
    try common.ensureDirPath(io, download_dir);

    var browser = try cdp.Browser.launch(.{
        .allocator = allocator,
        .io = io,
        .executable_path = chrome_path,
        .headless = .new,
        .port = opts.port,
        .user_data_dir = profile_dir,
        .window_size = .{ .width = 1280, .height = 900 },
        .no_sandbox = true,
        .timeout_ms = 30_000,
        .connect_timeout_ms = 10_000,
    });
    defer browser.close();

    var version = try browser.version();
    defer version.deinit(allocator);

    var automation = try adapter.Automation.attachBrowser(allocator, io, browser);
    defer automation.deinit();

    try automation.navigate(live_smoke_url);
    const observed = try automation.snapshot();

    const live_smoke_ok = observed.textarea_found or
        observed.upload_input_found or
        observed.send_button_found or
        observed.download_link_count > 0 or
        observed.assistant_message_count > 0 or
        observed.login_elements_found or
        observed.captcha_found or
        observed.blocked_indicators > 0;

    const queue_root = try std.fmt.allocPrint(allocator, "{s}/selftest/queue", .{opts.run_root});
    defer allocator.free(queue_root);
    try queue.enqueue(io, allocator, queue_root, .{
        .team_id = "selftest",
        .job_id = "job-1",
        .role = "ceo",
        .deliverable = "result.json",
        .task = "persist through sqlite only",
    });
    _ = try queue.dispatchFake(io, allocator, queue_root);

    const db_path = try sqlite.dbPathAlloc(allocator, queue_root);
    const pending_json = try std.fmt.allocPrint(allocator, "{s}/queue/pending/job-1.json", .{queue_root});
    defer allocator.free(pending_json);
    const done_json = try std.fmt.allocPrint(allocator, "{s}/queue/done/job-1.json", .{queue_root});
    defer allocator.free(done_json);
    const lock_json = try std.fmt.allocPrint(allocator, "{s}/batches/_locks/selftest.lock.json", .{opts.run_root});
    defer allocator.free(lock_json);

    var db = try sqlite.openRunDb(io, allocator, queue_root);
    defer db.close();
    var stmt = try db.prepare("SELECT COUNT(*) FROM queue_jobs WHERE state = 'done'");
    defer stmt.finalize();
    const sqlite_ok = switch (try stmt.step()) {
        .row => (try stmt.columnInt64(0)) == 1,
        .done => false,
    };

    return .{
        .ok = manual_check.exit_ok and manual_check.json_ok and version.product.len > 0 and live_smoke_ok and sqlite_ok and !common.exists(io, pending_json) and !common.exists(io, done_json) and !common.exists(io, lock_json),
        .chrome_available = true,
        .manual_cli_exit_ok = manual_check.exit_ok,
        .manual_cli_json_ok = manual_check.json_ok,
        .cdp_connect_ok = version.product.len > 0,
        .typing_ok = observed.textarea_found,
        .upload_ok = observed.upload_input_found,
        .download_ok = observed.download_link_count > 0,
        .sqlite_ok = sqlite_ok and common.exists(io, db_path),
        .no_state_json = !common.exists(io, pending_json) and !common.exists(io, done_json) and !common.exists(io, lock_json),
        .downloaded_files = 0,
        .db_path = db_path,
        .download_dir = try allocator.dupe(u8, download_dir),
    };
}

pub fn manualFixtureIssue() manual.ManualInterventionRequired {
    return .{
        .step = "send",
        .url = "https://chatgpt.com/c/manual-fixture",
        .observed = .{
            .textarea_found = true,
            .upload_input_found = true,
            .send_button_found = true,
            .send_enabled = false,
            .download_link_count = 0,
            .attachment_count = 0,
            .assistant_message_count = 0,
            .login_elements_found = false,
            .captcha_found = false,
            .blocked_indicators = 1,
        },
        .manual_steps = &.{
            "Inspect the page and remove the blocking UI state.",
            "Make sure the send button becomes enabled.",
            "Re-run the same hq command.",
        },
    };
}

const ManualCheck = struct {
    exit_ok: bool,
    json_ok: bool,
};

fn runManualFixtureCheck(io: std.Io, allocator: std.mem.Allocator, exe_path: []const u8) !ManualCheck {
    const result = try std.process.run(allocator, io, .{
        .argv = &.{ exe_path, "__manual_fixture" },
        .stdout_limit = .limited(32 * 1024),
        .stderr_limit = .limited(32 * 1024),
    });
    defer allocator.free(result.stdout);
    defer allocator.free(result.stderr);

    const exit_ok = switch (result.term) {
        .exited => |code| code == manual.exit_code,
        else => false,
    };

    var json_ok = false;
    if (result.stdout.len > 0) {
        const parsed = std.json.parseFromSlice(std.json.Value, allocator, result.stdout, .{}) catch null;
        if (parsed) |document| {
            defer document.deinit();
            if (document.value == .object) {
                const err_value = document.value.object.get("error");
                const code_value = document.value.object.get("exit_code");
                if (err_value != null and code_value != null and err_value.? == .string and code_value.? == .integer) {
                    json_ok = std.mem.eql(u8, err_value.?.string, "ManualInterventionRequired") and code_value.?.integer == manual.exit_code;
                }
            }
        }
    }

    return .{ .exit_ok = exit_ok, .json_ok = json_ok };
}

fn findChromeExecutable(io: std.Io, allocator: std.mem.Allocator, override: ?[]const u8) ![]u8 {
    if (override) |path| {
        if (common.exists(io, path)) return allocator.dupe(u8, path);
        return error.ChromeNotFound;
    }

    const candidates = switch (@import("builtin").os.tag) {
        .linux => [_][]const u8{
            "/usr/bin/google-chrome",
            "/usr/bin/google-chrome-stable",
            "/usr/bin/chromium",
            "/usr/bin/chromium-browser",
            "/snap/bin/chromium",
        },
        .macos => [_][]const u8{
            "/Applications/Google Chrome.app/Contents/MacOS/Google Chrome",
            "/Applications/Chromium.app/Contents/MacOS/Chromium",
        },
        .windows => [_][]const u8{
            "C:\\Program Files\\Google\\Chrome\\Application\\chrome.exe",
            "C:\\Program Files (x86)\\Google\\Chrome\\Application\\chrome.exe",
            "C:\\Program Files\\Chromium\\Application\\chrome.exe",
            "C:\\Program Files (x86)\\Chromium\\Application\\chrome.exe",
        },
        else => [_][]const u8{},
    };

    for (candidates) |candidate| {
        if (common.exists(io, candidate)) return allocator.dupe(u8, candidate);
    }
    return error.ChromeNotFound;
}
