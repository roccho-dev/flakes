const std = @import("std");

/// WebSocket opcodes (RFC 6455)
pub const OPCODE_CONTINUATION: u4 = 0x0;
pub const OPCODE_TEXT: u4 = 0x1;
pub const OPCODE_BINARY: u4 = 0x2;
pub const OPCODE_CLOSE: u4 = 0x8;
pub const OPCODE_PING: u4 = 0x9;
pub const OPCODE_PONG: u4 = 0xA;

/// Maximum payload size for control frames
pub const MAX_CONTROL_FRAME_PAYLOAD = 125;

/// Default maximum message size (16 MB for screenshots)
pub const DEFAULT_MAX_MESSAGE_SIZE = 16 * 1024 * 1024;

/// WebSocket connection errors
pub const WebSocketError = error{
    ConnectionRefused,
    ConnectionClosed,
    ConnectionReset,
    HandshakeFailed,
    TlsError,
    FrameTooLarge,
    InvalidFrame,
    Timeout,
    InvalidUrl,
    InvalidResponse,
    OutOfMemory,
    NotImplemented,
};

/// Received message
pub const Message = struct {
    opcode: u4,
    data: []const u8,

    pub fn deinit(self: *Message, allocator: std.mem.Allocator) void {
        allocator.free(self.data);
    }
};

/// WebSocket client options
pub const Options = struct {
    host: []const u8,
    port: u16,
    path: []const u8 = "/",
    tls: bool = false,
    connect_timeout_ms: u32 = 10_000,
    receive_timeout_ms: u32 = 30_000,
    max_message_size: usize = DEFAULT_MAX_MESSAGE_SIZE,
    allocator: std.mem.Allocator,
    io: std.Io,
};

