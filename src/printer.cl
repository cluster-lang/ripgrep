// ==============================================================================
// Module:      Terminal Output & Highlighting Engine (printer.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Terminal formatting, ANSI color rendering, context line buffering,
//              match replacement, JSON serialization, and file search adhering
//              to standard ripgrep output conventions.
// ==============================================================================

import "src/matcher.cl"

// ------------------------------------------------------------------------------
// Model:   PrintConfig
// Purpose: Configures terminal output formatting and display filters.
// Fields:
//   show_line_numbers: 1 to print line numbers preceding matched lines
//   count_only:        1 (-c) to only output total match count per file
//   files_only:        1 (-l) to only print filenames containing matches
//   invert_match:      1 (-v) to select non-matching lines
//   color_enabled:     1 to render ANSI escape codes for file paths, line numbers, and matches
//   context_before:    Number of leading context lines (-B)
//   context_after:     Number of trailing context lines (-A)
//   max_count:         Maximum matches to display per file (-m) (0 = unlimited)
//   quiet:             1 (-q) to suppress all normal output
//   replace_str:       Replacement string (-r) for matched spans
//   json_output:       1 (--json) to emit ripgrep-compatible JSON messages
// ------------------------------------------------------------------------------
model PrintConfig:
    show_line_numbers: int
    count_only: int
    files_only: int
    invert_match: int
    color_enabled: int
    context_before: int
    context_after: int
    max_count: int
    quiet: int
    replace_str: string
    json_output: int

// ------------------------------------------------------------------------------
// Function: print_config_default
// Syntax:   fn print_config_default() -> PrintConfig
// Purpose:  Returns standard default output configuration.
// ------------------------------------------------------------------------------
fn print_config_default() -> PrintConfig:
    return PrintConfig(1, 0, 0, 0, 1, 0, 0, 0, 0, "", 0)

// ------------------------------------------------------------------------------
// ANSI Terminal Color Codes
// ------------------------------------------------------------------------------
fn color_magenta() -> string: return chr(27) + "[35m"
fn color_green() -> string: return chr(27) + "[32m"
fn color_bold_red() -> string: return chr(27) + "[1;31m"
fn color_reset() -> string: return chr(27) + "[0m"

// ------------------------------------------------------------------------------
// Function: split_lines
// Syntax:   fn split_lines(content: string) -> vector[string]
// Purpose:  Splits a string buffer into discrete lines separated by LF, stripping CR.
// ------------------------------------------------------------------------------
fn split_lines(content: string) -> vector[string]:
    let lines: vector[string] = []
    let sz: int = len(content)
    let mut cur: string = ""
    let mut i: int = 0
    while i < sz:
        b := byte_at(content, i)
        if b == 10: // '\n'
            if len(cur) > 0:
                if byte_at(cur, len(cur) - 1) == 13:
                    cur = substring(cur, 0, len(cur) - 1)
            lines.push(cur)
            cur = ""
        else:
            cur = cur + chr(b)
        i = i + 1

    if len(cur) > 0:
        if byte_at(cur, len(cur) - 1) == 13:
            cur = substring(cur, 0, len(cur) - 1)
        lines.push(cur)

    return lines

// ------------------------------------------------------------------------------
// Function: replace_spans_in_line
// Syntax:   fn replace_spans_in_line(line: string, spans: vector[MatchSpan], repl: string) -> string
// Purpose:  Substitutes matched spans in a line with a user-specified replacement string.
// ------------------------------------------------------------------------------
fn replace_spans_in_line(line: string, spans: vector[MatchSpan], repl: string) -> string:
    if len(spans) == 0:
        return line
    let mut out: string = ""
    let mut last_idx: int = 0
    let sz: int = len(spans)
    let mut i: int = 0
    while i < sz:
        let sp: MatchSpan = spans[i]
        if sp.start_pos > last_idx:
            out = out + substring(line, last_idx, sp.start_pos - last_idx)
        out = out + repl
        last_idx = sp.end_pos
        i = i + 1
    if last_idx < len(line):
        out = out + substring(line, last_idx, len(line) - last_idx)
    return out

// ------------------------------------------------------------------------------
// Function: highlight_line
// Syntax:   fn highlight_line(line: string, spans: vector[MatchSpan], color_enabled: int) -> string
// Purpose:  Injects bold red ANSI styling around byte spans corresponding to pattern hits.
// ------------------------------------------------------------------------------
fn highlight_line(line: string, spans: vector[MatchSpan], color_enabled: int) -> string:
    if color_enabled == 0:
        return line
    if len(spans) == 0:
        return line

    let mut out: string = ""
    let mut last_idx: int = 0
    let sz: int = len(spans)
    let mut i: int = 0

    while i < sz:
        let sp: MatchSpan = spans[i]
        if sp.start_pos > last_idx:
            out = out + substring(line, last_idx, sp.start_pos - last_idx)
        
        out = out + color_bold_red()
        out = out + substring(line, sp.start_pos, sp.end_pos - sp.start_pos)
        out = out + color_reset()
        last_idx = sp.end_pos
        i = i + 1

    if last_idx < len(line):
        out = out + substring(line, last_idx, len(line) - last_idx)

    return out

