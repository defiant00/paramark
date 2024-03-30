const std = @import("std");
const Allocator = std.mem.Allocator;

const Lexer = @import("Lexer.zig");
const Token = Lexer.Token;

const Result = struct {
    buffer: std.ArrayList(u8),

    pub fn init(alloc: Allocator) Result {
        return .{
            .buffer = std.ArrayList(u8).init(alloc),
        };
    }

    pub fn deinit(self: Result) void {
        self.buffer.deinit();
    }

    pub fn print(self: Result) void {
        std.debug.print("buffer:\n{s}", .{self.buffer.items});
    }
};

const Parser = @This();

lexer: Lexer,
current: Token,
previous: Token,
result: Result,

fn errorAt(self: Parser, token: Token, message: []const u8) !void {
    const range = self.lexer.absoluteRange(token);
    if (token.type == .eof) {
        std.debug.print("[{d}, {d}]-[{d}, {d}] at end: {s}\n", .{
            range.start_line + 1,
            range.start_column + 1,
            range.end_line + 1,
            range.end_column + 1,
            message,
        });
    } else {
        std.debug.print("[{d}, {d}]-[{d}, {d}] at '{s}': {s}\n", .{
            range.start_line + 1,
            range.start_column + 1,
            range.end_line + 1,
            range.end_column + 1,
            token.value,
            message,
        });
    }
    return error.Syntax;
}

fn advance(self: *Parser) !void {
    self.previous = self.current;

    while (true) {
        self.current = try self.lexer.lexToken();

        // debug
        std.debug.print("{}:{} '{s}'\n", .{ self.current.type, self.current.depth, self.current.value });

        if (self.current.type != .comment and self.current.type != .error_) break;
    }
}

fn check(self: Parser, expected: Token.Type) bool {
    return self.current.type == expected;
}

fn match(self: *Parser, expected: Token.Type) !bool {
    if (!self.check(expected)) return false;
    try self.advance();
    return true;
}

fn consume(self: *Parser, expected: Token.Type, message: []const u8) !void {
    if (!self.check(expected)) errorAt(self.current, message);
    try self.advance();
}

pub fn parse(alloc: Allocator, source: []const u8) !Result {
    var parser = Parser{
        .lexer = try Lexer.init(source),
        .current = undefined,
        .previous = undefined,
        .result = Result.init(alloc),
    };

    try parser.advance();
    while (!try parser.match(.eof)) {
        try parser.advance();
    }

    return parser.result;
}
