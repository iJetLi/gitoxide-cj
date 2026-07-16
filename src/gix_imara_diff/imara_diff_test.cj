// 文件：imara_diff_test.cj
// 用途：gix_imara_diff 包的单元测试，对齐 Rust gitoxide gix-imara-diff 测试
// 所属包：gix.gix_imara_diff
// 对齐来源：gix-imara-diff/tests/*.rs, gix-imara-diff/src/tests.rs

package gitoxide.gix_imara_diff

import std.collection.*
import std.unittest.*

// ============================================================
// Diff 测试 — 对齐 gix-imara-diff/tests/diff.rs
// ============================================================

@Test
func testDiffConstruct(): Unit {
    // 对齐 Rust: Diff::default()
    let d = Diff()
    if (d.removed.size != 0) {
        throw Exception("removed should be empty initially")
    }
    if (d.added.size != 0) {
        throw Exception("added should be empty initially")
    }
}

@Test
func testDiffCountAdditions(): Unit {
    // 对齐 Rust: Diff::count_additions()
    let d = Diff()
    d.added.add(true)
    d.added.add(false)
    d.added.add(true)
    if (d.countAdditions() != 2) {
        throw Exception("should count 2 additions")
    }
}

@Test
func testDiffCountRemovals(): Unit {
    // 对齐 Rust: Diff::count_removals()
    let d = Diff()
    d.removed.add(true)
    d.removed.add(false)
    if (d.countRemovals() != 1) {
        throw Exception("should count 1 removal")
    }
}

@Test
func testDiffIsRemoved(): Unit {
    // 对齐 Rust: Diff::is_removed()
    let d = Diff()
    d.removed.add(true)
    d.removed.add(false)
    if (!d.isRemoved(0)) {
        throw Exception("index 0 should be removed")
    }
    if (d.isRemoved(1)) {
        throw Exception("index 1 should not be removed")
    }
}

@Test
func testDiffIsAdded(): Unit {
    // 对齐 Rust: Diff::is_added()
    let d = Diff()
    d.added.add(false)
    d.added.add(true)
    if (d.isAdded(0)) {
        throw Exception("index 0 should not be added")
    }
    if (!d.isAdded(1)) {
        throw Exception("index 1 should be added")
    }
}

// ============================================================
// Hunk 测试 — 对齐 gix-imara-diff/tests/hunk.rs
// ============================================================

@Test
func testHunkConstruct(): Unit {
    // 对齐 Rust: Hunk { old_start, old_len, new_start, new_len }
    let h = Hunk(1, 5, 1, 7)
    if (h.oldStart != 1) { throw Exception("oldStart should be 1") }
    if (h.oldLen != 5) { throw Exception("oldLen should be 5") }
    if (h.newStart != 1) { throw Exception("newStart should be 1") }
    if (h.newLen != 7) { throw Exception("newLen should be 7") }
}

@Test
func testHunkIsPureInsertion(): Unit {
    // 对齐 Rust: Hunk::is_pure_insertion()
    let h = Hunk(1, 0, 1, 3)
    if (!h.isPureInsertion()) { throw Exception("should be pure insertion") }
    let h2 = Hunk(1, 2, 1, 3)
    if (h2.isPureInsertion()) { throw Exception("should not be pure insertion") }
}

@Test
func testHunkIsPureRemoval(): Unit {
    // 对齐 Rust: Hunk::is_pure_removal()
    let h = Hunk(1, 3, 1, 0)
    if (!h.isPureRemoval()) { throw Exception("should be pure removal") }
    let h2 = Hunk(1, 3, 1, 2)
    if (h2.isPureRemoval()) { throw Exception("should not be pure removal") }
}

// ============================================================
// Interner 测试 — 对齐 gix-imara-diff/src/intern.rs
// ============================================================

