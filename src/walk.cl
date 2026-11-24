// ==============================================================================
// Module:      Fast Filesystem Walker & Ignore Engine (walk.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: High-speed recursive directory traversal engine featuring .gitignore rule
//              parsing, hidden file filters, file type filtering (-t / -T), glob
//              matching (-g), and fast binary file auto-detection.
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   WalkOptions
// Purpose: Configures directory traversal depth and filtering rules.
// Fields:
//   include_hidden:   1 to inspect hidden files and dot-directories, 0 to skip
//   no_ignore:        1 to bypass .gitignore rules, 0 to honor them
//   follow_symlinks:  1 to traverse symbolic links, 0 to ignore
//   max_depth:        Maximum recursion depth for filesystem traversal
//   type_filters:     List of included file types (e.g. "cl", "rust", "c")
//   type_not_filters: List of excluded file types
//   glob_filters:     List of glob patterns to match or negate (e.g. "*.cl", "!*.tmp")
// ------------------------------------------------------------------------------
model WalkOptions:
    include_hidden: int
    no_ignore: int
    follow_symlinks: int
    max_depth: int
    type_filters: vector[string]
    type_not_filters: vector[string]
    glob_filters: vector[string]

// ------------------------------------------------------------------------------
// Function: walk_options_default
// Syntax:   fn walk_options_default() -> WalkOptions
// Purpose:  Returns standard default traversal options (no hidden, honor gitignore, max depth 100).
// ------------------------------------------------------------------------------
fn walk_options_default() -> WalkOptions:
    let empty_t: vector[string] = []
    let empty_tn: vector[string] = []
    let empty_g: vector[string] = []
    return WalkOptions(0, 0, 0, 100, empty_t, empty_tn, empty_g)

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
// Filename and Extension Utilities
// ------------------------------------------------------------------------------
fn get_filename(filepath: string) -> string:
    let sz: int = len(filepath)
    let mut last_slash: int = -1
    let mut i: int = 0
    while i < sz:
        if byte_at(filepath, i) == 47: // '/'
            last_slash = i
        i = i + 1
    if last_slash >= 0 and last_slash + 1 < sz:
        return substring(filepath, last_slash + 1, sz - last_slash - 1)
    return filepath

fn get_extension(filepath: string) -> string:
    let sz: int = len(filepath)
    let mut last_dot: int = -1
    let mut i: int = sz - 1
    while i >= 0:
        b := byte_at(filepath, i)
        if b == 47: // '/'
            break
        if b == 46: // '.'
            last_dot = i
            break
        i = i - 1
    if last_dot >= 0:
        return substring(filepath, last_dot, sz - last_dot)
    return ""

// ------------------------------------------------------------------------------
// Glob Pattern Matcher
// ------------------------------------------------------------------------------
fn glob_match_inner(pat: string, text: string) -> int:
    let p_len: int = len(pat)
    let t_len: int = len(text)
    let mut p: int = 0
    let mut t: int = 0
    let mut star_p: int = -1
    let mut match_t: int = -1

    while t < t_len:
        if p < p_len and (byte_at(pat, p) == byte_at(text, t) or byte_at(pat, p) == 63): // '?'
            p = p + 1
            t = t + 1
        elif p < p_len and byte_at(pat, p) == 42: // '*'
            star_p = p
            p = p + 1
            match_t = t
        elif star_p != -1:
            p = star_p + 1
            match_t = match_t + 1
            t = match_t
        else:
            return 0

    while p < p_len and byte_at(pat, p) == 42:
        p = p + 1

    if p == p_len:
        return 1
    return 0

fn glob_matches(glob: string, filepath: string) -> int:
    let mut pat: string = glob
    let mut inverted: int = 0
    if len(pat) > 0 and byte_at(pat, 0) == 33: // '!'
        inverted = 1
        pat = substring(pat, 1, len(pat) - 1)

    let fname: string = get_filename(filepath)
    let mut matched: int = 0
    if glob_match_inner(pat, filepath) == 1:
        matched = 1
    elif glob_match_inner(pat, fname) == 1:
        matched = 1

    if inverted == 1:
        if matched == 1:
            return 0
        return 1
    return matched

