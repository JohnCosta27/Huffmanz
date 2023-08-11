const std = @import("std");
const mem = std.mem;
const Order = std.math.Order;

const h = @import("heap.zig");
const Heap = h.Heap;

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

pub const TreeNode = struct {
    // char
    value: u8,
    probability: i32,
    left_child: ?*const TreeNode,
    right_child: ?*const TreeNode,
};

fn lessThanTree(A: TreeNode, B: TreeNode) Order {
    // We want to have the lowest probability be highest priority, hence the inversion.
    return std.math.order(B.probability, A.probability);
}

pub fn main() !void {
    const page_alloc = std.heap.page_allocator;
    const myString = "aabcd";

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
        node.* = .{
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
        const right = heap.remove();

        // Because we would return the items that are in the array of the heap.
        // And the pointers in the array don't change, we would end up with
        // Recursive relations A -> B -> A
        // So to fix this I create copies, seperate.
        // I don't think this is ideal.
        const copies = try allocator.alloc(TreeNode, 3);

        copies[0] = .{
            .value = left.?.value,
            .probability = left.?.probability,
            .left_child = left.?.left_child,
            .right_child = left.?.right_child,
        };

        copies[1] = .{
            .value = right.?.value,
            .probability = right.?.probability,
            .left_child = right.?.left_child,
            .right_child = right.?.right_child,
        };

        copies[2] = .{
            .value = 0,
            .probability = left.?.probability + right.?.probability,
            .left_child = &copies[0],
            .right_child = &copies[1],
        };

        heap.insert(copies[2]);
    }

    // const nodePointer = heap.remove().?;

    var x: u8 = 1;
    x = x << 2;
    std.debug.print("{b}\n", .{x});
}

fn walk(node: TreeNode, search: u8, path: u8) ?u8 {
    var myPath = path;

    if (node.value == search) {
        return myPath;
    }

    if (node.left_child) |left| {
        myPath = myPath << 1;
        const ret = walk(left.*, search, myPath);
        if (ret != null) {
            return myPath;
        }
    }

    if (node.right_child) |right| {
        myPath = myPath << 1;
        myPath += 1;
        const ret = walk(right.*, search, myPath);
        std.debug.print("\nright:{?}\n", .{ret});
        if (ret != null) {
            return myPath;
        }
        myPath -= 1;
    }

    return null;
}

test "Walk function" {
    const first = TreeNode{
        .value = 1,
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };

    const second = TreeNode{
        .value = 2,
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };

    const third = TreeNode{
        .value = 3,
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };

    const forth = TreeNode{
        .value = 4,
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };

    const firstParent = TreeNode{
        .value = 0,
        .probability = 0,
        .left_child = &first,
        .right_child = &second,
    };

    const secondParent = TreeNode{
        .value = 0,
        .probability = 0,
        .left_child = &third,
        .right_child = &forth,
    };

    const root = TreeNode{
        .value = 0,
        .probability = 0,
        .left_child = &firstParent,
        .right_child = &secondParent,
    };

    // try expectEqual(walk(root, 1, 0).?, 0);
    try expectEqual(@as(u8, 1), walk(root, 2, 0).?);
    // try expectEqual(walk(root, 3, 0).?, 2);
    // try expectEqual(walk(root, 4, 0).?, 3);
}
