#!/bin/sh

# Exit on error
set -e

# Executable name
exe_name=0xd

# Zig output directory
zig_out_dir=./zig-out

# Executable path
exe_path=${zig_out_dir}/bin/${exe_name}

# Directory containing the executables
local_bin_dir=/usr/local/bin

# Move the executable
mv ${exe_path} ${local_bin_dir}
