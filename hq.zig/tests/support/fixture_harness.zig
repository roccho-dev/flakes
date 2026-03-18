const std = @import("std");
const builtin = @import("builtin");
const hq = @import("hq");
const cdp = @import("cdp");

pub const good_fixture_html = @embedFile("fixtures/chat_page/good.html");
pub const blocked_fixture_html = @embedFile("fixtures/chat_page/blocked.html");
pub const worker_block_fixture_html = @embedFile("fixtures/chat_page/worker_block.html");
pub const worker_block_prose_example_fixture_html = @embedFile("fixtures/chat_page/worker_block_prose_example.html");
pub const worker_block_report_header_fixture_html = @embedFile("fixtures/chat_page/worker_block_report_header_in_fence.html");
pub const worker_block_late_model_confirmation_fixture_html = @embedFile("fixtures/chat_page/worker_block_late_model_confirmation.html");

fn tmpRoot(allocator: std.mem.Allocator, label: []const u8, tmp: *std.testing.TmpDir) ![]u8 {
    return std.fmt.allocPrint(allocator, ".zig-cache/tmp/{s}/{s}", .{ tmp.sub_path, label });
}

pub fn findChromeForTests() ?[]const u8 {
    const candidates = switch (builtin.os.tag) {
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
        if (hq.common.exists(std.testing.io, candidate)) return candidate;
    }
    return null;
}

pub fn snapshotFromHtml(port: u16, label: []const u8, html: []const u8) !hq.manual.Observed {
    const chrome_path = findChromeForTests() orelse return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const profile_dir = try tmpRoot(std.testing.allocator, label, &tmp);
    defer std.testing.allocator.free(profile_dir);
    try hq.common.ensureDirPath(std.testing.io, profile_dir);

    var browser = cdp.Browser.launch(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .executable_path = chrome_path,
        .headless = .new,
        .port = port,
        .user_data_dir = profile_dir,
        .window_size = .{ .width = 1280, .height = 900 },
        .no_sandbox = true,
        .timeout_ms = 30_000,
        .connect_timeout_ms = 10_000,
    }) catch return error.SkipZigTest;
    defer browser.close();

    var automation = try hq.adapter.Automation.attachBrowser(std.testing.allocator, std.testing.io, browser);
    defer automation.deinit();

    try automation.setHtml(html);
    return try automation.snapshot();
}

pub fn sendOnHtml(port: u16, label: []const u8, html: []const u8, prompt: []const u8) !hq.adapter.SendOutcome {
    const chrome_path = findChromeForTests() orelse return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const profile_dir = try tmpRoot(std.testing.allocator, label, &tmp);
    defer std.testing.allocator.free(profile_dir);
    try hq.common.ensureDirPath(std.testing.io, profile_dir);

    const upload_path = try tmpRoot(std.testing.allocator, "fixtures/upload.txt", &tmp);
    defer std.testing.allocator.free(upload_path);
    try hq.common.ensureDirPath(std.testing.io, std.fs.path.dirname(upload_path).?);
    try hq.common.writeFile(std.testing.io, upload_path, "fixture upload\n");

    var browser = cdp.Browser.launch(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .executable_path = chrome_path,
        .headless = .new,
        .port = port,
        .user_data_dir = profile_dir,
        .window_size = .{ .width = 1280, .height = 900 },
        .no_sandbox = true,
        .timeout_ms = 30_000,
        .connect_timeout_ms = 10_000,
    }) catch return error.SkipZigTest;
    defer browser.close();

    var automation = try hq.adapter.Automation.attachBrowser(std.testing.allocator, std.testing.io, browser);
    defer automation.deinit();

    try automation.setHtml(html);
    return try automation.sendPromptOnCurrentPage("about:blank", prompt, upload_path);
}

pub fn uiGetOnHtml(port: u16, label: []const u8, html: []const u8) !hq.adapter.UiGetOutcome {
    const chrome_path = findChromeForTests() orelse return error.SkipZigTest;

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const profile_dir = try tmpRoot(std.testing.allocator, label, &tmp);
    defer std.testing.allocator.free(profile_dir);
    try hq.common.ensureDirPath(std.testing.io, profile_dir);

    var browser = cdp.Browser.launch(.{
        .allocator = std.testing.allocator,
        .io = std.testing.io,
        .executable_path = chrome_path,
        .headless = .new,
        .port = port,
        .user_data_dir = profile_dir,
        .window_size = .{ .width = 1280, .height = 900 },
        .no_sandbox = true,
        .timeout_ms = 30_000,
        .connect_timeout_ms = 10_000,
    }) catch return error.SkipZigTest;
    defer browser.close();

    var automation = try hq.adapter.Automation.attachBrowser(std.testing.allocator, std.testing.io, browser);
    defer automation.deinit();

    try automation.setHtml(html);
    return try automation.uiGetWorkerBlockOnCurrentPage("about:blank");
}
