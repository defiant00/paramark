const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

const Header = @import("Header.zig");
const Lexer = @import("Lexer.zig");
const Result = @import("Result.zig");
const Token = Lexer.Token;

const Parser = @This();

allocator: Allocator,
lexer: Lexer,
current: Token,
previous: Token,
result: Result,

fn errorAt(self: Parser, token: Token, message: []const u8) !void {
    const range = try self.lexer.absoluteRange(token);
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

fn parseContent(self: *Parser) !void {
    if (try self.match(.content)) {
        try self.result.appendContent(self.previous.value);
    } else if (try self.match(.literal_content)) {
        try self.result.appendLiteralContent(self.previous.value, self.previous.depth);
    } else if (try self.match(.comment)) {
        try self.result.appendComment(self.previous.value, self.previous.depth);
    } else if (try self.match(.open) or try self.match(.close)) {
        try self.parseTag();
    } else {
        try self.errorAt(self.current, "invalid token in content");
    }
}

fn parseFile(self: *Parser) !void {
    while (!try self.match(.eof)) {
        try self.parseContent();
    }
}

fn parseTag(self: *Parser) !void {
    const start_type = self.previous.type;

    if (try self.match(.literal) or try self.match(.string)) {
        var tag = Result.Tag.init(self.allocator, self.previous.value, self.previous.type == .string);
        while (!try self.match(.eof)) {
            if (try self.match(.literal) or try self.match(.string)) {
                try self.parseProperty(&tag);
            } else if (try self.match(.open) and start_type == .open) {
                try self.result.appendOpenTag(tag);
                break;
            } else if (try self.match(.close)) {
                if (start_type == .close) {
                    try self.result.appendCloseTag(tag);
                } else {
                    try self.result.appendTag(tag);
                }
                break;
            } else {
                try self.errorAt(self.current, "invalid token in tag");
            }
        }
    }
}

fn parseProperty(self: *Parser, tag: *Result.Tag) !void {
    const name = .{
        .value = self.previous.value,
        .is_string = self.previous.type == .string,
    };
    var value: ?Result.Tag.Value = null;
    if (try self.match(.assign)) {
        if (try self.match(.literal) or try self.match(.string)) {
            value = .{
                .value = self.previous.value,
                .is_string = self.previous.type == .string,
            };
        } else {
            try self.errorAt(self.current, "invalid token in tag");
        }
    }
    try tag.properties.append(.{ .name = name, .value = value });
}

pub fn parse(alloc: Allocator, source: []const u8) !Result {
    var parser = Parser{
        .allocator = alloc,
        .lexer = try Lexer.init(source),
        .current = undefined,
        .previous = undefined,
        .result = Result.init(alloc),
    };

    try parser.advance();
    try parser.parseFile();

    parser.result.header = parser.lexer.header;
    return parser.result;
}
