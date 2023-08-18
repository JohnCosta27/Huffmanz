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
    const myString = "this is a longer wz";
    const wordSize = myString.len;

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
    var item_counter: u16 = 0;

    while (mapIter.next()) |entry| {
        const node = try allocator.create(TreeNode);
        node.* = .{
            .value = entry.key_ptr.*,
            .probability = entry.value_ptr.*,
            .left_child = null,
            .right_child = null,
        };
        item_counter += 1;
        heap.insert(node.*);
    }

    var internal_counter: u8 = 0;

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
            .value = internal_counter,
            .probability = left.?.probability + right.?.probability,
            .left_child = &copies[0],
            .right_child = &copies[1],
        };

        item_counter += 1;
        internal_counter += 1;

        heap.insert(copies[2]);
    }

    const nodePointer = heap.remove().?;

    var bitmask: u64 = 0;
    var bitmask_used: u8 = 0;

    for (myString) |char| {
        var pattern = walk(nodePointer, char, 1).?;
        var bits_used = count_bits_used(pattern) - 1;

        var remaining = @as(i16, @bitSizeOf(u64)) - @as(i16, bitmask_used);

        if (remaining < bits_used) {
            // How many bits we need to fit into the current u64 mask
            // const fit = bits_used - remaining;

            var helper: u8 = std.math.pow(u8, 2, bits_used);

            std.debug.print("pattern: {b}\n", .{pattern});
            std.debug.print("helper: {b}\n", .{helper});

            std.debug.print("left bit: {b}\n", .{pattern & helper});
            helper = helper >> 1;

            std.debug.print("left bit: {b}\n", .{pattern & helper});
            helper = helper >> 1;

            std.debug.print("left bit: {b}\n", .{pattern & helper});
            helper = helper >> 1;

            std.debug.print("left bit: {b}\n", .{pattern & helper});
            helper = helper >> 1;

            std.debug.print("left bit: {b}\n", .{pattern & helper});
            helper = helper >> 1;
        }

        // Probably a better way to do this.
        // I tried bitshifting, but zig doesn't like shifting by non comptime values.
        var clean_pattern = pattern - std.math.pow(u8, 2, bits_used);
        var shifted_pattern = @as(u64, clean_pattern) << @truncate(u6, (64 - bits_used - bitmask_used));

        bitmask |= shifted_pattern;
        bitmask_used += bits_used;
    }

    const file = try std.fs.cwd().createFile("output.bin", .{ .read = true });
    const writer = file.writer();

    const bytes = std.mem.asBytes(&bitmask);

    var preOrderArr = try allocator.alloc(u8, item_counter);
    var preOrderIndex: usize = 0;
    preOrderTraversal(nodePointer, preOrderArr, &preOrderIndex);

    var inOrderArr = try allocator.alloc(u8, item_counter);
    var inOrderIndex: usize = 0;
    inOrderTraversal(nodePointer, inOrderArr, &inOrderIndex);

    // Format
    // TreeSize (u16) --- PreOrder [TreeSize]u8 --- InOrder [Treesize]u8 --- HuffmanCode []u8

    const size_as_u8 = std.mem.asBytes(&item_counter);
    const word_size_as_u8 = std.mem.asBytes(&wordSize);

    std.debug.print("{b}\n", .{bitmask});

    try writer.writeAll(size_as_u8[0..]);
    try writer.writeAll(word_size_as_u8[0..]);
    try writer.writeAll(preOrderArr[0..]);
    try writer.writeAll(inOrderArr[0..]);
    try writer.writeAll(bytes[0..]);

    try decompress();
}

