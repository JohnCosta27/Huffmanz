const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

pub fn Heap(comptime T: type, comptime compareFn: fn (T, T) Order) type {
    return struct {
        const Self = @This();

        array: []T,
        allocator: std.mem.Allocator,
        pointer: usize,

        pub fn init(allocator: mem.Allocator) !Self {
            const memory = try allocator.alloc(T, 64);
            return Self{
                .array = memory,
                .allocator = allocator,
                .pointer = 0,
            };
        }

        pub fn heapify(self: Self, array: []T) Self {
            mem.copy(T, self.array, array);

            self.build_max_heap();
            return self;
        }

        pub fn max(self: Self) ?T {
            if (self.pointer == 0) {
                return null;
            }
            return self.array[0];
        }

        pub fn insert(self: *Self, item: T) void {
            self.array[self.pointer] = item;
            self.pointer += 1;
            self.max_heapify(0);
        }

        pub fn remove(self: *Self) ?T {
            if (self.pointer <= 0) {
                return undefined;
            }

            const max_item = self.array[0];

            self.array[0] = self.array[self.pointer - 1];
            self.pointer -= 1;
            self.max_heapify(0);

            return max_item;
        }

        fn build_max_heap(self: Self) void {
            var counter: usize = 0;
            while (counter < std.math.sqrt(self.array.len)) {
                self.max_heapify(counter);
                counter += 1;
            }
        }

        fn max_heapify(self: Self, pos: usize) void {
            if (self.pointer <= pos) return;

            const left = 2 * pos + 1;
            const right = 2 * pos + 2;

            var largest = pos;

            const order = compareFn(self.array[left], self.array[right]);

            if (order == .gt and self.pointer > left) {
                largest = left;
            }

            if (order == .lt and self.pointer > right) {
                largest = right;
            }

            if (largest != pos) {
                const temp = self.array[largest];
                self.array[largest] = self.array[pos];
                self.array[pos] = temp;
                self.max_heapify(largest);
            }
        }

        pub fn print(self: Self) void {
            std.debug.print("\n", .{});
            for (self.array) |item| {
                std.debug.print("{}, ", .{item});
            }
            std.debug.print("\n", .{});
        }
    };
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

fn lessThani32(A: i32, B: i32) Order {
    return std.math.order(A, B);
}

fn lessThanCustom(A: CustomType, B: CustomType) Order {
    return std.math.order(A.value, B.value);
}

const CustomType = struct { value: u8 };

test "Build heap" {
    const allocator = std.heap.page_allocator;

    var heap = try Heap(i32, lessThani32).init(allocator);

    const bruh = heap.max();
    try expect(bruh == undefined);

    heap.insert(3);
    heap.insert(4);
    heap.insert(12);
    // heap.insert(20);
    // heap.insert(1);
    // heap.insert(10);

    // try expectEqual(@as(i32, 20), heap.remove().?);
    // try expectEqual(@as(i32, 10), heap.remove().?);
    try expectEqual(@as(i32, 4), heap.remove().?);
    try expectEqual(@as(i32, 3), heap.remove().?);
    try expectEqual(@as(i32, 12), heap.remove().?);
    // try expectEqual(@as(i32, 1), heap.remove().?);
}

// test "Heal with a custom struct type" {
// const allocator = std.heap.page_allocator;
//
// var heap = try Heap(CustomType, lessThanCustom).init(allocator);
//
// const first = CustomType{
// .value = @as(u8, 50),
// };
// const second = CustomType{
// .value = @as(u8, 100),
// };
// const third = CustomType{
// .value = @as(u8, 20),
// };
//
// heap.insert(first);
// try expect(heap.max().?.value == 50);
//
// _ = heap.remove();
//
// const removedItem = heap.max();
// try expect(removedItem == null);
//
// heap.insert(first);
// heap.insert(second);
// heap.insert(third);
//
// try expectEqual(@as(u8, 100), heap.remove().?.value);
// try expectEqual(@as(u8, 50), heap.remove().?.value);
// try expectEqual(@as(u8, 20), heap.remove().?.value);
// }
