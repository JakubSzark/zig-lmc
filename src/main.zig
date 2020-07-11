const std = @import("std");
const types = @import("./lmc_types.zig");
const parse = @import("./parse.zig");
const malloc = std.heap.c_allocator;
const print = std.debug.print;

const parseInstructions = parse.parseInstructions;
const findChar = parse.findChar;

const Allocator = std.mem.Allocator;
const TokenReader = @import("./token_reader.zig").TokenReader;

const OpCode = types.OpCode;
const Cell = types.Cell;

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

/// Scanf from C lib
extern fn scanf(format: [*:0]const u8, [*]u8) i32;

/// Executes a set of LMC instructions
fn executeInstructions(cells: *[100]Cell) void {
    print("\nExecuting...\n============\n", .{});
    var step: usize = 0;
    var accum: i32 = 0;

    var is_running = true;
    while (is_running) {
        // Get first digit of the instruction
        const inst = @intToEnum(OpCode, cells[step].instruction);
        const val = cells[step].value;

        switch (inst) {
            OpCode.INP => {
                // Get Input from User
                print(":> ", .{});
                const BUFFER_SIZE: usize = 128;
                var buffer = [_]u8{0} ** BUFFER_SIZE;
                var index: usize = 0;
                _ = scanf("%s", &buffer);

                const end = @intCast(usize, findChar(&buffer, 0));

                if (std.fmt.parseInt(i32, buffer[0..end], 10)) |value| {
                    accum = value;
                    step += 1;
                    continue;
                } else |err| {
                    print("You can only input numbers\n", .{});
                    is_running = false;
                }
            },
            OpCode.OUT => { // INP, OUT
                print("{}\n", .{accum});
                step += 1;
                continue;
            },
            else => {},
        }

        // Memory Address Related OpCodes
        if (val >= 0 or val <= 99) {
            switch (inst) {
                OpCode.BRP => { // BRP
                    if (accum > 0) {
                        step = @intCast(usize, val);
                        continue;
                    }
                },
                OpCode.BRZ => { // BRZ
                    if (accum == 0) {
                        step = @intCast(usize, val);
                        continue;
                    }
                },
                OpCode.BRA => { // BRA
                    step = @intCast(usize, val);
                    continue;
                },
                OpCode.LDA => { // LDA
                    accum = cells[@intCast(usize, val)].value;
                },
                OpCode.STA => { // STA
                    cells[@intCast(usize, val)].value = accum;
                },
                OpCode.SUB => { // SUB
                    accum -%= cells[@intCast(usize, val)].value;
                },
                OpCode.ADD => { // ADD
                    accum +%= cells[@intCast(usize, val)].value;
                },
                else => is_running = false,
            }
        }

        step += 1;
    }

    print("============\nHalted\n", .{});
}

pub fn main() !void {
    const path = try getArg(1);
    const buffer = try readFileAsString(path);

    var reader = try TokenReader.init(malloc, buffer);
    defer reader.deinit();

    var cells = try parseInstructions(&reader);
    executeInstructions(&cells);
}
