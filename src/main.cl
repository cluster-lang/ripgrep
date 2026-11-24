// ==============================================================================
// Module:      Main CLI Command-Line Driver (main.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Command-line interface parser, option validator, recursive search dispatcher,
//              type filter controller, and exit-code manager matching ripgrep CLI conventions.
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
    println("    cluster-rg [OPTIONS] -e <PATTERN> ... [PATH ...]")
    println("    cluster-rg [OPTIONS] --files [PATH ...]")
    println("    cluster-rg --type-list")
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
    println("    -e, --regexp <PATTERN>     Pattern to search for (supports multiple -e)")
    println("    -C, --context <NUM>        Show NUM lines before and after matches")
    println("    -A, --after-context <NUM>  Show NUM lines after matches")
    println("    -B, --before-context <NUM> Show NUM lines before matches")
    println("    -m, --max-count <NUM>      Stop searching in each file after NUM matches")
    println("    -q, --quiet                Do not print search results; return 0 if match found")
    println("    -r, --replace <REPLACEMENT> Replace matches with the given string")
    println("    -t, --type <TYPE>          Only search files matching TYPE (e.g. cl, rust, c)")
    println("    -T, --type-not <TYPE>      Do not search files matching TYPE")
    println("        --type-list            Show all supported file types")
    println("    -g, --glob <GLOB>          Include or exclude files matching GLOB")
    println("        --files                Print each file that would be searched")
    println("        --stats                Print search statistics (files, matches, lines)")
    println("        --max-depth <NUM>      Maximum depth of directory traversal")
    println("        --json                 Output matches in JSON lines format")
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
    let mut patterns: vector[string] = []
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
    let mut max_count: int = 0
    let mut quiet_mode: int = 0
    let mut files_mode: int = 0
    let mut stats_mode: int = 0
    let mut max_depth: int = 100
    let mut replace_str: string = ""
    let mut json_output: int = 0

    let mut type_filters: vector[string] = []
    let mut type_not_filters: vector[string] = []
    let mut glob_filters: vector[string] = []

    let mut i: int = 0
    while i < num_args:
        arg := sys_args[i]
        if arg == "-h" or arg == "--help":
            print_usage()
            return 0
        elif arg == "-V" or arg == "--version":
            println("cluster-ripgrep (rg) 1.0.0 (LLVM -O3)")
            return 0
        elif arg == "--type-list":
            print_type_list()
            return 0
        elif arg == "--files":
            files_mode = 1
        elif arg == "--stats":
            stats_mode = 1
        elif arg == "--json":
            json_output = 1
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
        elif arg == "-q" or arg == "--quiet":
            quiet_mode = 1
        elif arg == "--hidden":
            include_hidden = 1
        elif arg == "--no-ignore":
            no_ignore = 1
        elif arg == "-e" or arg == "--regexp":
            if i + 1 < num_args:
                patterns.push(sys_args[i + 1])
                i = i + 1
        elif arg == "-r" or arg == "--replace":
            if i + 1 < num_args:
                replace_str = sys_args[i + 1]
                i = i + 1
        elif arg == "-t" or arg == "--type":
            if i + 1 < num_args:
                type_filters.push(sys_args[i + 1])
                i = i + 1
        elif arg == "-T" or arg == "--type-not":
            if i + 1 < num_args:
                type_not_filters.push(sys_args[i + 1])
                i = i + 1
        elif arg == "-g" or arg == "--glob":
            if i + 1 < num_args:
                glob_filters.push(sys_args[i + 1])
                i = i + 1
        elif arg == "-m" or arg == "--max-count":
            if i + 1 < num_args:
                max_count = to_int(sys_args[i + 1])
                i = i + 1
        elif arg == "--max-depth":
            if i + 1 < num_args:
                max_depth = to_int(sys_args[i + 1])
                i = i + 1
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
            if pattern == "" and len(patterns) == 0 and files_mode == 0:
                pattern = arg
            else:
                paths.push(arg)
        i = i + 1

    // Build WalkOptions
    let walk_opts: WalkOptions = WalkOptions(include_hidden, no_ignore, 0, max_depth, type_filters, type_not_filters, glob_filters)

    if len(paths) == 0:
        paths.push(".")

    // If --files mode, just list files and exit
    if files_mode == 1:
        let mut p_i: int = 0
        while p_i < len(paths):
            f_list := walk_directory(paths[p_i], walk_opts)
            let mut fl_idx: int = 0
            while fl_idx < len(f_list):
                println(f_list[fl_idx])
                fl_idx = fl_idx + 1
            p_i = p_i + 1
        return 0

    // Combine multiple -e patterns if provided
    if len(patterns) > 0:
        if pattern != "":
            patterns.push(pattern)
        let mut comb: string = ""
        let mut pt_i: int = 0
        while pt_i < len(patterns):
            if pt_i > 0:
                comb = comb + "|"
            comb = comb + patterns[pt_i]
            pt_i = pt_i + 1
        pattern = comb

    if pattern == "":
        print_usage()
        return 1

    // Compile regex / literal pattern
    let mut reg: RegexPattern = regex_compile(pattern, ignore_case, word_boundary)
    if fixed_strings == 1:
        reg.is_literal_only = 1

    let p_cfg: PrintConfig = PrintConfig(show_line_num, count_only, files_only, invert_match, color_enabled, ctx_before, ctx_after, max_count, quiet_mode, replace_str, json_output)

    let mut total_matches: int = 0
    let mut files_matched: int = 0
    let mut files_searched: int = 0

    let mut p_idx: int = 0
    while p_idx < len(paths):
        target_path := paths[p_idx]
        files := walk_directory(target_path, walk_opts)
        
        let mut f_idx: int = 0
        let num_files: int = len(files)
        while f_idx < num_files:
            file_to_search := files[f_idx]
            files_searched = files_searched + 1
            m := search_file(file_to_search, reg, p_cfg)
            if m > 0:
                files_matched = files_matched + 1
                total_matches = total_matches + m
                if quiet_mode == 1:
                    return 0
            f_idx = f_idx + 1
        p_idx = p_idx + 1

    if stats_mode == 1:
        println(str(total_matches) + " matched lines")
        println(str(files_matched) + " files with matches")
        println(str(files_searched) + " files searched")

    if total_matches > 0:
        return 0
    return 1
