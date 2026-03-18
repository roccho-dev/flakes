const std = @import("std");
const hq = @import("hq");

test "chatgpt.buildDispatchPrompt preserves deliverable task and nudge contract" {
    const prompt = try hq.chatgpt.buildDispatchPrompt(std.testing.allocator, "ship it", "result.json", true);
    defer std.testing.allocator.free(prompt);

    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "Deliverable: result.json"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "Task:\nship it"));
    try std.testing.expect(std.mem.containsAtLeast(u8, prompt, 1, "Reminder: respond only through the requested deliverable artifact."));
}
