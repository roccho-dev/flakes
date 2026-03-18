const std = @import("std");
const cli = @import("cli");
const hq = @import("hq");

test "ui get writes versioned MANIFEST.json atomically" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const out_dir = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/ui_get_manifest",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(out_dir);
    try hq.common.ensureDirPath(std.testing.io, out_dir);

    const patch_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/PATCH.diff", .{out_dir});
    defer std.testing.allocator.free(patch_path);
    const report_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/TEST_REPORT_worker", .{out_dir});
    defer std.testing.allocator.free(report_path);
    const checklist_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/CHECKLIST", .{out_dir});
    defer std.testing.allocator.free(checklist_path);
    const block_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/WORKER_BLOCK", .{out_dir});
    defer std.testing.allocator.free(block_path);
    const meta_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/ui_get.json", .{out_dir});
    defer std.testing.allocator.free(meta_path);

    try hq.common.writeFile(std.testing.io, patch_path, "diff --git a/a b/a\n");
    try hq.common.writeFile(std.testing.io, report_path, "ok\n");
    try hq.common.writeFile(std.testing.io, checklist_path, "YES\n");
    try hq.common.writeFile(std.testing.io, block_path, "BEGIN_WORKER_BLOCK\n...\nEND_WORKER_BLOCK\n");
    try hq.common.writeFile(std.testing.io, meta_path, "{}\n");

    const manifest_path = try cli.writeUiGetManifestAtomic(std.testing.io, std.testing.allocator, out_dir, .{
        .manifest_version = 1,
        .ok = true,
        .url = "https://chatgpt.com/c/fixture",
        .model_confirmation = "MODEL_CONFIRMATION: Pro=YES | MODEL=GPT-5.4 Pro",
        .model_pro = "YES",
        .model_label = "GPT-5.4 Pro",
        .out_dir = out_dir,
        .patch = patch_path,
        .test_report = report_path,
        .checklist = checklist_path,
        .worker_block = block_path,
        .meta = meta_path,
    });
    defer std.testing.allocator.free(manifest_path);

    try std.testing.expect(hq.common.exists(std.testing.io, manifest_path));
    const tmp_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/MANIFEST.json.tmp", .{out_dir});
    defer std.testing.allocator.free(tmp_path);
    try std.testing.expect(!hq.common.exists(std.testing.io, tmp_path));

    const raw = try hq.common.readFileAlloc(std.testing.io, std.testing.allocator, manifest_path, 1024 * 1024);
    defer std.testing.allocator.free(raw);

    const parsed = try std.json.parseFromSlice(std.json.Value, std.testing.allocator, raw, .{});
    defer parsed.deinit();

    const root = parsed.value;
    try std.testing.expectEqualStrings("https://chatgpt.com/c/fixture", root.object.get("url").?.string);
    try std.testing.expectEqual(@as(i64, 1), root.object.get("manifest_version").?.integer);
    try std.testing.expect(root.object.get("ok").?.bool);
    try std.testing.expectEqualStrings(out_dir, root.object.get("outDir").?.string);
    try std.testing.expectEqualStrings(patch_path, root.object.get("patch").?.string);
    try std.testing.expectEqualStrings(report_path, root.object.get("test_report").?.string);
    try std.testing.expectEqualStrings(checklist_path, root.object.get("checklist").?.string);
    try std.testing.expectEqualStrings(block_path, root.object.get("worker_block").?.string);
    try std.testing.expectEqualStrings(meta_path, root.object.get("meta").?.string);
}

test "ui get requires outDir to be empty" {
    var tmp = std.testing.tmpDir(.{});
    defer tmp.cleanup();

    const out_dir = try std.fmt.allocPrint(
        std.testing.allocator,
        ".zig-cache/tmp/{s}/ui_get_outdir_not_empty",
        .{tmp.sub_path},
    );
    defer std.testing.allocator.free(out_dir);

    try hq.common.ensureDirPath(std.testing.io, out_dir);
    const dummy_path = try std.fmt.allocPrint(std.testing.allocator, "{s}/dummy.txt", .{out_dir});
    defer std.testing.allocator.free(dummy_path);
    try hq.common.writeFile(std.testing.io, dummy_path, "x\n");

    try std.testing.expectError(error.OutDirNotEmpty, cli.ensureUiGetOutDirEmpty(std.testing.io, out_dir));
}
