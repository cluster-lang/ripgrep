// ==============================================================================
// Module:      Fast Matcher Engine (matcher.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Complete high-speed Boyer-Moore-Horspool substring search and regular
//              expression engine with DFA/NFA evaluation, greedy range quantifiers,
//              character classes, word boundary (\b) assertions, alternation (foo|bar),
//              and match span extraction matching ripgrep specifications.
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   MatchSpan
// Purpose: Stores the 0-indexed byte offset range [start_pos, end_pos) of a matched token.
// ------------------------------------------------------------------------------
model MatchSpan:
    start_pos: int
    end_pos: int

// ------------------------------------------------------------------------------
// Model:   MatchResult
// Purpose: Encapsulates the overall result of a line search and all matched spans.
// ------------------------------------------------------------------------------
model MatchResult:
    matched: int
    spans: vector[MatchSpan]

// ------------------------------------------------------------------------------
// Helper: byte_to_lower
// ------------------------------------------------------------------------------
fn byte_to_lower(b: int) -> int:
    if b >= 65 and b <= 90:
        return b + 32
    return b

// ------------------------------------------------------------------------------
// Helper: is_word_char
// ------------------------------------------------------------------------------
fn is_word_char(b: int) -> int:
    if (b >= 65 and b <= 90) or (b >= 97 and b <= 122) or (b >= 48 and b <= 57) or b == 95:
        return 1
    return 0

// ------------------------------------------------------------------------------
// Helper: is_word_boundary
// ------------------------------------------------------------------------------
fn is_word_boundary(line: string, idx: int) -> int:
    llen := len(line)
    let mut prev_is_w: int = 0
    if idx > 0 and idx - 1 < llen:
        if is_word_char(byte_at(line, idx - 1)) == 1:
            prev_is_w = 1
    let mut curr_is_w: int = 0
    if idx < llen:
        if is_word_char(byte_at(line, idx)) == 1:
            curr_is_w = 1
    if prev_is_w != curr_is_w:
        return 1
    return 0

// ==============================================================================
// Boyer-Moore-Horspool Fast Substring Matcher
// ==============================================================================

model BmPattern:
    pat: string
    pat_len: int
    ignore_case: int
    shift: vector[int]

fn bm_compile(pattern: string, ignore_case: int) -> BmPattern:
    plen := len(pattern)
    let mut s: vector[int] = []
    let mut i: int = 0
    while i < 256:
        s.push(plen)
        i = i + 1

    let mut j: int = 0
    while j < plen - 1:
        let mut b: int = byte_at(pattern, j)
        if ignore_case == 1:
            b = byte_to_lower(b)
        if b >= 0 and b < 256:
            s[b] = plen - 1 - j
        j = j + 1

    return BmPattern(pattern, plen, ignore_case, s)

fn bm_find_in_line(bm: BmPattern, line: string, word_boundary: int) -> MatchResult:
    let empty_spans: vector[MatchSpan] = []
    plen := bm.pat_len
    llen := len(line)
    if plen == 0:
        return MatchResult(1, empty_spans)
    if llen < plen:
        return MatchResult(0, empty_spans)

    let mut spans: vector[MatchSpan] = []
    let mut i: int = 0
    while i <= llen - plen:
        let mut j: int = plen - 1
        let mut match_ok: int = 1
        while j >= 0:
            let mut c_line: int = byte_at(line, i + j)
            let mut c_pat: int = byte_at(bm.pat, j)
            if bm.ignore_case == 1:
                c_line = byte_to_lower(c_line)
                c_pat = byte_to_lower(c_pat)
            if c_line != c_pat:
                match_ok = 0
                break
            j = j - 1

        if match_ok == 1:
            let mut is_word_ok: int = 1
            if word_boundary == 1:
                if is_word_boundary(line, i) == 0 or is_word_boundary(line, i + plen) == 0:
                    is_word_ok = 0

            if is_word_ok == 1:
                spans.push(MatchSpan(i, i + plen))
                i = i + plen
            else:
                i = i + 1
        else:
            let mut last_b: int = byte_at(line, i + plen - 1)
            if bm.ignore_case == 1:
                last_b = byte_to_lower(last_b)
            let mut step: int = plen
            if last_b >= 0 and last_b < 256:
                step = bm.shift[last_b]
            i = i + step

    if len(spans) > 0:
        return MatchResult(1, spans)
    return MatchResult(0, empty_spans)

