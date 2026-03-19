const std = @import("std");
const cdp = @import("cdp");
const common = @import("common.zig");
const manual = @import("manual.zig");
const sqlite = @import("sqlite.zig");

pub const StatusResult = struct {
    url: []const u8,
    ready_to_collect: bool,
    observed: manual.Observed,
};

pub const SendResult = struct {
    url: []const u8,
    observed: manual.Observed,
};

pub const CollectResult = struct {
    url: []const u8,
    download_dir: []const u8,
    downloaded_files: usize,
    observed: manual.Observed,
};

pub const UiGetPayload = struct {
    url: []u8,
    model_confirmation_line: []u8,
    model_pro: []u8,
    model_label: []u8,
    worker_block_raw: []u8,
    patch: []u8,
    test_report: []u8,
    checklist: []u8,
    errors: []u8,
};

pub const StatusOutcome = union(enum) {
    ok: StatusResult,
    manual: manual.ManualInterventionRequired,
};

pub const SendOutcome = union(enum) {
    ok: SendResult,
    manual: manual.ManualInterventionRequired,
};

pub const CollectOutcome = union(enum) {
    ok: CollectResult,
    manual: manual.ManualInterventionRequired,
};

pub const UiGetOutcome = union(enum) {
    ok: UiGetPayload,
    manual: manual.ManualInterventionRequired,
};

const missing_composer_steps = [_][]const u8{
    "Open the target conversation in a logged-in Chrome session with remote debugging enabled.",
    "Resolve any login, security, or captcha prompt visible on the page.",
    "Re-run the same hq command after the composer becomes visible.",
};

const blocked_page_steps = [_][]const u8{
    "Make sure the chat page is open and fully loaded in the remote-debugging Chrome session.",
    "Resolve any login, verification, or captcha prompt.",
    "Re-run the same hq command after the page is interactive.",
};

const missing_upload_steps = [_][]const u8{
    "Open the conversation UI where file upload is available.",
    "Confirm the attachment input/button is visible and enabled.",
    "Re-run the same hq send command.",
};

const send_disabled_steps = [_][]const u8{
    "Inspect the chat page and make sure the composer contains the prompt.",
    "Wait until the send button becomes enabled, or clear any blocking banner/modals.",
    "Re-run the same hq send command.",
};

const missing_download_steps = [_][]const u8{
    "Wait for the assistant to finish and make attachments visible in the conversation.",
    "Ensure the artifact download link/button is present and clickable.",
    "Re-run the same hq collect command.",
};

const missing_worker_block_steps = [_][]const u8{
    "Scroll to the bottom so the newest assistant message is visible.",
    "Ensure the newest assistant message contains BEGIN_WORKER_BLOCK and END_WORKER_BLOCK.",
    "Ensure the reply includes MODEL_CONFIRMATION: Pro=YES | MODEL=<exact UI label>.",
    "Re-run the same hq ui get command.",
};

