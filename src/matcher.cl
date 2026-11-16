// ==============================================================================
// Module:      Fast Matcher Engine (matcher.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      mohammadzaid/(cluster) <zkalamgir@proton.me>
// License:     Cluster Community // License:     MIT License Fair-Source License (CCFL-1.0)
// Description: High-speed Boyer-Moore-Horspool substring search and regular expression
//              engine with DFA/NFA evaluation, greedy backtracking, character classes,
//              word boundary checks, and match span extraction.
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   MatchSpan
// Purpose: Stores the 0-indexed byte offset range [start_pos, end_pos) of a matched token.
// Fields:
//   start_pos: Starting byte index in the line string
//   end_pos:   Ending byte index (exclusive) in the line string
// ------------------------------------------------------------------------------
model MatchSpan:
    start_pos: int
    end_pos: int

// ------------------------------------------------------------------------------
// Model:   MatchResult
// Purpose: Encapsulates the overall result of a line search and all matched spans.
// Fields:
//   matched: 1 if at least one match occurred in the line, 0 otherwise
//   spans:   Collection of individual MatchSpan offsets for syntax highlighting
// ------------------------------------------------------------------------------
model MatchResult:
    matched: int
    spans: vector[MatchSpan]

// ------------------------------------------------------------------------------
// Function: byte_to_lower
// Syntax:   fn byte_to_lower(b: int) -> int
// Purpose:  Converts an ASCII byte to lowercase if it falls in the uppercase range 'A'-'Z'.
// ------------------------------------------------------------------------------
fn byte_to_lower(b: int) -> int:
    if b >= 65:
        if b <= 90:
            return b + 32
    return b

// ==============================================================================
// Boyer-Moore-Horspool Fast Substring Matcher
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   BmPattern
// Purpose: Precompiled Boyer-Moore-Horspool bad-character shift lookup table.
// Fields:
//   pat:         The raw pattern string
//   pat_len:     Length of pattern in bytes
//   ignore_case: 1 for case-insensitive matching, 0 for case-sensitive
//   shift:       256-element jump table indexed by ASCII character byte
// ------------------------------------------------------------------------------
model BmPattern:
    pat: string
    pat_len: int
    ignore_case: int
    shift: vector[int]

// ------------------------------------------------------------------------------
// Function: bm_compile
// Syntax:   fn bm_compile(pattern: string, ignore_case: int) -> BmPattern
// Purpose:  Constructs a bad-character shift table for sublinear Boyer-Moore scanning.
// ------------------------------------------------------------------------------
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

// ------------------------------------------------------------------------------
// Function: bm_find_in_line
// Syntax:   fn bm_find_in_line(bm: BmPattern, line: string, word_boundary: int) -> MatchResult
// Purpose:  Executes sublinear Boyer-Moore-Horspool substring search over a single line,
//           optionally enforcing whole-word boundaries (-w flag).
// ------------------------------------------------------------------------------
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
            // Check word boundary if requested
            let mut is_word_ok: int = 1
            if word_boundary == 1:
                if i > 0:
                    prev_b := byte_at(line, i - 1)
                    if (prev_b >= 65 and prev_b <= 90) or (prev_b >= 97 and prev_b <= 122) or (prev_b >= 48 and prev_b <= 57) or prev_b == 95:
                        is_word_ok = 0
                if i + plen < llen:
                    next_b := byte_at(line, i + plen)
                    if (next_b >= 65 and next_b <= 90) or (next_b >= 97 and next_b <= 122) or (next_b >= 48 and next_b <= 57) or next_b == 95:
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
// Regular Expression Matcher Engine
// ==============================================================================

// ------------------------------------------------------------------------------
// Model:   RegexAtom
// Purpose: Basic token atom within a compiled regex expression (char, dot, or character class).
// Fields:
//   kind:       Atom type identifier: "char", "dot", or "class"
//   ch:         Single character byte value when kind == "char"
//   char_class: String representation of character set/ranges when kind == "class"
//   negated:    1 if character class is inverted ([^...]), 0 otherwise
// ------------------------------------------------------------------------------
model RegexAtom:
    kind: string    // "char", "dot", "class"
    ch: int
    char_class: string
    negated: int

// ------------------------------------------------------------------------------
// Model:   RegexOp
// Purpose: Pairs a regex atom with its repetition quantifier ("exact", "star", "plus", "opt").
// ------------------------------------------------------------------------------
model RegexOp:
    atom: RegexAtom
    quantifier: string // "exact", "star", "plus", "opt"

// ------------------------------------------------------------------------------
// Model:   RegexPattern
// Purpose: Complete compiled regex structure containing anchors, sequence of ops,
//          case-sensitivity flags, and Boyer-Moore literal fast path.
// ------------------------------------------------------------------------------
model RegexPattern:
    raw: string
    anchor_start: int
    anchor_end: int
    ops: vector[RegexOp]
    ignore_case: int
    word_boundary: int
    is_literal_only: int
    bm: BmPattern

