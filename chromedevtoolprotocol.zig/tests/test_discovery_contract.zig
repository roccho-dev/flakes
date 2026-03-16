const std = @import("std");
const cdp = @import("cdp");

test "parseBrowserEndpoint extracts websocket url and metadata" {
    const raw =
        \\{
        \\  "Browser": "Chrome/142.0.7444.59",
        \\  "Protocol-Version": "1.3",
        \\  "webSocketDebuggerUrl": "ws://127.0.0.1:9222/devtools/browser/abc123"
        \\}
    ;

    var endpoint = try cdp.parseBrowserEndpoint(std.testing.allocator, raw);
    defer endpoint.deinit(std.testing.allocator);

    try std.testing.expectEqualStrings(
        "ws://127.0.0.1:9222/devtools/browser/abc123",
        endpoint.web_socket_debugger_url,
    );
    try std.testing.expectEqualStrings("1.3", endpoint.protocol_version.?);
    try std.testing.expectEqualStrings("Chrome/142.0.7444.59", endpoint.product.?);
}

test "parseBrowserEndpoint rejects missing websocket url" {
    const raw = "{\"Browser\":\"Chrome/142\",\"Protocol-Version\":\"1.3\"}";
    try std.testing.expectError(
        error.NoWebSocketUrl,
        cdp.parseBrowserEndpoint(std.testing.allocator, raw),
    );
}
