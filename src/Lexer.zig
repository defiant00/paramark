pub const Token = struct {
    pub const Type = enum {
        left_paren,
        right_paren,
        eof,
    };

    type: Type,
    position: usize,
    value: []const u8,
};

const AbsoluteRange = struct {
    start_line: usize,
    start_column: usize,
    end_line: usize,
    end_column: usize,
};

const Lexer = @This();

source: []const u8,
start_index: usize,
current_index: usize,

pub fn init(source: []const u8) Lexer {
    return .{
        .source = source,
        .start_index = 0,
        .current_index = 0,
    };
}

pub fn absoluteRange(self: Lexer, tok: Token) AbsoluteRange {
    var ar = AbsoluteRange{
        .start_line = 0,
        .start_column = 0,
        .end_line = 0,
        .end_column = 0,
    };

    for (self.source[0..tok.position]) |c| {
        if (c == '\n') {
            ar.start_line += 1;
            ar.start_column = 0;
        } else {
            ar.start_column += 1;
        }
    }

    ar.end_line = ar.start_line;
    ar.end_column = ar.start_column;

    for (tok.value) |c| {
        if (c == '\n') {
            ar.end_line += 1;
            ar.end_column = 0;
        } else {
            ar.end_column += 1;
        }
    }

    return ar;
}

fn isAtEnd(self: Lexer) bool {
    return self.current_index >= self.source.len;
}

fn advance(self: *Lexer) void {
    if (!self.isAtEnd()) {
        self.current_index += 1;
    }
}

fn peek(self: Lexer) u8 {
    return self.source[self.current_index];
}

fn peekNext(self: Lexer) ?u8 {
    return if (self.current_index + 1 < self.source.len) self.source[self.current_index + 1] else null;
}

fn discard(self: *Lexer) void {
    self.start_index = self.current_index;
}

fn token(self: Lexer, token_type: Token.Type) Token {
    return .{
        .type = token_type,
        .position = self.start_index,
        .value = self.source[self.start_index..self.current_index],
    };
}

pub fn lexToken(self: *Lexer) Token {
    self.discard();

    while (!self.isAtEnd()) {
        const c = self.peek();
        self.advance();

        switch (c) {
            else => {},
        }
    }

    return self.token(.eof);
}
