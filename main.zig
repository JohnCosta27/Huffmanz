const std = @import("std");
const mem = std.mem;
const expect = std.testing.expect;

const h = @import("heap.zig");
const el = @import("element.zig");
const Element = el.Element;
const Heap = h.Heap;

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

test "Inserts and removing items into/from heap" {
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

    const max_item = myHeap.remove();
    const max_priority: i32 = 343;

    try expect(max_item.?.priority == max_priority);
}
