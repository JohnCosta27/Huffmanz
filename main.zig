const std = @import("std");
const mem = std.mem;

const Heap = struct {
    array: []i32,
    allocator: std.mem.Allocator,

    pub fn init(allocator: mem.Allocator) Heap {
        return Heap{
            .array = allocator.alloc(i32, 1024),
            .allocator = allocator,
        };
    }

    pub fn heapify(allocator: mem.Allocator, array: []i32) !void {
        const memory = try allocator.alloc(i32, 32);

        const myHeap = Heap{
            .array = memory,
            .allocator = allocator,
        };

        mem.copy(i32, myHeap.array, array);

        for (myHeap.array) |item| {
            std.debug.print("Element: {}\n", .{item});
        }
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var myArr = [_]i32{ 10, 23, 24, 100, 52, 96 };

    _ = try Heap.heapify(allocator, myArr[0..]);
}