/// WebSocket client (RFC 6455)
pub const WebSocket = struct {
    allocator: std.mem.Allocator,
    io: std.Io,
    max_message_size: usize,
    receive_timeout_ms: u32,
    is_closed: bool,
    close_sent: bool,
    stream: std.Io.net.Stream,
    read_buf: [8192]u8,
    read_start: usize,
    read_end: usize,
    write_buf: [8192]u8,
    mask_state: u64,

    const Self = @This();

    /// Connect to a WebSocket server
    pub fn connect(opts: Options) WebSocketError!Self {
        if (opts.tls) {
            // Prevent silently speaking plaintext to a TLS endpoint.
            return WebSocketError.TlsError;
        }

        // Parse IP address. This currently expects a literal IP, which is fine
        // for local CDP / WSL-to-Windows usage where the host IP is known.
        const address = std.Io.net.IpAddress.parse(opts.host, opts.port) catch
            return WebSocketError.InvalidUrl;

        // NOTE: Zig 0.16 Threaded IO currently panics when using connect timeouts.
        // Keep connection attempts best-effort and enforce timeouts at the protocol layer.
        const stream = std.Io.net.IpAddress.connect(address, opts.io, .{
            .mode = .stream,
            .protocol = .tcp,
        }) catch |err| switch (err) {
            error.Timeout => return WebSocketError.Timeout,
            else => return WebSocketError.ConnectionRefused,
        };
        errdefer stream.close(opts.io);

        const mask_state = seedMaskState(opts.io);

        // Generate WebSocket key
        var key_bytes: [16]u8 = undefined;
        randomBytes(opts.io, &key_bytes);
        var key_buf: [24]u8 = undefined;
        const key_encoded = std.base64.standard.Encoder.encode(&key_buf, &key_bytes);

        // Build HTTP upgrade request
        const request = std.fmt.allocPrint(
            opts.allocator,
            "GET {s} HTTP/1.1\r\n" ++
                "Host: {s}:{d}\r\n" ++
                "Upgrade: websocket\r\n" ++
                "Connection: Upgrade\r\n" ++
                "Sec-WebSocket-Key: {s}\r\n" ++
                "Sec-WebSocket-Version: 13\r\n" ++
                "\r\n",
            .{ opts.path, opts.host, opts.port, key_encoded },
        ) catch return WebSocketError.OutOfMemory;
        defer opts.allocator.free(request);

        var write_buf_temp: [4096]u8 = undefined;
        var writer = stream.writer(opts.io, &write_buf_temp);
        writer.interface.writeAll(request) catch return WebSocketError.HandshakeFailed;
        writer.interface.flush() catch return WebSocketError.HandshakeFailed;

        var initial_read_buf: [8192]u8 = undefined;
        var response_len: usize = 0;
        const handshake_timeout = timeoutFromMs(opts.connect_timeout_ms);

        while (response_len < initial_read_buf.len) {
            const incoming = stream.socket.receiveTimeout(
                opts.io,
                initial_read_buf[response_len..],
                handshake_timeout,
            ) catch |err| switch (err) {
                error.Timeout => return WebSocketError.Timeout,
                else => return WebSocketError.HandshakeFailed,
            };

            if (incoming.data.len == 0) {
                return WebSocketError.HandshakeFailed;
            }

            response_len += incoming.data.len;

            if (std.mem.indexOf(u8, initial_read_buf[0..response_len], "\r\n\r\n")) |header_end| {
                const headers_end = header_end + 4;
                const response = initial_read_buf[0..headers_end];
                try verifyHandshake(response, key_encoded);

                return .{
                    .allocator = opts.allocator,
                    .io = opts.io,
                    .max_message_size = opts.max_message_size,
                    .receive_timeout_ms = opts.receive_timeout_ms,
                    .is_closed = false,
                    .close_sent = false,
                    .stream = stream,
                    .read_buf = initial_read_buf,
                    .read_start = headers_end,
                    .read_end = response_len,
                    .write_buf = undefined,
                    .mask_state = mask_state,
                };
            }
        }

        return WebSocketError.HandshakeFailed;
    }

    /// Send a text message
    pub fn sendText(self: *Self, payload: []const u8) WebSocketError!void {
        try self.sendFrame(OPCODE_TEXT, payload, true);
    }

    fn sendControlFrame(self: *Self, opcode: u4, payload: []const u8) WebSocketError!void {
        if (payload.len > MAX_CONTROL_FRAME_PAYLOAD) {
            return WebSocketError.InvalidFrame;
        }
        try self.sendFrame(opcode, payload, true);
    }

    fn sendFrame(self: *Self, opcode: u4, payload: []const u8, fin: bool) WebSocketError!void {
        if (self.is_closed) return WebSocketError.ConnectionClosed;

        var writer = self.stream.writer(self.io, &self.write_buf);

        var frame_buf: [14]u8 = undefined;
        var frame_len: usize = 2;

        frame_buf[0] = (if (fin) @as(u8, 0x80) else 0) | @as(u8, opcode);

        if (payload.len < 126) {
            frame_buf[1] = 0x80 | @as(u8, @truncate(payload.len));
        } else if (payload.len < 65536) {
            frame_buf[1] = 0x80 | 126;
            frame_buf[2] = @truncate(payload.len >> 8);
            frame_buf[3] = @truncate(payload.len);
            frame_len = 4;
        } else {
            frame_buf[1] = 0x80 | 127;
            writeLen64(frame_buf[2..10], payload.len);
            frame_len = 10;
        }

        const mask_key = self.nextMaskKey();
        @memcpy(frame_buf[frame_len..][0..4], &mask_key);
        frame_len += 4;

        writer.interface.writeAll(frame_buf[0..frame_len]) catch return WebSocketError.ConnectionClosed;

        if (payload.len > 0) {
            const masked = self.allocator.dupe(u8, payload) catch return WebSocketError.OutOfMemory;
            defer self.allocator.free(masked);

            for (masked, 0..) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }

            writer.interface.writeAll(masked) catch return WebSocketError.ConnectionClosed;
        }

        writer.interface.flush() catch return WebSocketError.ConnectionClosed;
    }

    fn nextMaskKey(self: *Self) [4]u8 {
        var key: [4]u8 = undefined;
        self.fillPseudoRandom(&key);
        return key;
    }

    fn fillPseudoRandom(self: *Self, dest: []u8) void {
        var state = self.mask_state;
        if (state == 0) state = 0x9e3779b97f4a7c15;

        for (dest) |*byte| {
            state ^= state << 13;
            state ^= state >> 7;
            state ^= state << 17;
            byte.* = @truncate(state);
        }

        self.mask_state = state;
    }

    /// Read exactly `len` bytes into `dest`.
    fn readBytes(self: *Self, dest: []u8) WebSocketError!void {
        var filled: usize = 0;
        while (filled < dest.len) {
            if (self.read_start == self.read_end) {
                try self.refillReadBuffer();
            }

            const available = self.read_end - self.read_start;
            const n = @min(dest.len - filled, available);
            @memcpy(dest[filled..][0..n], self.read_buf[self.read_start..][0..n]);
            self.read_start += n;
            filled += n;
        }
    }

    fn refillReadBuffer(self: *Self) WebSocketError!void {
        self.read_start = 0;
        self.read_end = 0;

        const incoming = self.stream.socket.receiveTimeout(
            self.io,
            self.read_buf[0..],
            timeoutFromMs(self.receive_timeout_ms),
        ) catch |err| switch (err) {
            error.Timeout => return WebSocketError.Timeout,
            else => return WebSocketError.ConnectionClosed,
        };

        if (incoming.data.len == 0) {
            return WebSocketError.ConnectionClosed;
        }

        self.read_end = incoming.data.len;
    }

    /// Read exactly `len` bytes into a newly allocated buffer.
    fn readBytesAlloc(self: *Self, len: usize) WebSocketError![]u8 {
        const buf = self.allocator.alloc(u8, len) catch return WebSocketError.OutOfMemory;
        errdefer self.allocator.free(buf);
        try self.readBytes(buf);
        return buf;
    }

    /// Read a single WebSocket frame's payload, returning fin, opcode, and data.
    fn readFrame(self: *Self) WebSocketError!struct { fin: bool, opcode: u4, data: []u8 } {
        var header: [2]u8 = undefined;
        try self.readBytes(&header);

        if ((header[0] & 0x70) != 0) {
            return WebSocketError.InvalidFrame;
        }

        const fin = (header[0] & 0x80) != 0;
        const opcode: u4 = @truncate(header[0] & 0x0F);
        const masked = (header[1] & 0x80) != 0;
        var payload_len: usize = header[1] & 0x7F;

        switch (opcode) {
            OPCODE_CONTINUATION, OPCODE_TEXT, OPCODE_BINARY, OPCODE_CLOSE, OPCODE_PING, OPCODE_PONG => {},
            else => return WebSocketError.InvalidFrame,
        }

        if (payload_len == 126) {
            var ext: [2]u8 = undefined;
            try self.readBytes(&ext);
            payload_len = (@as(usize, ext[0]) << 8) | ext[1];
        } else if (payload_len == 127) {
            var ext: [8]u8 = undefined;
            try self.readBytes(&ext);

            var parsed_len: u64 = 0;
            for (ext) |byte| {
                parsed_len = (parsed_len << 8) | byte;
            }

            if (parsed_len > std.math.maxInt(usize)) {
                return WebSocketError.FrameTooLarge;
            }
            payload_len = @intCast(parsed_len);
        }

        if (opcode >= 0x8 and (!fin or payload_len > MAX_CONTROL_FRAME_PAYLOAD)) {
            return WebSocketError.InvalidFrame;
        }
        if (payload_len > self.max_message_size) {
            return WebSocketError.FrameTooLarge;
        }

        var mask_key: [4]u8 = .{ 0, 0, 0, 0 };
        if (masked) {
            try self.readBytes(&mask_key);
        }

        const payload = try self.readBytesAlloc(payload_len);

        if (masked) {
            for (payload, 0..) |*byte, i| {
                byte.* ^= mask_key[i % 4];
            }
        }

        return .{ .fin = fin, .opcode = opcode, .data = payload };
    }

    /// Receive a complete message (handles continuation frames and control
    /// frames interleaved per RFC 6455).
    pub fn receiveMessage(self: *Self) WebSocketError!Message {
        var assembled: std.ArrayList(u8) = .empty;
        errdefer assembled.deinit(self.allocator);

        var message_opcode: ?u4 = null;

        while (true) {
            const frame = try self.readFrame();
            switch (frame.opcode) {
                OPCODE_PING => {
                    defer self.allocator.free(frame.data);
                    try self.sendControlFrame(OPCODE_PONG, frame.data);
                    continue;
                },
                OPCODE_PONG => {
                    self.allocator.free(frame.data);
                    continue;
                },
                OPCODE_CLOSE => {
                    defer self.allocator.free(frame.data);
                    self.is_closed = true;
                    if (!self.close_sent) {
                        _ = self.sendControlFrame(OPCODE_CLOSE, frame.data) catch {};
                        self.close_sent = true;
                    }
                    return WebSocketError.ConnectionClosed;
                },
                OPCODE_TEXT, OPCODE_BINARY => {
                    if (message_opcode != null) {
                        self.allocator.free(frame.data);
                        return WebSocketError.InvalidFrame;
                    }
                    message_opcode = frame.opcode;
                    try appendPayload(self, &assembled, frame.data);
                    self.allocator.free(frame.data);

                    if (frame.fin) {
                        return .{
                            .opcode = frame.opcode,
                            .data = try assembled.toOwnedSlice(self.allocator),
                        };
                    }
                },
                OPCODE_CONTINUATION => {
                    if (message_opcode == null) {
                        self.allocator.free(frame.data);
                        return WebSocketError.InvalidFrame;
                    }
                    try appendPayload(self, &assembled, frame.data);
                    self.allocator.free(frame.data);

                    if (frame.fin) {
                        return .{
                            .opcode = message_opcode.?,
                            .data = try assembled.toOwnedSlice(self.allocator),
                        };
                    }
                },
                else => {
                    self.allocator.free(frame.data);
                    return WebSocketError.InvalidFrame;
                },
            }
        }
    }

    /// Close the connection
    pub fn close(self: *Self) void {
        if (!self.is_closed and !self.close_sent) {
            _ = self.sendControlFrame(OPCODE_CLOSE, "") catch {};
            self.close_sent = true;
        }
        self.stream.close(self.io);
        self.is_closed = true;
    }
};

