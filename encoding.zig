const std = @import("std");
const _heap = @import("heap.zig");
const Tree = @import("tree.zig");
const Utils = @import("utils.zig");

const Heap = _heap.Heap;
const TreeNode = Tree.TreeNode;
const BUFFER_SIZE = 10;

fn lessThanTree(A: TreeNode, B: TreeNode) std.math.Order {
    // We want to have the lowest probability be highest priority, hence the inversion.
    return std.math.order(B.probability, A.probability);
}

//
// Handle the encoding from a file path.
// And write endoding to an output file
//
pub fn encode(file_path: [:0]const u8) !void {
    const page_alloc = std.heap.page_allocator;

    const findFile = try std.fs.cwd().openFile(file_path, .{});
    const max_size: usize = 999999;
    var content = try findFile.reader().readAllAlloc(page_alloc, max_size);
    const wordSize = content.len;
    defer page_alloc.free(content);

    // Map between ASCII and frequency
    var charMap = std.AutoHashMap(u8, i32).init(page_alloc);

    for (content) |char| {
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

    var my_bitmasks = try allocator.alloc(u64, BUFFER_SIZE);
    var bitmask_index: usize = 0;

    my_bitmasks[bitmask_index] = 0;
    var bitmask: *u64 = &my_bitmasks[bitmask_index];

    var bitmask_used: u16 = 0;

    for (content) |char| {
        // Pattern starting with 1, so that we don't lose the left 0s
        var pattern = Tree.walk(nodePointer, char, 1).?;

        // -1 because our pattern contains a left most 1, to not lose the 0s.
        var bits_used: u16 = Utils.count_bits_used(pattern) - 1;

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
    Tree.pre_order_traversal(nodePointer, preOrderArr, &preOrderIndex);

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
}

pub fn decompress() !void {
    const page_alloc = std.heap.page_allocator;
    var arena = std.heap.ArenaAllocator.init(page_alloc);
    const allocator = arena.allocator();
    defer arena.deinit();

    const findFile = try std.fs.cwd().openFile("output.bin", .{});
    const max_size: usize = 999999;
    var content = try findFile.reader().readAllAlloc(allocator, max_size);

    const tree_size = @intCast(u16, content[0]) + (@intCast(u16, content[1]) << 8);
    const word_size = @as(usize, Utils.convert_to_u64(content[2 .. @sizeOf(usize) + 2]));

    const offset = @sizeOf(u16) + @sizeOf(usize);

    var index: usize = 0;
    var tree = try Tree.build_simple_tree(allocator, content[offset..(tree_size + offset)], &index);

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

    var mirrored_bitmask = Utils.mirror_bitmask(bitmask);

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

        mirrored_bitmask = Utils.mirror_bitmask(bitmask);
    }

    const file = try std.fs.cwd().createFile("output.txt", .{ .read = true });
    const writer = file.writer();

    try writer.writeAll(word[0..]);
}
