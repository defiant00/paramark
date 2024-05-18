const std = @import("std");
const Allocator = std.mem.Allocator;

const Header = @import("Header.zig");

const Result = @This();

pub const Tag = struct {
    pub const Value = struct {
        value: []const u8,
        is_string: bool,

        fn print(self: Value) void {
            if (self.is_string) {
                std.debug.print("\"{s}\" (str)", .{self.value});
            } else {
                std.debug.print("\"{s}\"", .{self.value});
            }
        }
    };

    const Property = struct {
        name: Value,
        value: ?Value,
    };

    name: Value,
    properties: std.ArrayList(Property),

    pub fn init(alloc: Allocator, name: []const u8, is_string: bool) Tag {
        return .{
            .name = .{ .value = name, .is_string = is_string },
            .properties = std.ArrayList(Property).init(alloc),
        };
    }

    fn deinit(self: Tag) void {
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
            .open_tag => printTag(self.open_tag, "open "),
            .close_tag => printTag(self.close_tag, "close "),
            .tag => printTag(self.tag, ""),
            .comment => std.debug.print("comment ({}): \"{s}\"\n", .{
                self.comment.depth,
                self.comment.value,
            }),
        }
    }

    fn printTag(tag: Tag, desc: []const u8) void {
        std.debug.print("{s}tag ", .{desc});
        tag.name.print();
        std.debug.print("\n", .{});
        for (tag.properties.items) |prop| {
            std.debug.print("  ", .{});
            prop.name.print();
            if (prop.value) |val| {
                std.debug.print(" = ", .{});
                val.print();
            }
            std.debug.print("\n", .{});
        }
    }
};

header: Header,
items: std.ArrayList(Item),

pub fn init(alloc: Allocator) Result {
    return .{
        .header = Header.default(),
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

pub fn appendComment(self: *Result, value: []const u8, depth: u8) !void {
    try self.items.append(.{ .comment = .{
        .depth = depth,
        .value = value,
    } });
}

pub fn appendContent(self: *Result, value: []const u8) !void {
    try self.items.append(.{ .content = value });
}

pub fn appendLiteralContent(self: *Result, value: []const u8, depth: u8) !void {
    try self.items.append(.{ .literal_content = .{
        .depth = depth,
        .value = value,
    } });
}

pub fn appendOpenTag(self: *Result, tag: Tag) !void {
    try self.items.append(.{ .open_tag = tag });
}

pub fn appendCloseTag(self: *Result, tag: Tag) !void {
    try self.items.append(.{ .close_tag = tag });
}

pub fn appendTag(self: *Result, tag: Tag) !void {
    try self.items.append(.{ .tag = tag });
}