pub const Automation = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    browser: *cdp.Browser,
    own_browser: bool,
    session: *cdp.Session,
    page: cdp.Page,
    runtime: cdp.Runtime,
    dom: cdp.DOM,
    input: cdp.Input,

    const Self = @This();

    pub fn connect(allocator: std.mem.Allocator, io: std.Io, ws_url: []const u8) !Self {
        const browser = try cdp.Browser.connect(ws_url, allocator, io, .{ .receive_timeout_ms = 120_000 });
        return init(allocator, io, browser, true, null);
    }

    pub fn connectForUrl(allocator: std.mem.Allocator, io: std.Io, ws_url: []const u8, url_hint: []const u8) !Self {
        const browser = try cdp.Browser.connect(ws_url, allocator, io, .{ .receive_timeout_ms = 120_000 });
        return init(allocator, io, browser, true, url_hint);
    }

    pub fn attachBrowser(allocator: std.mem.Allocator, io: std.Io, browser: *cdp.Browser) !Self {
        return init(allocator, io, browser, false, null);
    }

    fn init(allocator: std.mem.Allocator, io: std.Io, browser: *cdp.Browser, own_browser: bool, url_hint: ?[]const u8) !Self {
        const session = if (url_hint) |hint|
            try attachToExistingOrNew(browser, allocator, hint)
        else
            try browser.newPage();
        errdefer session.deinit();

        var page = cdp.Page.init(session);
        var runtime = cdp.Runtime.init(session);
        var dom = cdp.DOM.init(session);
        const input = cdp.Input.init(session);

        try page.enable();
        try runtime.enable();
        try dom.enable();

        return .{
            .allocator = allocator,
            .io = io,
            .browser = browser,
            .own_browser = own_browser,
            .session = session,
            .page = page,
            .runtime = runtime,
            .dom = dom,
            .input = input,
        };
    }

    fn attachToExistingOrNew(browser: *cdp.Browser, allocator: std.mem.Allocator, url_hint: []const u8) !*cdp.Session {
        const targets = browser.pages() catch return browser.newPage();
        defer {
            for (targets) |*item| item.deinit(allocator);
            allocator.free(targets);
        }

        var best: ?[]const u8 = null;
        for (targets) |item| {
            if (!std.mem.eql(u8, item.url, url_hint)) continue;
            if (item.attached) continue;
            best = item.target_id;
        }
        if (best == null) {
            for (targets) |item| {
                if (!std.mem.eql(u8, item.url, url_hint)) continue;
                best = item.target_id;
            }
        }

        if (best) |target_id| {
            return try browser.connection.createSession(target_id);
        }
        return browser.newPage();
    }

    pub fn deinit(self: *Self) void {
        self.session.detach() catch {};
        self.session.deinit();
        if (self.own_browser) self.browser.disconnect();
    }

    pub fn navigate(self: *Self, url: []const u8) !void {
        var result = try self.page.navigate(self.allocator, url);
        defer result.deinit(self.allocator);

        var event = self.session.waitForEvent("Page.loadEventFired", 10_000) catch |err| switch (err) {
            error.Timeout => return,
            else => return err,
        };
        defer self.session.deinitCommandResult(&event);
    }

    pub fn ensureAtUrl(self: *Self, url: []const u8) !void {
        const href = self.evaluateJson(location_href_js, false) catch {
            try self.navigate(url);
            return;
        };
        defer self.allocator.free(href);

        if (std.mem.eql(u8, href, url) or std.mem.startsWith(u8, href, url)) return;
        try self.navigate(url);
    }

    pub fn setHtml(self: *Self, html: []const u8) !void {
        try self.page.setDocumentContent(html);
    }

    pub fn snapshot(self: *Self) !manual.Observed {
        const raw = try self.evaluateJson(snapshot_js, false);
        defer self.allocator.free(raw);
        return parseObserved(self.allocator, raw);
    }

    pub fn uiReadOnCurrentPage(self: *Self) ![]u8 {
        return try self.evaluateJson(ui_read_json_js, false);
    }

    pub fn sendPromptOnCurrentPage(self: *Self, url_hint: []const u8, prompt: []const u8, upload_path: ?[]const u8) !SendOutcome {
        const before = try self.snapshot();
        if (!before.textarea_found) {
            return .{ .manual = .{
                .step = "send",
                .url = url_hint,
                .observed = before,
                .manual_steps = &missing_composer_steps,
            } };
        }
        try self.clearComposer();
        try self.focusComposer();
        try self.input.insertText(prompt);
        if (upload_path) |path| {
            self.setUpload(path) catch |err| {
                if (err == error.MissingUpload) {
                    return .{ .manual = .{
                        .step = "send",
                        .url = url_hint,
                        .observed = try self.snapshot(),
                        .manual_steps = &missing_upload_steps,
                    } };
                }
                return err;
            };
        }

        var after_input = try self.snapshot();
        if (!after_input.send_button_found or !after_input.send_enabled) {
            const ready = self.waitForSendEnabled(15_000) catch false;
            if (ready) {
                after_input = try self.snapshot();
            }
        }
        if (!after_input.send_button_found or !after_input.send_enabled) {
            return .{ .manual = .{
                .step = "send",
                .url = url_hint,
                .observed = after_input,
                .manual_steps = &send_disabled_steps,
            } };
        }

        const clicked = try self.markAndClickSend();
        if (!clicked) {
            return .{ .manual = .{
                .step = "send",
                .url = url_hint,
                .observed = after_input,
                .manual_steps = &send_disabled_steps,
            } };
        }

        const committed = self.waitForComposerCleared(10_000) catch false;
        if (!committed) {
            return .{ .manual = .{
                .step = "send",
                .url = url_hint,
                .observed = try self.snapshot(),
                .manual_steps = &send_disabled_steps,
            } };
        }

        return .{ .ok = .{
            .url = url_hint,
            .observed = try self.snapshot(),
        } };
    }

    fn waitForSendEnabled(self: *Self, timeout_ms: u32) !bool {
        const expression = try std.fmt.allocPrint(self.allocator, wait_send_enabled_js_fmt, .{timeout_ms});
        defer self.allocator.free(expression);
        return self.evaluateBool(expression, false);
    }

    fn waitForComposerCleared(self: *Self, timeout_ms: u32) !bool {
        const expression = try std.fmt.allocPrint(self.allocator, wait_composer_cleared_js_fmt, .{timeout_ms});
        defer self.allocator.free(expression);
        return self.evaluateBool(expression, false);
    }

    pub fn collectDownloadsOnCurrentPage(self: *Self, url_hint: []const u8, download_dir: []const u8) !CollectOutcome {
        try common.ensureDirPath(self.io, download_dir);

        const observed = try self.snapshot();
        if (observed.download_link_count == 0) {
            return .{ .manual = .{
                .step = "collect",
                .url = url_hint,
                .observed = observed,
                .manual_steps = &missing_download_steps,
            } };
        }

        try self.browser.connection.sendCommandVoid("Browser.setDownloadBehavior", .{
            .behavior = "allow",
            .downloadPath = download_dir,
            .eventsEnabled = true,
        }, null);

        var index: usize = 0;
        while (index < observed.download_link_count) : (index += 1) {
            const marked = try self.markDownloadCandidate(index);
            if (!marked) {
                return .{ .manual = .{
                    .step = "collect",
                    .url = url_hint,
                    .observed = try self.snapshot(),
                    .manual_steps = &missing_download_steps,
                } };
            }

            const clicked = try self.clickMarkedNode("[data-hq-download-target='1']");
            if (!clicked) {
                return .{ .manual = .{
                    .step = "collect",
                    .url = url_hint,
                    .observed = try self.snapshot(),
                    .manual_steps = &missing_download_steps,
                } };
            }

            waitForDownloadComplete(self.io, self.browser.connection, 60_000) catch {
                return .{ .manual = .{
                    .step = "collect",
                    .url = url_hint,
                    .observed = try self.snapshot(),
                    .manual_steps = &missing_download_steps,
                } };
            };
        }

        return .{ .ok = .{
            .url = url_hint,
            .download_dir = download_dir,
            .downloaded_files = if (common.exists(self.io, download_dir)) try common.countEntries(self.io, download_dir) else 0,
            .observed = try self.snapshot(),
        } };
    }

    fn focusComposer(self: *Self) !void {
        const ok = self.evaluateBool(focus_composer_js, true) catch false;
        if (ok) return;

        const node_id = try self.queryNode("#prompt-textarea, textarea[aria-label*='message' i], textarea[aria-label*='prompt' i], textarea, [role='textbox'][contenteditable='true'], [contenteditable='true'][aria-label*='message' i], [contenteditable='true'][aria-label*='prompt' i], [contenteditable='true']");
        if (node_id == 0) return error.MissingComposer;
        self.dom.focus(node_id) catch return error.MissingComposer;
    }

    fn clearComposer(self: *Self) !void {
        const ok = try self.evaluateBool(clear_composer_js, false);
        if (!ok) return error.MissingComposer;
    }

    fn setUpload(self: *Self, path: []const u8) !void {
        var node_ids = try self.queryNodes("input[type='file']");
        if (node_ids.len == 0) {
            self.allocator.free(node_ids);
            _ = self.evaluateBool(open_upload_picker_js, true) catch false;
            if (!try self.waitForUploadInput(3_000)) return error.MissingUpload;
            node_ids = try self.queryNodes("input[type='file']");
        }
        defer self.allocator.free(node_ids);

        if (node_ids.len == 0) return error.MissingUpload;

        const files = [_][]const u8{path};
        var index = node_ids.len;
        while (index > 0) {
            index -= 1;
            self.dom.setFileInputFiles(node_ids[index], &files) catch continue;
            return;
        }

        return error.MissingUpload;
    }

    fn queryNode(self: *Self, selector: []const u8) !i64 {
        var root = try self.dom.getDocument(self.allocator, 1);
        defer root.deinit(self.allocator);
        return self.dom.querySelector(root.node_id, selector);
    }

    fn queryNodes(self: *Self, selector: []const u8) ![]i64 {
        var root = try self.dom.getDocument(self.allocator, 1);
        defer root.deinit(self.allocator);
        return self.dom.querySelectorAll(self.allocator, root.node_id, selector);
    }

    fn clickMarkedNode(self: *Self, selector: []const u8) !bool {
        const node_id = try self.queryNode(selector);
        if (node_id == 0) return false;
        const model = try self.dom.getBoxModel(self.allocator, node_id);
        const center_x = (model.content[0] + model.content[2] + model.content[4] + model.content[6]) / 4.0;
        const center_y = (model.content[1] + model.content[3] + model.content[5] + model.content[7]) / 4.0;
        try self.input.click(center_x, center_y, .{});
        return true;
    }

    fn markAndClickSend(self: *Self) !bool {
        return self.evaluateBool(click_send_js, true) catch false;
    }

    fn waitForUploadInput(self: *Self, timeout_ms: u32) !bool {
        const expression = try std.fmt.allocPrint(self.allocator, wait_upload_input_js_fmt, .{timeout_ms});
        defer self.allocator.free(expression);
        return self.evaluateBool(expression, false);
    }

    pub fn uiGetWorkerBlockOnCurrentPage(self: *Self, url_hint: []const u8) !UiGetOutcome {
        var extracted = self.runtime.evaluate(self.allocator, ui_extract_object_js, .{
            .object_group = "hq-ui",
            .return_by_value = false,
            .await_promise = true,
        }) catch {
            return .{ .manual = .{
                .step = "ui.get",
                .url = url_hint,
                .observed = try self.snapshot(),
                .manual_steps = &blocked_page_steps,
            } };
        };
        defer extracted.deinit(self.allocator);
        defer self.runtime.releaseObjectGroup("hq-ui") catch {};

        const object_id = extracted.object_id orelse return .{ .manual = .{
            .step = "ui.get",
            .url = url_hint,
            .observed = try self.snapshot(),
            .manual_steps = &missing_worker_block_steps,
        } };

        var meta = try self.runtime.callFunctionOn(self.allocator, ui_meta_fn, object_id, null, .{ .return_by_value = true });
        defer meta.deinit(self.allocator);
        const meta_val = meta.value orelse return error.MissingField;
        if (meta_val != .object) return error.TypeMismatch;

        const ok = try objectBool(meta_val, "ok");
        const url = try objectStringAlloc(self.allocator, meta_val, "url");
        errdefer self.allocator.free(url);
        const model_confirmation_line = try objectStringAlloc(self.allocator, meta_val, "model_confirmation_line");
        errdefer self.allocator.free(model_confirmation_line);
        const model_pro = try objectStringAlloc(self.allocator, meta_val, "model_pro");
        errdefer self.allocator.free(model_pro);
        const model_label = try objectStringAlloc(self.allocator, meta_val, "model_label");
        errdefer self.allocator.free(model_label);
        const errors = try objectStringAlloc(self.allocator, meta_val, "errors");
        errdefer self.allocator.free(errors);

        if (!ok) {
            self.allocator.free(url);
            self.allocator.free(model_confirmation_line);
            self.allocator.free(model_pro);
            self.allocator.free(model_label);
            self.allocator.free(errors);
            return .{ .manual = .{
                .step = "ui.get",
                .url = url_hint,
                .observed = try self.snapshot(),
                .manual_steps = &missing_worker_block_steps,
            } };
        }

        const worker_block_raw = try self.readStringKeyChunked(object_id, "worker_block_raw");
        errdefer self.allocator.free(worker_block_raw);
        const patch = try self.readStringKeyChunked(object_id, "patch");
        errdefer self.allocator.free(patch);
        const test_report = try self.readStringKeyChunked(object_id, "test_report");
        errdefer self.allocator.free(test_report);
        const checklist = try self.readStringKeyChunked(object_id, "checklist");
        errdefer self.allocator.free(checklist);

        return .{ .ok = .{
            .url = url,
            .model_confirmation_line = model_confirmation_line,
            .model_pro = model_pro,
            .model_label = model_label,
            .worker_block_raw = worker_block_raw,
            .patch = patch,
            .test_report = test_report,
            .checklist = checklist,
            .errors = errors,
        } };
    }

    fn readStringKeyChunked(self: *Self, object_id: []const u8, key: []const u8) ![]u8 {
        const len = try self.stringKeyLen(object_id, key);
        if (len == 0) return self.allocator.alloc(u8, 0);

        var out = try self.allocator.alloc(u8, len);
        errdefer self.allocator.free(out);

        const chunk_size: usize = 32 * 1024;
        var offset: usize = 0;
        while (offset < len) {
            const want: usize = @min(chunk_size, len - offset);
            const chunk = try self.stringKeySlice(object_id, key, offset, want);
            defer self.allocator.free(chunk);
            const take = @min(want, chunk.len);
            @memcpy(out[offset .. offset + take], chunk[0..take]);
            offset += take;
            if (take == 0) break;
        }
        return out[0..offset];
    }

    fn stringKeyLen(self: *Self, object_id: []const u8, key: []const u8) !usize {
        var args = [_]cdp.CallArgument{.{ .value = .{ .string = key } }};
        var res = try self.runtime.callFunctionOn(self.allocator, ui_len_fn, object_id, &args, .{ .return_by_value = true });
        defer res.deinit(self.allocator);
        const v = res.value orelse return error.MissingField;
        return switch (v) {
            .integer => |i| @intCast(i),
            .float => |f| @intFromFloat(f),
            else => error.TypeMismatch,
        };
    }

    fn stringKeySlice(self: *Self, object_id: []const u8, key: []const u8, offset: usize, len: usize) ![]u8 {
        var args = [_]cdp.CallArgument{
            .{ .value = .{ .string = key } },
            .{ .value = .{ .integer = @intCast(offset) } },
            .{ .value = .{ .integer = @intCast(len) } },
        };
        var res = try self.runtime.callFunctionOn(self.allocator, ui_slice_fn, object_id, &args, .{ .return_by_value = true });
        defer res.deinit(self.allocator);
        const raw = res.value orelse return error.MissingField;
        if (raw != .string) return error.TypeMismatch;
        return self.allocator.dupe(u8, raw.string);
    }

    fn markDownloadCandidate(self: *Self, index: usize) !bool {
        const expression = try std.fmt.allocPrint(self.allocator, mark_download_js_fmt, .{index});
        defer self.allocator.free(expression);
        return self.evaluateBool(expression, false);
    }

    fn evaluateJson(self: *Self, expression: []const u8, user_gesture: bool) ![]u8 {
        var result = try self.runtime.evaluate(self.allocator, expression, .{
            .return_by_value = true,
            .await_promise = true,
            .user_gesture = user_gesture,
        });
        defer result.deinit(self.allocator);
        const raw = result.asString() orelse return error.TypeMismatch;
        return self.allocator.dupe(u8, raw);
    }

    fn evaluateBool(self: *Self, expression: []const u8, user_gesture: bool) !bool {
        var result = try self.runtime.evaluate(self.allocator, expression, .{
            .return_by_value = true,
            .await_promise = true,
            .user_gesture = user_gesture,
        });
        defer result.deinit(self.allocator);

        if (result.value) |value| {
            return switch (value) {
                .bool => |b| b,
                .integer => |i| i != 0,
                else => error.TypeMismatch,
            };
        }
        return error.MissingField;
    }
};

