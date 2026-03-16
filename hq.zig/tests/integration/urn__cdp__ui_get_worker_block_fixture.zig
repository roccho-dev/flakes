const std = @import("std");
const harness = @import("fixture_harness");

const worker_html = harness.worker_block_fixture_html;
const worker_prose_html = harness.worker_block_prose_example_fixture_html;
const worker_header_in_fence_html = harness.worker_block_report_header_fixture_html;
const worker_late_mc_html = harness.worker_block_late_model_confirmation_fixture_html;

test "ui get fixture extracts strict worker block sections" {
    const outcome = try harness.uiGetOnHtml(19_934, "ui-get-worker-block-profile", worker_html);
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer {
                std.testing.allocator.free(payload.url);
                std.testing.allocator.free(payload.model_confirmation_line);
                std.testing.allocator.free(payload.model_pro);
                std.testing.allocator.free(payload.model_label);
                std.testing.allocator.free(payload.worker_block_raw);
                std.testing.allocator.free(payload.patch);
                std.testing.allocator.free(payload.test_report);
                std.testing.allocator.free(payload.checklist);
                std.testing.allocator.free(payload.errors);
            }

            try std.testing.expect(std.mem.containsAtLeast(u8, payload.model_confirmation_line, 1, "MODEL_CONFIRMATION:"));
            try std.testing.expectEqualStrings("YES", payload.model_pro);
            try std.testing.expectEqualStrings("GPT-5.4 Pro", payload.model_label);
            try std.testing.expect(std.mem.containsAtLeast(u8, payload.worker_block_raw, 1, "BEGIN_WORKER_BLOCK"));
            try std.testing.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
            try std.testing.expectEqualStrings("ok", std.mem.trim(u8, payload.test_report, " \t\r\n"));
            try std.testing.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
            try std.testing.expectEqual(@as(usize, 0), std.mem.trim(u8, payload.errors, " \t\r\n").len);
        },
    }
}

test "ui get ignores flush-left marker examples in prose" {
    const outcome = try harness.uiGetOnHtml(19_935, "ui-get-worker-block-prose-example", worker_prose_html);
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer {
                std.testing.allocator.free(payload.url);
                std.testing.allocator.free(payload.model_confirmation_line);
                std.testing.allocator.free(payload.model_pro);
                std.testing.allocator.free(payload.model_label);
                std.testing.allocator.free(payload.worker_block_raw);
                std.testing.allocator.free(payload.patch);
                std.testing.allocator.free(payload.test_report);
                std.testing.allocator.free(payload.checklist);
                std.testing.allocator.free(payload.errors);
            }

            try std.testing.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
            try std.testing.expectEqualStrings("ok", std.mem.trim(u8, payload.test_report, " \t\r\n"));
            try std.testing.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
            try std.testing.expectEqual(@as(usize, 0), std.mem.trim(u8, payload.errors, " \t\r\n").len);
        },
    }
}

test "ui get does not split on header words inside fenced report" {
    const outcome = try harness.uiGetOnHtml(19_936, "ui-get-worker-block-header-in-fence", worker_header_in_fence_html);
    switch (outcome) {
        .manual => return error.UnexpectedManualIntervention,
        .ok => |payload| {
            defer {
                std.testing.allocator.free(payload.url);
                std.testing.allocator.free(payload.model_confirmation_line);
                std.testing.allocator.free(payload.model_pro);
                std.testing.allocator.free(payload.model_label);
                std.testing.allocator.free(payload.worker_block_raw);
                std.testing.allocator.free(payload.patch);
                std.testing.allocator.free(payload.test_report);
                std.testing.allocator.free(payload.checklist);
                std.testing.allocator.free(payload.errors);
            }

            try std.testing.expect(std.mem.containsAtLeast(u8, payload.patch, 1, "diff --git"));
            try std.testing.expect(std.mem.containsAtLeast(u8, payload.test_report, 1, "CHECKLIST"));
            try std.testing.expect(std.mem.containsAtLeast(u8, payload.test_report, 1, "still ok"));
            try std.testing.expectEqualStrings("YES", std.mem.trim(u8, payload.checklist, " \t\r\n"));
            try std.testing.expectEqual(@as(usize, 0), std.mem.trim(u8, payload.errors, " \t\r\n").len);
        },
    }
}

test "ui get rejects model confirmation when it is not first non-empty line" {
    const outcome = try harness.uiGetOnHtml(19_937, "ui-get-worker-block-late-model-confirmation", worker_late_mc_html);
    switch (outcome) {
        .ok => return error.UnexpectedUiGetSuccess,
        .manual => return,
    }
}
