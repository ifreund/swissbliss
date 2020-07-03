const std = @import("std");
const testing = std.testing;

export fn add(a: i32, b: i32) i32 {
    return a + b;
}

test "" {
    _ = @import("bit_mask.zig");
}

test "basic add functionality" {
    testing.expect(add(3, 7) == 10);
}