// ------------------------------------------------------------------------------
// Function: search_file
// Syntax:   fn search_file(filepath: string, reg: RegexPattern, cfg: PrintConfig) -> int
// Purpose:  Reads a file, runs line-by-line pattern matching, applies context windowing
//           (-A, -B, -C), renders ANSI color highlights, supports -m, -q, -r, and --json.
// ------------------------------------------------------------------------------
fn search_file(filepath: string, reg: RegexPattern, cfg: PrintConfig) -> int:
    content := file_read(filepath)
    lines := split_lines(content)
    num_lines := len(lines)

    let mut match_count: int = 0
    let mut matched_line_indices: vector[int] = []
    let mut matched_results: vector[MatchResult] = []

    let mut i: int = 0
    while i < num_lines:
        line := lines[i]
        res := regex_find_in_line(reg, line)

        let mut is_hit: int = 0
        if cfg.invert_match == 1:
            if res.matched == 0:
                is_hit = 1
        else:
            if res.matched == 1:
                is_hit = 1

        if is_hit == 1:
            match_count = match_count + 1
            if cfg.quiet == 1:
                return 1
            matched_line_indices.push(i)
            matched_results.push(res)
            if cfg.max_count > 0 and match_count >= cfg.max_count:
                break
        i = i + 1

    if match_count == 0:
        return 0

    // Mode: -q / --quiet
    if cfg.quiet == 1:
        return match_count

    // Mode: -l / --files-with-matches
    if cfg.files_only == 1:
        if cfg.color_enabled == 1:
            println(color_magenta() + filepath + color_reset())
        else:
            println(filepath)
        return match_count

    // Mode: -c / --count
    if cfg.count_only == 1:
        if cfg.color_enabled == 1:
            println(color_magenta() + filepath + color_reset() + ":" + str(match_count))
        else:
            println(filepath + ":" + str(match_count))
        return match_count

    // Mode: --json
    if cfg.json_output == 1:
        let mut j_idx: int = 0
        while j_idx < len(matched_line_indices):
            l_num := matched_line_indices[j_idx]
            l_text := lines[l_num]
            println("{\"type\":\"match\",\"data\":{\"path\":{\"text\":\"" + filepath + "\"},\"lines\":{\"text\":\"" + l_text + "\\n\"},\"line_number\":" + str(l_num + 1) + "}}")
            j_idx = j_idx + 1
        return match_count

    // Mode: Standard match output with optional context lines (-C, -A, -B)
    let mut last_printed_idx: int = -1
    let mut m_idx: int = 0
    let total_matches: int = len(matched_line_indices)

    while m_idx < total_matches:
        line_num := matched_line_indices[m_idx]
        let res: MatchResult = matched_results[m_idx]

        // Context before
        let mut ctx_start: int = line_num - cfg.context_before
        if ctx_start < 0:
            ctx_start = 0
        if ctx_start > last_printed_idx + 1:
            if last_printed_idx >= 0:
                println("--")
            ctx_start = ctx_start
        else:
            ctx_start = last_printed_idx + 1

        let mut c_i: int = ctx_start
        while c_i < line_num:
            if c_i >= 0 and c_i < num_lines:
                ctx_line := lines[c_i]
                if cfg.color_enabled == 1:
                    println(color_magenta() + filepath + color_reset() + "-" + color_green() + str(c_i + 1) + color_reset() + "-" + ctx_line)
                else:
                    println(filepath + "-" + str(c_i + 1) + "-" + ctx_line)
                last_printed_idx = c_i
            c_i = c_i + 1

        // Matched line
        let mut line_content: string = lines[line_num]
        let mut displayed_line: string = ""
        if len(cfg.replace_str) > 0:
            displayed_line = replace_spans_in_line(line_content, res.spans, cfg.replace_str)
        else:
            displayed_line = highlight_line(line_content, res.spans, cfg.color_enabled)
        
        let mut line_str: string = ""
        if cfg.show_line_numbers == 1:
            if cfg.color_enabled == 1:
                line_str = color_green() + str(line_num + 1) + color_reset() + ":"
            else:
                line_str = str(line_num + 1) + ":"

        if cfg.color_enabled == 1:
            println(color_magenta() + filepath + color_reset() + ":" + line_str + displayed_line)
        else:
            println(filepath + ":" + line_str + displayed_line)
        last_printed_idx = line_num

        // Context after
        let mut ctx_end: int = line_num + cfg.context_after
        if ctx_end >= num_lines:
            ctx_end = num_lines - 1

        let mut a_i: int = line_num + 1
        while a_i <= ctx_end:
            if a_i < num_lines:
                ctx_line := lines[a_i]
                if cfg.color_enabled == 1:
                    println(color_magenta() + filepath + color_reset() + "-" + color_green() + str(a_i + 1) + color_reset() + "-" + ctx_line)
                else:
                    println(filepath + "-" + str(a_i + 1) + "-" + ctx_line)
                last_printed_idx = a_i
            a_i = a_i + 1

        m_idx = m_idx + 1

    return match_count
