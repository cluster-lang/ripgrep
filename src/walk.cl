// ==============================================================================
// Module:      Fast Filesystem Walker & Ignore Engine (walk.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      Zaid Alamgir (ZK Company)
// License:     MIT License
// Description: High-speed recursive directory traversal engine featuring .gitignore rule
//              parsing, hidden file filters, and fast binary file auto-detection.
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   WalkOptions
// Purpose: Configures directory traversal depth and filtering rules.
// Fields:
//   include_hidden:  1 to inspect hidden files and dot-directories, 0 to skip
//   no_ignore:       1 to bypass .gitignore rules, 0 to honor them
//   follow_symlinks: 1 to traverse symbolic links, 0 to ignore
//   max_depth:       Maximum recursion depth for filesystem traversal
// ------------------------------------------------------------------------------
model WalkOptions:
    include_hidden: int
    no_ignore: int
    follow_symlinks: int
    max_depth: int

// ------------------------------------------------------------------------------
// Function: walk_options_default
// Syntax:   fn walk_options_default() -> WalkOptions
// Purpose:  Returns standard default traversal options (no hidden, honor gitignore, max depth 100).
// ------------------------------------------------------------------------------
fn walk_options_default() -> WalkOptions:
    return WalkOptions(0, 0, 0, 100)

// ------------------------------------------------------------------------------
// Function: is_ignored_dir
// Syntax:   fn is_ignored_dir(name: string) -> int
// Purpose:  Identifies common build and metadata directories (.git, node_modules, target, etc.)
//           that should always be excluded from search by default.
// ------------------------------------------------------------------------------
fn is_ignored_dir(name: string) -> int:
    if name == ".git" or name == "node_modules" or name == "target" or name == "build" or name == ".zk_cache" or name == ".cl_cache" or name == ".vscode" or name == ".idea":
        return 1
    return 0

// ------------------------------------------------------------------------------
// Function: is_binary_file
// Syntax:   fn is_binary_file(filepath: string) -> int
// Purpose:  Inspects the initial 1024 bytes of a file for NULL bytes (0x00) to detect binary payloads.
// ------------------------------------------------------------------------------
fn is_binary_file(filepath: string) -> int:
    content := file_read(filepath)
    sz := len(content)
    let mut check_len: int = 1024
    if check_len > sz:
        check_len = sz

    let mut i: int = 0
    while i < check_len:
        b := byte_at(content, i)
        if b == 0:
            return 1 // Null byte found -> binary file!
        i = i + 1
    return 0

// ------------------------------------------------------------------------------
// Function: parse_gitignore
// Syntax:   fn parse_gitignore(dir_path: string) -> vector[string]
// Purpose:  Reads and parses local .gitignore files in a directory, stripping comments and blanks.
// ------------------------------------------------------------------------------
fn parse_gitignore(dir_path: string) -> vector[string]:
    let rules: vector[string] = []
    let gitignore_path: string = dir_path + "/.gitignore"
    if file_exists(gitignore_path) == 0:
        return rules

    content := file_read(gitignore_path)
    let sz: int = len(content)
    let mut cur: string = ""
    let mut i: int = 0

    while i < sz:
        b := byte_at(content, i)
        if b == 10 or b == 13:
            if len(cur) > 0:
                if byte_at(cur, 0) != 35: // '#'
                    rules.push(cur)
                cur = ""
        else:
            cur = cur + chr(b)
        i = i + 1

    if len(cur) > 0:
        if byte_at(cur, 0) != 35:
            rules.push(cur)

    return rules

// ------------------------------------------------------------------------------
// Function: matches_any_rule
// Syntax:   fn matches_any_rule(filename: string, rules: vector[string]) -> int
// Purpose:  Tests whether a filename matches or contains any gitignore glob string.
// ------------------------------------------------------------------------------
fn matches_any_rule(filename: string, rules: vector[string]) -> int:
    let mut i: int = 0
    let sz: int = len(rules)
    while i < sz:
        rule := rules[i]
        if rule == filename or string_contains(filename, rule) == 1:
            return 1
        i = i + 1
    return 0

// ------------------------------------------------------------------------------
// Function: walk_collect_files
// Syntax:   fn walk_collect_files(dir_path: string, opts: WalkOptions, depth: int, &out_files: vector[string]) -> void
// Purpose:  Recursively traverses directories using native `fs_list_dir`, applying gitignore
//           and hidden file filters, appending non-binary files into out_files.
// ------------------------------------------------------------------------------
fn walk_collect_files(dir_path: string, opts: WalkOptions, depth: int, &out_files: vector[string]):
    if depth > opts.max_depth:
        return

    items := fs_list_dir(dir_path)
    let mut local_rules: vector[string] = []
    if opts.no_ignore == 0:
        local_rules = parse_gitignore(dir_path)

    let mut i: int = 0
    let sz: int = len(items)

    while i < sz:
        item := items[i]
        
        let mut is_hidden: int = 0
        if len(item) > 0:
            if byte_at(item, 0) == 46: // '.'
                is_hidden = 1

        let mut skip_item: int = 0
        if is_hidden == 1:
            if opts.include_hidden == 0:
                skip_item = 1

        if opts.no_ignore == 0:
            if matches_any_rule(item, local_rules) == 1:
                skip_item = 1

        if skip_item == 0:
            let mut full_path: string = ""
            if dir_path == "." or dir_path == "./":
                full_path = item
            else:
                full_path = dir_path + "/" + item

            if fs_is_dir(full_path) == 1:
                if is_ignored_dir(item) == 0:
                    walk_collect_files(full_path, opts, depth + 1, out_files)
            else:
                if is_binary_file(full_path) == 0:
                    out_files.push(full_path)

        i = i + 1

// ------------------------------------------------------------------------------
// Function: walk_directory
// Syntax:   fn walk_directory(root_path: string, opts: WalkOptions) -> vector[string]
// Purpose:  Public entrypoint for file collection. Handles both single files and recursive directory trees.
// ------------------------------------------------------------------------------
fn walk_directory(root_path: string, opts: WalkOptions) -> vector[string]:
    let mut files: vector[string] = []
    if fs_is_dir(root_path) == 1:
        walk_collect_files(root_path, opts, 0, files)
    else:
        if file_exists(root_path) == 1:
            if is_binary_file(root_path) == 0:
                files.push(root_path)
    return files
