const std = @import("std");
const Encoding = @import("encoding.zig");

pub fn main() !void {
    var args = std.process.args();
    _ = args.skip();

    // const allocator = std.heap.page_allocator;
    const file_path = args.next();

    try Encoding.encode(file_path.?);
    try Encoding.decompress();
}
