const std = @import("std");

const group_size = 16;

// TODO: let's make it so we can have a vector of non-exhaustive enums
const Ctrl = enum(i8) {
    empty = -128, // 0b10000000
    deleted = -2, // 0b11111110
    sentinel = -1, // 0b11111111
    // full = 0b0xxxxxxx

    fn isFull(ctrl: i8) bool {
        return ctrl >= 0;
    }

    fn isEmpty(ctrl: i8) bool {
        return ctrl == Ctrl.empty;
    }

    fn isDeleted(ctrl: i8) bool {
        return ctrl == Ctrl.deleted;
    }

    fn isEmptyOrDeleted(ctrl: i8) bool {
        return ctrl < Ctrl.sentinel;
    }
};

// only var because we need to store pointers to it, it should never be modified.
var empty_group = [_]i8{Ctrl.sentinel} ++ [_]i8{Ctrl.empty} ** (group_size - 1);

pub fn RawHashMap(
    comptime K: type,
    comptime V: type,
    comptime hash_fn: fn (K) u32,
    comptime eql: fn (K, K) bool,
) type {
    return struct {
        const Self = @This();

        const KV = struct {
            key: K,
            value: value,
        };

        allocator: *std.mem.Allocator,
        slots: ?[*]KV,
        ctrls: [*]i8,
        size: usize,
        capacity: usize,

        /// Create a new, empty hash map.
        pub fn init(allocator: *std.mem.Allocator) Self {
            return Self{
                .allocator = allocator,
                .slots = null,
                .ctrls = &empty_group,
                .size = 0,
                .capacity = 0,
            };
        }

        /// Free all the allocated memory and reset to the initial, empty state.
        pub fn deinit(self: *Self) void {
            if (self.capacity == 0) return;

            var alloc: []u8 = undefined;
            alloc.ptr = @ptrCast([*]u8, self.slots);
            alloc.len = self.allocSize();
            self.allocator.free(alloc);

            self.slots = null;
            self.ctrls = &empty_group;
            self.size = 0;
            self.capacity = 0;
        }

        fn allocSize(capacity: usize) usize {
            return (@sizeOf(KV) + @sizeOf(i8)) * capacity + group_size + 1;
        }

        fn rehash(self: *Self, target: usize) void {
            if (target == 0 and self.capacity == 0) return;
            if (target == 0 and self.size == 0) {
                self.deinit();
                return;
            }
        }

        fn resize(self: *Self, new_capacity: usize) !void {
            std.debug.assert(isValidCapacity(new_capacity));

            const old_slots = self.slots;
            const old_ctrls = self.ctrls;
            const old_capacity = self.capacity;
            defer if (old_capacity != 0) {
                var alloc: []u8 = undefined;
                alloc.ptr = @ptrCast([*]u8, old_slots);
                alloc.len = allocSize(old_capacity);
                self.allocator.free(alloc);
            };

            self.capacity = new_capacity;
            const alloc = try self.allocator.allocAdvanced(u8, @alignOf(KV), allocSize(new_capacity), .exact);
            self.slots = @ptrCast([*]KV, alloc.ptr);
            self.ctrls = @ptrCast([*]i8, alloc.ptr + self.capacity * @sizeOf(KV));

            var total_probe_length: usize = 0;
            var i: usize = 0;
            while (i != old_capacity) : (i += 1) {
                if (Ctrl.isFull(old_ctrls[i])) {
                    const hash = hash_fn(old_slots[i]);
                    // TODO
                }
            }
        }
    };
}

// 1, 3, 7, 15, 31, 63, etc.
fn isValidCapacity(capacity: usize) bool {
    return (capacity + 1) & capacity == 0 and capacity > 0;
}

fn growthToLowerBoundCapacity(target: usize) usize {
    return;
}

fn h1(hash: u64) u57 {
    return hash >> 7;
}

fn h2(hash: u64) u7 {
    return @truncate(u7, hash);
}

fn Group(size: comptime_int) type {
    return struct {
        const Self = @This();

        ctrls: std.meta.Vector(size, i8),

        fn init(ctrls: [size]i8) Self {
            return Self{ .ctrls = ctrls };
        }

        fn match(self: Self, h2: u7) BitMaskIter(u16) {
            return self.matchInternal(@as(i8, h2));
        }

        fn matchEmpty(self: Self) BitMaskIter(u16) {
            // TODO: maybe use _mm_sign_epi8
            return self.matchInternal(Ctrl.empty);
        }

        fn matchEmptyOrDeleted() BitMaskIter(u16) {
            var cmp = @splat(size, Ctrl.sentinel) > ctrls;
            return BitMaskIter(u16){ .mask = @ptrCast(*u16, &cmp).* };
        }

        fn matchInternal(self: Self, target: i8) BitMaskIter(u16) {
            var cmp = self.ctrls == @splat(size, target);
            return BitMaskIter(u16){ .mask = @ptrCast(*u16, &cmp).* };
        }
    };
}

fn BitMaskIter(comptime T: type) type {
    return struct {
        /// An unsigned integer type with the minimum number of bits needed to
        /// represent the bit count of T.
        const BitIndex = std.meta.Int(false, 32 - @clz(u32, T.bit_count));

        mask: T,

        /// Iterate over the bitmask, consuming it. Returns the bit index of
        /// each set bit until there are no more set bits, then null.
        fn next(self: *BitMaskIter) ?BitIndex {
            if (self.mask == 0) return null;
            const ret = @ctz(T, self.mask);
            self.mask &= self.mask - 1; // remove the lowest set bit
            return ret;
        }
    };
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

test "bitmask iteration" {
    const testing = @import("std").testing;

    const expected = &[_]u6{ 0, 2 };
    var i: u32 = 0;

    var bit_mask = BitMask(u32){ .mask = 0x5 };

    for (expected) |e| testing.expectEqual(bit_mask.next(), e);
    testing.expectEqual(bit_mask.next(), null);
}
