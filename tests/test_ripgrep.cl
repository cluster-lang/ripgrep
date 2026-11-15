// ==============================================================================
// Comprehensive Test Suite for Cluster-Ripgrep
// 100% Pure Cluster Language Verification
// ==============================================================================

import "src/matcher.cl"
import "src/walk.cl"
import "src/printer.cl"

fn assert_true(cond: int, msg: string):
    if cond == 0:
        println("[FAIL] Assertion failed: " + msg)
        assert(0)

fn main() -> int:
    println("--- Testing Cluster-Ripgrep 100% Native Pure Engine ---")

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
    reg_cls := regex_compile("item-[0-9]+", 0, 0)
    res_cls := regex_find_in_line(reg_cls, "found item-42 and item-999 in list")
    assert_true(res_cls.matched == 1, "Class regex matched")
    assert_true(len(res_cls.spans) == 2, "Expected 2 spans for item-[0-9]+")
    println("✓ Character classes passed!")

    // Phase 6: Anchors (^, $)
    println("-> 6. Testing Line Anchors (^, $)...")
    reg_start := regex_compile("^hello", 0, 0)
    res_s1 := regex_find_in_line(reg_start, "hello world")
    res_s2 := regex_find_in_line(reg_start, "say hello world")
    assert_true(res_s1.matched == 1, "^hello should match at start")
    assert_true(res_s2.matched == 0, "^hello should NOT match non-start")

    reg_end := regex_compile("end$", 0, 0)
    res_e1 := regex_find_in_line(reg_end, "this is the end")
    res_e2 := regex_find_in_line(reg_end, "the ending is near")
    assert_true(res_e1.matched == 1, "end$ should match at line end")
    assert_true(res_e2.matched == 0, "end$ should NOT match non-end")
    println("✓ Line anchors passed!")

    // Phase 7: Split Lines and Highlighting
    println("-> 7. Testing line splitting and ANSI highlighting...")
    sample_text := "Line 1: Red\nLine 2: Blue\nLine 3: Green"
    lines := split_lines(sample_text)
    assert_true(len(lines) == 3, "Expected 3 lines")
    assert_true(lines[0] == "Line 1: Red", "Line 0 match")
    assert_true(lines[1] == "Line 2: Blue", "Line 1 match")
    assert_true(lines[2] == "Line 3: Green", "Line 2 match")
    println("✓ Line splitting passed!")

    // Phase 8: Directory Traversal
    println("-> 8. Testing directory traversal and ignore filtering...")
    w_opts := walk_options_default()
    files := walk_directory("src", w_opts)
    assert_true(len(files) >= 3, "Expected at least 3 source files in src/")
    println("✓ Directory traversal passed! Found " + str(len(files)) + " source files.")

    // Phase 9: File Search & Reporting
    println("-> 9. Testing in-memory file search...")
    test_file_path := "/tmp/cluster_rg_test.txt"
    file_write(test_file_path, "apple\nbanana\ncherry\napple pie\norange\n")
    p_reg := regex_compile("apple", 0, 0)
    p_cfg := print_config_default()
    hits := search_file(test_file_path, p_reg, p_cfg)
    assert_true(hits == 2, "Expected 2 hits for 'apple'")
    println("✓ File search passed!")

    // Phase 10: Inverted Matching (-v)
    println("-> 10. Testing Inverted Matching (-v)...")
    let p_cfg_v: PrintConfig = PrintConfig(1, 0, 0, 1, 0, 0, 0)
    hits_v := search_file(test_file_path, p_reg, p_cfg_v)
    assert_true(hits_v == 3, "Expected 3 non-apple lines (banana, cherry, orange)")
    println("✓ Inverted matching passed!")

    println("=================================================================")
    println("      ALL CLUSTER-RIPGREP TESTS PASSED (100% OK)!                ")
    println("=================================================================")
    return 0