pub fn status(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, ws_url: []const u8, url: []const u8) !StatusOutcome {
    var automation = try Automation.connectForUrl(allocator, io, ws_url, url);
    defer automation.deinit();

    try automation.ensureAtUrl(url);
    const observed = try automation.snapshot();
    const ready = observed.download_link_count > 0;

    if (!ready and !observed.textarea_found and (observed.login_elements_found or observed.captcha_found or observed.blocked_indicators > 0)) {
        const issue = manual.ManualInterventionRequired{
            .step = "status",
            .url = url,
            .observed = observed,
            .manual_steps = &blocked_page_steps,
        };
        try recordManual(io, allocator, run_root, ws_url, issue, null, null);
        return .{ .manual = issue };
    }

    try recordSession(io, allocator, run_root, ws_url, url, observed, null, null, null, 0, 0);
    return .{ .ok = .{
        .url = url,
        .ready_to_collect = ready,
        .observed = observed,
    } };
}

pub fn send(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, ws_url: []const u8, url: []const u8, prompt: []const u8, upload_path: ?[]const u8) !SendOutcome {
    var automation = try Automation.connectForUrl(allocator, io, ws_url, url);
    defer automation.deinit();

    try automation.ensureAtUrl(url);
    const outcome = try automation.sendPromptOnCurrentPage(url, prompt, upload_path);
    switch (outcome) {
        .ok => |result| try recordSession(io, allocator, run_root, ws_url, url, result.observed, prompt, null, null, 1, 0),
        .manual => |issue| try recordManual(io, allocator, run_root, ws_url, issue, prompt, null),
    }
    return outcome;
}