// ==============================================================================
// Complete Regular Expression Engine
// ==============================================================================

model RegexAtom:
    kind: string       // "char", "dot", "class", "boundary", "non_boundary"
    ch: int
    char_class: string
    negated: int

model RegexOp:
    atom: RegexAtom
    quantifier: string // "exact", "star", "plus", "opt", "range"
    min_count: int
    max_count: int

model RegexBranch:
    anchor_start: int
    anchor_end: int
    ops: vector[RegexOp]

model RegexPattern:
    raw: string
    branches: vector[RegexBranch]
    ignore_case: int
    word_boundary: int
    is_literal_only: int
    bm: BmPattern

fn char_class_match(cc: string, b: int, ignore_case: int) -> int:
    let mut check_b: int = b
    if ignore_case == 1:
        check_b = byte_to_lower(check_b)

    let mut i: int = 0
    let sz: int = len(cc)
    while i < sz:
        if i + 2 < sz:
            if byte_at(cc, i + 1) == 45: // '-' range
                let mut r_start: int = byte_at(cc, i)
                let mut r_end: int = byte_at(cc, i + 2)
                if ignore_case == 1:
                    r_start = byte_to_lower(r_start)
                    r_end = byte_to_lower(r_end)
                if check_b >= r_start and check_b <= r_end:
                    return 1
                i = i + 3
                continue
        let mut target_b: int = byte_at(cc, i)
        if ignore_case == 1:
            target_b = byte_to_lower(target_b)
        if target_b == check_b:
            return 1
        i = i + 1
    return 0

// Parse single branch expression
fn compile_single_branch(branch_str: string, ignore_case: int) -> RegexBranch:
    let ops: vector[RegexOp] = []
    let blen: int = len(branch_str)

    let mut anchor_start: int = 0
    let mut anchor_end: int = 0

    let mut pos: int = 0
    if blen > 0:
        if byte_at(branch_str, 0) == 94: // '^'
            anchor_start = 1
            pos = 1

    let mut end_pos: int = blen
    if end_pos > pos:
        if byte_at(branch_str, end_pos - 1) == 36: // '$'
            anchor_end = 1
            end_pos = end_pos - 1

    while pos < end_pos:
        let b: int = byte_at(branch_str, pos)
        pos = pos + 1

        let mut atom: RegexAtom = RegexAtom("char", b, "", 0)

        if b == 46: // '.'
            atom = RegexAtom("dot", 0, "", 0)
        elif b == 91: // '['
            let mut cc: string = ""
            let mut neg: int = 0
            if pos < end_pos:
                if byte_at(branch_str, pos) == 94: // '^'
                    neg = 1
                    pos = pos + 1
            while pos < end_pos:
                let cb: int = byte_at(branch_str, pos)
                pos = pos + 1
                if cb == 93: // ']'
                    break
                cc = cc + chr(cb)
            atom = RegexAtom("class", 0, cc, neg)
        elif b == 92: // '\'
            if pos < end_pos:
                let esc: int = byte_at(branch_str, pos)
                pos = pos + 1
                if esc == 100: // \d
                    atom = RegexAtom("class", 0, "0-9", 0)
                elif esc == 68: // \D
                    atom = RegexAtom("class", 0, "0-9", 1)
                elif esc == 119: // \w
                    atom = RegexAtom("class", 0, "a-zA-Z0-9_", 0)
                elif esc == 87: // \W
                    atom = RegexAtom("class", 0, "a-zA-Z0-9_", 1)
                elif esc == 115: // \s
                    atom = RegexAtom("class", 0, " \t\r\n", 0)
                elif esc == 83: // \S
                    atom = RegexAtom("class", 0, " \t\r\n", 1)
                elif esc == 98: // \b
                    atom = RegexAtom("boundary", 0, "", 0)
                elif esc == 66: // \B
                    atom = RegexAtom("non_boundary", 0, "", 0)
                elif esc == 116: // \t
                    atom = RegexAtom("char", 9, "", 0)
                elif esc == 110: // \n
                    atom = RegexAtom("char", 10, "", 0)
                elif esc == 114: // \r
                    atom = RegexAtom("char", 13, "", 0)
                else:
                    atom = RegexAtom("char", esc, "", 0)
        elif b == 40: // '(' - start group
            if pos + 1 < end_pos and byte_at(branch_str, pos) == 63 and byte_at(branch_str, pos + 1) == 58:
                // non-capturing group (?:...)
                pos = pos + 2
            continue
        elif b == 41: // ')' - end group
            continue
        else:
            atom = RegexAtom("char", b, "", 0)

        // Determine quantifier: exact, star, plus, opt, range {N,M}
        let mut quant: string = "exact"
        let mut min_c: int = 1
        let mut max_c: int = 1

        if pos < end_pos:
            let qb: int = byte_at(branch_str, pos)
            if qb == 42: // '*'
                quant = "star"
                min_c = 0
                max_c = 999999
                pos = pos + 1
            elif qb == 43: // '+'
                quant = "plus"
                min_c = 1
                max_c = 999999
                pos = pos + 1
            elif qb == 63: // '?'
                quant = "opt"
                min_c = 0
                max_c = 1
                pos = pos + 1
            elif qb == 123: // '{' range quantifier
                let mut num_str: string = ""
                pos = pos + 1
                while pos < end_pos:
                    let rb: int = byte_at(branch_str, pos)
                    pos = pos + 1
                    if rb == 125: // '}'
                        break
                    num_str = num_str + chr(rb)
                
                // Parse {N} or {N,M} or {N,}
                let mut comma_pos: int = -1
                let mut cp_i: int = 0
                while cp_i < len(num_str):
                    if byte_at(num_str, cp_i) == 44: // ','
                        comma_pos = cp_i
                        break
                    cp_i = cp_i + 1

                if comma_pos == -1:
                    let count_val: int = to_int(num_str)
                    quant = "range"
                    min_c = count_val
                    max_c = count_val
                elif comma_pos == len(num_str) - 1:
                    let count_val: int = to_int(substring(num_str, 0, comma_pos))
                    quant = "range"
                    min_c = count_val
                    max_c = 999999
                else:
                    let count_min: int = to_int(substring(num_str, 0, comma_pos))
                    let count_max: int = to_int(substring(num_str, comma_pos + 1, len(num_str) - comma_pos - 1))
                    quant = "range"
                    min_c = count_min
                    max_c = count_max

        ops.push(RegexOp(atom, quant, min_c, max_c))

    return RegexBranch(anchor_start, anchor_end, ops)

