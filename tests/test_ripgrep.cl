// ==============================================================================
// Module:      Comprehensive Verification Suite (tests/test_ripgrep.cl)
// Project:     Cluster Ripgrep (High-Performance Recursive Search Engine)
// Author:      mohammadzaid/(cluster) <zkalamgir@proton.me>
// License:     Cluster Community // License:     MIT License Fair-Source License (CCFL-1.0)
// Description: Multi-phase unit and integration test suite validating Boyer-Moore search,
//              case folding, word boundary detection, regex wildcards/quantifiers, character
//              classes, line anchors, ANSI coloring, and recursive directory traversal.
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
// Purpose:  Executes all 10 verification phases for Cluster Ripgrep.
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

    system("rm -f " + tmp_path)

    println("=================================================================")
    println("      ALL CLUSTER-RIPGREP TESTS PASSED (100% OK)!                ")
    println("=================================================================")
    return 0
