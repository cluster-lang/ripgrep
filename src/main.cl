// ==============================================================================
// Module:      Main CLI Command-Line Driver (main.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      Zaid Alamgir (ZK Company)
// License:     MIT License
// Description: Command-line interface parser, option validator, recursive search dispatcher,
//              and exit-code controller matching ripgrep CLI conventions.
// ==============================================================================

import "src/matcher.cl"
import "src/walk.cl"
import "src/printer.cl"

// ------------------------------------------------------------------------------
// Function: print_usage
// Syntax:   fn print_usage() -> void
// Purpose:  Displays usage syntax, available switches, and parameter definitions.
// ------------------------------------------------------------------------------
fn print_usage():
    println("cluster-ripgrep (rg) 1.0.0 (LLVM -O3)")
    println("USAGE:")
    println("    cluster-rg [OPTIONS] <PATTERN> [PATH ...]")
    println("")
    println("ARGS:")
    println("    <PATTERN>    A regular expression or literal string to search for")
    println("    <PATH> ...   A file or directory to search (defaults to current dir)")
    println("")
    println("OPTIONS:")
    println("    -i, --ignore-case          Case-insensitive search")
    println("    -v, --invert-match         Select non-matching lines")
    println("    -n, --line-number          Show line numbers (default: on)")
    println("    -N, --no-line-number       Suppress line numbers")
    println("    -c, --count                Only print count of matching lines")
    println("    -l, --files-with-matches   Only print paths with matching contents")
    println("    -w, --word-regexp          Only match whole words")
    println("    -F, --fixed-strings        Treat PATTERN as a literal string")
    println("    -C, --context <NUM>        Show NUM lines before and after matches")
    println("    -A, --after-context <NUM>  Show NUM lines after matches")
    println("    -B, --before-context <NUM> Show NUM lines before matches")
    println("        --hidden               Search hidden files and directories")
    println("        --no-ignore            Do not respect .gitignore rules")
    println("        --color <WHEN>         Color mode: 'always', 'never', 'auto'")
    println("    -h, --help                 Print help information")
    println("    -V, --version              Print version information")

// ------------------------------------------------------------------------------
// Function: main
// Syntax:   fn main() -> int
// Purpose:  CLI entrypoint. Parses command line switches, executes recursive search,
//           and returns 0 if matches are found, 1 if no matches are found, or error.
// ------------------------------------------------------------------------------
fn main() -> int:
    let num_args: int = len(sys_args)
    if num_args == 0:
        print_usage()
        return 1

    let mut pattern: string = ""
    let mut paths: vector[string] = []

    let mut ignore_case: int = 0
    let mut invert_match: int = 0
    let mut show_line_num: int = 1
    let mut count_only: int = 0
    let mut files_only: int = 0
    let mut word_boundary: int = 0
    let mut fixed_strings: int = 0
    let mut ctx_before: int = 0
    let mut ctx_after: int = 0
    let mut include_hidden: int = 0
    let mut no_ignore: int = 0
    let mut color_enabled: int = 1

    let mut i: int = 0
    while i < num_args:
        arg := sys_args[i]
        if arg == "-h" or arg == "--help":
            print_usage()
            return 0
        elif arg == "-V" or arg == "--version":
            println("cluster-ripgrep (rg) 1.0.0 (LLVM -O3)")
            return 0
        elif arg == "-i" or arg == "--ignore-case":
            ignore_case = 1
        elif arg == "-v" or arg == "--invert-match":
            invert_match = 1
        elif arg == "-n" or arg == "--line-number":
            show_line_num = 1
        elif arg == "-N" or arg == "--no-line-number":
            show_line_num = 0
        elif arg == "-c" or arg == "--count":
            count_only = 1
        elif arg == "-l" or arg == "--files-with-matches":
            files_only = 1
        elif arg == "-w" or arg == "--word-regexp":
            word_boundary = 1
        elif arg == "-F" or arg == "--fixed-strings":
            fixed_strings = 1
        elif arg == "--hidden":
            include_hidden = 1
        elif arg == "--no-ignore":
            no_ignore = 1
        elif arg == "--color":
            if i + 1 < num_args:
                c_mode := sys_args[i + 1]
                if c_mode == "never":
                    color_enabled = 0
                i = i + 1
        elif arg == "-C" or arg == "--context":
            if i + 1 < num_args:
                n := to_int(sys_args[i + 1])
                ctx_before = n
                ctx_after = n
                i = i + 1
        elif arg == "-A" or arg == "--after-context":
            if i + 1 < num_args:
                ctx_after = to_int(sys_args[i + 1])
                i = i + 1
        elif arg == "-B" or arg == "--before-context":
            if i + 1 < num_args:
                ctx_before = to_int(sys_args[i + 1])
                i = i + 1
        elif len(arg) > 0 and byte_at(arg, 0) == 45: // '-'
            // Ignore unknown flag
            dummy := 0
        else:
            if pattern == "":
                pattern = arg
            else:
                paths.push(arg)
        i = i + 1

    if pattern == "":
        print_usage()
        return 1

    if len(paths) == 0:
        paths.push(".")

    // Compile regex / literal pattern
    let reg: RegexPattern = regex_compile(pattern, ignore_case, word_boundary)
    if fixed_strings == 1:
        reg.is_literal_only = 1

    let walk_opts: WalkOptions = WalkOptions(include_hidden, no_ignore, 0, 100)
    let p_cfg: PrintConfig = PrintConfig(show_line_num, count_only, files_only, invert_match, color_enabled, ctx_before, ctx_after)

    let mut total_matches: int = 0
    let mut p_idx: int = 0
    while p_idx < len(paths):
        target_path := paths[p_idx]
        files := walk_directory(target_path, walk_opts)
        
        let mut f_idx: int = 0
        let num_files: int = len(files)
        while f_idx < num_files:
            file_to_search := files[f_idx]
            m := search_file(file_to_search, reg, p_cfg)
            total_matches = total_matches + m
            f_idx = f_idx + 1
        p_idx = p_idx + 1

    if total_matches > 0:
        return 0
    return 1
