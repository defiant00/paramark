pub const Token = struct {
    pub const Type = enum {
        left_paren,
        right_paren,
        equal,
        content,
        literal_content,
        literal,
        string,
        comment,
        error_,
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
in_content: bool,

pub fn init(source: []const u8) Lexer {
    return .{
        .source = source,
        .start_index = 0,
        .current_index = 0,
        .in_content = true,
    };
}

pub fn absoluteRange(self: Lexer, tok: Token) AbsoluteRange {
    var ar = .{
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

fn peekAt(self: Lexer, offset: usize) ?u8 {
    return if (self.current_index + offset < self.source.len) self.source[self.current_index + offset] else null;
}

fn discard(self: *Lexer) void {
    self.start_index = self.current_index;
}

fn token(self: *Lexer, token_type: Token.Type) Token {
    if (token_type == .left_paren or token_type == .right_paren) {
        self.in_content = !self.in_content;
    }

    const tok = .{
        .type = token_type,
        .position = self.start_index,
        .value = self.source[self.start_index..self.current_index],
    };
    self.discard();
    return tok;
}

fn errorToken(self: *Lexer, message: []const u8) Token {
    const tok = .{
        .type = .error_,
        .position = self.start_index,
        .value = message,
    };
    self.discard();
    return tok;
}

fn isLiteral(c: u8) bool {
    return switch (c) {
        ' ', '\t', '\r', '\n', '(', ')', '=' => false,
        else => true,
    };
}

fn multiBlock(self: *Lexer, tok_type: Token.Type, marker: u8, unterm_msg: []const u8) Token {
    // left paren has already been accepted

    // count depth
    var depth: usize = 0;
    while (!self.isAtEnd() and self.peek() == marker) {
        depth += 1;
        self.advance();
    }

    // discard start tag
    self.discard();

    // consume content
    while (!self.isAtEnd()) {
        if (self.peek() == marker) {
            var end_found = true;
            for (1..depth) |i| {
                if (self.peekAt(i) != marker) {
                    end_found = false;
                    break;
                }
            }
            if (self.peekAt(depth) != ')') {
                end_found = false;
            }
            if (end_found) break;
        }
        self.advance();
    }

    if (self.isAtEnd()) return self.errorToken(unterm_msg);

    const tok = self.token(tok_type);

    // accept and discard end tag
    for (0..depth + 1) |_| self.advance();
    self.discard();

    return tok;
}

fn content(self: *Lexer) Token {
    while (!self.isAtEnd()) {
        const c = self.peek();
        if (c == '(' or c == ')') break;
        self.advance();
    }
    return self.token(.content);
}

fn contentLeftParen(self: *Lexer) Token {
    if (!self.isAtEnd()) {
        if (self.peek() == '(') {
            self.advance();
            return self.token(.content);
        } else if (self.peek() == '"') {
            return self.multiBlock(.literal_content, '"', "unterminated literal text");
        } else if (self.peek() == '-') {
            return self.multiBlock(.comment, '-', "unterminated comment");
        }
    }
    return self.token(.left_paren);
}

fn contentRightParen(self: *Lexer) Token {
    if (!self.isAtEnd()) {
        if (self.peek() == ')') {
            self.advance();
            return self.token(.content);
        }
    }
    return self.token(.right_paren);
}

fn tagLeftParen(self: *Lexer) Token {
    if (!self.isAtEnd()) {
        if (self.peek() == '-') {
            return self.multiBlock(.comment, '-', "unterminated comment");
        }
    }
    return self.token(.left_paren);
}

fn tagLiteral(self: *Lexer) Token {
    while (!self.isAtEnd() and isLiteral(self.peek())) self.advance();
    return self.token(.literal);
}

fn tagString(self: *Lexer) Token {
    // discard opening quote
    self.discard();

    while (!self.isAtEnd()) {
        if (self.peek() == '"') {
            if (self.peekAt(1) == '"') {
                self.advance();
            } else {
                break;
            }
        }
        self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("unterminated string");

    const tok = self.token(.string);

    // discard closing quote
    self.advance();
    self.discard();

    return tok;
}

pub fn lexToken(self: *Lexer) Token {
    while (!self.isAtEnd()) {
        const c = self.peek();
        self.advance();

        if (self.in_content) {
            switch (c) {
                '(' => return self.contentLeftParen(),
                ')' => return self.contentRightParen(),
                else => return self.content(),
            }
        } else {
            switch (c) {
                ' ', '\t', '\r', '\n' => self.discard(),
                '(' => return self.tagLeftParen(),
                ')' => return self.token(.right_paren),
                '=' => return self.token(.equal),
                '"' => return self.tagString(),
                else => return self.tagLiteral(),
            }
        }
    }

    return self.token(.eof);
}