fn appendPayload(
    self: *WebSocket,
    assembled: *std.ArrayList(u8),
    payload: []const u8,
) WebSocketError!void {
    if (assembled.items.len + payload.len > self.max_message_size) {
        return WebSocketError.FrameTooLarge;
    }
    assembled.appendSlice(self.allocator, payload) catch return WebSocketError.OutOfMemory;
}

fn randomBytes(io: std.Io, dest: []u8) void {
    io.vtable.random(io.userdata, dest);
}

fn seedMaskState(io: std.Io) u64 {
    var bytes: [8]u8 = undefined;
    randomBytes(io, &bytes);
    var state: u64 = 0;
    for (bytes) |b| {
        state = (state << 8) | b;
    }
    return if (state == 0) 0x9e3779b97f4a7c15 else state;
}

fn timeoutFromMs(ms: u32) std.Io.Timeout {
    if (ms == 0) return .none;
    return .{ .duration = .{ .raw = std.Io.Duration.fromMilliseconds(@as(i64, @intCast(ms))), .clock = .awake } };
}

fn writeLen64(dest: []u8, len: usize) void {
    var value: u64 = @intCast(len);
    var i: usize = 8;
    while (i > 0) {
        i -= 1;
        dest[i] = @truncate(value & 0xFF);
        value >>= 8;
    }
}