pub fn collect(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, ws_url: []const u8, url: []const u8, download_dir: []const u8) !CollectOutcome {
    var automation = try Automation.connectForUrl(allocator, io, ws_url, url);
    defer automation.deinit();

    try automation.ensureAtUrl(url);
    const outcome = try automation.collectDownloadsOnCurrentPage(url, download_dir);
    switch (outcome) {
        .ok => |result| try recordSession(io, allocator, run_root, ws_url, url, result.observed, null, download_dir, null, 0, 1),
        .manual => |issue| try recordManual(io, allocator, run_root, ws_url, issue, null, download_dir),
    }
    return outcome;
}

fn recordManual(io: std.Io, allocator: std.mem.Allocator, run_root: []const u8, ws_url: []const u8, issue: manual.ManualInterventionRequired, prompt: ?[]const u8, download_dir: ?[]const u8) !void {
    const raw = try issue.stringifyAlloc(allocator);
    defer allocator.free(raw);
    try recordSession(io, allocator, run_root, ws_url, issue.url, issue.observed, prompt, download_dir, raw, 0, 0);
}

fn recordSession(
    io: std.Io,
    allocator: std.mem.Allocator,
    run_root: []const u8,
    ws_url: []const u8,
    url: []const u8,
    observed: manual.Observed,
    prompt: ?[]const u8,
    download_dir: ?[]const u8,
    error_json: ?[]const u8,
    send_increment: i64,
    collect_increment: i64,
) !void {
    var db = try sqlite.openRunDb(io, allocator, run_root);
    defer db.close();

    var insert_stmt = try db.prepare("INSERT OR IGNORE INTO sessions (url, ws_url, updated_at) VALUES (?, ?, ?)");
    defer insert_stmt.finalize();
    try insert_stmt.bindText(1, url);
    try insert_stmt.bindText(2, ws_url);
    try insert_stmt.bindInt64(3, common.nowUnixSeconds());
    _ = try insert_stmt.step();

    var update_stmt = try db.prepare("UPDATE sessions SET " ++
        "ws_url = ?, " ++
        "ready_to_collect = ?, " ++
        "last_download_count = ?, " ++
        "last_textarea_found = ?, " ++
        "last_upload_input_found = ?, " ++
        "last_send_button_found = ?, " ++
        "last_send_enabled = ?, " ++
        "last_attachment_count = ?, " ++
        "last_assistant_message_count = ?, " ++
        "last_login_elements_found = ?, " ++
        "last_captcha_found = ?, " ++
        "last_blocked_indicators = ?, " ++
        "last_prompt = ?, " ++
        "last_download_dir = ?, " ++
        "last_error_json = ?, " ++
        "send_count = send_count + ?, " ++
        "collect_count = collect_count + ?, " ++
        "updated_at = ? " ++
        "WHERE url = ?");
    defer update_stmt.finalize();

    try update_stmt.bindText(1, ws_url);
    try update_stmt.bindBool(2, observed.download_link_count > 0);
    try update_stmt.bindInt64(3, @intCast(observed.download_link_count));
    try update_stmt.bindBool(4, observed.textarea_found);
    try update_stmt.bindBool(5, observed.upload_input_found);
    try update_stmt.bindBool(6, observed.send_button_found);
    try update_stmt.bindBool(7, observed.send_enabled);
    try update_stmt.bindInt64(8, @intCast(observed.attachment_count));
    try update_stmt.bindInt64(9, @intCast(observed.assistant_message_count));
    try update_stmt.bindBool(10, observed.login_elements_found);
    try update_stmt.bindBool(11, observed.captcha_found);
    try update_stmt.bindInt64(12, @intCast(observed.blocked_indicators));
    try bindOptionalText(&update_stmt, 13, prompt);
    try bindOptionalText(&update_stmt, 14, download_dir);
    try bindOptionalText(&update_stmt, 15, error_json);
    try update_stmt.bindInt64(16, send_increment);
    try update_stmt.bindInt64(17, collect_increment);
    try update_stmt.bindInt64(18, common.nowUnixSeconds());
    try update_stmt.bindText(19, url);
    _ = try update_stmt.step();
}

fn bindOptionalText(stmt: *sqlite.Stmt, index: c_int, value: ?[]const u8) !void {
    if (value) |text| {
        try stmt.bindText(index, text);
    } else {
        try stmt.bindNull(index);
    }
}

fn waitForDownloadComplete(io: std.Io, connection: *cdp.Connection, timeout_ms: u32) !void {
    const start = std.Io.Clock.awake.now(io);
    while (true) {
        const now = std.Io.Clock.awake.now(io);
        const elapsed_ms: i64 = start.durationTo(now).toMilliseconds();
        if (elapsed_ms >= @as(i64, @intCast(timeout_ms))) return error.Timeout;
        const remaining: u32 = @intCast(@as(i64, @intCast(timeout_ms)) - elapsed_ms);

        var event = try connection.waitForEvent("Browser.downloadProgress", null, remaining);
        defer connection.deinitCommandResult(&event);
        if (event != .object) continue;
        const state_val = event.object.get("state") orelse continue;
        if (state_val != .string) continue;
        if (std.mem.eql(u8, state_val.string, "completed")) return;
        if (std.mem.eql(u8, state_val.string, "canceled")) return error.DownloadCanceled;
    }
}

fn parseObserved(allocator: std.mem.Allocator, raw: []const u8) !manual.Observed {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw, .{});
    defer parsed.deinit();
    const value = parsed.value;
    if (value != .object) return error.InvalidSnapshot;

    return .{
        .textarea_found = try objectBool(value, "textarea_found"),
        .upload_input_found = try objectBool(value, "upload_input_found"),
        .send_button_found = try objectBool(value, "send_button_found"),
        .send_enabled = try objectBool(value, "send_enabled"),
        .download_link_count = @intCast(try objectInt(value, "download_link_count")),
        .attachment_count = @intCast(try objectInt(value, "attachment_count")),
        .assistant_message_count = @intCast(try objectInt(value, "assistant_message_count")),
        .login_elements_found = try objectBool(value, "login_elements_found"),
        .captcha_found = try objectBool(value, "captcha_found"),
        .blocked_indicators = @intCast(try objectInt(value, "blocked_indicators")),
    };
}

