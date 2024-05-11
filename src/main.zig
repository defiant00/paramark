const std = @import("std");
const Allocator = std.mem.Allocator;

const Parser = @import("Parser.zig");

const paramark_version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
const spec_version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len >= 3 and std.ascii.eqlIgnoreCase(args[1], "debug")) {
        for (args[2..]) |file| {
            try fileDebug(alloc, file);
        }
    } else if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "help")) {
        printUsage();
    } else if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "version")) {
        std.debug.print("(mark) {}\n spec  {}\n", .{ paramark_version, spec_version });
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn fileDebug(alloc: Allocator, path: []const u8) !void {
    std.debug.print("{s}\n", .{path});

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    const result = try Parser.parse(alloc, source);
    defer result.deinit();

    std.debug.print("\nResults:\n", .{});
    result.print();
}

fn printUsage() void {
    std.debug.print(
        \\Usage: pm [command]
        \\
        \\Commands:
        \\  debug [file]    Debug specified files
        \\
        \\  help            Print this help and exit
        \\  version         Print version and exit
        \\
    , .{});
}
