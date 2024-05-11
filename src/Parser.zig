const std = @import("std");
const Allocator = std.mem.Allocator;
const unicode = std.unicode;

const Lexer = @import("Lexer.zig");
const Token = Lexer.Token;

const Result = struct {
    const Tag = struct {
        const Property = struct {
            name: []const u8,
            value: ?[]const u8,
        };

        name: []const u8,
        properties: std.ArrayList(Property),

        pub fn init(alloc: Allocator, name: []const u8) Tag {
            return .{
                .name = name,
                .properties = std.ArrayList(Property).init(alloc),
            };
        }

        pub fn deinit(self: Tag) void {
            self.properties.deinit();
        }
    };

    const DepthVal = struct {
        depth: u8,
        value: []const u8,
    };

    const Item = union(enum) {
        content: []const u8,
        literal_content: DepthVal,
        open_tag: Tag,
        close_tag: Tag,
        tag: Tag,
        comment: DepthVal,

        fn print(self: Item) void {
            switch (self) {
                .content => std.debug.print("content: \"{s}\"\n", .{self.content}),
                .literal_content => std.debug.print("literal content ({}): \"{s}\"\n", .{
                    self.literal_content.depth,
                    self.literal_content.value,
                }),
                .open_tag, .close_tag, .tag => {
                    std.debug.print("{}\n", .{self});
                    // TODO print out properties
                },
                .comment => std.debug.print("comment ({}): \"{s}\"\n", .{
                    self.comment.depth,
                    self.comment.value,
                }),
            }
        }
    };

    items: std.ArrayList(Item),

    pub fn init(alloc: Allocator) Result {
        return .{
            .items = std.ArrayList(Item).init(alloc),
        };
    }

    pub fn deinit(self: Result) void {
        for (self.items.items) |item| {
            switch (item) {
                .open_tag => item.open_tag.deinit(),
                .close_tag => item.close_tag.deinit(),
                .tag => item.tag.deinit(),
                else => {},
            }
        }
        self.items.deinit();
    }

    pub fn print(self: Result) void {
        for (self.items.items) |i| {
            i.print();
        }
    }

    fn appendComment(self: *Result, value: []const u8, depth: u8) !void {
        try self.items.append(.{ .comment = .{
            .depth = depth,
            .value = value,
        } });
    }

    fn appendContent(self: *Result, value: []const u8) !void {
        try self.items.append(.{ .content = value });
    }

    fn appendLiteralContent(self: *Result, value: []const u8, depth: u8) !void {
        try self.items.append(.{ .literal_content = .{
            .depth = depth,
            .value = value,
        } });
    }

    fn appendOpenTag(self: *Result, tag: Tag) !void {
        try self.items.append(.{ .open_tag = tag });
    }
};

const Parser = @This();

allocator: Allocator,
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

fn appendUnescapeContent(self: *Parser, val: []const u8) !void {
    var i: usize = 0;
    while (i < val.len) {
        const size = try unicode.utf8ByteSequenceLength(val[i]);
        // try self.result.buffer.appendSlice(val[i .. i + size]);
        const c = try unicode.utf8Decode(val[i .. i + size]);
        if (c == self.lexer.header.open or c == self.lexer.header.close) {
            // since the next character should always be the same, use the same size
            i += size;
        }
        i += size;
    }
}

fn parseContent(self: *Parser) !void {
    if (try self.match(.content)) {
        try self.result.appendContent(self.previous.value);
    } else if (try self.match(.literal_content)) {
        try self.result.appendLiteralContent(self.previous.value, self.previous.depth);
    } else if (try self.match(.comment)) {
        try self.result.appendComment(self.previous.value, self.previous.depth);
    } else {
        try self.parseTag();
    }
}

fn parseFile(self: *Parser) !void {
    while (!try self.match(.eof)) {
        try self.parseContent();
    }
}

fn parseTag(self: *Parser) !void {
    try self.advance();

    const tag = Result.Tag.init(self.allocator, self.previous.value);
    try self.result.appendOpenTag(tag);
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

    return parser.result;
}
