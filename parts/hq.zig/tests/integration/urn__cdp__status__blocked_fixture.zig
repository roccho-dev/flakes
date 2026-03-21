const std = @import("std");
const harness = @import("fixture_harness");

const blocked_html = harness.blocked_fixture_html;

test "status-style blocked fixture surfaces manual indicators" {
    const observed = try harness.snapshotFromHtml(19_932, "status-blocked-profile", blocked_html);

    try std.testing.expect(!observed.textarea_found);
    try std.testing.expect(!observed.upload_input_found);
    try std.testing.expect(!observed.send_button_found);
    try std.testing.expect(!observed.send_enabled);
    try std.testing.expectEqual(@as(usize, 0), observed.download_link_count);
    try std.testing.expectEqual(@as(usize, 0), observed.attachment_count);
    try std.testing.expectEqual(@as(usize, 0), observed.assistant_message_count);
    try std.testing.expect(observed.login_elements_found);
    try std.testing.expect(observed.captcha_found);
    try std.testing.expectEqual(@as(usize, 4), observed.blocked_indicators);

    const ready_to_collect = observed.download_link_count > 0;
    const should_manual = !ready_to_collect and !observed.textarea_found and
        (observed.login_elements_found or observed.captcha_found or observed.blocked_indicators > 0);
    try std.testing.expect(should_manual);
}
