const std = @import("std");
const hq = @import("hq");

test "chatgpt.listAssistantMessageIdsFromConversationJson filters assistant ids newest first" {
    const raw =
        \\{
        \\  "messages": [
        \\    { "id": "u-1", "role": "user", "created_at": 100 },
        \\    { "id": "a-1", "role": "assistant", "created_at": 110 },
        \\    { "id": "a-2", "role": "assistant", "created_at": 120 },
        \\    { "id": "tool-1", "role": "tool", "created_at": 130 }
        \\  ]
        \\}
    ;

    const ids = try hq.chatgpt.listAssistantMessageIdsFromConversationJson(std.testing.allocator, raw);
    defer {
        for (ids) |id| std.testing.allocator.free(id);
        std.testing.allocator.free(ids);
    }

    try std.testing.expectEqual(@as(usize, 2), ids.len);
    try std.testing.expectEqualStrings("a-2", ids[0]);
    try std.testing.expectEqualStrings("a-1", ids[1]);
}
