const std = @import("std");
const support = @import("support");
const harness = @import("fixture_harness");

const worker_html = harness.worker_block_fixture_html;
const worker_prose_html = harness.worker_block_prose_example_fixture_html;
const worker_header_in_fence_html = harness.worker_block_report_header_fixture_html;
const worker_late_mc_html = harness.worker_block_late_model_confirmation_fixture_html;

fn freePayload(allocator: std.mem.Allocator, payload: anytype) void {
    allocator.free(payload.url);
    allocator.free(payload.model_confirmation_line);
    allocator.free(payload.model_pro);
    allocator.free(payload.model_label);
    allocator.free(payload.worker_block_raw);
    allocator.free(payload.patch);
    allocator.free(payload.test_report);
    allocator.free(payload.checklist);
    allocator.free(payload.errors);
}

fn assertGoodPayload(payload: anytype) !void {
    try support.expect(std.mem.containsAtLeast(u8, payload.model_confirmation_line, 1, "MODEL_CONFIRMATION:"));
    try support.expectEqualStrings("YES", payload.model_pro);
    try support.expectEqualStrings("GPT-5.4 Pro", payload.model_label);
    try support.expect(std.mem.containsAtLeast(u8, payload.worker_block_raw, 1, "BEGIN_WORKER_BLOCK"));
    try support.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
    try support.expectEqualStrings("ok", std.mem.trim(u8, payload.test_report, " \t\r\n"));
    try support.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
    try support.expectEqual(usize, 0, std.mem.trim(u8, payload.errors, " \t\r\n").len);
}

fn assertProsePayload(payload: anytype) !void {
    try support.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
    try support.expectEqualStrings("ok", std.mem.trim(u8, payload.test_report, " \t\r\n"));
    try support.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
    try support.expectEqual(usize, 0, std.mem.trim(u8, payload.errors, " \t\r\n").len);
}

fn assertHeaderFencePayload(payload: anytype) !void {
    try support.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
    try support.expect(std.mem.containsAtLeast(u8, payload.test_report, 1, "CHECKLIST"));
    try support.expect(std.mem.containsAtLeast(u8, payload.test_report, 1, "still ok"));
    try support.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
    try support.expectEqual(usize, 0, std.mem.trim(u8, payload.errors, " \t\r\n").len);
}

fn assertOutcomeGood(outcome: anytype, allocator: std.mem.Allocator) !void {
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer freePayload(allocator, payload);
            try assertGoodPayload(payload);
        },
    }
}

fn assertOutcomeProse(outcome: anytype, allocator: std.mem.Allocator) !void {
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer freePayload(allocator, payload);
            try assertProsePayload(payload);
        },
    }
}

fn assertOutcomeHeader(outcome: anytype, allocator: std.mem.Allocator) !void {
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer freePayload(allocator, payload);
            try assertHeaderFencePayload(payload);
        },
    }
}

fn assertOutcomeLateModel(outcome: anytype) !void {
    switch (outcome) {
        .ok => return error.UnexpectedUiGetSuccess,
        .manual => return,
    }
}

test "ui get fixture extracts strict worker block sections" {
    const outcome = try harness.uiGetOnHtml(19_934, "ui-get-worker-block-profile", worker_html);
    try assertOutcomeGood(outcome, std.testing.allocator);
}

test "ui get ignores flush-left marker examples in prose" {
    const outcome = try harness.uiGetOnHtml(19_935, "ui-get-worker-block-prose-example", worker_prose_html);
    try assertOutcomeProse(outcome, std.testing.allocator);
}

test "ui get does not split on header words inside fenced report" {
    const outcome = try harness.uiGetOnHtml(19_936, "ui-get-worker-block-header-in-fence", worker_header_in_fence_html);
    try assertOutcomeHeader(outcome, std.testing.allocator);
}

test "ui get rejects model confirmation when it is not first non-empty line" {
    const outcome = try harness.uiGetOnHtml(19_937, "ui-get-worker-block-late-model-confirmation", worker_late_mc_html);
    try assertOutcomeLateModel(outcome);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const a = runtime.allocator;
    const io = runtime.io;

    const outcome1 = harness.uiGetOnHtmlRuntime(io, a, 19_934, "ui-get-worker-block-profile", worker_html) catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertOutcomeGood(outcome1, a);

    const outcome2 = harness.uiGetOnHtmlRuntime(io, a, 19_935, "ui-get-worker-block-prose-example", worker_prose_html) catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertOutcomeProse(outcome2, a);

    const outcome3 = harness.uiGetOnHtmlRuntime(io, a, 19_936, "ui-get-worker-block-header-in-fence", worker_header_in_fence_html) catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertOutcomeHeader(outcome3, a);

    const outcome4 = harness.uiGetOnHtmlRuntime(io, a, 19_937, "ui-get-worker-block-late-model-confirmation", worker_late_mc_html) catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertOutcomeLateModel(outcome4);
}
