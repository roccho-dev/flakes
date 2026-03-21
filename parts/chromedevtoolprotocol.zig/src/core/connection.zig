const std = @import("std");
const protocol = @import("protocol.zig");
const WebSocket = @import("../transport/websocket.zig").WebSocket;
const WebSocketError = @import("../transport/websocket.zig").WebSocketError;
const Session = @import("session.zig").Session;

const json_util = @import("../util/json.zig");

/// CDP Connection - synchronous version for Zig 0.16
/// Handles WebSocket communication with Chrome DevTools Protocol
pub const Connection = struct {
    websocket: WebSocket,
    allocator: std.mem.Allocator,
    id_allocator: protocol.IdAllocator,
    last_error: ?protocol.ErrorPayload,
    receive_timeout_ms: u32,
    verbose: bool,

    const Self = @This();

    pub const Options = struct {
        allocator: std.mem.Allocator,
        io: std.Io,
        receive_timeout_ms: u32 = 30_000,
        connect_timeout_ms: u32 = 10_000,
        max_message_size: usize = @import("../transport/websocket.zig").DEFAULT_MAX_MESSAGE_SIZE,
        verbose: bool = false,
    };

    /// Open a connection to a WebSocket URL
    pub fn open(ws_url: []const u8, opts: Options) !*Self {
        // Parse ws:// URL to extract host, port, path
        const host_start = if (std.mem.startsWith(u8, ws_url, "wss://"))
            @as(usize, 6)
        else if (std.mem.startsWith(u8, ws_url, "ws://"))
            @as(usize, 5)
        else
            return error.InvalidUrl;

        const rest = ws_url[host_start..];

        // Find path separator
        const path_start = std.mem.indexOf(u8, rest, "/") orelse rest.len;
        const host_port = rest[0..path_start];
        const path = if (path_start < rest.len) rest[path_start..] else "/";

        // Parse host and port
        var host: []const u8 = undefined;
        var port: u16 = if (std.mem.startsWith(u8, ws_url, "wss://")) 443 else 80;

        if (std.mem.indexOf(u8, host_port, ":")) |colon| {
            host = host_port[0..colon];
            port = std.fmt.parseInt(u16, host_port[colon + 1 ..], 10) catch return error.InvalidUrl;
        } else {
            host = host_port;
        }

        const websocket = WebSocket.connect(.{
            .host = host,
            .port = port,
            .path = path,
            .tls = std.mem.startsWith(u8, ws_url, "wss://"),
            .connect_timeout_ms = opts.connect_timeout_ms,
            .receive_timeout_ms = opts.receive_timeout_ms,
            .max_message_size = opts.max_message_size,
            .allocator = opts.allocator,
            .io = opts.io,
        }) catch |err| switch (err) {
            WebSocketError.Timeout => return error.Timeout,
            WebSocketError.InvalidUrl => return error.InvalidUrl,
            else => return error.ConnectionFailed,
        };

        const self = try opts.allocator.create(Self);
        self.* = .{
            .websocket = websocket,
            .allocator = opts.allocator,
            .id_allocator = protocol.IdAllocator.init(),
            .last_error = null,
            .receive_timeout_ms = opts.receive_timeout_ms,
            .verbose = opts.verbose,
        };

        return self;
    }

    /// Close the network transport but keep the allocation owned by the caller.
    pub fn close(self: *Self) void {
        self.websocket.close();
    }

    /// Release the connection allocation and all owned resources.
    pub fn deinit(self: *Self) void {
        self.close();
        self.clearLastError();
        self.allocator.destroy(self);
    }

    /// Release a command result allocated by this connection.
    pub fn deinitCommandResult(self: *Self, value: *std.json.Value) void {
        json_util.deinitValue(self.allocator, value);
    }

    /// Send a CDP command and wait for response (synchronous).
    ///
    /// Ownership: the returned `std.json.Value` is deep-cloned and owned by the
    /// caller. Call `connection.deinitCommandResult(&value)` (or
    /// `cdp.json.deinitValue(allocator, &value)`) when finished with it.
    pub fn sendCommand(
        self: *Self,
        method: []const u8,
        params: anytype,
        session_id: ?[]const u8,
    ) !std.json.Value {
        const id = self.id_allocator.next();

        // Serialize and send
        const json_str = try protocol.serializeCommand(
            self.allocator,
            id,
            method,
            params,
            session_id,
        );
        defer self.allocator.free(json_str);

        if (self.verbose) {
            std.debug.print("-> {s}\n", .{json_str});
        }

        try self.websocket.sendText(json_str);

        // Read response synchronously
        // Keep reading until we get a response with our id
        var attempts: u32 = 0;
        const max_attempts: u32 = 1000;

        while (attempts < max_attempts) : (attempts += 1) {
            var msg = self.websocket.receiveMessage() catch |err| {
                if (self.verbose) {
                    std.debug.print("Receive error: {}\n", .{err});
                }
                return switch (err) {
                    WebSocketError.Timeout => error.Timeout,
                    else => error.ConnectionClosed,
                };
            };
            defer msg.deinit(self.allocator);

            if (self.verbose) {
                std.debug.print("<- {s}\n", .{msg.data});
            }

            // Parse JSON
            const parsed = std.json.parseFromSlice(
                std.json.Value,
                self.allocator,
                msg.data,
                .{},
            ) catch continue;
            defer parsed.deinit();

            // Check if this is our response
            if (parsed.value.object.get("id")) |id_val| {
                if (id_val == .integer and id_val.integer == id) {
                    // Check for error
                    if (parsed.value.object.get("error")) |err_val| {
                        self.recordLastError(err_val);
                        if (err_val.object.get("code")) |code_val| {
                            const code: i32 = @intCast(code_val.integer);
                            return mapCdpError(code);
                        }
                        return error.ProtocolError;
                    }

                    // Return the result
                    if (parsed.value.object.get("result")) |result| {
                        return try json_util.cloneValue(self.allocator, result);
                    }

                    // Empty result is valid for some commands
                    return json_util.emptyObjectValue(self.allocator);
                }
            }

            // Not our response, might be an event - continue reading
        }

        return error.Timeout;
    }

    /// Send a CDP command whose response body is intentionally discarded.
    pub fn sendCommandVoid(
        self: *Self,
        method: []const u8,
        params: anytype,
        session_id: ?[]const u8,
    ) !void {
        var result = try self.sendCommand(method, params, session_id);
        defer self.deinitCommandResult(&result);
    }

    /// Wait for a specific event and return its params object.
    pub fn waitForEvent(
        self: *Self,
        method: []const u8,
        session_id: ?[]const u8,
        timeout_ms: u32,
    ) !std.json.Value {
        const previous_timeout = self.websocket.receive_timeout_ms;
        self.websocket.receive_timeout_ms = timeout_ms;
        defer self.websocket.receive_timeout_ms = previous_timeout;

        while (true) {
            var msg = self.websocket.receiveMessage() catch |err| {
                return switch (err) {
                    WebSocketError.Timeout => error.Timeout,
                    else => error.ConnectionClosed,
                };
            };
            defer msg.deinit(self.allocator);

            if (self.verbose) {
                std.debug.print("<- {s}\n", .{msg.data});
            }

            var parsed = protocol.parseMessage(self.allocator, msg.data) catch continue;
            defer parsed.deinit(self.allocator);

            switch (parsed) {
                .event => |event| {
                    if (!sessionMatches(session_id, event.session_id)) continue;
                    if (!std.mem.eql(u8, event.method, method)) continue;
                    return try json_util.cloneValue(self.allocator, event.params);
                },
                else => continue,
            }
        }
    }

    /// Get last error
    pub fn getLastError(self: *Self) ?protocol.ErrorPayload {
        return self.last_error;
    }

    /// Create a session attached to a target
    pub fn createSession(self: *Self, target_id: []const u8) !*Session {
        var result = try self.sendCommand("Target.attachToTarget", .{
            .targetId = target_id,
            .flatten = true,
        }, null);
        defer self.deinitCommandResult(&result);

        const session_id = try json_util.getString(result, "sessionId");
        return Session.init(session_id, self, self.allocator);
    }

    /// Destroy a session
    pub fn destroySession(self: *Self, session_id: []const u8) !void {
        try self.sendCommandVoid("Target.detachFromTarget", .{
            .sessionId = session_id,
        }, null);
    }

    fn clearLastError(self: *Self) void {
        if (self.last_error) |*err_payload| {
            err_payload.deinit(self.allocator);
            self.last_error = null;
        }
    }

    fn recordLastError(self: *Self, err_val: std.json.Value) void {
        self.clearLastError();

        if (err_val != .object) return;

        const code_val = err_val.object.get("code") orelse return;
        const message_val = err_val.object.get("message") orelse return;

        const code: i64 = switch (code_val) {
            .integer => |i| i,
            .float => |f| @intFromFloat(f),
            else => return,
        };
        const message = switch (message_val) {
            .string => |s| self.allocator.dupe(u8, s) catch return,
            else => return,
        };
        errdefer self.allocator.free(message);

        const data = if (err_val.object.get("data")) |data_val|
            switch (data_val) {
                .string => |s| self.allocator.dupe(u8, s) catch null,
                else => null,
            }
        else
            null;

        self.last_error = .{
            .code = code,
            .message = message,
            .data = data,
        };
    }
};

fn sessionMatches(expected: ?[]const u8, actual: ?[]const u8) bool {
    if (expected == null and actual == null) return true;
    if (expected == null or actual == null) return false;
    return std.mem.eql(u8, expected.?, actual.?);
}

/// Map CDP error code to Zig error
fn mapCdpError(code: i32) error{
    InvalidParams,
    MethodNotFound,
    InternalError,
    InvalidRequest,
    ServerError,
    ProtocolError,
} {
    return switch (code) {
        -32600 => error.InvalidRequest,
        -32601 => error.MethodNotFound,
        -32602 => error.InvalidParams,
        -32603 => error.InternalError,
        else => if (code >= -32099 and code <= -32000)
            error.ServerError
        else
            error.ProtocolError,
    };
}
