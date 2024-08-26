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
///     - 8 + 1 + 1 bytes
/// 2. Hex string
///     - 8 * (2 * 2 + 1) bytes
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

        while (byte_slice_iterator.next()) |byte_slice| {
            const hex_str = try createFormattedHexStr(byte_slice);

            // Dislay the hex string
            std.debug.print("{s}", .{hex_str});

            // Dislay the human readable string
            std.debug.print("{s}\n", .{createHumanReadableStr(byte_slice)});

            // // Display the slice as a human readable string
            // for (byte_slice, 0..) |byte, index| {
            //     if (byte <= 0x20 or byte >= 0x7f) {
            //         printCharInColor('.');
            //     } else {
            //         std.debug.print("{c}", .{byte});
            //     }

            //     // Print a newline after the last byte
            //     if (index == byte_slice.len - 1) {
            //         std.debug.print("\n", .{});
            //     }
            // }
        }
    }
}

fn createRowStr(bytes: []const u8) ![row_str_len]u8 {

    // Check the number of input bytes
    if (bytes.len > max_num_bytes_per_line) {
        return HexDumpError.TooManyBytesPerRow;
    }

    // Initialize the row string buffer
    var row_str: [row_str_len]u8 = undefined;

    // Character index in the string
    var char_index: usize = 0;

    for (bytes, 0..) |byte, index| {

        //
        if (@mod(index, 2) == 1) {}
    }
}

fn createHumanReadableStr(bytes: []const u8) [max_num_bytes_per_line]u8 {
    // Initialize the string buffer
    var str: [max_num_bytes_per_line]u8 = undefined;

    for (bytes, 0..) |byte, index| {
        if (byte <= 0x20 or byte >= 0x7f) {
            str[index] = '.';
        } else {
            str[index] = byte;
        }
    }

    return str;
}

fn createFormattedHexStr(bytes: []const u8) ![hex_str_len]u8 {

    // Check the number of input bytes
    if (bytes.len > max_num_bytes_per_line) {
        return HexDumpError.TooManyBytesPerRow;
    }

    // Initialize the row string buffer
    var hex_str: [hex_str_len]u8 = undefined;

    // Index of the byte in the row
    var byte_index: usize = 0;

    // Character index in the string
    var char_index: usize = 0;

    while (true) : (char_index += 5) {

        // Can write 2 bytes
        if (byte_index + 1 < bytes.len) {
            _ = try std.fmt.bufPrint(
                hex_str[char_index .. char_index + 5],
                "{x:0>2}{x:0>2} ",
                .{ bytes[byte_index], bytes[byte_index + 1] },
            );

            // Increment the index
            byte_index += 2;
        } else if (byte_index < bytes.len) {

            // Can only write 1 byte
            _ = try std.fmt.bufPrint(
                hex_str[char_index .. char_index + 5],
                "{x:0>2}   ",
                .{bytes[byte_index]},
            );

            // Increment the index
            byte_index += 1;
        } else {
            // Reached the end of the row
            break;
        }
    }

    // Calculate the number of remaining characters
    const num_remaining_chars = hex_str_len - char_index;

    // Fill the remaining characters with spaces
    @memset(hex_str[char_index .. char_index + num_remaining_chars], 32);

    return hex_str;
}

test "print hex string" {
    const row = [_]u8{ 65, 66, 64 };

    const hex_str = try createFormattedHexStr(&row);

    std.debug.print("{s}END\n", .{hex_str});
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
