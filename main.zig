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
    // const myString = "BR.<> Athe quick brown fox jumps over the lazy dog THE QUICK BROWN FOX JUMPS OVER THE LAZY DOG the quick brown fox jumps over the lazy dog  DOG .,/?><";
    const myString = "Lorem ipsum dolor sit amet, consectetur adipiscing elit, sed do eiusmod tempor incididunt ut labore et dolore magna aliqua. Ut enim ad minim veniam, quis nostrud exercitation ullamco laboris nisi ut aliquip ex ea commodo consequat. Duis aute irure dolor in reprehenderit in voluptate velit esse cillum dolore eu fugiat nulla pariatur. Excepteur sint occaecat cupidatat non proident, sunt in culpa qui officia deserunt mollit anim id est laborum.";
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

        item_counter += 1;

        heap.insert(copies[2]);
    }

    const nodePointer = heap.remove().?;

    const BUFFER_SIZE = 10;

    var my_bitmasks = try allocator.alloc(u64, BUFFER_SIZE);
    var bitmask_index: usize = 0;

    my_bitmasks[bitmask_index] = 0;
    var bitmask: *u64 = &my_bitmasks[bitmask_index];

    var bitmask_used: u16 = 0;

    for (myString) |char| {
        // Pattern starting with 1, so that we don't lose the left 0s
        var pattern = walk(nodePointer, char, 1).?;

        // -1 because our pattern contains a left most 1, to not lose the 0s.
        var bits_used: u16 = count_bits_used(pattern) - 1;

        const remaining = @bitSizeOf(u64) - bitmask_used;

        if (remaining < bits_used) {
            var clean_pattern = pattern - std.math.pow(u16, 2, bits_used);
            var split_pattern = @as(u64, clean_pattern >> @truncate(u4, bits_used - remaining));

            bitmask.* |= split_pattern;

            bitmask_index += 1;

            // We must relloac, as we reached end of our buffer.
            if (bitmask_index == my_bitmasks.len) {
                my_bitmasks = try allocator.realloc(my_bitmasks, my_bitmasks.len + BUFFER_SIZE);
            }

            my_bitmasks[bitmask_index] = 0;
            bitmask = &my_bitmasks[bitmask_index];
            bitmask_used = 0;

            // We must take whats left of this current pattern.
            var helper: u16 = @as(u16, 0xFFFF) >> @truncate(u4, 16 - (bits_used - remaining));
            pattern = clean_pattern & helper;
            pattern = pattern + std.math.pow(u16, 2, bits_used - remaining);

            bits_used = bits_used - remaining;
        }

        // Probably a better way to do this.
        // I tried bitshifting, but zig doesn't like shifting by non comptime values.
        var clean_pattern = pattern - std.math.pow(u16, 2, bits_used);
        var shifted_pattern = @as(u64, clean_pattern) << @truncate(u6, (64 - bits_used - bitmask_used));

        bitmask.* |= shifted_pattern;
        bitmask_used += bits_used;
    }

    const file = try std.fs.cwd().createFile("output.bin", .{ .read = true });
    const writer = file.writer();

    var preOrderArr = try allocator.alloc(u8, item_counter);
    var preOrderIndex: usize = 0;
    preOrderTraversal(nodePointer, preOrderArr, &preOrderIndex);

    // Format
    // TreeSize (u16) --- PreOrder [TreeSize]u8 --- HuffmanCode []u8

    const size_as_u8 = std.mem.asBytes(&item_counter);
    const word_size_as_u8 = std.mem.asBytes(&wordSize);

    try writer.writeAll(size_as_u8[0..]);
    try writer.writeAll(word_size_as_u8[0..]);
    try writer.writeAll(preOrderArr[0..]);

    var c: usize = 0;
    while (c <= bitmask_index) {
        try writer.writeAll(std.mem.asBytes(&my_bitmasks[c]));
        c += 1;
    }

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
    std.debug.print("Tree Size: {}\n", .{tree_size});

    const word_size = @as(usize, convertToU64(content[2 .. @sizeOf(usize) + 2]));
    std.debug.print("Word Size: {}\n", .{word_size});

    const offset = @sizeOf(u16) + @sizeOf(usize);

    var index: usize = 0;
    var tree = try build_simple_tree(allocator, content[offset..(tree_size + offset)], &index);

    // Mirrored so we can do % 2 trick to know to go left or right.
    const bitmask_offset = tree_size + offset;

    var bitmasks_used: usize = 0;

    var bitmask: u64 = 0;

    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset]) << 0;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 1]) << 8;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 2]) << 16;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 3]) << 24;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 4]) << 32;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 5]) << 40;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 6]) << 48;
    bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 7]) << 56;

    var word = try allocator.alloc(u8, word_size);
    var char_counter: usize = 0;
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

        if (current_node.value != 0) {
            word[char_counter] = current_node.*.value;
            current_node = tree;
            char_counter += 1;
        }

        mirrored_bitmask = mirrored_bitmask >> 1;

        if (counter != 63) {
            counter += 1;
            continue;
        }

        counter = 0;
        bitmask = 0;
        bitmasks_used += 1;

        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset]) << 0;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 1]) << 8;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 2]) << 16;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 3]) << 24;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 4]) << 32;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 5]) << 40;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 6]) << 48;
        bitmask |= @as(u64, content[bitmasks_used * 8 + bitmask_offset + 7]) << 56;

        mirrored_bitmask = mirror_bitmask(bitmask);
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

fn build_simple_tree(allocator: std.mem.Allocator, preOrder: []u8, index: *usize) !*TreeNode {
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

fn convertToU64(arr: *[8]u8) u64 {
    var result: u64 = 0;
    for (arr.*) |value, i| {
        result |= @as(u64, value) << @truncate(u6, (8 * i));
    }
    return result;
}

fn walk(node: TreeNode, search: u16, path: u16) ?u16 {
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

fn count_bits_used(num: u16) u8 {
    var mask: u16 = 0b1000000000000000;
    var counter: u8 = 0;
    while (mask != 0 and mask & num == 0) {
        counter += 1;
        mask = mask >> 1;
    }
    return @bitSizeOf(u16) - counter;
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
