const std = @import("std");
const harness = @import("fixture_harness");

const good_html = harness.good_fixture_html;

test "send fixture handles ChatGPT selectors and delayed upload input" {
    const outcome = try harness.sendOnHtml(19_933, "send-good-profile", good_html, "ship selectors");
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |result| {
            try std.testing.expect(result.observed.textarea_found);
            try std.testing.expect(result.observed.send_button_found);
            try std.testing.expectEqual(@as(usize, 1), result.observed.download_link_count);
            try std.testing.expectEqual(@as(usize, 1), result.observed.assistant_message_count);
            try std.testing.expect(result.observed.attachment_count >= 1);
        },
    }
}
