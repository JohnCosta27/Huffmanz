const std = @import("std");
const mem = std.mem;

const Queue = @import("priority_queue.zig");
const PriorityQueue = Queue.PriorityQueue;

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;
    const myString = "Hello world";

    // Map between ASCII and frequency
    var charMap = std.AutoHashMap(u8, u32).init(page_alloc);

    for (myString) |char| {
        const mapChar = charMap.get(char);
        if (mapChar != null) {
            try charMap.put(char, mapChar.? + 1);
        } else {
            try charMap.put(char, 1);
        }
    }

    // var q = PriorityQueue.init(page_alloc);

    var mapIter = charMap.iterator();

    while (mapIter.next()) |entry| {
        std.debug.print("Key: {}, Value: {d}\n", .{ entry.key_ptr.*, entry.value_ptr.* });
    }
}
