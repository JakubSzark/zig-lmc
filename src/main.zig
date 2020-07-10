const std = @import("std");
const malloc = std.heap.c_allocator;
const print = std.debug.print;

const Allocator = std.mem.Allocator;

/// Errors the may occur when retrieving arguments
const ArgGetError = error{
    OutOfMemory,
    DoesNotExist,
};

/// Returns a CLI argument at the specified index.
/// Argument must be freed after use.
fn getArg(index: usize) ArgGetError![]u8 {
    const NextError = std.process.ArgIterator.NextError;

    var i: usize = 0;
    var args = std.process.args();
    while (args.next(malloc)) |arg| {
        if (arg) |a| {
            if (i == index) return a;
            malloc.free(a);
        } else |err| switch (err) {
            NextError.OutOfMemory => return error.OutOfMemory,
        }

        i += 1;
    }

    return error.DoesNotExist;
}

/// Reads a file at the CWD into a string.
/// String must be freed after use.
fn readFileAsString(path: []const u8) ![]u8 {
    var file = try std.fs.cwd().openFile(path, .{});
    defer file.close();
    const totalBytes = try file.getEndPos();
    var buffer = try malloc.alloc(u8, totalBytes);
    _ = try file.read(buffer);
    return buffer;
}

/// Reads a string buffer by token
const TokenReader = struct {
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

/// Check if string contains a character
fn findChar(str: []const u8, char: u8) i32 {
    for (str) |ch, i| if (ch == char) return @intCast(i32, i);
    return -1;
}

/// Little Man Computer Op Codes
const OpCode = enum(usize) {
    HLT = 0,
    ADD = 100,
    SUB = 200,
    STA = 300,
    DAT = 400,
    LDA = 500,
    BRA = 600,
    BRZ = 700,
    BRP = 800,
    INP = 901,
    OUT = 902,

    /// Returns whether or not a OpCode should have an argument
    pub fn hasArg(code: OpCode) bool {
        return switch (code) {
            .INP, .HLT, .OUT => false,
            else => true,
        };
    }

    /// Parses a string to a OpCode
    fn parse(str: []const u8) ?OpCode {
        const fields = @typeInfo(OpCode).Enum.fields;
        inline for (fields) |field| {
            if (std.mem.eql(u8, field.name, str)) {
                return @intToEnum(OpCode, field.value);
            }
        }

        return null;
    }
};

/// Errors that may happen during instruction parsing
const ParseError = error{
    ArgumentFormat,
    ArgumentMissing,
    UnknownInstruction,
};

/// Prints a token
fn printToken(token: []const u8) void {
    print("{} <-- ", .{token});
}

/// Parses a file into a LMC instruction set
fn parseInstructions(reader: *TokenReader) ![100]usize {
    var labels = std.StringHashMap(u8).init(malloc);
    defer labels.deinit();

    // Parse labels into HashMap
    var instruction: u8 = 0;
    while (reader.nextToken()) |token| {
        // Check if contains a colon
        const colonIndex = findChar(token, ':');

        if (colonIndex != -1) {
            const label = token[0..@intCast(usize, colonIndex)];
            try labels.putNoClobber(label, instruction);
            continue;
        }

        if (OpCode.parse(token)) |_| {
            instruction += 1;
        }
    }

    reader.reset();
    var instructions = [_]usize{0} ** 100;

    // Parse instructions into OpCodes
    instruction = 0;
    while (reader.nextToken()) |token| {
        // Make sure its not a label
        if (findChar(token, ':') == -1) {
            if (OpCode.parse(token)) |op_code| {
                if (op_code != OpCode.DAT) {
                    instructions[instruction] = @enumToInt(op_code);
                }

                // We need to process the argument
                if (OpCode.hasArg(op_code)) {
                    if (reader.nextToken()) |arg_token| {
                        if (arg_token[0] == '$') {
                            // Parse memory address string into integer
                            if (std.fmt.parseInt(usize, arg_token[1..], 10)) |value| {
                                instructions[instruction] += value;
                            } else |err| {
                                printToken(arg_token);
                                return ParseError.ArgumentFormat;
                            }
                        } else if (labels.contains(arg_token)) {
                            if (labels.get(arg_token)) |address| {
                                instructions[instruction] += address;
                            }
                        } else if (op_code == OpCode.DAT) {
                            if (std.fmt.parseInt(usize, arg_token, 10)) |value| {
                                instructions[instruction] = value;
                            } else |err| {
                                printToken(arg_token);
                                return ParseError.ArgumentFormat;
                            }
                        } else {
                            printToken(arg_token);
                            return ParseError.ArgumentFormat;
                        }
                    } else {
                        printToken(token);
                        return ParseError.ArgumentMissing;
                    }
                }

                print("[{}] {}\n", .{ instruction, instructions[instruction] });

                instruction += 1;
            } else {
                printToken(token);
                return ParseError.UnknownInstruction;
            }
        }
    }

    return instructions;
}

/// Scanf from C lib
extern fn scanf(format: [*:0]const u8, [*]u8) i32;

/// Executes a set of LMC instructions
fn executeInstructions(instructions: *[100]usize) void {
    print("\n", .{});
    var step: usize = 0;
    var accum: usize = 0;

    var is_running = true;
    while (is_running) {
        // Get first digit of the instruction
        const inst = instructions[step];
        const first_digit = @floatToInt(usize, @floor(@intToFloat(f32, inst) / 100.0));

        switch (first_digit) {
            9 => { // INP, OUT
                if (inst == 901) {
                    // Get Input from User
                    print("> ", .{});
                    const BUFFER_SIZE: usize = 128;
                    var buffer = [_]u8{0} ** BUFFER_SIZE;
                    var index: usize = 0;
                    _ = scanf("%s", &buffer);

                    const end = @intCast(usize, findChar(&buffer, 0));

                    if (std.fmt.parseInt(usize, buffer[0..end], 10)) |value| {
                        accum = value;
                    } else |err| {
                        print("You can only input numbers\n", .{});
                        is_running = false;
                    }
                } else if (inst == 902) {
                    print("{}\n", .{accum});
                }
            },
            8 => { // BRP
                if (accum > 0) {
                    step = inst - 800;
                    continue;
                }
            },
            7 => { // BRZ
                if (accum == 0) {
                    step = inst - 700;
                    continue;
                }
            },
            6 => { // BRA
                step = inst - 600;
                continue;
            },
            5 => { // LDA
                accum = instructions[inst - 500];
            },
            3 => { // STA
                instructions[inst - 300] = accum;
            },
            2 => { // SUB
                accum -%= instructions[inst - 200];
            },
            1 => { // ADD
                accum +%= instructions[inst - 100];
            },
            else => is_running = false,
        }

        step += 1;
    }
}

pub fn main() !void {
    const path = try getArg(1);
    const buffer = try readFileAsString(path);

    var reader = try TokenReader.init(malloc, buffer);
    defer reader.deinit();

    var instructions = try parseInstructions(&reader);
    executeInstructions(&instructions);
}
