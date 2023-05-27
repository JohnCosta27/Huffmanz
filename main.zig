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
        const memory = try allocator.alloc(i32, 8);

        const myHeap = Heap{
            .array = memory,
            .allocator = allocator,
        };

        mem.copy(i32, myHeap.array, array);

        myHeap.build_max_heap();

        for (myHeap.array) |item| {
            std.debug.print("Element: {}\n", .{item});
        }
    }

    fn build_max_heap(self: Heap) void {
        var counter: usize = 0;
        while (counter < self.array.len) {
            self.max_heapify(counter);
            counter += 1;
        }
    }

    fn max_heapify(self: Heap, pos: usize) void {
        const left = 2 * pos + 1;
        const right = 2 * pos + 2;

        var largest = pos;
        const arrSize = self.array.len;

        if (left < arrSize and self.array[left] > self.array[largest]) {
            largest = left;
        }

        if (right < arrSize and self.array[right] > self.array[largest]) {
            largest = right;
        }

        if (largest != pos) {
            const temp = self.array[largest];
            self.array[largest] = self.array[pos];
            self.array[pos] = temp;
            self.max_heapify(largest);
        }
    }
};

pub fn main() !void {
    const allocator = std.heap.page_allocator;
    var myArr = [_]i32{ 32, 100, 343, 28, 20, 32, 13, 5 };

    _ = try Heap.heapify(allocator, myArr[0..]);
}
