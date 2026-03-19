const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .cpu_model = .baseline },
    });
    const optimize = b.standardOptimizeOption(.{});

    const cdp_root = resolveCdpRoot(b);

    const sqlite_dir = b.path("third_party/sqlite/sqlite-autoconf-3510200");
    const sqlite3_c = b.path("third_party/sqlite/sqlite-autoconf-3510200/sqlite3.c");

    const cdp_mod = b.createModule(.{
        .root_source_file = b.path(cdp_root),
        .target = target,
        .optimize = optimize,
    });

    const hq_mod = b.createModule(.{
        .root_source_file = b.path("src/root.zig"),
        .target = target,
        .optimize = optimize,
    });
    hq_mod.addImport("cdp", cdp_mod);
    hq_mod.addIncludePath(sqlite_dir);

    const cli_test_mod = b.createModule(.{
        .root_source_file = b.path("cli_root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_test_mod.addImport("hq", hq_mod);
    cli_test_mod.addImport("cdp", cdp_mod);

    const cli_exe_mod = b.createModule(.{
        .root_source_file = b.path("cli_root.zig"),
        .target = target,
        .optimize = optimize,
    });
    cli_exe_mod.addImport("hq", hq_mod);
    cli_exe_mod.addImport("cdp", cdp_mod);

    const support_mod = b.createModule(.{
        .root_source_file = b.path("tests/support/urn__support__hq.zig"),
        .target = target,
        .optimize = optimize,
    });
    support_mod.addImport("hq", hq_mod);

    const fixture_harness_mod = b.createModule(.{
        .root_source_file = b.path("tests/support/fixture_harness.zig"),
        .target = target,
        .optimize = optimize,
    });
    fixture_harness_mod.addImport("hq", hq_mod);
    fixture_harness_mod.addImport("cdp", cdp_mod);

    const exe = b.addExecutable(.{
        .name = "hq",
        .root_module = cli_exe_mod,
    });

    exe.root_module.addIncludePath(sqlite_dir);
    exe.root_module.addCSourceFile(.{ .file = sqlite3_c, .flags = &[_][]const u8{} });
    exe.root_module.link_libc = true;
    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    if (b.args) |args| run_cmd.addArgs(args);
    const run_step = b.step("run", "Run hq");
    run_step.dependOn(&run_cmd.step);

    const unit_step = b.step("test-hq-unit", "Run HQ unit tests");
    const contract_step = b.step("test-hq-contract", "Run HQ contract tests");
    const integration_step = b.step("test-hq-integration", "Run HQ integration tests");
    const cli_step = b.step("test-hq-cli", "Run HQ CLI tests");

    addHqTestFile(b, unit_step, "tests/unit/urn__common__args.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, unit_step, "tests/unit/urn__common__paths.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);

    addHqTestFile(b, contract_step, "tests/contract/urn__batch__preflight.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, contract_step, "tests/contract/urn__chatgpt__conversation_json.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, contract_step, "tests/contract/urn__chatgpt__dispatch_prompt.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, contract_step, "tests/contract/urn__hq__exports.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, contract_step, "tests/contract/urn__queue__render_expected_payload.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);

    addHqTestFile(b, integration_step, "tests/integration/urn__batch__apply_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__batch__run_doctor_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__cdp__local_http_fixture_test.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__cdp__snapshot__fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__cdp__status__blocked_fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__cdp__send__fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__cdp__ui_get_worker_block_fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__queue__dispatch_fake.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__queue__enqueue_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__queue__layout_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, integration_step, "tests/integration/urn__queue__supervise_fake.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);

    addHqTestFile(b, cli_step, "tests/cli/urn__entrypoint__smoke.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, cli_step, "tests/cli/urn__manual_fixture__json.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
    addHqTestFile(b, cli_step, "tests/cli/urn__ui_get__manifest_json.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);

    const test_step = b.step("test-hq", "Run all HQ tests");
    test_step.dependOn(unit_step);
    test_step.dependOn(contract_step);
    test_step.dependOn(integration_step);
    test_step.dependOn(cli_step);
}

fn resolveCdpRoot(b: *std.Build) []const u8 {
    if (b.option([]const u8, "cdp-root", "Path to parts/chromedevtoolprotocol.zig/src/root.zig")) |override| {
        return override;
    }

    const candidates = [_][]const u8{
        "../chromedevtoolprotocol.zig/src/root.zig",
        "../../chromedevtoolprotocol.zig/src/root.zig",
        "../../cdp/chromedevtoolprotocol.zig/src/root.zig",
    };

    for (candidates) |candidate| {
        const file = std.fs.cwd().openFile(candidate, .{}) catch continue;
        file.close();
        return candidate;
    }

    std.debug.panic(
        "unable to locate chromedevtoolprotocol.zig; pass -Dcdp-root=<path> or place the repo in a supported layout",
        .{},
    );
}

fn addHqTestFile(
    b: *std.Build,
    suite_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hq_mod: *std.Build.Module,
    cdp_mod: *std.Build.Module,
    cli_mod: *std.Build.Module,
    support_mod: *std.Build.Module,
    fixture_harness_mod: *std.Build.Module,
    sqlite_dir: std.Build.LazyPath,
    sqlite3_c: std.Build.LazyPath,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("hq", hq_mod);
    test_mod.addImport("cdp", cdp_mod);
    test_mod.addImport("cli", cli_mod);
    test_mod.addImport("support", support_mod);
    test_mod.addImport("fixture_harness", fixture_harness_mod);

    const tests = b.addTest(.{ .root_module = test_mod });
    tests.root_module.addIncludePath(sqlite_dir);
    tests.root_module.addCSourceFile(.{ .file = sqlite3_c, .flags = &[_][]const u8{} });
    tests.root_module.link_libc = true;

    const run_tests = b.addRunArtifact(tests);
    suite_step.dependOn(&run_tests.step);
}
