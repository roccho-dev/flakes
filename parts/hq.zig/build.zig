const std = @import("std");

const HqSuite = enum {
    unit,
    contract,
    cli,
    integration,
    all,
};

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{
        .default_target = .{ .cpu_model = .baseline },
    });
    const optimize = b.standardOptimizeOption(.{});
    const selected_suite = resolveSelectedSuite(b);
    const selected_integration_case = b.option([]const u8, "hq-integration-case", "Run only one HQ integration test source file");

    const sqlite_dir = b.path("third_party/sqlite/sqlite-autoconf-3510200");
    const sqlite3_c = b.path("third_party/sqlite/sqlite-autoconf-3510200/sqlite3.c");

    const run_step = b.step("run", "Run hq");
    const unit_step = b.step("test-hq-unit", "Run HQ unit tests");
    const contract_step = b.step("test-hq-contract", "Run HQ contract tests");
    const integration_step = b.step("test-hq-integration", "Run HQ integration tests");
    const cli_step = b.step("test-hq-cli", "Run HQ CLI tests");
    const test_step = b.step("test-hq", "Run all HQ tests");

    if (suiteEnabled(selected_suite, .unit)) {
        const unit_hq_mod = createUnitHqModule(b, target, optimize);
        addHqUnitTestFile(b, unit_step, "tests/unit/urn__common__args.zig", target, optimize, unit_hq_mod, sqlite_dir);
        addHqUnitTestFile(b, unit_step, "tests/unit/urn__common__paths.zig", target, optimize, unit_hq_mod, sqlite_dir);
        test_step.dependOn(unit_step);
    }

    if (selected_suite != .unit) {
        const cdp_root = resolveCdpRoot(b);
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

        if (suiteEnabled(selected_suite, .contract)) {
            const support_mod = b.createModule(.{
                .root_source_file = b.path("tests/support/urn__support__hq.zig"),
                .target = target,
                .optimize = optimize,
            });
            support_mod.addImport("hq", hq_mod);

            addHqCoreTestFile(b, contract_step, "tests/contract/urn__batch__preflight.zig", target, optimize, hq_mod, sqlite_dir, .support, support_mod, null);
            addHqCoreTestFile(b, contract_step, "tests/contract/urn__chatgpt__conversation_json.zig", target, optimize, hq_mod, sqlite_dir, .none, null, null);
            addHqCoreTestFile(b, contract_step, "tests/contract/urn__chatgpt__dispatch_prompt.zig", target, optimize, hq_mod, sqlite_dir, .none, null, null);
            addHqCoreTestFile(b, contract_step, "tests/contract/urn__hq__exports.zig", target, optimize, hq_mod, sqlite_dir, .cdp, null, cdp_mod);
            addHqCoreTestFile(b, contract_step, "tests/contract/urn__queue__render_expected_payload.zig", target, optimize, hq_mod, sqlite_dir, .none, null, null);
            test_step.dependOn(contract_step);
        }

        if (suiteEnabled(selected_suite, .cli) or suiteEnabled(selected_suite, .integration)) {
            const cli_test_mod = b.createModule(.{
                .root_source_file = b.path("cli_root.zig"),
                .target = target,
                .optimize = optimize,
            });
            cli_test_mod.addImport("hq", hq_mod);
            cli_test_mod.addImport("cdp", cdp_mod);

            if (suiteEnabled(selected_suite, .cli)) {
                const cli_exe_mod = b.createModule(.{
                    .root_source_file = b.path("cli_root.zig"),
                    .target = target,
                    .optimize = optimize,
                });
                cli_exe_mod.addImport("hq", hq_mod);
                cli_exe_mod.addImport("cdp", cdp_mod);

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
                run_step.dependOn(&run_cmd.step);

                addCliEntrypointTestFile(b, cli_step, "tests/cli/urn__entrypoint__smoke.zig", target, optimize, cli_test_mod);
                addHqCoreTestFile(b, cli_step, "tests/cli/urn__manual_fixture__json.zig", target, optimize, hq_mod, sqlite_dir, .none, null, null);
                addHqCliTestFile(b, cli_step, "tests/cli/urn__ui_get__manifest_json.zig", target, optimize, hq_mod, cli_test_mod, sqlite_dir);
                test_step.dependOn(cli_step);
            }

            if (suiteEnabled(selected_suite, .integration)) {
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
                fixture_harness_mod.addImport("support", support_mod);

                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__batch__apply_sqlite.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__batch__apply_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__batch__run_doctor_sqlite.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__batch__run_doctor_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__cdp__local_http_fixture_test.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__cdp__local_http_fixture_test.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__cdp__snapshot__fixture.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__cdp__snapshot__fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__cdp__status__blocked_fixture.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__cdp__status__blocked_fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__cdp__send__fixture.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__cdp__send__fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__cdp__ui_get_worker_block_fixture.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__cdp__ui_get_worker_block_fixture.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__queue__dispatch_fake.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__queue__dispatch_fake.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__queue__enqueue_sqlite.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__queue__enqueue_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__queue__layout_sqlite.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__queue__layout_sqlite.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                                if (integrationCaseEnabled(selected_integration_case, "tests/integration/urn__queue__supervise_fake.zig")) addHqIntegrationCase(b, integration_step, "tests/integration/urn__queue__supervise_fake.zig", target, optimize, hq_mod, cdp_mod, cli_test_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
                test_step.dependOn(integration_step);
            }
        }
    }
}

