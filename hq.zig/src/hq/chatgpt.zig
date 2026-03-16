const std = @import("std");

pub fn buildDispatchPrompt(
    allocator: std.mem.Allocator,
    task: []const u8,
    deliverable: []const u8,
    nudge: bool,
) ![]const u8 {
    const suffix = if (nudge)
        "\n\nReminder: respond only through the requested deliverable artifact."
    else
        "";
    return std.fmt.allocPrint(
        allocator,
        "Deliverable: {s}\nTask:\n{s}{s}",
        .{ deliverable, task, suffix },
    );
}

const MessageRef = struct {
    id: []const u8,
    created_at: i64,
};

fn lessThan(_: void, a: MessageRef, b: MessageRef) bool {
    return a.created_at > b.created_at;
}

pub fn listAssistantMessageIdsFromConversationJson(
    allocator: std.mem.Allocator,
    raw_json: []const u8,
) ![][]const u8 {
    const parsed = try std.json.parseFromSlice(std.json.Value, allocator, raw_json, .{});
    defer parsed.deinit();

    const object = switch (parsed.value) {
        .object => |obj| obj,
        else => return error.InvalidConversationJson,
    };

    const messages_value = object.get("messages") orelse return error.InvalidConversationJson;
    if (messages_value != .array) return error.InvalidConversationJson;

    var refs: std.ArrayList(MessageRef) = .empty;
    defer {
        for (refs.items) |item| allocator.free(item.id);
        refs.deinit(allocator);
    }

    for (messages_value.array.items) |item| {
        if (item != .object) continue;
        const role_value = item.object.get("role") orelse continue;
        const id_value = item.object.get("id") orelse continue;
        if (role_value != .string or id_value != .string) continue;
        if (!std.mem.eql(u8, role_value.string, "assistant")) continue;

        const created_at: i64 = if (item.object.get("created_at")) |value|
            switch (value) {
                .integer => value.integer,
                .float => @intFromFloat(value.float),
                else => 0,
            }
        else
            0;

        try refs.append(allocator, .{
            .id = try allocator.dupe(u8, id_value.string),
            .created_at = created_at,
        });
    }

    std.mem.sort(MessageRef, refs.items, {}, lessThan);

    const out = try allocator.alloc([]const u8, refs.items.len);
    for (refs.items, 0..) |item, index| {
        out[index] = try allocator.dupe(u8, item.id);
    }
    return out;
}