fn decompress() !void {
    const page_alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_alloc);
    const allocator = arena.allocator();
    defer arena.deinit();

    const findFile = try std.fs.cwd().openFile("output.bin", .{});
    const max_size: usize = 999999;
    var content = try findFile.reader().readAllAlloc(allocator, max_size);

    const tree_size = @intCast(u16, content[0]) + (@intCast(u16, content[1]) << 8);

    const word_size = @as(usize, convertToU64(content[2 .. @sizeOf(usize) + 2]));
    std.debug.print("Word Size: {}\n", .{word_size});

    const offset = @sizeOf(u16) + @sizeOf(usize);

    var index: u8 = 0;
    var tree = try build_tree(allocator, content[offset..(tree_size + offset)], content[(tree_size + offset)..(tree_size * 2 + offset)], 0, @truncate(u8, tree_size) - 1, &index);

    // Mirrored so we can do % 2 trick to know to go left or right.
    const bitmask_offset = tree_size * 2 + offset;

    var bitmask: u64 = 0;

    bitmask |= @as(u64, content[bitmask_offset]) << 0;
    bitmask |= @as(u64, content[bitmask_offset + 1]) << 8;
    bitmask |= @as(u64, content[bitmask_offset + 2]) << 16;
    bitmask |= @as(u64, content[bitmask_offset + 3]) << 24;
    bitmask |= @as(u64, content[bitmask_offset + 4]) << 32;
    bitmask |= @as(u64, content[bitmask_offset + 5]) << 40;
    bitmask |= @as(u64, content[bitmask_offset + 6]) << 48;
    bitmask |= @as(u64, content[bitmask_offset + 7]) << 56;

    var word = try allocator.alloc(u8, word_size);
    var char_counter: u8 = 0;
    var current_node: *const TreeNode = tree;

    var mirrored_bitmask = mirror_bitmask(bitmask);

    var counter: u8 = 0;
    while (counter < 64 and char_counter < word_size) {
        const first_bit = mirrored_bitmask & 1;

        if (first_bit == 1) {
            current_node = current_node.right_child.?;
        } else {
            current_node = current_node.left_child.?;
        }

        // Fix later. Using 30 because I had to randomise internal tree nodes values.
        if (current_node.value > 30) {
            word[char_counter] = current_node.value;
            current_node = tree;
            char_counter += 1;
        }

        mirrored_bitmask = mirrored_bitmask >> 1;
        counter += 1;
    }

    std.debug.print("\n", .{});
    for (word) |c| {
        std.debug.print("{c}", .{c});
    }
    std.debug.print("\n", .{});
}

fn preOrderTraversal(node: TreeNode, arr: []u8, arrPointer: *usize) void {
    arr[arrPointer.*] = node.value;
    arrPointer.* += 1;

    if (node.left_child) |left| {
        preOrderTraversal(left.*, arr, arrPointer);
    }

    if (node.right_child) |right| {
        preOrderTraversal(right.*, arr, arrPointer);
    }
}

fn inOrderTraversal(node: TreeNode, arr: []u8, arrPointer: *usize) void {
    if (node.left_child) |left| {
        inOrderTraversal(left.*, arr, arrPointer);
    }

    arr[arrPointer.*] = node.value;
    arrPointer.* += 1;

    if (node.right_child) |right| {
        inOrderTraversal(right.*, arr, arrPointer);
    }
}

fn search_node(traversal: []u8, value: u8) u8 {
    var i: u8 = 0;
    while (i < traversal.len) {
        if (traversal[i] == value) {
            return i;
        }
        i += 1;
    }
    @panic("Could not find node in traversal");
}

fn build_tree(allocator: std.mem.Allocator, preOrder: []u8, inOrder: []u8, inOrderStart: u8, inOrderEnd: u8, preOrderIndex: *u8) !*TreeNode {
    if (inOrderStart > inOrderEnd) {
        return undefined;
    }

    var node = try allocator.create(TreeNode);
    node.* = .{
        .value = preOrder[preOrderIndex.*],
        .probability = 0,
        .left_child = null,
        .right_child = null,
    };
    preOrderIndex.* += 1;

    if (inOrderStart == inOrderEnd) {
        return node;
    }

    const inOrderIndex = search_node(inOrder, node.value);

    node.left_child = try build_tree(allocator, preOrder, inOrder, inOrderStart, inOrderIndex - 1, preOrderIndex);
    node.right_child = try build_tree(allocator, preOrder, inOrder, inOrderIndex + 1, inOrderEnd, preOrderIndex);

    return node;
}