fn verifyHandshake(response: []const u8, key_encoded: []const u8) WebSocketError!void {
    const first_line_end = std.mem.indexOf(u8, response, "\r\n") orelse
        return WebSocketError.HandshakeFailed;
    const status_line = response[0..first_line_end];
    if (!std.mem.startsWith(u8, status_line, "HTTP/1.1 101") and
        !std.mem.startsWith(u8, status_line, "HTTP/1.0 101"))
    {
        return WebSocketError.HandshakeFailed;
    }

    const upgrade = getHeaderValue(response, "Upgrade") orelse
        return WebSocketError.HandshakeFailed;
    if (!std.ascii.eqlIgnoreCase(upgrade, "websocket")) {
        return WebSocketError.HandshakeFailed;
    }

    const accept = getHeaderValue(response, "Sec-WebSocket-Accept") orelse
        return WebSocketError.HandshakeFailed;
    const expected = computeAcceptKey(key_encoded);
    if (!std.mem.eql(u8, accept, &expected)) {
        return WebSocketError.HandshakeFailed;
    }
}

fn getHeaderValue(headers: []const u8, name: []const u8) ?[]const u8 {
    var lines = std.mem.splitSequence(u8, headers, "\r\n");
    _ = lines.next(); // status line

    while (lines.next()) |line| {
        if (line.len == 0) break;
        const colon = std.mem.indexOfScalar(u8, line, ':') orelse continue;
        const header_name = std.mem.trimEnd(u8, line[0..colon], " ");
        if (!std.ascii.eqlIgnoreCase(header_name, name)) continue;
        return std.mem.trim(u8, line[colon + 1 ..], " ");
    }

    return null;
}

fn computeAcceptKey(key: []const u8) [28]u8 {
    const guid = "258EAFA5-E914-47DA-95CA-C5AB0DC85B11";
    var input: [60]u8 = undefined;
    @memcpy(input[0..key.len], key);
    @memcpy(input[key.len..][0..guid.len], guid);

    var sha1 = std.crypto.hash.Sha1.init(.{});
    sha1.update(input[0 .. key.len + guid.len]);
    var hash: [20]u8 = undefined;
    sha1.final(&hash);

    var result: [28]u8 = undefined;
    _ = std.base64.standard.Encoder.encode(&result, &hash);
    return result;
}

// ─── Tests ──────────────────────────────────────────────────────────────────

test "computeAcceptKey" {
    const key = "dGhlIHNhbXBsZSBub25jZQ==";
    const result = computeAcceptKey(key);
    try std.testing.expectEqualStrings("s3pPLMBiTxaQ9kYGzzhZRbK+xOo=", &result);
}
