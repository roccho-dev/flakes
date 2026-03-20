const std = @import("std");

pub const exit_code: u8 = 42;

pub const Observed = struct {
    textarea_found: bool = false,
    upload_input_found: bool = false,
    send_button_found: bool = false,
    send_enabled: bool = false,
    download_link_count: usize = 0,
    attachment_count: usize = 0,
    assistant_message_count: usize = 0,
    login_elements_found: bool = false,
    captcha_found: bool = false,
    blocked_indicators: usize = 0,
};

pub const ManualInterventionRequired = struct {
    step: []const u8,
    url: []const u8,
    observed: Observed,
    manual_steps: []const []const u8,

    pub fn stringifyAlloc(self: *const @This(), allocator: std.mem.Allocator) ![]u8 {
        return std.json.Stringify.valueAlloc(allocator, .{
            .@"error" = "ManualInterventionRequired",
            .exit_code = exit_code,
            .step = self.step,
            .url = self.url,
            .observed = self.observed,
            .manual_steps = self.manual_steps,
        }, .{ .whitespace = .indent_2 });
    }
};
