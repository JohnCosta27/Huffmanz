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

    const nodePointer = heap.remove().?;

    var bitmask: u64 = 0;
    var bitmask_used: u8 = 0;

    for (myString) |char| {
        var pattern = walk(nodePointer, char, 1).?;
        var bits_used = count_bits_used(pattern) - 1;

        // Probably a better way to do this.
        // I tried bitshifting, but zig doesn't like shifting by non comptime values.
        var clean_pattern = pattern - std.math.pow(u8, 2, bits_used);
        var shifted_pattern = @as(u64, clean_pattern) << @truncate(u6, (64 - bits_used - bitmask_used));

        bitmask |= shifted_pattern;
        bitmask_used += bits_used;
    }

    const file = try std.fs.cwd().createFile("output.bin", .{ .read = true });
    const writer = file.writer();

    const bytes = u64ToBytes(bitmask);
    try writer.writeAll(bytes[0..]);
}

fn u64ToBytes(u: u64) []u8 {
    var bytes: [8]u8 = undefined;

    // Manually extract each byte and place it into the slice
    bytes[0] = @truncate(u8, u >> 56);
    bytes[1] = @truncate(u8, u >> 48);
    bytes[2] = @truncate(u8, u >> 40);
    bytes[3] = @truncate(u8, u >> 32);
    bytes[4] = @truncate(u8, u >> 24);
    bytes[5] = @truncate(u8, u >> 16);
    bytes[6] = @truncate(u8, u >> 8);
    bytes[7] = @truncate(u8, u);

    // Convert the fixed-size array into a slice
    return bytes[0..];
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

test "Random stuff" {
    const x = "bruh";

    std.debug.print("\n", .{});
    for (x) |a| {
        std.debug.print("{c}", .{a});
    }
    std.debug.print("\n", .{});
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
