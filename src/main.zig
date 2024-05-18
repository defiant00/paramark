const std = @import("std");
const Allocator = std.mem.Allocator;

const Parser = @import("Parser.zig");
const ToXml = @import("ToXml.zig");

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
    } else if (args.len >= 4 and std.ascii.eqlIgnoreCase(args[1], "to") and std.ascii.eqlIgnoreCase(args[2], "xml")) {
        for (args[3..]) |file| {
            try fileToXml(alloc, file);
        }
    } else if (args.len >= 4 and std.ascii.eqlIgnoreCase(args[1], "update")) {
        for (args[3..]) |file| {
            try fileUpdate(alloc, args[2], file);
        }
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

fn fileToXml(alloc: Allocator, path: []const u8) !void {
    std.debug.print("{s}\n", .{path});

    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    const result = try Parser.parse(alloc, source);
    defer result.deinit();

    const strings = [_][]const u8{ path, ".xml" };
    const out_path = try std.mem.concat(alloc, u8, &strings);
    defer alloc.free(out_path);

    var out_file = try std.fs.cwd().createFile(out_path, .{});
    defer out_file.close();

    var buffered_writer = std.io.bufferedWriter(out_file.writer());

    try ToXml.convert(result, buffered_writer.writer().any());
    try buffered_writer.flush();
}

fn fileUpdate(alloc: Allocator, header: []const u8, path: []const u8) !void {
    std.debug.print("{s}\n", .{path});
    std.debug.print("  header: `{s}`\n", .{header});

    var file = try std.fs.cwd().openFile(path, .{});

    const source = try file.readToEndAlloc(alloc, std.math.maxInt(usize));
    defer alloc.free(source);

    file.close();

    const result = try Parser.parse(alloc, source);
    defer result.deinit();

    file = try std.fs.cwd().createFile(path, .{});
    defer file.close();

    var buffered_writer = std.io.bufferedWriter(file.writer());

    // TODO update and write out file
    try buffered_writer.writer().writeAll("updated to ");
    try buffered_writer.writer().writeAll(header);
    try buffered_writer.flush();
}

fn printUsage() void {
    std.debug.print(
        \\Usage: pm [command]
        \\
        \\Commands:
        \\  debug [files]              Debug files
        \\  update [header] [files]    Update files to the specified header
        \\
        \\  to xml [files]             Convert files to XML
        \\
        \\  help                       Print this help and exit
        \\  version                    Print version and exit
        \\
    , .{});
}
