const std = @import("std");
const e = @import("element.zig");
const h = @import("heap.zig");

const Heap = h.Heap;
const Element = e.Element;

const PriorityQueue = struct {
    heap: Heap,

    pub fn init(allocator: std.mem.Allocator) !PriorityQueue {
        var myHeap = try Heap.init(allocator);
        return PriorityQueue{
            .heap = myHeap,
        };
    }

    pub fn is_empty(self: PriorityQueue) bool {
        return self.heap.max() == null;
    }

    pub fn enqueue(self: *PriorityQueue, item: Element) void {
        self.heap.insert(item);
    }

    pub fn dequeue(self: *PriorityQueue) ?Element {
        return self.heap.remove();
    }

    pub fn peek(self: PriorityQueue) ?Element {
        if (self.is_empty()) {
            return undefined;
        }

        return self.heap.max();
    }
};

const expect = std.testing.expect;

test "Queues items in correct order" {
    const allocator = std.heap.page_allocator;

    var q = try PriorityQueue.init(allocator);

    try expect(q.is_empty() == true);

    const element = Element{
        .value = "Should be first",
        .priority = 420,
    };

    q.enqueue(element);

    try expect(q.is_empty() == false);

    var popped = q.peek();
    try expect(popped.?.priority == 420);

    const anotherElement = Element{
        .value = "now i'm first",
        .priority = 42069,
    };

    q.enqueue(anotherElement);

    popped = q.peek();

    try expect(popped.?.priority == 42069);
}