// ------------------------------------------------------------------------------
// File Type System
// ------------------------------------------------------------------------------
fn match_file_type(t: string, ext: string) -> int:
    if t == "cl" and ext == ".cl":
        return 1
    if t == "rust" and ext == ".rs":
        return 1
    if t == "c" and (ext == ".c" or ext == ".h"):
        return 1
    if t == "cpp" and (ext == ".cpp" or ext == ".cc" or ext == ".cxx" or ext == ".hpp" or ext == ".hxx"):
        return 1
    if t == "py" and ext == ".py":
        return 1
    if t == "js" and (ext == ".js" or ext == ".jsx" or ext == ".mjs" or ext == ".cjs"):
        return 1
    if t == "ts" and (ext == ".ts" or ext == ".tsx"):
        return 1
    if t == "json" and ext == ".json":
        return 1
    if t == "md" and (ext == ".md" or ext == ".markdown"):
        return 1
    if t == "toml" and ext == ".toml":
        return 1
    if t == "yaml" and (ext == ".yaml" or ext == ".yml"):
        return 1
    if t == "go" and ext == ".go":
        return 1
    if t == "sh" and (ext == ".sh" or ext == ".bash"):
        return 1
    if t == "html" and (ext == ".html" or ext == ".htm"):
        return 1
    if t == "css" and (ext == ".css" or ext == ".scss" or ext == ".sass"):
        return 1
    if t == "java" and ext == ".java":
        return 1
    if t == "txt" and ext == ".txt":
        return 1
    if t == "sql" and ext == ".sql":
        return 1
    return 0

fn print_type_list():
    println("c: *.c, *.h")
    println("cl: *.cl")
    println("cpp: *.cpp, *.cc, *.cxx, *.hpp, *.hxx")
    println("css: *.css, *.scss, *.sass")
    println("go: *.go")
    println("html: *.html, *.htm")
    println("java: *.java")
    println("js: *.js, *.jsx, *.mjs, *.cjs")
    println("json: *.json")
    println("md: *.md, *.markdown")
    println("py: *.py")
    println("rust: *.rs")
    println("sh: *.sh, *.bash")
    println("sql: *.sql")
    println("toml: *.toml")
    println("ts: *.ts, *.tsx")
    println("txt: *.txt")
    println("yaml: *.yaml, *.yml")

fn is_file_allowed(filepath: string, opts: WalkOptions) -> int:
    ext := get_extension(filepath)

    // Check type exclusions (-T / --type-not)
    let num_not: int = len(opts.type_not_filters)
    let mut i: int = 0
    while i < num_not:
        t := opts.type_not_filters[i]
        if match_file_type(t, ext) == 1:
            return 0
        i = i + 1

    // Check type inclusions (-t / --type)
    let num_types: int = len(opts.type_filters)
    if num_types > 0:
        let mut type_ok: int = 0
        let mut j: int = 0
        while j < num_types:
            t := opts.type_filters[j]
            if match_file_type(t, ext) == 1:
                type_ok = 1
                break
            j = j + 1
        if type_ok == 0:
            return 0

    // Check glob patterns (-g / --glob)
    let num_globs: int = len(opts.glob_filters)
    if num_globs > 0:
        let mut g_idx: int = 0
        while g_idx < num_globs:
            g := opts.glob_filters[g_idx]
            if glob_matches(g, filepath) == 0:
                return 0
            g_idx = g_idx + 1

    return 1

// ------------------------------------------------------------------------------
// Gitignore Parser
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
// Syntax:   fn walk_collect_files(dir_path: string, opts: WalkOptions, depth: int) -> vector[string]
// Purpose:  Recursively traverses directories using native `fs_list_dir`, applying gitignore,
//           hidden filters, type filters, glob filters, and binary file checks.
// ------------------------------------------------------------------------------
fn walk_collect_files(dir_path: string, opts: WalkOptions, depth: int) -> vector[string]:
    let mut out_files: vector[string] = []
    if depth > opts.max_depth:
        return out_files

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
                    sub_files := walk_collect_files(full_path, opts, depth + 1)
                    let mut k: int = 0
                    while k < len(sub_files):
                        out_files.push(sub_files[k])
                        k = k + 1
            else:
                if is_binary_file(full_path) == 0:
                    if is_file_allowed(full_path, opts) == 1:
                        out_files.push(full_path)

        i = i + 1
    return out_files

// ------------------------------------------------------------------------------
// Function: walk_directory
// Syntax:   fn walk_directory(root_path: string, opts: WalkOptions) -> vector[string]
// Purpose:  Public entrypoint for file collection. Handles both single files and recursive directory trees.
// ------------------------------------------------------------------------------
fn walk_directory(root_path: string, opts: WalkOptions) -> vector[string]:
    if fs_is_dir(root_path) == 1:
        return walk_collect_files(root_path, opts, 0)
    let mut files: vector[string] = []
    if file_exists(root_path) == 1:
        if is_binary_file(root_path) == 0:
            if is_file_allowed(root_path, opts) == 1:
                files.push(root_path)
    return files
