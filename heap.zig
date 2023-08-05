const std = @import("std");
const mem = std.mem;

const el = @import("element.zig");
const Element = el.Element;

pub const Heap = struct {
    array: []Element,
    allocator: std.mem.Allocator,
    pointer: usize,

    pub fn init(allocator: mem.Allocator) Heap {
        return Heap{
            .array = allocator.alloc(i32, 1024),
            .allocator = allocator,
        };
    }

    pub fn heapify(allocator: mem.Allocator, array: []Element) !Heap {
        const memory = try allocator.alloc(Element, 10);

        const myHeap = Heap{
            .array = memory,
            .allocator = allocator,
            .pointer = array.len,
        };

        mem.copy(Element, myHeap.array, array);

        myHeap.build_max_heap();
        return myHeap;
    }

    pub fn insert(self: *Heap, item: Element) void {
        self.array[self.pointer] = item;
        self.pointer += 1;
        self.max_heapify(0);
    }

    pub fn remove(self: *Heap) ?Element {
        if (self.pointer <= 0) {
            return undefined;
        }

        const max_item = self.array[0];

        self.array[0] = self.array[self.pointer - 1];
        self.pointer -= 1;
        self.max_heapify(0);

        return max_item;
    }

    fn build_max_heap(self: Heap) void {
        var counter: usize = 0;
        while (counter < std.math.sqrt(self.array.len)) {
            self.max_heapify(counter);
            counter += 1;
        }
    }

    fn max_heapify(self: Heap, pos: usize) void {
        const left = 2 * pos + 1;
        const right = 2 * pos + 2;

        var largest = pos;
        const arrSize = self.array.len;

        if (left < arrSize and self.array[left].priority > self.array[largest].priority) {
            largest = left;
        }

        if (right < arrSize and self.array[right].priority > self.array[largest].priority) {
            largest = right;
        }

        if (largest != pos) {
            const temp = self.array[largest];
            self.array[largest] = self.array[pos];
            self.array[pos] = temp;
            self.max_heapify(largest);
        }
    }

    pub fn print(self: Heap) void {
        std.debug.print("\n", .{});
        for (self.array) |item| {
            std.debug.print("{}, ", .{item.priority});
        }
        std.debug.print("\n", .{});
    }
};
