const std = @import("std");
const cdp = @import("cdp");
const hq = @import("hq");

const fixtures = @import("fixture_harness");
const good_fixture_html = fixtures.good_fixture_html;
const blocked_fixture_html = fixtures.blocked_fixture_html;
const fixture_download_body = "{\"status\":\"ok\",\"artifact\":\"conversation.json\"}\n";

const LaunchedBrowser = struct {
    browser: *cdp.Browser,
    port: u16,
};

const HttpFixtureServer = struct {
    allocator: std.mem.Allocator,
    state: *State,
    thread: ?std.Thread,

    const Self = @This();

    const State = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        server: std.Io.net.Server,
        port: u16,
        failure: ?anyerror = null,
    };

    pub fn start(allocator: std.mem.Allocator, io: std.Io) !Self {
        var port: u16 = 18_321;
        var last_err: anyerror = error.BindFailed;
        while (port < 18_385) : (port += 1) {
            const address = std.Io.net.IpAddress.parse("127.0.0.1", port) catch return error.BindFailed;
            var server = std.Io.net.IpAddress.listen(address, io, .{
                .reuse_address = true,
            }) catch |err| {
                last_err = err;
                continue;
            };
            errdefer server.deinit(io);

            const state = try allocator.create(State);
            errdefer allocator.destroy(state);
            state.* = .{
                .allocator = allocator,
                .io = io,
                .server = server,
                .port = port,
                .failure = null,
            };

            const thread = try std.Thread.spawn(.{}, runServerThread, .{state});
            return .{
                .allocator = allocator,
                .state = state,
                .thread = thread,
            };
        }
        return last_err;
    }

    pub fn goodUrlAlloc(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://127.0.0.1:{}/fixtures/chat_page/good.html", .{self.state.port});
    }

    pub fn blockedUrlAlloc(self: *const Self, allocator: std.mem.Allocator) ![]u8 {
        return std.fmt.allocPrint(allocator, "http://127.0.0.1:{}/fixtures/chat_page/blocked.html", .{self.state.port});
    }

    pub fn stop(self: *Self) !void {
        defer self.allocator.destroy(self.state);
        if (self.thread) |thread| {
            _ = sendShutdown(self.state.io, self.state.port) catch {};
            thread.join();
            self.thread = null;
        }
        if (self.state.failure) |err| return err;
    }
};

test "urn:cdp:local-http-fixture:good exercises snapshot send collect when HQ_LIVE_CDP=1" {
    try requireLiveCdp();

    const chrome_path = try findChromeExecutable(std.testing.io, std.testing.allocator, null);
    defer std.testing.allocator.free(chrome_path);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/integration-live-cdp", .{tmp.sub_path});
    defer std.testing.allocator.free(run_root);
    const profile_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/profile", .{run_root});
    defer std.testing.allocator.free(profile_dir);
    const download_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/downloads", .{run_root});
    defer std.testing.allocator.free(download_dir);
    const upload_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/upload-fixture.txt", .{run_root});
    defer std.testing.allocator.free(upload_path);

    try hq.common.ensureDirPath(std.testing.io, run_root);
    try hq.common.ensureDirPath(std.testing.io, profile_dir);
    try hq.common.ensureDirPath(std.testing.io, download_dir);
    try hq.common.writeFile(std.testing.io, upload_path, "integration upload fixture\n");

    var server = try HttpFixtureServer.start(std.testing.allocator, std.testing.io);
    defer server.stop() catch |err| {
        std.log.err("integration fixture server shutdown failed: {s}", .{@errorName(err)});
    };

    const fixture_url = try server.goodUrlAlloc(std.testing.allocator);
    defer std.testing.allocator.free(fixture_url);

    var launched = try launchChrome(std.testing.io, std.testing.allocator, chrome_path, profile_dir);
    defer launched.browser.close();

    var version = try launched.browser.version();
    defer version.deinit(std.testing.allocator);
    try std.testing.expect(version.product.len > 0);
    try std.testing.expect(launched.port >= 19_941);

    var automation = try hq.adapter.Automation.attachBrowser(std.testing.allocator, std.testing.io, launched.browser);
    defer automation.deinit();

    try automation.navigate(fixture_url);
    const before = try automation.snapshot();
    try std.testing.expect(before.textarea_found);
    try std.testing.expect(!before.upload_input_found);
    try std.testing.expect(before.send_button_found);
    try std.testing.expect(!before.send_enabled);
    try std.testing.expectEqual(@as(usize, 0), before.download_link_count);

    const send_outcome = try automation.sendPromptOnCurrentPage(fixture_url, "ship via cdp", upload_path);
    const send_result = switch (send_outcome) {
        .ok => |result| result,
        .manual => |issue| {
            std.log.err("integration send escalated unexpectedly at step {s}", .{issue.step});
            return error.UnexpectedManualIntervention;
        },
    };
    try std.testing.expect(send_result.observed.textarea_found);
    try std.testing.expectEqual(@as(usize, 1), send_result.observed.attachment_count);
    try std.testing.expect(send_result.observed.assistant_message_count >= 1);
    try std.testing.expect(send_result.observed.download_link_count >= 1);

    const collect_outcome = try automation.collectDownloadsOnCurrentPage(fixture_url, download_dir);
    const collect_result = switch (collect_outcome) {
        .ok => |result| result,
        .manual => |issue| {
            std.log.err("integration collect escalated unexpectedly at step {s}", .{issue.step});
            return error.UnexpectedManualIntervention;
        },
    };
    try std.testing.expect(collect_result.downloaded_files >= 1);
    try std.testing.expect((try hq.common.countEntries(std.testing.io, download_dir)) >= 1);
}

