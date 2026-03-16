const std = @import("std");

pub const HttpResponse = struct {
    status_code: u16,
    body: []const u8,
    allocator: std.mem.Allocator,

    pub fn deinit(self: *HttpResponse) void {
        self.allocator.free(self.body);
    }
};

pub const BrowserEndpoint = struct {
    web_socket_debugger_url: []const u8,
    protocol_version: ?[]const u8 = null,
    product: ?[]const u8 = null,

    pub fn deinit(self: *BrowserEndpoint, allocator: std.mem.Allocator) void {
        allocator.free(self.web_socket_debugger_url);
        if (self.protocol_version) |value| allocator.free(value);
        if (self.product) |value| allocator.free(value);
    }
};

pub fn get(allocator: std.mem.Allocator, io: std.Io, host: []const u8, port: u16, path: []const u8) !HttpResponse {
    const address = std.Io.net.IpAddress.parse(host, port) catch return error.ConnectionFailed;
    const stream = std.Io.net.IpAddress.connect(address, io, .{
        .mode = .stream,
        .protocol = .tcp,
    }) catch return error.ConnectionFailed;
    defer stream.close(io);

    const request = try std.fmt.allocPrint(
        allocator,
        "GET {s} HTTP/1.1\r\nHost: {s}:{}\r\nConnection: close\r\n\r\n",
        .{ path, host, port },
    );
    defer allocator.free(request);

    var write_buf: [4096]u8 = undefined;
    var writer = stream.writer(io, &write_buf);
    writer.interface.writeAll(request) catch return error.SendFailed;
    writer.interface.flush() catch return error.SendFailed;

    var response_buf: std.ArrayList(u8) = .empty;
    errdefer response_buf.deinit(allocator);

    var read_buf: [4096]u8 = undefined;
    var reader = stream.reader(io, &read_buf);
    const max_response_size: usize = 64 * 1024;

    while (response_buf.items.len < max_response_size) {
        const chunk = reader.interface.peekGreedy(1) catch break;
        if (chunk.len == 0) break;
        try response_buf.appendSlice(allocator, chunk);
        reader.interface.toss(chunk.len);

        if (std.mem.indexOf(u8, response_buf.items, "\r\n\r\n")) |header_end| {
            const headers = response_buf.items[0..header_end];
            if (std.mem.indexOf(u8, headers, "Content-Length:")) |cl_start| {
                const cl_line_start = cl_start + "Content-Length:".len;
                if (std.mem.indexOf(u8, headers[cl_line_start..], "\r\n")) |cl_line_end| {
                    const cl_str = std.mem.trim(u8, headers[cl_line_start..][0..cl_line_end], " ");
                    if (std.fmt.parseInt(usize, cl_str, 10)) |content_length| {
                        const body_start = header_end + 4;
                        if (response_buf.items.len >= body_start + content_length) break;
                    } else |_| {}
                }
            }
        }
    }

    const response_data = response_buf.items;
    if (response_data.len == 0) return error.InvalidResponse;

    const header_end = std.mem.indexOf(u8, response_data, "\r\n\r\n") orelse return error.InvalidResponse;
    const first_line_end = std.mem.indexOf(u8, response_data, "\r\n") orelse return error.InvalidResponse;
    const status_line = response_data[0..first_line_end];
    const first_space = std.mem.indexOf(u8, status_line, " ") orelse return error.InvalidResponse;
    const after_space = status_line[first_space + 1 ..];
    const second_space = std.mem.indexOf(u8, after_space, " ") orelse after_space.len;
    const status_str = after_space[0..second_space];
    const status_code = std.fmt.parseInt(u16, status_str, 10) catch return error.InvalidResponse;
    const body_start = header_end + 4;
    const body = try allocator.dupe(u8, response_data[body_start..]);
    response_buf.deinit(allocator);

    return .{
        .status_code = status_code,
        .body = body,
        .allocator = allocator,
    };
}

pub fn parseBrowserEndpoint(allocator: std.mem.Allocator, json_body: []const u8) !BrowserEndpoint {
    const parsed = std.json.parseFromSlice(std.json.Value, allocator, json_body, .{}) catch
        return error.InvalidJson;
    defer parsed.deinit();

    const object = switch (parsed.value) {
        .object => |obj| obj,
        else => return error.InvalidJson,
    };

    const ws_value = object.get("webSocketDebuggerUrl") orelse return error.NoWebSocketUrl;
    if (ws_value != .string) return error.InvalidJson;

    return .{
        .web_socket_debugger_url = try allocator.dupe(u8, ws_value.string),
        .protocol_version = if (object.get("Protocol-Version")) |v|
            if (v == .string) try allocator.dupe(u8, v.string) else null
        else
            null,
        .product = if (object.get("Browser")) |v|
            if (v == .string) try allocator.dupe(u8, v.string) else null
        else
            null,
    };
}

pub fn getChromeWsUrlAtHost(
    allocator: std.mem.Allocator,
    io: std.Io,
    host: []const u8,
    port: u16,
) ![]const u8 {
    var response = try get(allocator, io, host, port, "/json/version");
    defer response.deinit();

    if (response.status_code != 200) return error.ChromeNotResponding;

    var endpoint = try parseBrowserEndpoint(allocator, response.body);
    defer endpoint.deinit(allocator);
    return allocator.dupe(u8, endpoint.web_socket_debugger_url);
}

pub fn getChromeWsUrl(allocator: std.mem.Allocator, io: std.Io, port: u16) ![]const u8 {
    return getChromeWsUrlAtHost(allocator, io, "127.0.0.1", port);
}

pub fn waitForChromeWsUrlAtHost(
    allocator: std.mem.Allocator,
    io: std.Io,
    host: []const u8,
    port: u16,
    timeout_ms: u32,
) ![]const u8 {
    if (port == 0) return error.MissingPort;

    var waited_ms: u32 = 0;
    while (waited_ms < timeout_ms) : (waited_ms += 200) {
        if (getChromeWsUrlAtHost(allocator, io, host, port)) |ws_url| {
            return ws_url;
        } else |_| {
            try std.Io.sleep(io, std.Io.Duration.fromMilliseconds(200), .awake);
        }
    }
    return error.StartupTimeout;
}

pub fn waitForChromeWsUrl(
    allocator: std.mem.Allocator,
    io: std.Io,
    port: u16,
    timeout_ms: u32,
) ![]const u8 {
    return waitForChromeWsUrlAtHost(allocator, io, "127.0.0.1", port, timeout_ms);
}
