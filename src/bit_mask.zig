const std = @import("std");

/// A simple abstraction over a bitmask allowing for nice iteration.
pub fn BitMask(comptime T: type) type {
    return struct {
        const Self = @This();

        /// An unsigned integer type with the minimum number of bits needed to
        /// represent the bit count of T.
        const BitIndex = std.meta.Int(false, 32 - @clz(u32, T.bit_count));

        mask: T,

        /// Iterate over the bitmask, consuming it. Returns the bit index of
        /// each set bit until there are no more set bits, then null.
        pub fn next(self: *Self) ?BitIndex {
            if (self.mask == 0) return null;
            const ret = @ctz(T, self.mask);
            self.removeLowestBit();
            return ret;
        }

        fn removeLowestBit(self: *Self) void {
            self.mask &= self.mask - 1;
        }
    };
}

test "bitmask iteration" {
    const testing = @import("std").testing;

    const expected = &[_]u6{ 0, 2 };
    var i: u32 = 0;

    var bit_mask = BitMask(u32){ .mask = 0x5 };

    for (expected) |e| testing.expectEqual(bit_mask.next(), e);
    testing.expectEqual(bit_mask.next(), null);
}