// ------------------------------------------------------------------------------
// Function: is_regex_meta
// Syntax:   fn is_regex_meta(c: int) -> int
// Purpose:  Returns 1 if the byte corresponds to a regex metacharacter (. * + ? ^ $ [ ] ( ) | \).
// ------------------------------------------------------------------------------
fn is_regex_meta(c: int) -> int:
    if c == 46 or c == 42 or c == 43 or c == 63 or c == 94 or c == 36 or c == 91 or c == 93 or c == 40 or c == 41 or c == 124 or c == 92:
        return 1
    return 0

// ------------------------------------------------------------------------------
// Function: char_class_match
// Syntax:   fn char_class_match(cc: string, b: int, ignore_case: int) -> int
// Purpose:  Tests whether a byte 'b' matches any literal or hyphen range in character class 'cc'.
// ------------------------------------------------------------------------------
fn char_class_match(cc: string, b: int, ignore_case: int) -> int:
    let mut check_b: int = b
    if ignore_case == 1:
        check_b = byte_to_lower(check_b)

    let mut i: int = 0
    let sz: int = len(cc)
    while i < sz:
        if i + 2 < sz:
            if byte_at(cc, i + 1) == 45: // '-' range
                r_start := byte_at(cc, i)
                r_end := byte_at(cc, i + 2)
                if check_b >= r_start and check_b <= r_end:
                    return 1
                i = i + 3
                continue
        if byte_at(cc, i) == check_b:
            return 1
        i = i + 1
    return 0

// ------------------------------------------------------------------------------
// Function: regex_compile
// Syntax:   fn regex_compile(pattern: string, ignore_case: int, word_boundary: int) -> RegexPattern
// Purpose:  Compiles a regex pattern string into a stream of atomic operators and quantifiers,
//           detecting literal substrings to automatically activate the Boyer-Moore fast path.
// ------------------------------------------------------------------------------
fn regex_compile(pattern: string, ignore_case: int, word_boundary: int) -> RegexPattern:
    let ops: vector[RegexOp] = []
    let plen: int = len(pattern)
    let bm: BmPattern = bm_compile(pattern, ignore_case)

    let mut anchor_start: int = 0
    let mut anchor_end: int = 0
    let mut has_meta: int = 0

    let mut pos: int = 0
    if plen > 0:
        if byte_at(pattern, 0) == 94: // '^'
            anchor_start = 1
            has_meta = 1
            pos = 1

    let mut end_pos: int = plen
    if end_pos > pos:
        if byte_at(pattern, end_pos - 1) == 36: // '$'
            anchor_end = 1
            has_meta = 1
            end_pos = end_pos - 1

    while pos < end_pos:
        b := byte_at(pattern, pos)
        pos = pos + 1

        let mut atom: RegexAtom = RegexAtom("char", b, "", 0)

        if b == 46: // '.'
            atom = RegexAtom("dot", 0, "", 0)
            has_meta = 1
        elif b == 91: // '['
            has_meta = 1
            let mut cc: string = ""
            let mut neg: int = 0
            if pos < end_pos:
                if byte_at(pattern, pos) == 94: // '^'
                    neg = 1
                    pos = pos + 1
            while pos < end_pos:
                cb := byte_at(pattern, pos)
                pos = pos + 1
                if cb == 93: // ']'
                    break
                cc = cc + chr(cb)
            atom = RegexAtom("class", 0, cc, neg)
        elif b == 92: // '\'
            if pos < end_pos:
                esc := byte_at(pattern, pos)
                pos = pos + 1
                if esc == 100: // \d
                    atom = RegexAtom("class", 0, "0-9", 0)
                    has_meta = 1
                elif esc == 119: // \w
                    atom = RegexAtom("class", 0, "a-zA-Z0-9_", 0)
                    has_meta = 1
                elif esc == 115: // \s
                    atom = RegexAtom("class", 0, " \t\r\n", 0)
                    has_meta = 1
                else:
                    atom = RegexAtom("char", esc, "", 0)
        else:
            atom = RegexAtom("char", b, "", 0)

        // Check quantifier
        let mut quant: string = "exact"
        if pos < end_pos:
            qb := byte_at(pattern, pos)
            if qb == 42: // '*'
                quant = "star"
                has_meta = 1
                pos = pos + 1
            elif qb == 43: // '+'
                quant = "plus"
                has_meta = 1
                pos = pos + 1
            elif qb == 63: // '?'
                quant = "opt"
                has_meta = 1
                pos = pos + 1

        ops.push(RegexOp(atom, quant))

    let mut is_lit: int = 0
    if has_meta == 0:
        is_lit = 1

    return RegexPattern(pattern, anchor_start, anchor_end, ops, ignore_case, word_boundary, is_lit, bm)