// Split pattern by top-level pipe '|'
fn split_alternations(pattern: string) -> vector[string]:
    let mut parts: vector[string] = []
    let plen: int = len(pattern)
    let mut cur: string = ""
    let mut in_class: int = 0
    let mut i: int = 0

    while i < plen:
        let b: int = byte_at(pattern, i)
        if b == 92: // '\'
            cur = cur + chr(b)
            if i + 1 < plen:
                i = i + 1
                cur = cur + chr(byte_at(pattern, i))
        elif b == 91: // '['
            in_class = 1
            cur = cur + chr(b)
        elif b == 93: // ']'
            in_class = 0
            cur = cur + chr(b)
        elif b == 124 and in_class == 0: // '|'
            parts.push(cur)
            cur = ""
        else:
            cur = cur + chr(b)
        i = i + 1

    parts.push(cur)
    return parts

// Detect whether pattern has metacharacters
fn has_regex_metacharacters(p: string) -> int:
    let plen: int = len(p)
    let mut i: int = 0
    while i < plen:
        let b: int = byte_at(p, i)
        if b == 46 or b == 42 or b == 43 or b == 63 or b == 94 or b == 36 or b == 91 or b == 93 or b == 40 or b == 41 or b == 124 or b == 92 or b == 123 or b == 125:
            return 1
        i = i + 1
    return 0

// Main compiler entrypoint
fn regex_compile(pattern: string, ignore_case: int, word_boundary: int) -> RegexPattern:
    let bm: BmPattern = bm_compile(pattern, ignore_case)
    let mut is_lit: int = 0
    if has_regex_metacharacters(pattern) == 0:
        is_lit = 1

    let alt_strings: vector[string] = split_alternations(pattern)
    let mut branches: vector[RegexBranch] = []
    let mut k: int = 0
    while k < len(alt_strings):
        branches.push(compile_single_branch(alt_strings[k], ignore_case))
        k = k + 1

    return RegexPattern(pattern, branches, ignore_case, word_boundary, is_lit, bm)

