const std = @import("std");
const TokenReader = @import("./token_reader.zig").TokenReader;
const types = @import("./lmc_types.zig");
const malloc = std.heap.c_allocator;
const print = std.debug.print;

const OpCode = types.OpCode;
const Cell = types.Cell;

/// Prints a token
fn printToken(token: []const u8) void {
    print("{} <-- ", .{token});
}

/// Errors that may happen during instruction parsing
const ParseError = error{
    ArgumentFormat,
    ArgumentMissing,
    UnknownInstruction,
};

/// Check if string contains a character
pub fn findChar(str: []const u8, char: u8) i32 {
    for (str) |ch, i| if (ch == char) return @intCast(i32, i);
    return -1;
}

/// Parses a file into a LMC instruction set
pub fn parseInstructions(reader: *TokenReader) ![100]Cell {
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
    var cells = [_]Cell{.{}} ** 100;
    print("Parsing...\n============\n", .{});

    // Parse instructions into OpCodes
    instruction = 0;
    while (reader.nextToken()) |token| {
        // Make sure its not a label
        if (findChar(token, ':') == -1) {
            if (OpCode.parse(token)) |op_code| {
                cells[instruction].instruction = @enumToInt(op_code);

                // We need to process the argument
                if (OpCode.hasArg(op_code)) {
                    if (reader.nextToken()) |arg_token| {
                        if (arg_token[0] == '$') {
                            // Parse memory address string into integer
                            if (std.fmt.parseInt(i32, arg_token[1..], 10)) |value| {
                                cells[instruction].value = value;
                            } else |err| {
                                printToken(arg_token);
                                return ParseError.ArgumentFormat;
                            }
                        } else if (labels.contains(arg_token)) {
                            if (labels.get(arg_token)) |address| {
                                cells[instruction].value = address;
                            }
                        } else if (op_code == OpCode.DAT) {
                            if (std.fmt.parseInt(i32, arg_token, 10)) |value| {
                                cells[instruction].value = value;
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

                print("{}\t{}\t{}\n", .{
                    instruction,
                    OpCode.get_name(cells[instruction].instruction),
                    cells[instruction].value,
                });

                instruction += 1;
            } else {
                printToken(token);
                return ParseError.UnknownInstruction;
            }
        }
    }

    print("============\nFinished.\n", .{});

    return cells;
}
