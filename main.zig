const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

const h = @import("heap.zig");
const Heap = h.Heap;

pub const TreeNode = struct {
    // char
    value: u8,
    probability: i32,
    left_child: ?*const TreeNode,
    right_child: ?*const TreeNode,
};

fn lessThanTree(A: TreeNode, B: TreeNode) Order {
    return std.math.order(A.probability, B.probability);
}

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;
    const myString = "Hello";

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

    var arena = std.heap.ArenaAllocator.init(page_alloc);
    const allocator = arena.allocator();
    defer arena.deinit();

    var heap = try Heap(TreeNode, lessThanTree).init(page_alloc);
    var mapIter = charMap.iterator();

    while (mapIter.next()) |entry| {
        const node = try allocator.create(TreeNode);
        node.* = TreeNode{
            .value = entry.key_ptr.*,
            .probability = entry.value_ptr.*,
            .left_child = null,
            .right_child = null,
        };

        heap.insert(node.*);
    }

    // At least 2 items in heap.
    while (heap.pointer > 1) {
        const left = heap.remove();
        std.debug.print("{}\n", .{left.?.value});
        const right = heap.remove();
        const parent = try allocator.create(TreeNode);

        parent.* = TreeNode{
            .value = 0,
            .probability = left.?.probability + right.?.probability,
            .left_child = &left.?,
            .right_child = &right.?,
        };
        heap.insert(parent.*);
    }

    const nodePointer = heap.remove().?;

    std.debug.print("{*}\n", .{nodePointer.left_child.?});
    std.debug.print("{*}\n", .{nodePointer.left_child.?.left_child.?});
    std.debug.print("{*}\n", .{nodePointer.left_child.?.left_child.?.left_child.?});

    traverse(&nodePointer);
}

fn traverse(node: ?*const TreeNode) void {
    // std.debug.print("{}\n", .{node.?.value});
    if (node.?.left_child) |left| {
        traverse(left);
    }
    if (node.?.right_child) |right| {
        traverse(right);
    }
}
