const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

const Element = struct {
    value: []const u8,
    priority: i32,
};

const Heap = struct {
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

    pub fn enqueue() void {
        // self.heap.insert();
    }

    pub fn dequeue() []u8 {}
};

test "Build heap from array" {
    const allocator = std.heap.page_allocator;

    var myArr = [_]Element{
        Element{
            .value = "Hello",
            .priority = 10,
        },
        Element{
            .value = "World",
            .priority = 20,
        },
        Element{
            .value = "Again",
            .priority = 15,
        },
    };

    var myHeap = try Heap.heapify(allocator, myArr[0..]);

    var counter: usize = 0;
    while (counter < std.math.sqrt(myHeap.array.len)) {
        const left = 2 * counter + 1;
        const right = 2 * counter + 2;

        try expect(myHeap.array[counter].priority >= myHeap.array[left].priority and myHeap.array[counter].priority >= myHeap.array[right].priority);

        counter += 1;
    }
}

test "Inserts items into heap" {
    const allocator = std.heap.page_allocator;
    var myArr = [_]Element{ Element{
        .value = "32",
        .priority = 32,
    }, Element{
        .value = "100",
        .priority = 100,
    }, Element{
        .value = "343",
        .priority = 343,
    }, Element{
        .value = "28",
        .priority = 28,
    }, Element{
        .value = "20",
        .priority = 20,
    }, Element{
        .value = "32",
        .priority = 32,
    }, Element{
        .value = "13",
        .priority = 13,
    } };

    var myHeap = try Heap.heapify(allocator, myArr[0..]);
    myHeap.insert(Element{
        .value = "43",
        .priority = 43,
    });
    myHeap.print();

    var counter: usize = 0;
    while (counter < std.math.sqrt(myHeap.array.len)) {
        const left = 2 * counter + 1;
        const right = 2 * counter + 2;

        try expect(myHeap.array[counter].priority >= myHeap.array[left].priority and myHeap.array[counter].priority >= myHeap.array[right].priority);

        counter += 1;
    }
}
