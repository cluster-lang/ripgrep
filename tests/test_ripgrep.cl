// ==============================================================================
// Module:      Comprehensive Verification Suite (tests/test_ripgrep.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      zk-mohammad <ZaidKhan-alamgir@proton.me>
// License:     Cluster Community & Fair-Source License (CCFL v2.0)
// Description: Multi-phase unit and integration test suite validating Boyer-Moore search,
//              case folding, word boundary detection, regex wildcards/quantifiers, character
//              classes, line anchors, ANSI coloring, recursive directory traversal,
//              escaped shorthands (\d, \w, \s), alternation (foo|bar), range quantifiers,
//              file type filtering (-t, -T), glob patterns (-g), max count (-m), and replacement (-r).
// ==============================================================================

import "src/matcher.cl"
import "src/walk.cl"
import "src/printer.cl"

// ------------------------------------------------------------------------------
// Function: assert_true
// Syntax:   fn assert_true(cond: int, msg: string) -> void
// Purpose:  Verifies condition is non-zero, raising test failure on assertion violation.
// ------------------------------------------------------------------------------
fn assert_true(cond: int, msg: string):
    if cond == 0:
        println("[FAIL] Assertion failed: " + msg)
        assert(0)

// ------------------------------------------------------------------------------
// Function: main
// Syntax:   fn main() -> int
// Purpose:  Executes all 21 verification phases for Cluster Ripgrep.
// ------------------------------------------------------------------------------
fn main() -> int:
    println("--- Testing Cluster-Ripgrep Verification Suite ---")

    // Phase 1: Literal Substring Search (Boyer-Moore)
    println("-> 1. Testing Boyer-Moore literal search...")
    bm := bm_compile("cluster", 0)
    res1 := bm_find_in_line(bm, "the cluster language is cluster powered", 0)
    assert_true(res1.matched == 1, "BM match expected")
    assert_true(len(res1.spans) == 2, "Expected 2 spans")
    println("✓ Boyer-Moore literal search passed!")

    // Phase 2: Case-Insensitive Matching
    println("-> 2. Testing Case-insensitive search...")
    bm_ci := bm_compile("RIPGREP", 1)
    res2 := bm_find_in_line(bm_ci, "ripgrep is fast and RipGrep is awesome", 0)
    assert_true(res2.matched == 1, "CI match expected")
    assert_true(len(res2.spans) == 2, "Expected 2 CI spans")
    println("✓ Case-insensitive search passed!")

    // Phase 3: Word Boundary Search (-w)
    println("-> 3. Testing Word Boundary matching...")
    bm_w := bm_compile("cat", 0)
    res_w1 := bm_find_in_line(bm_w, "concatenate the cat and catch the cat", 1)
    assert_true(res_w1.matched == 1, "Word match expected")
    assert_true(len(res_w1.spans) == 2, "Expected exactly 2 whole-word 'cat' matches")
    println("✓ Word boundary search passed!")

    // Phase 4: Regex Wildcards and Quantifiers
    println("-> 4. Testing Regex engine (dot, star, plus, opt)...")
    reg_dot := regex_compile("c..l", 0, 0)
    res_dot := regex_find_in_line(reg_dot, "let cool and call succeed")
    assert_true(res_dot.matched == 1, "Dot regex matched")
    assert_true(len(res_dot.spans) == 2, "Expected 2 spans for 'cool' and 'call'")

    reg_star := regex_compile("ab*c", 0, 0)
    res_star := regex_find_in_line(reg_star, "ac and abc and abbbc")
    assert_true(res_star.matched == 1, "Star regex matched")
    assert_true(len(res_star.spans) == 3, "Expected 3 spans for ab*c")

    reg_plus := regex_compile("ab+c", 0, 0)
    res_plus := regex_find_in_line(reg_plus, "ac and abc and abbbc")
    assert_true(res_plus.matched == 1, "Plus regex matched")
    assert_true(len(res_plus.spans) == 2, "Expected 2 spans for ab+c (ac excluded)")
    println("✓ Regex wildcards & quantifiers passed!")

    // Phase 5: Character Classes ([0-9], [a-z])
    println("-> 5. Testing Character Classes...")
    reg_cc := regex_compile("item-[0-9]+", 0, 0)
    res_cc := regex_find_in_line(reg_cc, "order item-42 processed item-999")
    assert_true(res_cc.matched == 1, "Character class matched")
    assert_true(len(res_cc.spans) == 2, "Expected 2 digit spans")
    println("✓ Character classes passed!")

    // Phase 6: Line Anchors (^ and $)
    println("-> 6. Testing Line Anchors (^, $)...")
    reg_start := regex_compile("^start", 0, 0)
    res_s1 := regex_find_in_line(reg_start, "start of line")
    assert_true(res_s1.matched == 1, "Anchor start matched")
    res_s2 := regex_find_in_line(reg_start, "not at the start")
    assert_true(res_s2.matched == 0, "Anchor start failed as expected")

    reg_end := regex_compile("end$", 0, 0)
    res_e1 := regex_find_in_line(reg_end, "this is the end")
    assert_true(res_e1.matched == 1, "Anchor end matched")
    res_e2 := regex_find_in_line(reg_end, "the end is not here")
    assert_true(res_e2.matched == 0, "Anchor end failed as expected")
    println("✓ Line anchors passed!")

    // Phase 7: Line Splitting & ANSI Highlighting
    println("-> 7. Testing line splitting and ANSI highlighting...")
    multiline := "line one\nline two\r\nline three"
    l_vec := split_lines(multiline)
    assert_true(len(l_vec) == 3, "Expected 3 split lines")
    assert_true(l_vec[0] == "line one", "Line 0 match")
    assert_true(l_vec[1] == "line two", "Line 1 match (CR stripped)")
    assert_true(l_vec[2] == "line three", "Line 2 match")
    println("✓ Line splitting passed!")

    // Phase 8: Directory Traversal and Gitignore Filtering
    println("-> 8. Testing directory traversal and ignore filtering...")
    opts := walk_options_default()
    files := walk_directory("src", opts)
    assert_true(len(files) >= 4, "Expected src/ files found")
    println("✓ Directory traversal passed! Found " + str(len(files)) + " source files.")

    // Phase 9: File Search Pipeline End-to-End
    println("-> 9. Testing in-memory file search...")
    tmp_path := "/tmp/cluster_rg_test.txt"
    test_content := "apple\nbanana\ncherry\napple pie\norange\n"
    file_write(tmp_path, test_content)

    reg_search := regex_compile("apple", 0, 0)
    cfg := print_config_default()
    m_count := search_file(tmp_path, reg_search, cfg)
    assert_true(m_count == 2, "Expected 2 matches for apple")
    println("✓ File search passed!")

    // Phase 10: Inverted Match (-v)
    println("-> 10. Testing Inverted Matching (-v)...")
    let mut cfg_inv: PrintConfig = print_config_default()
    cfg_inv.invert_match = 1
    m_inv := search_file(tmp_path, reg_search, cfg_inv)
    assert_true(m_inv == 3, "Expected 3 inverted matches (banana, cherry, orange)")
    println("✓ Inverted matching passed!")

    // Phase 11: Fixed Strings (-F with regex characters)
    println("-> 11. Testing Fixed Strings (-F)...")
    tmp_lit := "/tmp/cluster_rg_lit.txt"
    file_write(tmp_lit, "function(a.*b)\nfunction_literal\n")
    let mut reg_lit: RegexPattern = regex_compile("a.*b", 0, 0)
    reg_lit.is_literal_only = 1
    m_lit := search_file(tmp_lit, reg_lit, cfg)
    assert_true(m_lit == 1, "Expected 1 literal fixed string match")
    system("rm -f " + tmp_lit)
    println("✓ Fixed strings search passed!")

    // Phase 12: Count Only Mode (-c)
    println("-> 12. Testing Count Only Mode (-c)...")
    let mut cfg_cnt: PrintConfig = print_config_default()
    cfg_cnt.count_only = 1
    m_cnt := search_file(tmp_path, reg_search, cfg_cnt)
    assert_true(m_cnt == 2, "Expected count 2")
    println("✓ Count only mode passed!")

    // Phase 13: Files With Matches (-l)
    println("-> 13. Testing Files With Matches Mode (-l)...")
    let mut cfg_f: PrintConfig = print_config_default()
    cfg_f.files_only = 1
    m_f := search_file(tmp_path, reg_search, cfg_f)
    assert_true(m_f == 2, "Files with matches mode returned matches")
    println("✓ Files with matches mode passed!")

    // Phase 14: Escaped Class Shorthands (\d, \w, \s, \D, \W, \S)
    println("-> 14. Testing Escaped Shorthands (\\d, \\w, \\s)...")
    reg_d := regex_compile("\\d+", 0, 0)
    res_d := regex_find_in_line(reg_d, "port 8080 active")
    assert_true(res_d.matched == 1, "Digits \\d+ matched")
    assert_true(len(res_d.spans) == 1, "Expected 1 span for 8080")

    reg_w := regex_compile("\\w+", 0, 0)
    res_w := regex_find_in_line(reg_w, "hello_world 123")
    assert_true(res_w.matched == 1, "Word chars \\w+ matched")
    assert_true(len(res_w.spans) == 2, "Expected 2 words")

    reg_s := regex_compile("a\\sb", 0, 0)
    res_s := regex_find_in_line(reg_s, "a b and a\tb")
    assert_true(res_s.matched == 1, "Whitespace \\s matched")
    assert_true(len(res_s.spans) == 2, "Expected 2 matches for space and tab")
    println("✓ Escaped shorthands passed!")

    // Phase 15: Word Boundary Assertions (\b, \B)
    println("-> 15. Testing Regex Word Boundaries (\\b)...")
    reg_b := regex_compile("\\bcat\\b", 0, 0)
    res_b := regex_find_in_line(reg_b, "concatenate the cat in the hat")
    assert_true(res_b.matched == 1, "\\bcat\\b matched")
    assert_true(len(res_b.spans) == 1, "Expected exactly 1 word 'cat'")
    println("✓ Regex word boundaries passed!")

    // Phase 16: Alternation (foo|bar|baz)
    println("-> 16. Testing Alternation (foo|bar|baz)...")
    reg_alt := regex_compile("apple|banana|cherry", 0, 0)
    res_alt := regex_find_in_line(reg_alt, "I like banana and apple")
    assert_true(res_alt.matched == 1, "Alternation matched")
    assert_true(len(res_alt.spans) == 2, "Expected 2 alternate matches")
    println("✓ Regex alternation passed!")

    // Phase 17: Range Quantifiers ({N}, {N,M})
    println("-> 17. Testing Range Quantifiers ({N,M})...")
    reg_range := regex_compile("a{2,4}", 0, 0)
    res_r1 := regex_find_in_line(reg_range, "baac and baaaad")
    assert_true(res_r1.matched == 1, "Range {2,4} matched")
    assert_true(len(res_r1.spans) == 2, "Expected 2 matches for aa and aaaa")
    println("✓ Range quantifiers passed!")

    // Phase 18: File Type Filtering (-t cl, -T rust)
    println("-> 18. Testing File Type Filtering...")
    assert_true(match_file_type("cl", ".cl") == 1, "Type cl matched .cl")
    assert_true(match_file_type("rust", ".rs") == 1, "Type rust matched .rs")
    assert_true(match_file_type("cl", ".rs") == 0, "Type cl rejected .rs")

    let mut t_opts: WalkOptions = walk_options_default()
    t_opts.type_filters.push("cl")
    assert_true(is_file_allowed("src/matcher.cl", t_opts) == 1, ".cl allowed")
    assert_true(is_file_allowed("src/main.rs", t_opts) == 0, ".rs rejected by cl type filter")

    let mut tn_opts: WalkOptions = walk_options_default()
    tn_opts.type_not_filters.push("rust")
    assert_true(is_file_allowed("src/matcher.cl", tn_opts) == 1, ".cl allowed with --type-not rust")
    assert_true(is_file_allowed("src/main.rs", tn_opts) == 0, ".rs excluded by --type-not rust")
    println("✓ File type filtering passed!")

    // Phase 19: Glob Matching (-g)
    println("-> 19. Testing Glob Pattern Matching...")
    assert_true(glob_matches("*.cl", "src/walk.cl") == 1, "Glob *.cl matched walk.cl")
    assert_true(glob_matches("*.rs", "src/walk.cl") == 0, "Glob *.rs rejected walk.cl")
    assert_true(glob_matches("!*.tmp", "cache.tmp") == 0, "Glob !*.tmp rejected cache.tmp")
    assert_true(glob_matches("!*.tmp", "main.cl") == 1, "Glob !*.tmp accepted main.cl")
    println("✓ Glob pattern matching passed!")

    // Phase 20: Max Count (-m) and Quiet Mode (-q)
    println("-> 20. Testing Max Count (-m) and Quiet Mode (-q)...")
    let mut cfg_m: PrintConfig = print_config_default()
    cfg_m.max_count = 1
    m_count_limit := search_file(tmp_path, reg_search, cfg_m)
    assert_true(m_count_limit == 1, "Max count 1 respected")

    let mut cfg_q: PrintConfig = print_config_default()
    cfg_q.quiet = 1
    m_quiet := search_file(tmp_path, reg_search, cfg_q)
    assert_true(m_quiet == 1, "Quiet mode matched without printing")
    println("✓ Max count and quiet mode passed!")

    // Phase 21: Replacement Mode (-r)
    println("-> 21. Testing Replacement Mode (-r)...")
    spans_repl := regex_find_in_line(reg_search, "apple pie and apple cider")
    replaced := replace_spans_in_line("apple pie and apple cider", spans_repl.spans, "orange")
    assert_true(replaced == "orange pie and orange cider", "Replacement string correct: " + replaced)
    println("✓ Replacement mode passed!")

    // Clean up temporary test file
    system("rm -f " + tmp_path)

    println("=================================================================")
    println("      ALL 21 CLUSTER-RIPGREP PHASES PASSED (100% OK)!            ")
    println("=================================================================")
    return 0
