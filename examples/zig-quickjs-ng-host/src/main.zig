const std = @import("std");
const quickjs = @import("quickjs");

pub fn main() !void {
    const rt = try quickjs.Runtime.init();
    defer rt.deinit();

    const ctx = try quickjs.Context.init(rt);
    defer ctx.deinit();

    const result = ctx.eval(
        \\(function() { return 40 + 2; })()
    , "<example>", .{});
    defer result.deinit(ctx);

    if (result.isException()) {
        const exc = ctx.getException();
        defer exc.deinit(ctx);
        if (exc.toCString(ctx)) |msg| {
            defer ctx.freeCString(msg);
            std.debug.print("exception: {s}\n", .{msg});
        } else {
            std.debug.print("exception: <unknown>\n", .{});
        }
        return error.JavaScriptException;
    }

    const value = try result.toInt32(ctx);
    if (value != 42) return error.UnexpectedResult;
}
