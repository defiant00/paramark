const std = @import("std");

const paramark_version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };
const spec_version = std.SemanticVersion{ .major = 0, .minor = 1, .patch = 0 };

pub fn main() !void {
    var gpa = std.heap.GeneralPurposeAllocator(.{}){};
    const alloc = gpa.allocator();

    const args = try std.process.argsAlloc(alloc);
    defer std.process.argsFree(alloc, args);

    if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "help")) {
        printUsage();
    } else if (args.len == 2 and std.ascii.eqlIgnoreCase(args[1], "version")) {
        std.debug.print("(mark) {}\n spec  {}\n", .{ paramark_version, spec_version });
    } else {
        printUsage();
        return error.InvalidCommand;
    }
}

fn printUsage() void {
    std.debug.print(
        \\Usage: pm [command]
        \\
        \\Commands:
        \\  ?
        \\
        \\  help        Print this help and exit
        \\  version     Print version and exit
        \\
    , .{});
}
