const std = @import("std");

/// A Memory Cell
pub const Cell = struct {
    instruction: u8 = 0, value: i32 = 0
};

/// Little Man Computer Op Codes
pub const OpCode = enum(u8) {
    HLT = 0,
    ADD = 1,
    SUB = 2,
    STA = 3,
    DAT = 4,
    LDA = 5,
    BRA = 6,
    BRZ = 7,
    BRP = 8,
    INP = 9,
    OUT = 10,

    /// Returns whether or not a OpCode should have an argument
    pub fn hasArg(code: OpCode) bool {
        return switch (code) {
            .INP, .HLT, .OUT => false,
            else => true,
        };
    }

    /// Parses a string to a OpCode
    pub fn parse(str: []const u8) ?OpCode {
        const fields = @typeInfo(OpCode).Enum.fields;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, str)) {
                return @intToEnum(OpCode, field.value);
            }
        }

        return null;
    }

    pub fn get_name(code: u8) []const u8 {
        const fields = @typeInfo(OpCode).Enum.fields;
        inline for (fields) |field| {
            if (field.value == code) return field.name;
        }

        return "Unknown";
    }
};