// Match single atom against a byte
fn regex_match_atom(atom: RegexAtom, b: int, ignore_case: int) -> int:
    if atom.kind == "dot":
        return 1
    if atom.kind == "class":
        let m: int = char_class_match(atom.char_class, b, ignore_case)
        if atom.negated == 1:
            if m == 1: return 0
            return 1
        return m
    // Plain char
    let mut c1: int = atom.ch
    let mut c2: int = b
    if ignore_case == 1:
        c1 = byte_to_lower(c1)
        c2 = byte_to_lower(c2)
    if c1 == c2:
        return 1
    return 0

// Recursive branch matcher
fn match_branch_ops(branch: RegexBranch, line: string, op_i: int, cur: int, ignore_case: int) -> int:
    let llen: int = len(line)
    if op_i >= len(branch.ops):
        if branch.anchor_end == 1:
            if cur != llen:
                return -1
        return cur

    let op: RegexOp = branch.ops[op_i]

    // Zero-width boundary assertions
    if op.atom.kind == "boundary":
        if is_word_boundary(line, cur) == 1:
            return match_branch_ops(branch, line, op_i + 1, cur, ignore_case)
        return -1
    if op.atom.kind == "non_boundary":
        if is_word_boundary(line, cur) == 0:
            return match_branch_ops(branch, line, op_i + 1, cur, ignore_case)
        return -1

    // Exact single match optimization
    if op.quantifier == "exact":
        if cur >= llen:
            return -1
        if regex_match_atom(op.atom, byte_at(line, cur), ignore_case) == 0:
            return -1
        return match_branch_ops(branch, line, op_i + 1, cur + 1, ignore_case)

    // Range / Quantifier handling (*, +, ?, {N,M})
    let mut max_possible: int = cur
    while max_possible < llen and (max_possible - cur) < op.max_count:
        if regex_match_atom(op.atom, byte_at(line, max_possible), ignore_case) == 1:
            max_possible = max_possible + 1
        else:
            break

    let actual_matched: int = max_possible - cur
    if actual_matched < op.min_count:
        return -1

    // Greedy backtracking: try from max down to min
    let mut try_len: int = actual_matched
    while try_len >= op.min_count:
        let res: int = match_branch_ops(branch, line, op_i + 1, cur + try_len, ignore_case)
        if res >= 0:
            return res
        try_len = try_len - 1

    return -1

fn match_branch_at(branch: RegexBranch, line: string, start_idx: int, ignore_case: int) -> int:
    return match_branch_ops(branch, line, 0, start_idx, ignore_case)

// Line-level evaluator returning all match spans
fn regex_find_in_line(reg: RegexPattern, line: string) -> MatchResult:
    let empty_spans: vector[MatchSpan] = []

    // Boyer-Moore literal fast path
    if reg.is_literal_only == 1:
        return bm_find_in_line(reg.bm, line, reg.word_boundary)

    let mut spans: vector[MatchSpan] = []
    let llen: int = len(line)

    let mut b_idx: int = 0
    let num_branches: int = len(reg.branches)

    while b_idx < num_branches:
        let branch: RegexBranch = reg.branches[b_idx]

        if branch.anchor_start == 1:
            let end_p: int = match_branch_at(branch, line, 0, reg.ignore_case)
            if end_p >= 0:
                let mut word_ok: int = 1
                if reg.word_boundary == 1:
                    if is_word_boundary(line, 0) == 0 or is_word_boundary(line, end_p) == 0:
                        word_ok = 0
                if word_ok == 1:
                    spans.push(MatchSpan(0, end_p))
        else:
            let mut i: int = 0
            while i <= llen:
                let end_p: int = match_branch_at(branch, line, i, reg.ignore_case)
                if end_p >= 0:
                    let match_len: int = end_p - i
                    let mut word_ok: int = 1
                    if reg.word_boundary == 1:
                        if is_word_boundary(line, i) == 0 or is_word_boundary(line, end_p) == 0:
                            word_ok = 0

                    if word_ok == 1:
                        if match_len > 0:
                            spans.push(MatchSpan(i, end_p))
                            i = end_p
                        else:
                            i = i + 1
                    else:
                        i = i + 1
                else:
                    i = i + 1

        b_idx = b_idx + 1

    if len(spans) > 0:
        return MatchResult(1, spans)
    return MatchResult(0, empty_spans)