test "urn:cdp:local-http-fixture:blocked exposes blocked indicators when HQ_LIVE_CDP=1" {
    try requireLiveCdp();

    const chrome_path = try findChromeExecutable(std.testing.io, std.testing.allocator, null);
    defer std.testing.allocator.free(chrome_path);

    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const run_root = try std.fmt.allocPrint(std.testing.allocator, ".zig-cache/tmp/{s}/integration-live-cdp-blocked", .{tmp.sub_path});
    defer std.testing.allocator.free(run_root);
    const profile_dir = try std.fmt.allocPrint(std.testing.allocator, "{s}/profile", .{run_root});
    defer std.testing.allocator.free(profile_dir);

    try hq.common.ensureDirPath(std.testing.io, run_root);
    try hq.common.ensureDirPath(std.testing.io, profile_dir);

    var server = try HttpFixtureServer.start(std.testing.allocator, std.testing.io);
    defer server.stop() catch |err| {
        std.log.err("blocked fixture server shutdown failed: {s}", .{@errorName(err)});
    };

    const fixture_url = try server.blockedUrlAlloc(std.testing.allocator);
    defer std.testing.allocator.free(fixture_url);

    var launched = try launchChrome(std.testing.io, std.testing.allocator, chrome_path, profile_dir);
    defer launched.browser.close();

    var automation = try hq.adapter.Automation.attachBrowser(std.testing.allocator, std.testing.io, launched.browser);
    defer automation.deinit();

    try automation.navigate(fixture_url);
    const observed = try automation.snapshot();
    try std.testing.expect(!observed.textarea_found);
    try std.testing.expect(!observed.upload_input_found);
    try std.testing.expect(observed.login_elements_found);
    try std.testing.expect(observed.blocked_indicators >= 1);
}

fn requireLiveCdp() !void {
    const raw = std.process.Environ.getAlloc(std.testing.environ, std.testing.allocator, "HQ_LIVE_CDP") catch return error.SkipZigTest;
    defer std.testing.allocator.free(raw);
    if (!std.mem.eql(u8, raw, "1")) return error.SkipZigTest;
}

fn launchChrome(io: std.Io, allocator: std.mem.Allocator, chrome_path: []const u8, profile_dir: []const u8) !LaunchedBrowser {
    var port: u16 = 19_941;
    var last_err: anyerror = error.ChromeLaunchFailed;

    while (port < 19_960) : (port += 1) {
        const attempt = cdp.Browser.launch(.{
            .allocator = allocator,
            .io = io,
            .executable_path = chrome_path,
            .headless = .new,
            .port = port,
            .user_data_dir = profile_dir,
            .window_size = .{ .width = 1280, .height = 900 },
            .no_sandbox = true,
            .timeout_ms = 30_000,
            .connect_timeout_ms = 10_000,
        }) catch |err| {
            last_err = err;
            continue;
        };

        return .{
            .browser = attempt,
            .port = port,
        };
    }

    return last_err;
}

fn runServerThread(state: *HttpFixtureServer.State) void {
    serve(state) catch |err| {
        state.failure = err;
    };
}

fn serve(state: *HttpFixtureServer.State) !void {
    defer state.server.deinit(state.io);

    while (true) {
        const stream = state.server.accept(state.io) catch |err| {
            if (state.failure == null) state.failure = err;
            return;
        };
        const should_stop = try handleConnection(state, stream);
        if (should_stop) return;
    }
}

