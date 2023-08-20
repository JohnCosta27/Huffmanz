const std = @import("std");
const Encoding = @import("encoding.zig");

pub fn main() !void {
    const args = try std.process.argsAlloc(std.heap.page_allocator);
    const stdout = std.io.getStdOut().writer();

    if (args.len != 4) {
        try stdout.print("You need 3 args\n", .{});
        return;
    }

    const option = args[1];
    const file_path = args[2];
    const output_path = args[3];

    if (compare_strings(option, "encode")) {
        try Encoding.encode(file_path, output_path);
    } else if (compare_strings(option, "decode")) {
        try Encoding.decompress(file_path, output_path);
        return;
    } else {
        try stdout.print("Available options: encode | decode\n", .{});
    }
}

fn compare_strings(str1: []const u8, str2: []const u8) bool {
    var counter: usize = 0;
    if (str1.len != str2.len) return false;

    while (counter < str1.len) {
        if (str1[counter] != str2[counter]) {
            return false;
        }
        counter += 1;
    }

    return true;
}
