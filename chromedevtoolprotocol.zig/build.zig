const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const cdp_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });

    const test_files = [_][]const u8{
        "tests/test_discovery_contract.zig",
        "tests/test_launch_contract.zig",
        "tests/test_protocol_contract.zig",
    };

    const test_step = b.step("test", "Run chromedevtoolprotocol contract tests");
    for (test_files) |test_file| {
        const test_mod = b.createModule(.{
            .root_source_file = b.path(test_file),
            .target = target,
            .optimize = optimize,
        });
        test_mod.addImport("cdp", cdp_mod);

        const t = b.addTest(.{ .root_module = test_mod });
        const run_t = b.addRunArtifact(t);
        test_step.dependOn(&run_t.step);
    }
}
