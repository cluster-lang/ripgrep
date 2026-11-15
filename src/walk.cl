// ==============================================================================
// Fast Filesystem Walker & Ignore Engine for Cluster-Ripgrep
// 100% Pure Cluster Language - Native fs_list_dir & binary file detection
// ==============================================================================

model WalkOptions:
    include_hidden: int
    no_ignore: int
    follow_symlinks: int
    max_depth: int

fn walk_options_default() -> WalkOptions:
    return WalkOptions(0, 0, 0, 100)

fn is_ignored_dir(name: string) -> int:
    if name == ".git" or name == "node_modules" or name == "target" or name == "build" or name == ".zk_cache" or name == ".cl_cache" or name == ".vscode" or name == ".idea":
        return 1
    return 0

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
                // Skip comments and empty lines
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
        
        // Skip hidden files/dirs if not enabled
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

fn walk_directory(root_path: string, opts: WalkOptions) -> vector[string]:
    let mut files: vector[string] = []
    if fs_is_dir(root_path) == 1:
        walk_collect_files(root_path, opts, 0, files)
    else:
        if file_exists(root_path) == 1:
            if is_binary_file(root_path) == 0:
                files.push(root_path)
    return files
