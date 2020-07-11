const std = @import("std");
const Allocator = std.mem.Allocator;

/// Reads a string buffer by token
pub const TokenReader = struct {
    delimiters: []const u8 = " \n\t",
    comment: u8 = '#',
    cursor: usize = 0,
    allocator: *Allocator,
    buffer: []const u8,

    /// Makes a copy of the specified string and creates a TokenReader
    pub fn init(allocator: *Allocator, str: []const u8) !TokenReader {
        const buffer = try allocator.alloc(u8, str.len);
        std.mem.copy(u8, buffer, str);
        return TokenReader{
            .allocator = allocator,
            .buffer = buffer,
        };
    }

    /// Free's buffer of the Token Reader
    pub fn deinit(self: *TokenReader) void {
        self.allocator.free(self.buffer);
    }

    /// Returns whether a character is a delimiter
    fn isDelimiter(self: *TokenReader, ch: u8) bool {
        for (self.delimiters) |delim| {
            if (ch == delim) return true;
        }
        return false;
    }

    /// Resets the cursor back to the start
    pub fn reset(self: *TokenReader) void {
        self.cursor = 0;
    }

    /// Returns a slice of the next token in the buffer
    pub fn nextToken(self: *TokenReader) ?[]const u8 {
        var i: usize = self.cursor;
        var inComment = false;
        while (i < self.buffer.len) : (i += 1) {
            // Comments should end at new lines
            if (inComment and self.buffer[i] == '\n') {
                self.cursor = i;
                inComment = false;
            }

            // Check for a comment
            if (self.buffer[i] == self.comment) inComment = true;
            if (inComment) continue;

            // Edge case for the final token
            if (i == self.buffer.len - 1) {
                const start = self.cursor;
                self.cursor = i + 1;
                return self.buffer[start..self.buffer.len];
            }

            if (!self.isDelimiter(self.buffer[self.cursor])) {
                if (self.isDelimiter(self.buffer[i])) {
                    const start = self.cursor;
                    self.cursor = i;
                    return self.buffer[start..i];
                }
            } else {
                if (!self.isDelimiter(self.buffer[i])) {
                    self.cursor = i;
                }
            }
        }

        return null;
    }
};
