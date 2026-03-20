const std = @import("std");
const cli = @import("cli");

test "cli entrypoint stays importable and exposes main" {
    try std.testing.expect(@hasDecl(cli, "main"));
}
