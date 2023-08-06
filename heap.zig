const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

const el = @import("element.zig");
const Element = el.Element;

pub fn Heap(comptime T: type, comptime compareFn: fn (T, T) Order) type {
    return struct {
        array: []T,
        allocator: std.mem.Allocator,
        pointer: usize,

        const Self = @This();

        pub fn init(allocator: mem.Allocator) !Self {
            const memory = try allocator.alloc(T, 64);
            return .{
                .array = memory,
                .allocator = allocator,
                .pointer = 0,
            };
        }

        pub fn heapify(self: Heap, array: []T) Self {
            mem.copy(T, self.array, array);

            self.build_max_heap();
            return self;
        }

        pub fn max(self: Heap) ?Element {
            if (self.pointer == 0) {
                return null;
            }
            return self.array[0];
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

            if (left >= arrSize) return;
            if (right >= arrSize) return;

            const order = compareFn(self.array[left], self.array[right]);

            if (order == .gt) {
                largest = left;
            }

            if (order == .lt) {
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
                std.debug.print("{}, ", .{item});
            }
            std.debug.print("\n", .{});
        }
    };
}

const expect = std.testing.expect;

fn lessThan(comptime T: type) fn (T, T) Order {
    return struct {
        fn lt(a: T, b: T) Order {
            return std.math.order(a, b);
        }
    }.lt;
}

test "Build heap from array" {
    const allocator = std.heap.page_allocator;

    const lt = comptime lessThan(i32);

    var myHeap = try Heap(i32, lt).init(allocator);

    var counter: usize = 0;
    while (counter < std.math.sqrt(myHeap.array.len)) {
        const left = 2 * counter + 1;
        const right = 2 * counter + 2;

        try expect(myHeap.array[counter] >= myHeap.array[left] and myHeap.array[counter] >= myHeap.array[right]);

        counter += 1;
    }
}