@Test
func testInternerIntern(): Unit {
    // 对齐 Rust: Interner::intern()
    let interner = Interner()
    let t1 = interner.intern("hello")
    let t2 = interner.intern("world")
    let t3 = interner.intern("hello")
    if (t1 != t3) { throw Exception("same string should get same token") }
    if (t1 == t2) { throw Exception("different strings should get different tokens") }
    if (interner.numTokens() != 2) { throw Exception("should have 2 distinct tokens") }
}

@Test
func testInternerGet(): Unit {
    // 对齐 Rust: Index<Token> for Interner
    let interner = Interner()
    let t = interner.intern("test")
    let s = interner.get(t)
    if (s.isNone()) { throw Exception("should find token") }
    if (s.getOrThrow() != "test") { throw Exception("token should map back to 'test'") }
}

@Test
func testInternerClear(): Unit {
    // 对齐 Rust: Interner::clear()
    let interner = Interner()
    interner.intern("a")
    interner.intern("b")
    interner.clear()
    if (interner.numTokens() != 0) { throw Exception("should have 0 tokens after clear") }
}

// ============================================================
// InternedInput 测试 — 对齐 gix-imara-diff/src/intern.rs
// ============================================================

@Test
func testInternedInputNew(): Unit {
    // 对齐 Rust: InternedInput::new()
    let input = InternedInput.new("abc\ndef\n", "abc\ndefg\n")
    if (input.before.size != 2) { throw Exception("before should have 2 lines") }
    if (input.after.size != 2) { throw Exception("after should have 2 lines") }
    if (input.interner.numTokens() != 3) { throw Exception("should have 3 distinct tokens") }
}

@Test
func testInternedInputClear(): Unit {
    // 对齐 Rust: InternedInput::clear()
    let input = InternedInput.new("abc", "def")
    input.clear()
    if (input.before.size != 0) { throw Exception("before should be empty after clear") }
    if (input.after.size != 0) { throw Exception("after should be empty after clear") }
}

// ============================================================
// diffLines 测试 — 对齐 gix-imara-diff/tests/diff.rs
// ============================================================

@Test
func testDiffIdentical(): Unit {
    // 对齐 Rust: diff identical files
    let input = InternedInput.new("abcdef", "abcdef")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countAdditions() != 0) { throw Exception("identical should have 0 additions") }
    if (diff.countRemovals() != 0) { throw Exception("identical should have 0 removals") }
}

@Test
func testDiffAdditions(): Unit {
    // 对齐 Rust: diff with pure additions
    let input = InternedInput.new("abc\n", "abc\ndef\n")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countRemovals() != 0) { throw Exception("should have 0 removals") }
    if (diff.countAdditions() == 0) { throw Exception("should have additions") }
}

@Test
func testDiffDeletions(): Unit {
    // 对齐 Rust: diff with pure deletions
    let input = InternedInput.new("abc\ndef\n", "abc\n")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countAdditions() != 0) { throw Exception("should have 0 additions") }
    if (diff.countRemovals() == 0) { throw Exception("should have removals") }
}

@Test
func testDiffModifications(): Unit {
    // 对齐 Rust: diff with modifications
    let input = InternedInput.new("abcdef", "abcdefg")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countRemovals() == 0 && diff.countAdditions() == 0) {
        throw Exception("should have some changes")
    }
}

@Test
func testDiffEmptyOld(): Unit {
    // 对齐 Rust: diff with empty old file
    let input = InternedInput.new("", "abc\ndef\n")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countRemovals() != 0) { throw Exception("should have 0 removals") }
    if (diff.countAdditions() != 2) { throw Exception("should have 2 additions, got " + diff.countAdditions().toString()) }
}

@Test
func testDiffEmptyNew(): Unit {
    // 对齐 Rust: diff with empty new file
    let input = InternedInput.new("abc\ndef\n", "")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countAdditions() != 0) { throw Exception("should have 0 additions") }
    if (diff.countRemovals() != 2) { throw Exception("should have 2 removals, got " + diff.countRemovals().toString()) }
}