fn objectBool(value: std.json.Value, key: []const u8) !bool {
    const field = value.object.get(key) orelse return error.MissingField;
    return switch (field) {
        .bool => |b| b,
        .integer => |i| i != 0,
        else => error.TypeMismatch,
    };
}

fn objectInt(value: std.json.Value, key: []const u8) !i64 {
    const field = value.object.get(key) orelse return error.MissingField;
    return switch (field) {
        .integer => |i| i,
        .float => |f| @intFromFloat(f),
        else => error.TypeMismatch,
    };
}

fn objectStringAlloc(allocator: std.mem.Allocator, value: std.json.Value, key: []const u8) ![]u8 {
    const field = value.object.get(key) orelse return error.MissingField;
    if (field != .string) return error.TypeMismatch;
    return allocator.dupe(u8, field.string);
}

const clear_composer_js =
    \\(() => {
    \\  const el = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  if (!el) return false;
    \\  if ('value' in el) {
    \\    const proto = Object.getPrototypeOf(el);
    \\    const desc = proto ? Object.getOwnPropertyDescriptor(proto, 'value') : null;
    \\    const set = desc && desc.set ? desc.set.bind(el) : null;
    \\    if (set) set(''); else el.value = '';
    \\  } else {
    \\    el.textContent = '';
    \\  }
    \\  el.dispatchEvent(new Event('input', { bubbles: true }));
    \\  return true;
    \\})()
;

const send_enabled_js =
    \\(() => {
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const composer = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  const root = composer ? (composer.closest('form') || composer.closest('main') || composer.parentElement) : document;
    \\  const pick = () => {
    \\    const candidates = [
    \\      root && root.querySelector ? root.querySelector('button[data-testid="send-button"]') : null,
    \\      root && root.querySelector ? root.querySelector('#composer-submit-button') : null,
    \\      root && root.querySelector ? root.querySelector('button[type="submit"]') : null,
    \\    ];
    \\    let btn = candidates.find((el) => isVisible(el));
    \\    if (btn) return btn;
    \\    const buttons = Array.from(document.querySelectorAll('button'));
    \\    btn = buttons.find((b) => {
    \\      if (!isVisible(b)) return false;
    \\      const label = (b.getAttribute('aria-label') || '').toLowerCase();
    \\      const testid = (b.getAttribute('data-testid') || '').toLowerCase();
    \\      return testid === 'send-button' || testid.includes('send') || label.includes('send');
    \\    }});
    \\    return btn || null;
    \\  }};
    \\  const send = pick();
    \\  return !!send && !send.disabled && send.getAttribute('aria-disabled') !== 'true';
    \\})()
;

const composer_empty_js =
    \\(() => {
    \\  const el = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  if (!el) return false;
    \\  const text = ('value' in el) ? (el.value || '') : (el.innerText || el.textContent || '');
    \\  return (text.trim().length === 0);
    \\})()
;

const focus_composer_js =
    \\(() => {
    \\  const el = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  if (!el) return false;
    \\  try { el.click(); } catch (_) {}
    \\  el.focus();
    \\  return true;
    \\})()
;

const location_href_js =
    \\(() => location && location.href ? location.href : '')()
;

const snapshot_js =
    \\JSON.stringify((() => {
    \\  const q = (sel) => document.querySelector(sel);
    \\  const all = (sel) => Array.from(document.querySelectorAll(sel));
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const fileExt = /\.(zip|diff|patch|txt|md|html|json|yaml|yml|tsv)\b/;
    \\  const composer = q('#prompt-textarea') || q('textarea') || q('[contenteditable="true"]');
    \\  const root = composer ? (composer.closest('form') || composer.closest('main') || composer.parentElement) : document;
    \\  const pickSend = () => {
    \\    const candidates = [
    \\      root && root.querySelector ? root.querySelector('button[data-testid="send-button"]') : null,
    \\      root && root.querySelector ? root.querySelector('#composer-submit-button') : null,
    \\      root && root.querySelector ? root.querySelector('button[type="submit"]') : null,
    \\    ];
    \\    let btn = candidates.find((el) => isVisible(el));
    \\    if (btn) return btn;
    \\    const buttons = all('button');
    \\    btn = buttons.find((b) => {
    \\      if (!isVisible(b)) return false;
    \\      const label = (b.getAttribute('aria-label') || '').toLowerCase();
    \\      const testid = (b.getAttribute('data-testid') || '').toLowerCase();
    \\      return testid === 'send-button' || testid.includes('send') || label.includes('send');
    \\    });
    \\    return btn || null;
    \\  };
    \\  const send = pickSend();
    \\  const downloads = all('a[download], a[href^="blob:"], a[href^="data:"], button, div[role="button"]').filter((el) => {
    \\    const text = (el.innerText || '').trim().toLowerCase();
    \\    const label = (el.getAttribute('aria-label') || '').toLowerCase();
    \\    const title = (el.getAttribute('title') || '').toLowerCase();
    \\    const testid = (el.getAttribute('data-testid') || '').toLowerCase();
    \\    const meta = (text + ' ' + label + ' ' + title + ' ' + testid);
    \\    const isAnchor = (el.tagName || '').toLowerCase() === 'a';
    \\    const isDirect = el.matches('a[download], a[href^="blob:"], a[href^="data:"]');
    \\    const hasDownloadHint = meta.includes('download');
    \\    if (!isAnchor && !hasDownloadHint && !isDirect) return false;
    \\    const href = isAnchor ? ((el.getAttribute('href') || '') + '').toLowerCase() : '';
    \\    const isFile = fileExt.test(text) || fileExt.test(label) || fileExt.test(testid) || (isAnchor && fileExt.test(href));
    \\    const isDownload = isDirect || hasDownloadHint || (isAnchor && isFile);
    \\    return isVisible(el) && isDownload;
    \\  });
    \\  const assistantMessages = all('[data-message-author-role="assistant"], [data-testid*="assistant"], [data-role="assistant"]');
    \\  const login = !!q('input[type="password"], form[action*="login"], [href*="login"], button[data-testid*="login"]');
    \\  const captcha = !!q('iframe[src*="captcha"], [class*="captcha" i], [id*="captcha" i]');
    \\  const blockedText = /(verify you are human|log in|sign in|captcha|access denied)/i.test(document.body ? document.body.innerText : '');
    \\  const verifyHuman = Array.from(document.querySelectorAll('button, a, [role="button"]')).some((el) => {
    \\    const meta = ((el.innerText || '') + ' ' + (el.getAttribute('aria-label') || '') + ' ' + (el.getAttribute('title') || '')).trim();
    \\    return /(verify you are human|human verification|i am human)/i.test(meta);
    \\  });
    \\  const upload = q('input[type="file"]');
    \\  return {
    \\    textarea_found: !!(q('#prompt-textarea') || q('textarea') || q('[contenteditable="true"]')),
    \\    upload_input_found: !!upload,
    \\    send_button_found: !!send,
    \\    send_enabled: !!send && !send.disabled && send.getAttribute('aria-disabled') !== 'true',
    \\    download_link_count: downloads.length,
    \\    attachment_count: upload && upload.files ? upload.files.length : 0,
    \\    assistant_message_count: assistantMessages.length,
    \\    login_elements_found: login,
    \\    captcha_found: captcha,
    \\    blocked_indicators: (blockedText ? 1 : 0) + (verifyHuman ? 1 : 0) + (login ? 1 : 0) + (captcha ? 1 : 0)
    \\  };
    \\})())
