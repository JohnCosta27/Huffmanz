const std = @import("std");
const expectEqual = std.testing.expectEqual;

pub fn convert_to_u64(arr: *[8]u8) u64 {
    var result: u64 = 0;
    for (arr.*) |value, i| {
        result |= @as(u64, value) << @truncate(u6, (8 * i));
    }
    return result;
}

pub fn count_bits_used(num: u16) u8 {
    var mask: u16 = 0b1000000000000000;
    var counter: u8 = 0;
    while (mask != 0 and mask & num == 0) {
        counter += 1;
        mask = mask >> 1;
    }
    return @bitSizeOf(u16) - counter;
}

pub fn mirror_bitmask(bitmask: u64) u64 {
    var mirrored: u64 = 0;
    var i: usize = 0;
    while (i < @bitSizeOf(u64)) {
        mirrored |= (bitmask >> @truncate(u6, i) & 1) << @truncate(u6, @bitSizeOf(u64) - 1 - i);
        i += 1;
    }
    return mirrored;
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