// ------------------------------------------------------------------------------
// Function: regex_match_atom
// Syntax:   fn regex_match_atom(atom: RegexAtom, b: int, ignore_case: int) -> int
// Purpose:  Evaluates whether a single byte 'b' satisfies an atomic regex condition.
// ------------------------------------------------------------------------------
fn regex_match_atom(atom: RegexAtom, b: int, ignore_case: int) -> int:
    if atom.kind == "dot":
        return 1
    if atom.kind == "class":
        m := char_class_match(atom.char_class, b, ignore_case)
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

// ------------------------------------------------------------------------------
// Function: regex_match_ops
// Syntax:   fn regex_match_ops(reg: RegexPattern, line: string, op_i: int, cur: int) -> int
// Purpose:  Recursive greedy backtracking evaluator for regex operator chains.
//           Returns the ending byte offset of the match, or -1 if no match occurs.
// ------------------------------------------------------------------------------
fn regex_match_ops(reg: RegexPattern, line: string, op_i: int, cur: int) -> int:
    llen := len(line)
    if op_i >= len(reg.ops):
        if reg.anchor_end == 1:
            if cur != llen:
                return -1
        return cur

    let op: RegexOp = reg.ops[op_i]
    q := op.quantifier

    if q == "exact":
        if cur >= llen:
            return -1
        if regex_match_atom(op.atom, byte_at(line, cur), reg.ignore_case) == 0:
            return -1
        return regex_match_ops(reg, line, op_i + 1, cur + 1)

    if q == "opt":
        if cur < llen:
            if regex_match_atom(op.atom, byte_at(line, cur), reg.ignore_case) == 1:
                res := regex_match_ops(reg, line, op_i + 1, cur + 1)
                if res >= 0:
                    return res
        return regex_match_ops(reg, line, op_i + 1, cur)

    if q == "plus":
        if cur >= llen:
            return -1
        if regex_match_atom(op.atom, byte_at(line, cur), reg.ignore_case) == 0:
            return -1
        let mut max_cur: int = cur + 1
        while max_cur < llen:
            if regex_match_atom(op.atom, byte_at(line, max_cur), reg.ignore_case) == 1:
                max_cur = max_cur + 1
            else:
                break
        let mut try_p: int = max_cur
        while try_p >= cur + 1:
            res := regex_match_ops(reg, line, op_i + 1, try_p)
            if res >= 0:
                return res
            try_p = try_p - 1
        return -1

    if q == "star":
        let mut max_cur: int = cur
        while max_cur < llen:
            if regex_match_atom(op.atom, byte_at(line, max_cur), reg.ignore_case) == 1:
                max_cur = max_cur + 1
            else:
                break
        let mut try_p: int = max_cur
        while try_p >= cur:
            res := regex_match_ops(reg, line, op_i + 1, try_p)
            if res >= 0:
                return res
            try_p = try_p - 1
        return -1

    return -1

// ------------------------------------------------------------------------------
// Function: regex_match_at
// Syntax:   fn regex_match_at(reg: RegexPattern, line: string, start_idx: int) -> int
// Purpose:  Tests whether the compiled regex pattern matches starting at byte offset start_idx.
// ------------------------------------------------------------------------------
fn regex_match_at(reg: RegexPattern, line: string, start_idx: int) -> int:
    return regex_match_ops(reg, line, 0, start_idx)

// ------------------------------------------------------------------------------
// Function: regex_find_in_line
// Syntax:   fn regex_find_in_line(reg: RegexPattern, line: string) -> MatchResult
// Purpose:  Scans a line for matches, delegating literal expressions to the Boyer-Moore
//           fast path, or evaluating anchored/unanchored regex patterns to return all spans.
// ------------------------------------------------------------------------------
fn regex_find_in_line(reg: RegexPattern, line: string) -> MatchResult:
    let empty_spans: vector[MatchSpan] = []

    // If pattern has no regex operators, delegate to Boyer-Moore fast path
    if reg.is_literal_only == 1:
        return bm_find_in_line(reg.bm, line, reg.word_boundary)

    let mut spans: vector[MatchSpan] = []
    llen := len(line)

    if reg.anchor_start == 1:
        end_p := regex_match_at(reg, line, 0)
        if end_p >= 0:
            spans.push(MatchSpan(0, end_p))
            return MatchResult(1, spans)
        return MatchResult(0, empty_spans)

    let mut i: int = 0
    while i <= llen:
        end_p := regex_match_at(reg, line, i)
        if end_p >= 0:
            let match_len: int = end_p - i
            if match_len > 0:
                spans.push(MatchSpan(i, end_p))
                i = end_p
            else:
                i = i + 1
        else:
            i = i + 1

    if len(spans) > 0:
        return MatchResult(1, spans)
    return MatchResult(0, empty_spans)
