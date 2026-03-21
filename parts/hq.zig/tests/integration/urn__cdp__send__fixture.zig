const std = @import("std");
const support = @import("support");
const harness = @import("fixture_harness");

const good_html = harness.good_fixture_html;

fn assertOutcome(outcome: anytype) !void {
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |result| {
            try support.expect(result.observed.textarea_found);
            try support.expect(result.observed.send_button_found);
            try support.expectEqual(usize, 1, result.observed.download_link_count);
            try support.expectEqual(usize, 1, result.observed.assistant_message_count);
            try support.expect(result.observed.attachment_count >= 1);
        },
    }
}

test "send fixture handles ChatGPT selectors and delayed upload input" {
    const outcome = try harness.sendOnHtml(19_933, "send-good-profile", good_html, "ship selectors");
    try assertOutcome(outcome);
}

pub fn main(minimal: std.process.Init.Minimal) !void {
    var runtime = try support.Runtime.init(minimal);
    defer runtime.deinit();

    const outcome = harness.sendOnHtmlRuntime(runtime.io, runtime.allocator, 19_933, "send-good-profile", good_html, "ship selectors") catch |err| switch (err) {
        error.SkipZigTest => return,
        else => return err,
    };
    try assertOutcome(outcome);
}
