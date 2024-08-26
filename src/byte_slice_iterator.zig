const std = @import("std");

pub const ByteSliceIterator = struct {
    const Self = @This();

    bytes: []const u8,
    slice_len: usize,
    index: usize = 0,

    pub fn next(self: *Self) ?[]const u8 {
        // Return null if the end of the bytes is reached
        if (self.index >= self.bytes.len) {
            return null;
        }

        // Start position of the row
        const start = self.index;

        // Find the end position of the slice to return
        var end = self.index + self.slice_len;
        if (end > self.bytes.len) {
            end = self.bytes.len;
        }

        // Update the index
        self.index = end;

        // Return the slice
        return self.bytes[start..end];
    }
};

test "iterator" {
    const bytes = [_]u8{ 65, 66, 64 };

    var row_iterator = ByteSliceIterator{
        .bytes = &bytes,
        .slice_len = 2,
    };

    while (row_iterator.next()) |row| {
        std.debug.print("{s}\n", .{row});
    }
}