fn handleConnection(state: *HttpFixtureServer.State, stream: std.Io.net.Stream) !bool {
    defer stream.close(state.io);

    var read_buf: [4096]u8 = undefined;
    var reader = stream.reader(state.io, &read_buf);
    var request_buf: [4096]u8 = undefined;
    var request_len: usize = 0;

    while (request_len < request_buf.len - 4) {
        const byte = reader.interface.takeByte() catch break;
        request_buf[request_len] = byte;
        request_len += 1;
        if (request_len >= 4 and
            request_buf[request_len - 4] == '\r' and
            request_buf[request_len - 3] == '\n' and
            request_buf[request_len - 2] == '\r' and
            request_buf[request_len - 1] == '\n')
        {
            break;
        }
    }

    const request = request_buf[0..request_len];
    const path = parsePath(request) orelse "/";

    if (std.mem.eql(u8, path, "/__shutdown__")) {
        try writeResponse(state, stream, "200 OK", "text/plain; charset=utf-8", "bye\n", "Cache-Control: no-store\r\n");
        return true;
    }
    if (std.mem.eql(u8, path, "/") or std.mem.eql(u8, path, "/fixtures/chat_page/good.html")) {
        try writeResponse(state, stream, "200 OK", "text/html; charset=utf-8", good_fixture_html, "Cache-Control: no-store\r\n");
        return false;
    }
    if (std.mem.eql(u8, path, "/fixtures/chat_page/blocked.html")) {
        try writeResponse(state, stream, "200 OK", "text/html; charset=utf-8", blocked_fixture_html, "Cache-Control: no-store\r\n");
        return false;
    }
    if (std.mem.eql(u8, path, "/fixture-download.json")) {
        try writeResponse(
            state,
            stream,
            "200 OK",
            "application/json",
            fixture_download_body,
            "Cache-Control: no-store\r\nContent-Disposition: attachment; filename=\"conversation.json\"\r\n",
        );
        return false;
    }
    if (std.mem.eql(u8, path, "/favicon.ico")) {
        try writeResponse(state, stream, "204 No Content", "image/x-icon", "", "Cache-Control: no-store\r\n");
        return false;
    }

    try writeResponse(state, stream, "404 Not Found", "text/plain; charset=utf-8", "not found\n", "Cache-Control: no-store\r\n");
    return false;
}

fn parsePath(request: []const u8) ?[]const u8 {
    const line_end = std.mem.indexOf(u8, request, "\r\n") orelse return null;
    const first_line = request[0..line_end];
    const first_space = std.mem.indexOfScalar(u8, first_line, ' ') orelse return null;
    const path_start = first_space + 1;
    const second_space = std.mem.indexOfScalarPos(u8, first_line, path_start, ' ') orelse return null;
    return first_line[path_start..second_space];
}

fn writeResponse(
    state: *HttpFixtureServer.State,
    stream: std.Io.net.Stream,
    status: []const u8,
    content_type: []const u8,
    body: []const u8,
    extra_headers: []const u8,
) !void {
    const response = try std.fmt.allocPrint(
        state.allocator,
        "HTTP/1.1 {s}\r\n" ++
            "Content-Length: {}\r\n" ++
            "Content-Type: {s}\r\n" ++
            "Connection: close\r\n" ++
            "{s}\r\n" ++
            "{s}",
        .{ status, body.len, content_type, extra_headers, body },
    );
    defer state.allocator.free(response);

    var write_buf: [4096]u8 = undefined;
    var writer = stream.writer(state.io, &write_buf);
    try writer.interface.writeAll(response);
    try writer.interface.flush();
}

fn sendShutdown(io: std.Io, port: u16) !void {
    const address = std.Io.net.IpAddress.parse("127.0.0.1", port) catch return error.ConnectionFailed;
    const stream = std.Io.net.IpAddress.connect(address, io, .{
        .mode = .stream,
        .protocol = .tcp,
    }) catch return error.ConnectionFailed;
    defer stream.close(io);

    var write_buf: [256]u8 = undefined;
    var writer = stream.writer(io, &write_buf);
    try writer.interface.writeAll(
        "GET /__shutdown__ HTTP/1.1\r\n" ++
            "Host: 127.0.0.1\r\n" ++
            "Connection: close\r\n" ++
            "\r\n",
    );
    try writer.interface.flush();
}

fn findChromeExecutable(io: std.Io, allocator: std.mem.Allocator, override: ?[]const u8) ![]const u8 {
    if (override) |path| {
        if (hq.common.exists(io, path)) return allocator.dupe(u8, path);
        return error.ChromeNotFound;
    }

    const env_path = std.process.Environ.getAlloc(std.testing.environ, allocator, "HQ_CHROME") catch |err| switch (err) {
        error.EnvironmentVariableMissing => null,
        else => return err,
    };
    if (env_path) |path| {
        defer allocator.free(path);
        if (hq.common.exists(io, path)) return allocator.dupe(u8, path);
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
        if (hq.common.exists(io, candidate)) return allocator.dupe(u8, candidate);
    }
    return error.ChromeNotFound;
}
