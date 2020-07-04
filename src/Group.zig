const Self = @This();

const std = @import("std");
const BitMask = @import("bit_mask.zig").BitMask;

// TODO: let's make it so we can have a vector of non-exhaustive enums
const Ctrl = enum(i8) {
    empty = -128, // 0b10000000
    deleted = -2, // 0b11111110
    sentinel = -1, // 0b11111111
    // full = 0b0xxxxxxx
};

ctrls: std.meta.Vector(16, i8),

pub fn init(ctrls: [*]const i8) Self {
    return Self{
        .ctrls = ctrls[0..16].*,
    };
}

pub fn match(self: Self, h2: u7) BitMask(u16) {
    return self.matchInternal(@as(i8, h2));
}

pub fn matchEmpty(self: Self) BitMask(u16) {
    // TODO: maybe use _mm_sign_epi8
    return self.matchInternal(Ctrl.empty);
}

pub fn matchEmptyOrDeleted() BitMask(u16) {
    var cmp = @splat(16, Ctrl.sentinel) > ctrls;
    return BitMask(u16){ .mask = @ptrCast(*u16, &cmp).* };
}

fn matchInternal(self: Self, target: i8) BitMask(u16) {
    var cmp = self.ctrls == @splat(16, target);
    return BitMask(u16){ .mask = @ptrCast(*u16, &cmp).* };
}

test "group match" {
    const testing = std.testing;

    const hash = 0b1010101;
    const ctrls = @bitCast([16]i8, [16]u8{
        0b0111110,
        0b1011101,
        0b1101011,
        0b1010101,
        0b1101011,
        0b1011101,
        0b0111110,
        0b1010101,
        0b1111111,
        0b0000000,
        0b1111111,
        0b1011101,
        0b1110111,
        0b1011101,
        0b1111111,
        0b1010101,
    });

    const group = Self.init(&ctrls);
    var mask_it = group.match(hash);

    const expected = [_]u5{ 3, 7, 15 };
    for (expected) |e| testing.expectEqual(mask_it.next(), e);
    testing.expectEqual(mask_it.next(), null);
}
