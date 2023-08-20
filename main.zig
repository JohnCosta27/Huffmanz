const Encoding = @import("encoding.zig");

pub fn main() !void {
    try Encoding.encode();
    try Encoding.decompress();
}