fn resolveSelectedSuite(b: *std.Build) HqSuite {
    const raw = b.option([]const u8, "hq-suite", "Build only one HQ suite graph: unit|contract|cli|integration|all") orelse "all";
    return std.meta.stringToEnum(HqSuite, raw) orelse std.debug.panic(
        "invalid -Dhq-suite={s}; expected unit|contract|cli|integration|all",
        .{raw},
    );
}

fn suiteEnabled(selected: HqSuite, candidate: HqSuite) bool {
    return selected == .all or selected == candidate;
}

fn integrationCaseEnabled(selected_case: ?[]const u8, root_source_file: []const u8) bool {
    return if (selected_case) |value| std.mem.eql(u8, value, root_source_file) else true;
}

fn createUnitHqModule(
    b: *std.Build,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
) *std.Build.Module {
    const generated = b.addWriteFiles();
    const unit_hq_root = generated.add("generated/hq_unit_root.zig",
        \\pub const common = @import("common");
        \\
    );

    const common_mod = b.createModule(.{
        .root_source_file = b.path("src/hq/common.zig"),
        .target = target,
        .optimize = optimize,
    });

    const unit_hq_mod = b.createModule(.{
        .root_source_file = unit_hq_root,
        .target = target,
        .optimize = optimize,
    });
    unit_hq_mod.addImport("common", common_mod);
    return unit_hq_mod;
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
        const file = std.Io.Dir.cwd().openFile(b.graph.io, candidate, .{}) catch continue;
        file.close(b.graph.io);
        return candidate;
    }

    std.debug.panic(
        "unable to locate chromedevtoolprotocol.zig; pass -Dcdp-root=<path> or place the repo in a supported layout",
        .{},
    );
}

fn addHqUnitTestFile(
    b: *std.Build,
    suite_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hq_mod: *std.Build.Module,
    sqlite_dir: std.Build.LazyPath,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("hq", hq_mod);
    test_mod.addIncludePath(sqlite_dir);

    const tests = b.addTest(.{ .root_module = test_mod });
    tests.root_module.addIncludePath(sqlite_dir);

    const run_tests = b.addRunArtifact(tests);
    suite_step.dependOn(&run_tests.step);
}

const ExtraImport = enum { none, support, cdp };

fn addHqCoreTestFile(
    b: *std.Build,
    suite_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hq_mod: *std.Build.Module,
    sqlite_dir: std.Build.LazyPath,
    extra: ExtraImport,
    support_mod: ?*std.Build.Module,
    cdp_mod: ?*std.Build.Module,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("hq", hq_mod);
    test_mod.addIncludePath(sqlite_dir);

    switch (extra) {
        .none => {},
        .support => test_mod.addImport("support", support_mod.?),
        .cdp => test_mod.addImport("cdp", cdp_mod.?),
    }

    const tests = b.addTest(.{ .root_module = test_mod });
    tests.root_module.addIncludePath(sqlite_dir);

    const run_tests = b.addRunArtifact(tests);
    suite_step.dependOn(&run_tests.step);
}

fn addCliEntrypointTestFile(
    b: *std.Build,
    suite_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    cli_mod: *std.Build.Module,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("cli", cli_mod);

    const tests = b.addTest(.{ .root_module = test_mod });
    const run_tests = b.addRunArtifact(tests);
    suite_step.dependOn(&run_tests.step);
}

fn addHqCliTestFile(
    b: *std.Build,
    suite_step: *std.Build.Step,
    root_source_file: []const u8,
    target: std.Build.ResolvedTarget,
    optimize: std.builtin.OptimizeMode,
    hq_mod: *std.Build.Module,
    cli_mod: *std.Build.Module,
    sqlite_dir: std.Build.LazyPath,
) void {
    const test_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    test_mod.addImport("hq", hq_mod);
    test_mod.addImport("cli", cli_mod);
    test_mod.addIncludePath(sqlite_dir);

    const tests = b.addTest(.{ .root_module = test_mod });
    tests.root_module.addIncludePath(sqlite_dir);

    const run_tests = b.addRunArtifact(tests);
    suite_step.dependOn(&run_tests.step);
}

fn integrationCaseUsesExecutable(root_source_file: []const u8) bool {
    _ = root_source_file;
    return true;
}

fn addHqIntegrationCase(
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
    if (integrationCaseUsesExecutable(root_source_file)) {
        addHqIntegrationExeFile(b, suite_step, root_source_file, target, optimize, hq_mod, cdp_mod, cli_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
        return;
    }
    addHqTestFile(b, suite_step, root_source_file, target, optimize, hq_mod, cdp_mod, cli_mod, support_mod, fixture_harness_mod, sqlite_dir, sqlite3_c);
}

fn addHqIntegrationExeFile(
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
    const exe_mod = b.createModule(.{
        .root_source_file = b.path(root_source_file),
        .target = target,
        .optimize = optimize,
    });
    exe_mod.addImport("hq", hq_mod);
    exe_mod.addImport("cdp", cdp_mod);
    exe_mod.addImport("cli", cli_mod);
    exe_mod.addImport("support", support_mod);
    exe_mod.addImport("fixture_harness", fixture_harness_mod);

    const exe = b.addExecutable(.{
        .name = b.fmt("hq-int-{s}", .{std.fs.path.stem(root_source_file)}),
        .root_module = exe_mod,
    });
    exe.root_module.addIncludePath(sqlite_dir);
    exe.root_module.addCSourceFile(.{ .file = sqlite3_c, .flags = &[_][]const u8{} });
    exe.root_module.link_libc = true;

    const run_exe = b.addRunArtifact(exe);
    suite_step.dependOn(&run_exe.step);
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
