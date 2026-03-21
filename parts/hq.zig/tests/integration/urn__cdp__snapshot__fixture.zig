const std = @import("std");
const harness = @import("fixture_harness");

const good_html = harness.good_fixture_html;

test "snapshot fixture matches ChatGPT-like good page" {
    const actual = try harness.snapshotFromHtml(19_931, "snapshot-good-profile", good_html);
    const expected: @TypeOf(actual) = .{
        .textarea_found = true,
        .upload_input_found = false,
        .send_button_found = true,
        .send_enabled = false,
        .download_link_count = 0,
        .attachment_count = 0,
        .assistant_message_count = 0,
        .login_elements_found = false,
        .captcha_found = false,
        .blocked_indicators = 0,
    };
    try std.testing.expectEqualDeep(expected, actual);
}
