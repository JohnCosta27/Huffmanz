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

        pub fn max(self: Self) ?T {
            if (self.pointer == 0) {
                return null;
            }
            return self.array[0];
        }

        pub fn insert(self: *Self, item: T) void {
            self.array[self.pointer] = item;
            self.sift_up(self.pointer);
            self.pointer += 1;
        }

        pub fn remove(self: *Self) ?T {
            if (self.pointer <= 0) {
                return undefined;
            }

            const max_item = self.array[0];

            self.array[0] = self.array[self.pointer - 1];
            self.pointer -= 1;
            self.sift_down(0);

            return max_item;
        }

        fn sift_up(self: Self, index: usize) void {
            // Base case
            if (index <= 0) return;

            var parent: usize = 0;
            if (index % 2 == 0) {
                parent = (index - 2) / 2;
            } else {
                parent = (index - 1) / 2;
            }

            const comparison = compareFn(self.array[parent], self.array[index]);

            if (comparison == Order.lt) {
                const temp = self.array[parent];
                self.array[parent] = self.array[index];
                self.array[index] = temp;
                self.sift_up(parent);
            }
        }
        fn sift_down(self: Self, index: usize) void {
            // Base case
            const firstChildIndex = 2 * index + 1;
            if (self.pointer <= firstChildIndex) return;

            const secondChildIndex = 2 * index + 2;
            var largestIndex: usize = index;

            if (compareFn(self.array[largestIndex], self.array[firstChildIndex]) == Order.lt) {
                largestIndex = firstChildIndex;
            }

            if (self.pointer > secondChildIndex) {
                if (compareFn(self.array[largestIndex], self.array[secondChildIndex]) == Order.lt) {
                    largestIndex = secondChildIndex;
                }
            }

            if (largestIndex != index) {
                const temp = self.array[largestIndex];
                self.array[largestIndex] = self.array[index];
                self.array[index] = temp;
                self.sift_down(largestIndex);
            }
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
    heap.insert(20);
    heap.insert(35);
    heap.insert(2);
    heap.insert(1);
    heap.insert(10);
    heap.insert(40);

    try expectEqual(@as(i32, 40), heap.remove().?);
    try expectEqual(@as(i32, 35), heap.remove().?);
    try expectEqual(@as(i32, 20), heap.remove().?);
    try expectEqual(@as(i32, 12), heap.remove().?);
    try expectEqual(@as(i32, 10), heap.remove().?);
    try expectEqual(@as(i32, 4), heap.remove().?);
    try expectEqual(@as(i32, 3), heap.remove().?);
    try expectEqual(@as(i32, 2), heap.remove().?);
    try expectEqual(@as(i32, 1), heap.remove().?);
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
