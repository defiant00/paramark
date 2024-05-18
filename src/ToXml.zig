const std = @import("std");
const unicode = std.unicode;

const Header = @import("Header.zig");
const Parser = @import("Parser.zig");
const Result = @import("Result.zig");

pub fn convert(result: Result, writer: std.io.AnyWriter) !void {
    try writer.writeAll("<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n");

    for (result.items.items) |item| {
        switch (item) {
            .content => try writeContent(result.header, writer, item.content),
            .literal_content => {
                try writer.writeAll("<![CDATA[");
                try writer.writeAll(item.literal_content.value);
                try writer.writeAll("]]>");
            },
            .open_tag => {
                try writer.writeAll("<");
                try writeTagContent(result.header, writer, item.open_tag, true);
                try writer.writeAll(">");
            },
            .close_tag => {
                try writer.writeAll("</");
                try writeTagContent(result.header, writer, item.close_tag, false);
                try writer.writeAll(">");
            },
            .tag => {
                try writer.writeAll("<");
                try writeTagContent(result.header, writer, item.tag, true);
                try writer.writeAll(" />");
            },
            .comment => {
                try writer.writeAll("<!--");
                try writer.writeAll(item.comment.value);
                try writer.writeAll("-->");
            },
        }
    }
}

fn writeContent(header: Header, writer: std.io.AnyWriter, content: []const u8) !void {
    var iter = header.unescapeContentIterator(content);
    var buf = [4]u8{ 0, 0, 0, 0 };
    while (iter.nextCodepoint()) |c| {
        switch (c) {
            '<' => try writer.writeAll("&lt;"),
            '>' => try writer.writeAll("&gt;"),
            '&' => try writer.writeAll("&amp;"),
            '\'' => try writer.writeAll("&apos;"),
            '"' => try writer.writeAll("&quot;"),
            else => {
                const size = try unicode.utf8Encode(c, &buf);
                try writer.writeAll(buf[0..size]);
            },
        }
    }
}

fn writeTagContent(header: Header, writer: std.io.AnyWriter, tag: Result.Tag, write_props: bool) !void {
    try writeTagName(header, writer, tag.name);

    if (write_props) {
        for (tag.properties.items) |prop| {
            try writer.writeByte(' ');
            try writeTagName(header, writer, prop.name);
            try writer.writeAll("=\"");
            if (prop.value) |val| {
                try writeTagValue(header, writer, val);
            }
            try writer.writeByte('"');
        }
    }
}

fn writeTagName(header: Header, writer: std.io.AnyWriter, value: Result.Tag.Value) !void {
    const name_invalid = "!\"#$%&'()*+,/;<=>?@[\\]^`{|}~";
    const name_sub = '_';

    if (value.is_string) {
        var iter = header.unescapeTagStringIterator(value.value);
        var buf = [4]u8{ 0, 0, 0, 0 };
        while (iter.nextCodepoint()) |c| {
            const size = try unicode.utf8Encode(c, &buf);
            for (0..size) |i| {
                try writer.writeByte(getSubInvalid(buf[i], name_invalid, name_sub));
            }
        }
    } else {
        for (value.value) |c| {
            try writer.writeByte(getSubInvalid(c, name_invalid, name_sub));
        }
    }
}

fn writeTagValue(header: Header, writer: std.io.AnyWriter, value: Result.Tag.Value) !void {
    if (value.is_string) {
        var iter = header.unescapeTagStringIterator(value.value);
        var buf = [4]u8{ 0, 0, 0, 0 };
        while (iter.nextCodepoint()) |c| {
            switch (c) {
                '\'' => try writer.writeAll("&apos;"),
                '"' => try writer.writeAll("&quot;"),
                else => {
                    const size = try unicode.utf8Encode(c, &buf);
                    try writer.writeAll(buf[0..size]);
                },
            }
        }
    } else {
        for (value.value) |c| {
            switch (c) {
                '\'' => try writer.writeAll("&apos;"),
                '"' => try writer.writeAll("&quot;"),
                else => try writer.writeByte(c),
            }
        }
    }
}

fn getSubInvalid(c: u8, invalid: []const u8, sub: u8) u8 {
    return if (std.mem.indexOfScalar(u8, invalid, c)) |_| sub else c;
}
