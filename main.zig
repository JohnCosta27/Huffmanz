const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

const h = @import("heap.zig");
const Heap = h.Heap;

pub const TreeNode = struct {
    // char
    value: u8,
    probability: i32,
    left_child: ?*TreeNode,
    right_child: ?*TreeNode,
};

fn lessThanTree(A: TreeNode, B: TreeNode) Order {
    return std.math.order(A.probability, B.probability);
}

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;
    const myString = "Hello world";

    // Map between ASCII and frequency
    var charMap = std.AutoHashMap(u8, i32).init(page_alloc);

    for (myString) |char| {
        const mapChar = charMap.get(char);
        if (mapChar != null) {
            try charMap.put(char, mapChar.? + 1);
        } else {
            try charMap.put(char, 1);
        }
    }

    var heap = try Heap(TreeNode, lessThanTree).init(page_alloc);
    var mapIter = charMap.iterator();

    while (mapIter.next()) |entry| {
        var node: TreeNode = TreeNode{
            .value = entry.key_ptr.*,
            .probability = entry.value_ptr.*,
            .left_child = null,
            .right_child = null,
        };

        heap.insert(node);
    }

    // At least 2 items in heap.
    while (heap.pointer > 1) {
        var left = heap.remove().?;
        var right = heap.remove().?;
        var newNode = TreeNode{
            .value = 0,
            .probability = left.probability + right.probability,
            .left_child = &left,
            .right_child = &right,
        };

        heap.insert(newNode);
    }

    // const nodePointer = heap.remove().?;

    var firstChild = TreeNode{
        .value = 5,
        .probability = 5,
        .left_child = null,
        .right_child = null,
    };

    var secondChild = TreeNode{
        .value = 10,
        .probability = 10,
        .left_child = null,
        .right_child = null,
    };
    var root = TreeNode{
        .value = 1,
        .probability = 5,
        .left_child = &secondChild,
        .right_child = &firstChild,
    };

    traverse(&root);
}

fn traverse(node: ?*const TreeNode) void {
    std.debug.print("{}\n", .{node.?.value});
    if (node.?.left_child != null) {
        traverse(node.?.left_child.?);
    }
    if (node.?.right_child != null) {
        traverse(node.?.right_child.?);
    }
}
