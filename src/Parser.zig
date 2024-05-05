const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

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

        if (self.current.type != .error_) break;
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

fn append(self: *Parser, val: []const u8) !void {
    try self.result.buffer.appendSlice(val);
}

fn appendUnescapeContent(self: *Parser, val: []const u8) !void {
    var i: usize = 0;
    while (i < val.len) {
        const size = try unicode.utf8ByteSequenceLength(val[i]);
        try self.result.buffer.appendSlice(val[i .. i + size]);
        const c = try unicode.utf8Decode(val[i .. i + size]);
        if (c == self.lexer.open_char or c == self.lexer.close_char) {
            // since the next character should always be the same, use the same size
            i += size;
        }
        i += size;
    }
}

fn parseContent(self: *Parser) !void {
    if (try self.match(.content)) {
        try self.appendUnescapeContent(self.previous.value);
    } else if (try self.match(.literal_content)) {
        try self.append(self.previous.value);
    } else if (try self.match(.comment)) {
        // TODO comments
    } else {
        // TODO tags
        try self.advance();
    }
}

fn parseFile(self: *Parser) !void {
    while (!try self.match(.eof)) {
        try self.parseContent();
    }
}

pub fn parse(alloc: Allocator, source: []const u8) !Result {
    var parser = Parser{
        .lexer = try Lexer.init(source),
        .current = undefined,
        .previous = undefined,
        .result = Result.init(alloc),
    };

    try parser.advance();
    try parser.parseFile();

    return parser.result;
}
