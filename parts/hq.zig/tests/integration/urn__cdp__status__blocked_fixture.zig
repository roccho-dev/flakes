const std = @import("std");
const support = @import("support");
const harness = @import("fixture_harness");

const blocked_html = harness.blocked_fixture_html;

fn assertObserved(observed: anytype) !void {
    try support.expect(!observed.textarea_found);
    try support.expect(!observed.upload_input_found);
    try support.expect(!observed.send_button_found);
    try support.expect(!observed.send_enabled);
    try support.expectEqual(usize, 0, observed.download_link_count);
    try support.expectEqual(usize, 0, observed.attachment_count);
    try support.expectEqual(usize, 0, observed.assistant_message_count);
    try support.expect(observed.login_elements_found);
    try support.expect(observed.captcha_found);
    try support.expectEqual(usize, 4, observed.blocked_indicators);

    const ready_to_collect = observed.download_link_count > 0;
    const should_manual = !ready_to_collect and !observed.textarea_found and
        (observed.login_elements_found or observed.captcha_found or observed.blocked_indicators > 0);
    try support.expect(should_manual);
}

test "status-style blocked fixture surfaces manual indicators" {
    const observed = try harness.snapshotFromHtml(19_932, "status-blocked-profile", blocked_html);
    try assertObserved(observed);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const observed = harness.snapshotFromHtmlRuntime(runtime.io, runtime.allocator, 19_932, "status-blocked-profile", blocked_html) catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertObserved(observed);
}
