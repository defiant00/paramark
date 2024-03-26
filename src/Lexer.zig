const unicode = @import("std").unicode;

pub const Token = struct {
    pub const Type = enum {
        open,
        close,
        assign,
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

open_char: u21,
close_char: u21,
assign_char: u21,
quote_char: u21,
comment_char: u21,

pub fn init(source: []const u8) Lexer {
    var open_ch: u21 = '(';
    var close_ch: u21 = ')';
    var assign_ch: u21 = '=';
    var quote_ch: u21 = '"';
    var comment_ch: u21 = '-';

    // TODO
    open_ch = '(';
    close_ch = ')';
    assign_ch = '=';
    quote_ch = '"';
    comment_ch = '-';

    return .{
        .source = source,
        .start_index = 0,
        .current_index = 0,
        .in_content = true,

        .open_char = open_ch,
        .close_char = close_ch,
        .assign_char = assign_ch,
        .quote_char = quote_ch,
        .comment_char = comment_ch,
    };
}

pub fn absoluteRange(self: Lexer, tok: Token) AbsoluteRange {
    var ar = .{
        .start_line = 0,
        .start_column = 0,
        .end_line = 0,
        .end_column = 0,
    };

    // TODO
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

    // TODO
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

fn currentLength(self: Lexer) !u3 {
    return unicode.utf8ByteSequenceLength(self.source[self.current_index]);
}

fn advance(self: *Lexer) !void {
    if (!self.isAtEnd()) {
        self.current_index += try self.currentLength();
    }
}

fn peek(self: Lexer) !u21 {
    return unicode.utf8Decode(self.source[self.current_index .. self.current_index + try self.currentLength()]);
}

// TODO
fn peekAt(self: Lexer, offset: usize) ?u21 {
    return if (self.current_index + offset < self.source.len) self.source[self.current_index + offset] else null;
}

fn discard(self: *Lexer) void {
    self.start_index = self.current_index;
}

fn token(self: *Lexer, token_type: Token.Type) Token {
    if (token_type == .open or token_type == .close) {
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

fn isLiteral(self: Lexer, c: u21) bool {
    return !(c == ' ' or c == '\t' or c == '\r' or c == '\n' or c == self.open_char or c == self.close_char or c == self.assign_char);
}

fn multiBlock(self: *Lexer, tok_type: Token.Type, marker: u21, unterm_msg: []const u8) !Token {
    // open has already been accepted

    // count depth
    var depth: usize = 0;
    while (!self.isAtEnd() and try self.peek() == marker) {
        depth += 1;
        try self.advance();
    }

    // discard start tag
    self.discard();

    // consume content
    while (!self.isAtEnd()) {
        if (try self.peek() == marker) {
            var end_found = true;
            for (1..depth) |i| {
                if (self.peekAt(i) != marker) {
                    end_found = false;
                    break;
                }
            }
            if (self.peekAt(depth) != self.close_char) {
                end_found = false;
            }
            if (end_found) break;
        }
        try self.advance();
    }

    if (self.isAtEnd()) return self.errorToken(unterm_msg);

    const tok = self.token(tok_type);

    // accept and discard end tag
    for (0..depth + 1) |_| try self.advance();
    self.discard();

    return tok;
}

fn content(self: *Lexer) !Token {
    while (!self.isAtEnd()) {
        const c = try self.peek();
        if (c == self.open_char or c == self.close_char) break;
        try self.advance();
    }
    return self.token(.content);
}

fn contentOpen(self: *Lexer) !Token {
    if (!self.isAtEnd()) {
        if (try self.peek() == self.open_char) {
            try self.advance();
            return self.token(.content);
        } else if (try self.peek() == self.quote_char) {
            return self.multiBlock(.literal_content, self.quote_char, "unterminated literal text");
        } else if (try self.peek() == self.comment_char) {
            return self.multiBlock(.comment, self.comment_char, "unterminated comment");
        }
    }
    return self.token(.open);
}

fn contentClose(self: *Lexer) !Token {
    if (!self.isAtEnd()) {
        if (try self.peek() == self.close_char) {
            try self.advance();
            return self.token(.content);
        }
    }
    return self.token(.close);
}

fn tagOpen(self: *Lexer) !Token {
    if (!self.isAtEnd()) {
        if (try self.peek() == self.comment_char) {
            return self.multiBlock(.comment, self.comment_char, "unterminated comment");
        }
    }
    return self.token(.open);
}

fn tagLiteral(self: *Lexer) !Token {
    while (!self.isAtEnd() and self.isLiteral(try self.peek())) try self.advance();
    return self.token(.literal);
}

fn tagString(self: *Lexer) !Token {
    // discard opening quote
    self.discard();

    while (!self.isAtEnd()) {
        if (try self.peek() == self.quote_char) {
            if (self.peekAt(1) == self.quote_char) {
                try self.advance();
            } else {
                break;
            }
        }
        try self.advance();
    }

    if (self.isAtEnd()) return self.errorToken("unterminated string");

    const tok = self.token(.string);

    // discard closing quote
    try self.advance();
    self.discard();

    return tok;
}

pub fn lexToken(self: *Lexer) !Token {
    while (!self.isAtEnd()) {
        const c = try self.peek();
        try self.advance();

        if (self.in_content) {
            if (c == self.open_char) {
                return self.contentOpen();
            } else if (c == self.close_char) {
                return self.contentClose();
            }
            return self.content();
        } else {
            switch (c) {
                ' ', '\t', '\r', '\n' => self.discard(),
                else => {
                    if (c == self.open_char) {
                        return self.tagOpen();
                    } else if (c == self.close_char) {
                        return self.token(.close);
                    } else if (c == self.assign_char) {
                        return self.token(.assign);
                    } else if (c == self.quote_char) {
                        return self.tagString();
                    }
                    return self.tagLiteral();
                },
            }
        }
    }

    return self.token(.eof);
}
