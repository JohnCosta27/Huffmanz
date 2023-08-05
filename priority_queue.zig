const std = @import("std");
const Element = @import("element.zig");
const Heap = @import("heap.zig");

const PriorityQueue = struct {
    heap: Heap,

    pub fn init(allocator: std.mem.Allocator) PriorityQueue {
        return PriorityQueue{
            .allocator = allocator,
        };
    }

    pub fn is_empty(self: PriorityQueue) bool {
        return self.heap.array.len <= 0;
    }

    pub fn enqueue(self: PriorityQueue, item: Element) void {
        self.heap.insert(item);
    }

    pub fn dequeue(self: PriorityQueue) ?Element {
        return self.heap.remove();
    }
};
