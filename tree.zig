const std = @import("std");
const utils = @import("utils.zig");

pub const TreeNode = struct {
    // char
    value: u8,
    probability: i32,
    left_child: ?*const TreeNode,
    right_child: ?*const TreeNode,
};

pub fn pre_order_traversal(node: TreeNode, arr: []u8, arrPointer: *usize) void {
    arr[arrPointer.*] = node.value;
    arrPointer.* += 1;

    if (node.left_child) |left| {
        pre_order_traversal(left.*, arr, arrPointer);
    }

    if (node.right_child) |right| {
        pre_order_traversal(right.*, arr, arrPointer);
    }
}

pub fn build_simple_tree(allocator: std.mem.Allocator, preOrder: []u8, index: *usize) !*TreeNode {
    if (preOrder[index.*] != 0) {
        var node = try allocator.create(TreeNode);
        node.* = .{
            .value = preOrder[index.*],
            .probability = 0,
            .left_child = null,
            .right_child = null,
        };
        index.* += 1;
        return node;
    }
    var node = try allocator.create(TreeNode);
    node.* = .{
        .value = 0,
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };
    index.* += 1;

    node.*.left_child = try build_simple_tree(allocator, preOrder, index);
    node.*.right_child = try build_simple_tree(allocator, preOrder, index);

    return node;
}

pub fn walk(node: TreeNode, search: u16, path: u16) ?u16 {
    var myPath = path;

    if (node.value == search) {
        return myPath;
    }

    if (node.left_child) |left| {
        myPath = myPath << 1;
        const ret = walk(left.*, search, myPath);
        if (ret != null) {
            return ret;
        }
        myPath = myPath >> 1;
    }

    if (node.right_child) |right| {
        myPath = myPath << 1;
        myPath += 1;
        var ret = walk(right.*, search, myPath);
        if (ret != null) {
            return ret;
        }
        myPath -= 1;
        myPath = myPath >> 1;
    }

    return null;
}

const expect = std.testing.expect;
const expectEqual = std.testing.expectEqual;

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

    const page_alloc = std.heap.page_allocator;

    var preOrderArr = try page_alloc.alloc(u8, 7);
    var preOrderPointer: usize = 0;
    pre_order_traversal(root, preOrderArr, &preOrderPointer);

    // Important to start with 1. otherwise bitshifting on 0s would do nothing.
    try expectEqual(@as(u16, 0b00000100), walk(root, 1, 1).?);
    try expectEqual(@as(u16, 0b00000101), walk(root, 2, 1).?);
    try expectEqual(@as(u16, 0b00000110), walk(root, 3, 1).?);
    try expectEqual(@as(u16, 0b00000111), walk(root, 4, 1).?);

    var bitmask: u64 = 0;
    var bitmask_used: u16 = 0;

    var pattern = walk(root, 1, 1).?;
    // Minus 1 because of the beginning 1.
    var pattern_used = utils.count_bits_used(pattern) - 1;
    try expectEqual(@as(u16, 2), pattern_used);

    var clean_pattern = pattern - std.math.pow(u8, 2, pattern_used);
    try expectEqual(@as(u16, 0b00000000), clean_pattern);

    var shifted_bits: u64 = @as(u64, clean_pattern);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + pattern_used)));

    bitmask |= shifted_bits;
    bitmask_used += pattern_used;

    var test_counter: u64 = 0;

    try expectEqual(@as(u16, 2), bitmask_used);
    try expectEqual(test_counter, bitmask);

    // ------------

    pattern = walk(root, 4, 1).?;
    pattern_used = utils.count_bits_used(pattern) - 1;
    clean_pattern = pattern - std.math.pow(u8, 2, pattern_used);

    try expectEqual(@as(u16, 2), pattern_used);
    try expectEqual(@as(u16, 0b00000111), pattern);
    try expectEqual(@as(u16, 0b00000011), clean_pattern);
    try expectEqual(@as(u16, 2), pattern_used);

    shifted_bits = @as(u64, clean_pattern);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + pattern_used)));

    bitmask |= shifted_bits;
    bitmask_used += pattern_used;

    test_counter += std.math.pow(u64, 2, 61) + std.math.pow(u64, 2, 60);

    try expectEqual(@as(u16, 4), bitmask_used);
    try expectEqual(@as(u64, test_counter), bitmask);

    // ----------

    pattern = walk(root, 3, 1).?;
    pattern_used = utils.count_bits_used(pattern) - 1;
    clean_pattern = pattern - std.math.pow(u8, 2, pattern_used);

    try expectEqual(@as(u16, 2), pattern_used);
    try expectEqual(@as(u16, 0b00000110), pattern);
    try expectEqual(@as(u16, 0b00000010), clean_pattern);
    try expectEqual(@as(u16, 2), pattern_used);

    shifted_bits = @as(u64, clean_pattern);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + pattern_used)));

    bitmask |= shifted_bits;
    bitmask_used += pattern_used;

    test_counter += std.math.pow(u64, 2, 59);

    try expectEqual(@as(u16, 6), bitmask_used);
    try expectEqual(test_counter, bitmask);
}
