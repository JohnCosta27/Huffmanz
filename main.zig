const std = @import("std");
const mem = std.mem;

const Queue = @import("priority_queue.zig");
const PriorityQueue = Queue.PriorityQueue;
const el = @import("element.zig");
const Element = el.Element;

pub const TreeNode = struct {
    // String
    value: []const u8,
    priority: i32,
};

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;
    const myString = "Hello world";

    // Map between ASCII and frequency
    var charMap = std.AutoHashMap(u8, i32).init(page_alloc);

    for (myString) |char| {
        const mapChar = charMap.get(char);
        if (mapChar != null) {
            try charMap.put(char, mapChar.? + 1);
        } else {
            try charMap.put(char, 1);
        }
    }

    var q = try PriorityQueue.init(page_alloc);
    var mapIter = charMap.iterator();

    while (mapIter.next()) |entry| {
        // std.debug.print("Key: {c}, Value: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
        const elArray = [_]u8{entry.key_ptr.*};
        q.enqueue(Element{
            .value = &elArray,
            .priority = -entry.value_ptr.*,
        });
    }
}