;

const open_upload_picker_js =
    \\(() => {
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const isEnabled = (el) => !!el && !el.disabled && el.getAttribute('aria-disabled') !== 'true';
    \\  const selectors = [
    \\    "button[data-testid*='upload' i]",
    \\    "button[data-testid*='attach' i]",
    \\    "button[aria-label*='upload' i]",
    \\    "button[aria-label*='attach' i]",
    \\    "button[title*='upload' i]",
    \\    "button[title*='attach' i]",
    \\    "[role='button'][aria-label*='upload' i]",
    \\    "[role='button'][aria-label*='attach' i]"
    \\  ];
    \\  const roots = [
    \\    document.querySelector('form'),
    \\    document.querySelector('main'),
    \\    document
    \\  ].filter(Boolean);
    \\  let btn = null;
    \\  for (const root of roots) {
    \\    if (!root.querySelectorAll) continue;
    \\    for (const selector of selectors) {
    \\      const found = Array.from(root.querySelectorAll(selector)).find((el) => isVisible(el) && isEnabled(el));
    \\      if (found) { btn = found; break; }
    \\    }
    \\    if (btn) break;
    \\  }
    \\  if (!btn) {
    \\    const candidates = Array.from(document.querySelectorAll('button, [role="button"]'));
    \\    btn = candidates.find((b) => {
    \\      if (!isVisible(b) || !isEnabled(b)) return false;
    \\      const label = (b.getAttribute('aria-label') || '').toLowerCase();
    \\      const title = (b.getAttribute('title') || '').toLowerCase();
    \\      const testid = (b.getAttribute('data-testid') || '').toLowerCase();
    \\      const text = (b.innerText || '').toLowerCase();
    \\      const meta = (label + ' ' + title + ' ' + testid + ' ' + text);
    \\      return meta.includes('attach') || meta.includes('upload');
    \\    }) || null;
    \\  }
    \\  if (!btn) return false;
    \\  try { btn.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    \\  try { btn.click(); } catch (_) {}
    \\  return true;
    \\})()
;

const click_send_js =
    \\(() => {
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const composer = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  const root = composer ? (composer.closest('form') || composer.closest('main') || composer.parentElement) : document;
    \\  const candidates = [
    \\    root && root.querySelector ? root.querySelector('button[data-testid="send-button"]') : null,
    \\    root && root.querySelector ? root.querySelector('#composer-submit-button') : null,
    \\    root && root.querySelector ? root.querySelector('button[type="submit"]') : null,
    \\  ];
    \\  let send = candidates.find((el) => isVisible(el));
    \\  if (!send) {
    \\    const buttons = Array.from(document.querySelectorAll('button'));
    \\    send = buttons.find((b) => {
    \\      if (!isVisible(b)) return false;
    \\      const label = (b.getAttribute('aria-label') || '').toLowerCase();
    \\      const testid = (b.getAttribute('data-testid') || '').toLowerCase();
    \\      return testid === 'send-button' || testid.includes('send') || label.includes('send');
    \\    }) || null;
    \\  }
    \\  if (!send) return false;
    \\  if (send.disabled || send.getAttribute('aria-disabled') === 'true') return false;
    \\  try { send.scrollIntoView({ block: 'center', inline: 'center' }); } catch (_) {}
    \\  try { send.click(); } catch (_) {}
    \\  return true;
    \\})()
;

const mark_download_js_fmt =
    \\(() => {{
    \\  for (const el of document.querySelectorAll('[data-hq-download-target]')) delete el.dataset.hqDownloadTarget;
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const fileExt = /\.(zip|diff|patch|txt|md|html|json|yaml|yml|tsv)\b/;
    \\  const matches = Array.from(document.querySelectorAll('a[download], a[href^="blob:"], a[href^="data:"], button, div[role="button"]')).filter((el) => {{
    \\    const text = (el.innerText || '').trim().toLowerCase();
    \\    const label = (el.getAttribute('aria-label') || '').toLowerCase();
    \\    const title = (el.getAttribute('title') || '').toLowerCase();
    \\    const testid = (el.getAttribute('data-testid') || '').toLowerCase();
    \\    const meta = (text + ' ' + label + ' ' + title + ' ' + testid);
    \\    const isAnchor = (el.tagName || '').toLowerCase() === 'a';
    \\    const isDirect = el.matches('a[download], a[href^="blob:"], a[href^="data:"]');
    \\    const hasDownloadHint = meta.includes('download');
    \\    if (!isAnchor && !hasDownloadHint && !isDirect) return false;
    \\    const href = isAnchor ? ((el.getAttribute('href') || '') + '').toLowerCase() : '';
    \\    const isFile = fileExt.test(text) || fileExt.test(label) || fileExt.test(testid) || (isAnchor && fileExt.test(href));
    \\    const isDownload = isDirect || hasDownloadHint || (isAnchor && isFile);
    \\    return isVisible(el) && isDownload;
    \\  }});
    \\  const target = matches[{d}] || null;
    \\  if (!target) return false;
    \\  target.dataset.hqDownloadTarget = '1';
    \\  return true;
    \\}})()
;

const wait_send_enabled_js_fmt =
    \\(() => new Promise((resolve) => {{
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const composer = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\  const root = composer ? (composer.closest('form') || composer.closest('main') || composer.parentElement) : document;
    \\  const pick = () => {{
    \\    const candidates = [
    \\      root && root.querySelector ? root.querySelector('button[data-testid="send-button"]') : null,
    \\      root && root.querySelector ? root.querySelector('#composer-submit-button') : null,
    \\      root && root.querySelector ? root.querySelector('button[type="submit"]') : null,
    \\    ];
    \\    let btn = candidates.find((el) => isVisible(el));
    \\    if (btn) return btn;
    \\    const buttons = Array.from(document.querySelectorAll('button'));
    \\    btn = buttons.find((b) => {{
    \\      if (!isVisible(b)) return false;
    \\      const label = (b.getAttribute('aria-label') || '').toLowerCase();
    \\      const testid = (b.getAttribute('data-testid') || '').toLowerCase();
    \\      return testid === 'send-button' || testid.includes('send') || label.includes('send');
    \\    }});
    \\    return btn || null;
    \\  }};
    \\  const ok = () => {{
    \\    const send = pick();
    \\    return !!send && !send.disabled && send.getAttribute('aria-disabled') !== 'true';
    \\  }};
    \\  if (ok()) return resolve(true);
    \\  let done = false;
    \\  const finish = (v) => {{ if (done) return; done = true; try {{ mo.disconnect(); }} catch (_) {{}} resolve(v); }};
    \\  const mo = new MutationObserver(() => {{ if (ok()) finish(true); }});
    \\  try {{ mo.observe(root && root.nodeType === 1 ? root : document.documentElement, {{ subtree: true, attributes: true, childList: true }}); }} catch (_) {{}}
    \\  setTimeout(() => finish(false), {d});
    \\}}))()
;

const wait_composer_cleared_js_fmt =
    \\(() => new Promise((resolve) => {{
    \\  const empty = () => {{
    \\    const el = document.querySelector('#prompt-textarea') || document.querySelector('textarea') || document.querySelector('[contenteditable="true"]');
    \\    if (!el) return false;
    \\    const text = ('value' in el) ? (el.value || '') : (el.innerText || el.textContent || '');
    \\    return (text.trim().length === 0);
    \\  }};
    \\  if (empty()) return resolve(true);
    \\  let done = false;
    \\  const finish = (v) => {{ if (done) return; done = true; try {{ mo.disconnect(); }} catch (_) {{}} resolve(v); }};
    \\  const mo = new MutationObserver(() => {{ if (empty()) finish(true); }});
    \\  try {{ mo.observe(document.documentElement, {{ subtree: true, childList: true, attributes: true, characterData: true }}); }} catch (_) {{}}
    \\  setTimeout(() => finish(false), {d});
    \\}}))()
;

const wait_upload_input_js_fmt =
    \\(() => new Promise((resolve) => {{
    \\  const found = () => !!document.querySelector('input[type="file"]');
    \\  if (found()) return resolve(true);
    \\  let done = false;
    \\  const finish = (v) => {{ if (done) return; done = true; try {{ mo.disconnect(); }} catch (_) {{}} resolve(v); }};
    \\  const mo = new MutationObserver(() => {{ if (found()) finish(true); }});
    \\  try {{ mo.observe(document.documentElement, {{ subtree: true, childList: true }}); }} catch (_) {{}}
    \\  setTimeout(() => finish(false), {d});
    \\}}))()
;

const ui_extract_object_js =
    \\(() => {
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const url = (location && location.href) ? location.href : '';
    \\  const rawAssistants = Array.from(document.querySelectorAll('[data-message-author-role="assistant"], [data-testid*="assistant"], [data-role="assistant"]')).filter(isVisible);
    \\  const assistants = rawAssistants
    \\    .map((el) => ({ el, text: String(el.innerText || el.textContent || '') }))
    \\    .filter((x) => x.text.trim().length > 0);
    \\  const last = assistants.length ? assistants[assistants.length - 1].el : null;
    \\  const text = assistants.length ? assistants[assistants.length - 1].text : '';
    \\  const errors = [];
    \\  const out = {
    \\    ok: true,
    \\    url,
    \\    model_confirmation_line: '',
    \\    model_pro: '',
    \\    model_label: '',
    \\    worker_block_raw: '',
    \\    patch: '',
    \\    test_report: '',
    \\    checklist: '',
    \\    errors: '',
    \\  };
    \\  if (!last) {
    \\    out.ok = false;
    \\    errors.push('no assistant message visible');
    \\  }
    \\  const rtrim = (s) => String(s || '').replace(/[ \t]+$/, '');
    \\  const allLines = text.split(/\r?\n/);
    \\  const firstNonEmptyLineIndex = () => {
    \\    for (let i = 0; i < allLines.length; i += 1) {
    \\      const t = String(allLines[i] || '').trim();
    \\      if (t.length > 0) return i;
    \\    }
    \\    return -1;
    \\  };
    \\  const proIdx = firstNonEmptyLineIndex();
    \\  const proLine = proIdx >= 0 ? rtrim(allLines[proIdx]) : '';
    \\  const mc = proLine.match(/^MODEL_CONFIRMATION:\s*Pro=(YES|NO)\s*\|\s*MODEL=(.+)\s*$/);
    \\  if (mc) {
    \\    out.model_confirmation_line = proLine;
    \\    out.model_pro = (mc[1] || '').trim();
    \\    out.model_label = (mc[2] || '').trim();
    \\    if (out.model_pro !== 'YES') { out.ok = false; errors.push('MODEL_CONFIRMATION Pro is not YES'); }
    \\    if (!out.model_label || out.model_label.toUpperCase().includes('UNCONFIRMED')) { out.ok = false; errors.push('MODEL_CONFIRMATION MODEL is unconfirmed'); }
    \\  } else {
    \\    out.ok = false;
    \\    errors.push('missing MODEL_CONFIRMATION on first non-empty line');
    \\  }
    \\
    \\  const isFence = (line) => String(line || '').trim().startsWith('```');
    \\  const findHeaderOutsideFences = (from, to, needle) => {
    \\    let inFence = false;
    \\    for (let i = from; i <= to; i += 1) {
    \\      const raw = allLines[i] || '';
    \\      if (isFence(raw)) inFence = !inFence;
    \\      if (!inFence && rtrim(raw) === needle) return i;
    \\    }
    \\    return -1;
    \\  };
    \\  const findCanonicalWorkerBlock = () => {
    \\    const startAt = proIdx >= 0 ? (proIdx + 1) : 0;
    \\    for (let b = startAt; b < allLines.length; b += 1) {
    \\      if (rtrim(allLines[b]) !== 'BEGIN_WORKER_BLOCK') continue;
    \\      let e = -1;
    \\      for (let i = b + 1; i < allLines.length; i += 1) {
    \\        if (rtrim(allLines[i]) === 'END_WORKER_BLOCK') { e = i; break; }
    \\      }
    \\      if (e < 0) continue;
    \\      const patch = findHeaderOutsideFences(b + 1, e, 'PATCH.diff');
    \\      if (patch < 0) { b = e; continue; }
    \\      const report = findHeaderOutsideFences(patch + 1, e, 'TEST_REPORT_worker');
    \\      if (report < 0) { b = e; continue; }
    \\      const checklist = findHeaderOutsideFences(report + 1, e, 'CHECKLIST');
    \\      if (checklist < 0) { b = e; continue; }
    \\      return { begin: b, end: e, patch, report, checklist };
    \\    }
    \\    return null;
    \\  };
    \\  const block = findCanonicalWorkerBlock();
    \\  if (block) {
    \\    out.worker_block_raw = allLines.slice(block.begin, block.end + 1).join('\n');
    \\    const stripFence = (s, kind) => {
    \\      const raw = String(s || '');
    \\      const all = raw.split(/\r?\n/);
    \\      const trimBlank = () => {
    \\        while (all.length && all[0].trim() === '') all.shift();
    \\        while (all.length && all[all.length - 1].trim() === '') all.pop();
    \\      };
    \\      const nextNonEmpty = (start) => {
    \\        for (let i = start || 0; i < all.length; i += 1) {
    \\          const t = (all[i] || '').trim();
    \\          if (t) return t;
    \\        }
    \\        return '';
    \\      };
    \\
    \\      trimBlank();
    \\      if (!all.length) return '';
    \\
    \\      // Some UIs inject a language label line instead of ``` fences.
    \\      const headLc = all[0].trim().toLowerCase();
    \\      if (headLc === 'diff' && kind === 'PATCH.diff') {
    \\        const nxt = nextNonEmpty(1);
    \\        if (nxt.startsWith('diff --git') || nxt.startsWith('```')) { all.shift(); trimBlank(); }
    \\      } else if ((headLc === 'plain text' || headLc === 'text') && (kind === 'TEST_REPORT_worker' || kind === 'CHECKLIST')) {
    \\        all.shift();
    \\        trimBlank();
    \\      }
    \\
    \\      if (all.length && all[0].trim().startsWith('```')) {
    \\        all.shift();
    \\        trimBlank();
    \\        if (all.length && all[all.length - 1].trim().startsWith('```')) all.pop();
    \\        trimBlank();
    \\      }
    \\      return all.join('\n').trim();
    \\    };
    \\    out.patch = stripFence(allLines.slice(block.patch + 1, block.report).join('\n'), 'PATCH.diff');
    \\    out.test_report = stripFence(allLines.slice(block.report + 1, block.checklist).join('\n'), 'TEST_REPORT_worker');
    \\    out.checklist = stripFence(allLines.slice(block.checklist + 1, block.end).join('\n'), 'CHECKLIST');
    \\    if (!out.patch) { out.ok = false; errors.push('missing PATCH.diff section'); }
    \\    if (!out.test_report) { out.ok = false; errors.push('missing TEST_REPORT_worker section'); }
    \\    if (!out.checklist) { out.ok = false; errors.push('missing CHECKLIST section'); }
    \\  } else {
    \\    out.ok = false;
    \\    errors.push('missing canonical worker block');
    \\  }
    \\  out.errors = errors.join('\n');
    \\  return out;
    \\})()
;

const ui_read_json_js =
    \\JSON.stringify((() => {
    \\  const isVisible = (el) => !!el && !el.hidden && getComputedStyle(el).display !== 'none' && getComputedStyle(el).visibility !== 'hidden';
    \\  const url = (location && location.href) ? location.href : '';
    \\  const rawAssistants = Array.from(document.querySelectorAll('[data-message-author-role="assistant"], [data-testid*="assistant"], [data-role="assistant"]')).filter(isVisible);
    \\  const assistants = rawAssistants
    \\    .map((el) => ({ el, text: String(el.innerText || el.textContent || '') }))
    \\    .filter((x) => x.text.trim().length > 0);
    \\  const last = assistants.length ? assistants[assistants.length - 1].el : null;
    \\  const text = assistants.length ? assistants[assistants.length - 1].text : '';
    \\  const rtrim = (s) => String(s || '').replace(/[ \t]+$/, '');
    \\  const allLines = text.split(/\r?\n/);
    \\  const firstNonEmptyLineIndex = () => {
    \\    for (let i = 0; i < allLines.length; i += 1) {
    \\      const t = String(allLines[i] || '').trim();
    \\      if (t.length > 0) return i;
    \\    }
    \\    return -1;
    \\  };
    \\  const proIdx = firstNonEmptyLineIndex();
    \\  const proLine = proIdx >= 0 ? rtrim(allLines[proIdx]) : '';
    \\  const mc = proLine.match(/^MODEL_CONFIRMATION:\s*Pro=(YES|NO)\s*\|\s*MODEL=(.+)\s*$/);
    \\  const isFence = (line) => String(line || '').trim().startsWith('```');
    \\  const findHeaderOutsideFences = (from, to, needle) => {
    \\    let inFence = false;
    \\    for (let i = from; i <= to; i += 1) {
    \\      const raw = allLines[i] || '';
    \\      if (isFence(raw)) inFence = !inFence;
    \\      if (!inFence && rtrim(raw) === needle) return i;
    \\    }
    \\    return -1;
    \\  };
    \\  const findCanonicalWorkerBlock = () => {
    \\    const startAt = proIdx >= 0 ? (proIdx + 1) : 0;
    \\    for (let b = startAt; b < allLines.length; b += 1) {
    \\      if (rtrim(allLines[b]) !== 'BEGIN_WORKER_BLOCK') continue;
    \\      let e = -1;
    \\      for (let i = b + 1; i < allLines.length; i += 1) {
    \\        if (rtrim(allLines[i]) === 'END_WORKER_BLOCK') { e = i; break; }
    \\      }
    \\      if (e < 0) continue;
    \\      const patch = findHeaderOutsideFences(b + 1, e, 'PATCH.diff');
    \\      if (patch < 0) { b = e; continue; }
    \\      const report = findHeaderOutsideFences(patch + 1, e, 'TEST_REPORT_worker');
    \\      if (report < 0) { b = e; continue; }
    \\      const checklist = findHeaderOutsideFences(report + 1, e, 'CHECKLIST');
    \\      if (checklist < 0) { b = e; continue; }
    \\      return { begin: b, end: e };
    \\    }
    \\    return null;
    \\  };
    \\  const block = findCanonicalWorkerBlock();
    \\  const tailMax = 4096;
    \\  const tail = text.length > tailMax ? text.slice(text.length - tailMax) : text;
    \\  return {
    \\    url,
    \\    assistant_visible_count: assistants.length,
    \\    last_assistant_found: !!last,
    \\    last_assistant_text_tail: tail,
    \\    model_confirmation_line: mc ? proLine : '',
    \\    model_pro: mc ? (mc[1] || '').trim() : '',
    \\    model_label: mc ? (mc[2] || '').trim() : '',
    \\    worker_block_found: !!block,
    \\  };
    \\})())
;

const ui_meta_fn =
    \\function () {
    \\  return {
    \\    ok: !!this.ok,
    \\    url: (this.url || ''),
    \\    model_confirmation_line: (this.model_confirmation_line || ''),
    \\    model_pro: (this.model_pro || ''),
    \\    model_label: (this.model_label || ''),
    \\    errors: (this.errors || ''),
    \\  };
    \\}
;

const ui_len_fn =
    \\function (key) {
    \\  const v = this && key ? this[key] : '';
    \\  return (typeof v === 'string') ? v.length : 0;
    \\}
;

const ui_slice_fn =
    \\function (key, off, len) {
    \\  const v = this && key ? this[key] : '';
    \\  if (typeof v !== 'string') return '';
    \\  const o = (off | 0);
    \\  const l = (len | 0);
    \\  return v.slice(o, o + l);
    \\}
;
