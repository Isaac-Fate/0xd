const std = @import("std");
const testing = std.testing;
const yazap = @import("yazap");

const expect = testing.expect;

const allocator = std.heap.page_allocator;
const log = std.log;
const App = yazap.App;
const Arg = yazap.Arg;

const HexDumpError = @import("./errors.zig").HexDumpError;
const ByteSliceIterator = @import("./byte_slice_iterator.zig").ByteSliceIterator;

/// Each line (exluding the trailing newline character) of the output consists of 3 parts:
/// 1. Offset string
///     - 8 + 1 + 1 = 10 bytes
/// 2. Hex string
///     - 8 * (2 * 2 + 1) = 40 bytes
/// 3. ASCII string
///     - 16 bytes
const line_len = offset_str_len + hex_str_len + ascii_str_len;
const offset_str_len = 8 + 1 + 1;
const hex_str_len = 8 * (2 * 2 + 1);
const ascii_str_len = 16;

const max_num_bytes_per_line = 0x10;

const row_str_len = hex_str_len + max_num_bytes_per_line;

const max_num_bytes_per_col = 2;

const ansi_cyan = "\x1b[0;36m";
const ansi_red = "\x1b[0;31m";
const ansi_reset = "\x1b[0m";

pub fn main() anyerror!void {

    // Create the app
    var app = App.init(allocator, "0xd", "Dump file content in hex");
    defer app.deinit();

    // Create the root command
    var rootCommand = app.rootCommand();

    // Positional arguments
    try rootCommand.addArg(Arg.positional("FILE", "File to dump", 1));

    // Optional arguments
    try rootCommand.addArg(Arg.booleanOption("version", 'v', "Show version"));

    // Parse the arguments and get all the matches
    const matches = try app.parseProcess();

    // Display the help message and exit if no arguments are supplied
    if (!(matches.containsArgs())) {
        try app.displayHelp();
        return;
    }

    // Display version and exit
    if (matches.containsArg("version")) {
        std.debug.print("0.0.1\n", .{});
        return;
    }

    if (matches.getSingleValue("FILE")) |file_name| {
        log.debug("file to process: {s}", .{file_name});

        // Open the file
        var file = try std.fs.cwd().openFile(file_name, .{});
        defer file.close();

        // Get the file metadata
        const file_metadata = try file.metadata();

        // Get the file size
        const file_size = file_metadata.size();

        // Initialize a buffer to store file content
        const file_content = try allocator.alloc(u8, file_size);
        defer allocator.free(file_content);

        // Read the file
        _ = try file.read(file_content);

        // Create a byte slice iterator
        var byte_slice_iterator = ByteSliceIterator{
            .bytes = file_content,
            .slice_len = max_num_bytes_per_line,
        };

        var line_index: usize = 0;

        while (byte_slice_iterator.next()) |byte_slice| {

            // Calculate the offset
            const offset = line_index * max_num_bytes_per_line;

            const line = try makeLine(byte_slice, offset);

            // Dislay the line
            std.debug.print("{s}\n", .{line});

            // Increment the line index
            line_index += 1;
        }
    }
}

fn makeLine(bytes: []const u8, offset: usize) ![line_len]u8 {

    // Check the number of input bytes
    if (bytes.len > max_num_bytes_per_line) {
        return HexDumpError.TooManyBytesPerRow;
    }

    // Initialize the line string buffer
    var line: [line_len]u8 = .{32} ** line_len;

    // Put the offset string into the first 10 bytes of the line
    _ = try std.fmt.bufPrint(line[0..offset_str_len], "{x:0>8}: ", .{offset});

    for (bytes, 0..) |byte, byte_index| {

        // First byte in a 2-byte group
        if (@mod(byte_index, 2) == 0) {

            // Calculate the character index in the hex string
            const hex_str_char_index: usize = offset_str_len + (byte_index >> 1) * 5;

            // Set the 2-character hex representation of the byte
            _ = try std.fmt.bufPrint(line[hex_str_char_index .. hex_str_char_index + 2], "{x:0>2}", .{byte});
        } else {
            // Calculate the character index in the hex string
            const hex_str_char_index: usize = offset_str_len + (byte_index >> 1) * 5 + 2;

            // Set the 2-character hex representation of the byte
            // with a trailing space
            // 3 characters in total
            _ = try std.fmt.bufPrint(line[hex_str_char_index .. hex_str_char_index + 3], "{x:0>2} ", .{byte});
        }

        // Set the ASCII representation of the byte
        const ascii_char_index = offset_str_len + hex_str_len + byte_index;

        if (byte > 0x20 and byte < 0x7f) {
            _ = try std.fmt.bufPrint(line[ascii_char_index .. ascii_char_index + 1], "{c}", .{byte});
        } else {
            _ = try std.fmt.bufPrint(line[ascii_char_index .. ascii_char_index + 1], "{c}", .{'.'});
        }
    }

    return line;
}

test "print line" {
    const bytes = [_]u8{ 0x11, 0x12, 0x13, 0x14, 0x15, 0x16, 0x17, 0x18, 0x19, 0x1a, 0x1b, 0x1c, 0x1d, 0x1e, 0x1f, 0x20 };

    const line = try makeLine(&bytes, 0);

    std.debug.print("{s}\n", .{line});

    std.debug.print("{d}\n", .{5 >> 1});
}

test "ansi color" {
    printStrInColor("hello\n");
}

fn printStrInColor(str: []const u8) void {

    // Print the message in the specified color, and then
    // reset the color to the default one
    std.debug.print("{s}{s}{s}", .{ ansi_cyan, str, ansi_reset });
}

fn printCharInColor(char: u8) void {

    // Print the message in the specified color, and then
    // reset the color to the default one
    std.debug.print("{s}{c}{s}", .{ ansi_cyan, char, ansi_reset });
}