fn convertToU64(arr: *[8]u8) u64 {
    var result: u64 = 0;
    for (arr.*) |value, i| {
        result |= @as(u64, value) << @truncate(u6, (8 * i));
    }
    return result;
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

fn count_bits_used(num: u8) u8 {
    var mask: u8 = 0b10000000;
    var counter: u8 = 0;
    while (mask != 0 and mask & num == 0) {
        counter += 1;
        mask = mask >> 1;
    }
    return 8 - counter;
}

fn mirror_bitmask(bitmask: u64) u64 {
    var mirrored: u64 = 0;
    var i: usize = 0;
    while (i < @bitSizeOf(u64)) {
        mirrored |= (bitmask >> @truncate(u6, i) & 1) << @truncate(u6, @bitSizeOf(u64) - 1 - i);
        i += 1;
    }
    return mirrored;
}

test "Flip number\n" {
    var x: u8 = 0b11101010;

    try expectEqual(mirror_bitmask(x), 0b01010111);
}

test "left most function" {
    try expectEqual(@as(u8, 8), count_bits_used(0b11111111));
    try expectEqual(@as(u8, 7), count_bits_used(0b01111111));
    try expectEqual(@as(u8, 6), count_bits_used(0b00111111));
    try expectEqual(@as(u8, 5), count_bits_used(0b00011111));
    try expectEqual(@as(u8, 4), count_bits_used(0b00001111));
    try expectEqual(@as(u8, 3), count_bits_used(0b00000111));
    try expectEqual(@as(u8, 2), count_bits_used(0b00000011));
    try expectEqual(@as(u8, 1), count_bits_used(0b00000001));
    try expectEqual(@as(u8, 0), count_bits_used(0b00000000));
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

    const page_alloc = std.heap.page_allocator;

    var preOrderArr = try page_alloc.alloc(u8, 7);
    var preOrderPointer: usize = 0;
    preOrderTraversal(root, preOrderArr, &preOrderPointer);

    var inOrderArr = try page_alloc.alloc(u8, 7);
    var inOrderPointer: usize = 0;
    inOrderTraversal(root, inOrderArr, &inOrderPointer);

    // std.debug.print("\n", .{});
    // for (preOrderArr) |item| {
    // std.debug.print("{}, ", .{item});
    // }
    // std.debug.print("\n", .{});
    //
    // std.debug.print("\n", .{});
    // for (inOrderArr) |item| {
    // std.debug.print("{}, ", .{item});
    // }
    // std.debug.print("\n", .{});

    // Important to start with 1. otherwise bitshifting on 0s would do nothing.
    try expectEqual(@as(u8, 0b00000100), walk(root, 1, 1).?);
    try expectEqual(@as(u8, 0b00000101), walk(root, 2, 1).?);
    try expectEqual(@as(u8, 0b00000110), walk(root, 3, 1).?);
    try expectEqual(@as(u8, 0b00000111), walk(root, 4, 1).?);

    var bitmask: u64 = 0;
    var bitmask_used: u8 = 0;

    var bruh = walk(root, 1, 1).?;
    // Minus 1 because of the beginning 1.
    var bruhUsed = count_bits_used(bruh) - 1;
    try expectEqual(@as(u8, 2), bruhUsed);

    var cleanBruh = bruh - std.math.pow(u8, 2, bruhUsed);
    try expectEqual(@as(u8, 0b00000000), cleanBruh);

    var shifted_bits: u64 = @as(u64, cleanBruh);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + bruhUsed)));

    bitmask |= shifted_bits;
    bitmask_used += bruhUsed;

    var test_counter: u64 = 0;

    try expectEqual(@as(u8, 2), bitmask_used);
    try expectEqual(test_counter, bitmask);

    // ------------

    bruh = walk(root, 4, 1).?;
    bruhUsed = count_bits_used(bruh) - 1;
    cleanBruh = bruh - std.math.pow(u8, 2, bruhUsed);

    try expectEqual(@as(u8, 2), bruhUsed);
    try expectEqual(@as(u8, 0b00000111), bruh);
    try expectEqual(@as(u8, 0b00000011), cleanBruh);
    try expectEqual(@as(u8, 2), bruhUsed);

    shifted_bits = @as(u64, cleanBruh);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + bruhUsed)));

    bitmask |= shifted_bits;
    bitmask_used += bruhUsed;

    test_counter += std.math.pow(u64, 2, 61) + std.math.pow(u64, 2, 60);

    try expectEqual(@as(u8, 4), bitmask_used);
    try expectEqual(@as(u64, test_counter), bitmask);

    // ----------

    bruh = walk(root, 3, 1).?;
    bruhUsed = count_bits_used(bruh) - 1;
    cleanBruh = bruh - std.math.pow(u8, 2, bruhUsed);

    try expectEqual(@as(u8, 2), bruhUsed);
    try expectEqual(@as(u8, 0b00000110), bruh);
    try expectEqual(@as(u8, 0b00000010), cleanBruh);
    try expectEqual(@as(u8, 2), bruhUsed);

    shifted_bits = @as(u64, cleanBruh);
    shifted_bits = shifted_bits << @truncate(u6, (64 - (bitmask_used + bruhUsed)));

    bitmask |= shifted_bits;
    bitmask_used += bruhUsed;

    test_counter += std.math.pow(u64, 2, 59);

    try expectEqual(@as(u8, 6), bitmask_used);
    try expectEqual(test_counter, bitmask);
}
