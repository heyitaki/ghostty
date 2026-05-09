//! cmux fork: shared helper for resolving the Xcode `Developer/` path
//! used by RunSteps that must run under Xcode (metal, metallib,
//! xcodebuild). The host zig link step needs DEVELOPER_DIR pointed at
//! Command Line Tools so libSystem.tbd has arm64-macos targets — Xcode
//! 26's MacOSX26.4.sdk ships arm64e-only — but the Metal Toolchain stub
//! and xcodebuild both refuse to run unless DEVELOPER_DIR points at a
//! full Xcode install. These RunSteps therefore set DEVELOPER_DIR
//! per-step using the path returned here.
const std = @import("std");

/// Resolve the Xcode `Developer/` directory. Order:
///   1. `GHOSTTY_XCODE_DEVELOPER_DIR` env override (Xcode-beta, custom path)
///   2. `/usr/bin/xcode-select -p` invoked with DEVELOPER_DIR cleared so it
///      returns the persistent setting instead of inheriting whatever the
///      parent zig build was invoked with
///   3. Default: `/Applications/Xcode.app/Contents/Developer`
pub fn developerDir(b: *std.Build) []const u8 {
    const default = "/Applications/Xcode.app/Contents/Developer";

    if (b.graph.env_map.get("GHOSTTY_XCODE_DEVELOPER_DIR")) |v| {
        return b.dupe(v);
    }

    var empty_env = std.process.EnvMap.init(b.allocator);
    defer empty_env.deinit();

    const result = std.process.Child.run(.{
        .allocator = b.allocator,
        .argv = &.{ "/usr/bin/xcode-select", "-p" },
        .env_map = &empty_env,
    }) catch return default;
    defer b.allocator.free(result.stdout);
    defer b.allocator.free(result.stderr);

    if (result.term != .Exited or result.term.Exited != 0) {
        return default;
    }
    const trimmed = std.mem.trim(u8, result.stdout, " \n\r\t");
    if (trimmed.len == 0) return default;
    return b.dupe(trimmed);
}