@Test
func testDiffBothEmpty(): Unit {
    // 对齐 Rust: diff both empty
    let input = InternedInput.new("", "")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countAdditions() != 0) { throw Exception("should have 0 additions") }
    if (diff.countRemovals() != 0) { throw Exception("should have 0 removals") }
}

@Test
func testDiffMixed(): Unit {
    // 对齐 Rust: diff with mixed changes
    let input = InternedInput.new("abcd", "axcy")
    let diff = Diff.compute(Algorithm.Myers, input)
    if (diff.countRemovals() == 0 && diff.countAdditions() == 0) {
        throw Exception("should have some changes")
    }
}

// ============================================================
// diffLinesWith 测试 — 对齐 gix-imara-diff 公共 API
// ============================================================

@Test
func testDiffLinesWithMyers(): Unit {
    // 对齐 Rust: Diff::compute(Algorithm::Myers, &input)
    let diff = diffLinesWith(Algorithm.Myers, "abc\ndef\n", "abc\ndefg\n")
    if (diff.hunks.size == 0) { throw Exception("should have hunks") }
}

@Test
func testDiffLinesWithIdentical(): Unit {
    // 对齐 Rust: Diff::compute() 对相同内容
    let diff = diffLinesWith(Algorithm.Myers, "abc\ndef\n", "abc\ndef\n")
    if (diff.hunks.size != 0) { throw Exception("identical content should have no hunks") }
}

// ============================================================
// diffLines (旧版 API) 测试
// ============================================================

@Test
func testDiffLinesOldApi(): Unit {
    let oldLines = ArrayList<String>()
    oldLines.add("abc")
    oldLines.add("def")
    let newLines = ArrayList<String>()
    newLines.add("abc")
    newLines.add("defg")
    let diff = diffLines(oldLines, newLines)
    if (diff.hunks.size == 0) { throw Exception("should have hunks") }
}

// ============================================================
// Token 测试
// ============================================================

@Test
func testTokenEquality(): Unit {
    let t1 = Token(1)
    let t2 = Token(1)
    let t3 = Token(2)
    if (t1 != t2) { throw Exception("same value tokens should be equal") }
    if (t1 == t3) { throw Exception("different value tokens should not be equal") }
}

// ============================================================
// Algorithm 枚举测试
// ============================================================

@Test
func testAlgorithmValues(): Unit {
    // 对齐 Rust: Algorithm 枚举
    let _myers = Algorithm.Myers
    let _histogram = Algorithm.Histogram
    let _minimal = Algorithm.MyersMinimal
}

// ============================================================
// Diff hunks() 测试
// ============================================================

@Test
func testDiffHunksFromCompute(): Unit {
    // 对齐 Rust: Diff::hunks()
    let input = InternedInput.new("abc", "axc")
    let diff = Diff.compute(Algorithm.Myers, input)
    let hunks = diff.computeHunks()
    if (hunks.size == 0) { throw Exception("should have hunks") }
    // 第一个 hunk 应该是 b->x 的修改
    let firstHunk = hunks[0]
    if (firstHunk.oldLen == 0 && firstHunk.newLen == 0) {
        throw Exception("hunk should have some changes")
    }
}

@Test
func testDiffHunksPureAddition(): Unit {
    // 对齐 Rust: Diff::hunks() 纯新增
    let input = InternedInput.new("", "abc")
    let diff = Diff.compute(Algorithm.Myers, input)
    let hunks = diff.computeHunks()
    if (hunks.size != 1) { throw Exception("should have 1 hunk") }
    if (!hunks[0].isPureInsertion()) { throw Exception("should be pure insertion") }
}

@Test
func testDiffHunksPureDeletion(): Unit {
    // 对齐 Rust: Diff::hunks() 纯删除
    let input = InternedInput.new("abc", "")
    let diff = Diff.compute(Algorithm.Myers, input)
    let hunks = diff.computeHunks()
    if (hunks.size != 1) { throw Exception("should have 1 hunk") }
    if (!hunks[0].isPureRemoval()) { throw Exception("should be pure removal") }
}
