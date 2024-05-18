const std = @import("std");
const unicode = std.unicode;

const Header = @This();

open: u21,
close: u21,
assign: u21,
quote: u21,
comment: u21,

pub fn default() Header {
    return .{
        .open = '(',
        .close = ')',
        .assign = '=',
        .quote = '"',
        .comment = '-',
    };
}

pub fn parse(source: []const u8) !Header {
    // (-pm v="1.0"-)
    var open: u21 = '(';
    var close: u21 = ')';
    var assign: u21 = '=';
    var quote: u21 = '"';
    var comment: u21 = '-';
    var valid_header = false;

    var iter = (try unicode.Utf8View.init(source)).iterator();

    // open
    if (iter.nextCodepoint()) |c_open| {
        open = c_open;

        // comment
        if (iter.nextCodepoint()) |c_comment| {
            comment = c_comment;

            // "pm v"
            if (iter.nextCodepoint() == 'p' and iter.nextCodepoint() == 'm' and iter.nextCodepoint() == ' ' and iter.nextCodepoint() == 'v') {

                // assign
                if (iter.nextCodepoint()) |c_assign| {
                    assign = c_assign;

                    // quote
                    if (iter.nextCodepoint()) |c_quote| {
                        quote = c_quote;

                        // version
                        while (iter.nextCodepoint()) |c_version| {
                            if (isNumeric(c_version)) {
                                // part of the version, do nothing
                            } else {

                                // closing quote
                                if (c_version == quote) {

                                    // comment
                                    if (iter.nextCodepoint() == comment) {

                                        // close
                                        if (iter.nextCodepoint()) |c_close| {
                                            close = c_close;

                                            valid_header = true;
                                        }
                                    }
                                }
                                break;
                            }
                        }
                    }
                }
            }
        }
    }

    if (valid_header) {
        return .{
            .open = open,
            .close = close,
            .assign = assign,
            .quote = quote,
            .comment = comment,
        };
    }

    return default();
}

const UnescapeContentIterator = struct {
    header: Header,
    value: []const u8,
    index: usize,

    pub fn nextCodepoint(self: *UnescapeContentIterator) ?u21 {
        if (self.index >= self.value.len) return null;
        const size = unicode.utf8ByteSequenceLength(self.value[self.index]) catch return null;
        const c = unicode.utf8Decode(self.value[self.index .. self.index + size]) catch return null;
        if (c == self.header.open or c == self.header.close) {
            // since the next character should always be the same, use the same size
            self.index += size;
        }
        self.index += size;
        return c;
    }
};

pub fn unescapeContentIterator(self: Header, value: []const u8) UnescapeContentIterator {
    return .{
        .header = self,
        .value = value,
        .index = 0,
    };
}

const UnescapeTagStringIterator = struct {
    header: Header,
    value: []const u8,
    index: usize,

    pub fn nextCodepoint(self: *UnescapeTagStringIterator) ?u21 {
        if (self.index >= self.value.len) return null;
        const size = unicode.utf8ByteSequenceLength(self.value[self.index]) catch return null;
        const c = unicode.utf8Decode(self.value[self.index .. self.index + size]) catch return null;
        if (c == self.header.quote) {
            // since the next character should always be the same, use the same size
            self.index += size;
        }
        self.index += size;
        return c;
    }
};

pub fn unescapeTagStringIterator(self: Header, value: []const u8) UnescapeTagStringIterator {
    return .{
        .header = self,
        .value = value,
        .index = 0,
    };
}

fn isNumeric(c: u21) bool {
    return switch (c) {
        '0'...'9', '.' => true,
        else => false,
    };
}
