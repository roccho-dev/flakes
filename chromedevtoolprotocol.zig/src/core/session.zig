const std = @import("std");
const Connection = @import("connection.zig").Connection;

/// A session attached to a specific target (browser tab, worker, etc.)
/// Commands sent through a session are multiplexed via sessionId
pub const Session = struct {
    id: []const u8,
    connection: *Connection,
    allocator: std.mem.Allocator,

    const Self = @This();

    /// Initialize a session
    pub fn init(
        id: []const u8,
        connection: *Connection,
        allocator: std.mem.Allocator,
    ) !*Self {
        const self = try allocator.create(Self);
        self.* = .{
            .id = try allocator.dupe(u8, id),
            .connection = connection,
            .allocator = allocator,
        };
        return self;
    }

    /// Send a command through this session.
    ///
    /// Ownership: the returned `std.json.Value` is owned by the caller and must
    /// be released with `session.deinitCommandResult(&value)` when no longer
    /// needed.
    pub fn sendCommand(
        self: *Self,
        method: []const u8,
        params: anytype,
    ) !std.json.Value {
        const sid = if (self.id.len > 0) self.id else null;
        return self.connection.sendCommand(method, params, sid);
    }

    /// Send a command through this session and discard the response body.
    pub fn sendCommandVoid(
        self: *Self,
        method: []const u8,
        params: anytype,
    ) !void {
        const sid = if (self.id.len > 0) self.id else null;
        return self.connection.sendCommandVoid(method, params, sid);
    }

    /// Release a command result allocated by this session/connection.
    pub fn deinitCommandResult(self: *Self, value: *std.json.Value) void {
        self.connection.deinitCommandResult(value);
    }

    /// Wait for a specific event on this session.
    pub fn waitForEvent(self: *Self, method: []const u8, timeout_ms: u32) !std.json.Value {
        const sid = if (self.id.len > 0) self.id else null;
        return self.connection.waitForEvent(method, sid, timeout_ms);
    }

    /// Detach from the target
    pub fn detach(self: *Self) !void {
        try self.connection.sendCommandVoid("Target.detachFromTarget", .{
            .sessionId = self.id,
        }, null);
    }

    /// Clean up resources
    pub fn deinit(self: *Self) void {
        self.allocator.free(self.id);
        self.allocator.destroy(self);
    }

    /// Get the session ID
    pub fn getId(self: *const Self) []const u8 {
        return self.id;
    }
};
