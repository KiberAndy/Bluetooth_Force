const std = @import("std");

pub fn build(b: *std.Build) void {
    const optimize = b.standardOptimizeOption(.{});
    const target = b.standardTargetOptions(.{});

    const libs = [_][]const u8{ "user32", "winmm" };

    const exe = b.addExecutable(.{
        .name = "bluetooth_force",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });

    for (libs) |lib| exe.root_module.linkSystemLibrary(lib, .{});

    // Console in Debug (for diagnostics), Windows in release (background)
    exe.subsystem = if (optimize == .Debug) .console else .windows;

    b.installArtifact(exe);

    // Install ToothTray.exe alongside bluetooth_force.exe
    b.installFile("ToothTray.exe", "bin/ToothTray.exe");

    // Test target
    const test_exe = b.addTest(.{
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
        }),
    });
    for (libs) |lib| test_exe.root_module.linkSystemLibrary(lib, .{});
    const run_test = b.addRunArtifact(test_exe);
    run_test.has_side_effects = true;

    const test_step = b.step("test", "Run unit tests");
    test_step.dependOn(&run_test.step);
}
