// 文件：imara_diff_test.cj
// 用途：gix_imara_diff 包的单元测试，对齐 Rust gitoxide gix-imara-diff 测试
// 所属包：gix.gix_imara_diff
// 对齐来源：gix-imara-diff/tests/*.rs

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
    if (d.hunks.size != 0) {
        throw Exception("hunks should be empty initially")
    }
}

@Test
func testDiffWithHunk(): Unit {
    // 对齐 Rust: Diff 包含差异块
    let d = Diff()
    d.hunks.add(Hunk(1, 3, 1, 3))
    if (d.hunks.size != 1) {
        throw Exception("hunks should have 1 entry")
    }
}

// ============================================================
// Hunk 测试 — 对齐 gix-imara-diff/tests/hunk.rs
// ============================================================

@Test
func testHunkConstruct(): Unit {
    // 对齐 Rust: Hunk { old_start, old_len, new_start, new_len }
    let h = Hunk(1, 5, 1, 7)
    if (h.oldStart != 1) {
        throw Exception("oldStart should be 1")
    }
    if (h.oldLen != 5) {
        throw Exception("oldLen should be 5")
    }
    if (h.newStart != 1) {
        throw Exception("newStart should be 1")
    }
    if (h.newLen != 7) {
        throw Exception("newLen should be 7")
    }
    if (h.lines.size != 0) {
        throw Exception("lines should be empty initially")
    }
}

@Test
func testHunkWithLines(): Unit {
    // 对齐 Rust: Hunk 包含差异行
    let h = Hunk(1, 1, 1, 1)
    h.lines.add(DiffLine(LineKind.Context, "unchanged"))
    h.lines.add(DiffLine(LineKind.Deletion, "removed"))
    h.lines.add(DiffLine(LineKind.Addition, "added"))
    if (h.lines.size != 3) {
        throw Exception("lines should have 3 entries")
    }
}

// ============================================================
// DiffLine 测试 — 对齐 gix-imara-diff/tests/line.rs
// ============================================================

@Test
func testDiffLineContext(): Unit {
    // 对齐 Rust: DiffLine { kind: Context, text }
    let line = DiffLine(LineKind.Context, "hello")
    if (line.kind != LineKind.Context) {
        throw Exception("kind should be Context")
    }
    if (line.text != "hello") {
        throw Exception("text should be 'hello'")
    }
}

@Test
func testDiffLineAddition(): Unit {
    // 对齐 Rust: DiffLine { kind: Addition, text }
    let line = DiffLine(LineKind.Addition, "new line")
    if (line.kind != LineKind.Addition) {
        throw Exception("kind should be Addition")
    }
}

@Test
func testDiffLineDeletion(): Unit {
    // 对齐 Rust: DiffLine { kind: Deletion, text }
    let line = DiffLine(LineKind.Deletion, "old line")
    if (line.kind != LineKind.Deletion) {
        throw Exception("kind should be Deletion")
    }
}

// ============================================================
// LineKind 测试 — 对齐 gix-imara-diff/src/line.rs
// ============================================================

@Test
func testLineKindVariants(): Unit {
    // 对齐 Rust: LineKind 枚举变体
    let kinds = ArrayList<LineKind>()
    kinds.add(LineKind.Context)
    kinds.add(LineKind.Addition)
    kinds.add(LineKind.Deletion)
    if (kinds.size != 3) {
        throw Exception("should have 3 LineKind variants")
    }
}

// ============================================================
// diffLines 函数测试 — 对齐 gix-imara-diff/tests/diff_lines.rs
// ============================================================

@Test
func testDiffLinesIdentical(): Unit {
    // 对齐 Rust: diffLines 对相同内容应产生全部 Context 行
    let old = ArrayList<String>()
    old.add("line1")
    old.add("line2")
    let new_ = ArrayList<String>()
    new_.add("line1")
    new_.add("line2")
    let result = diffLines(old, new_)
    if (result.hunks.size != 1) {
        throw Exception("should have 1 hunk")
    }
    if (result.hunks[0].lines.size != 2) {
        throw Exception("should have 2 context lines")
    }
    if (result.hunks[0].lines[0].kind != LineKind.Context) {
        throw Exception("first line should be Context")
    }
    if (result.hunks[0].lines[1].kind != LineKind.Context) {
        throw Exception("second line should be Context")
    }
}

@Test
func testDiffLinesModification(): Unit {
    // 对齐 Rust: diffLines 对修改行应产生 Deletion + Addition
    let old = ArrayList<String>()
    old.add("old line")
    let new_ = ArrayList<String>()
    new_.add("new line")
    let result = diffLines(old, new_)
    if (result.hunks[0].lines.size != 2) {
        throw Exception("should have 2 lines (deletion + addition)")
    }
    if (result.hunks[0].lines[0].kind != LineKind.Deletion) {
        throw Exception("first line should be Deletion")
    }
    if (result.hunks[0].lines[1].kind != LineKind.Addition) {
        throw Exception("second line should be Addition")
    }
}

@Test
func testDiffLinesEmptyOld(): Unit {
    // 对齐 Rust: 旧文件为空，新文件有内容
    let old = ArrayList<String>()
    let new_ = ArrayList<String>()
    new_.add("added1")
    new_.add("added2")
    let result = diffLines(old, new_)
    if (result.hunks[0].lines.size != 2) {
        throw Exception("should have 2 addition lines")
    }
    if (result.hunks[0].lines[0].kind != LineKind.Addition) {
        throw Exception("first line should be Addition")
    }
}

@Test
func testDiffLinesEmptyNew(): Unit {
    // 对齐 Rust: 新文件为空，旧文件有内容
    let old = ArrayList<String>()
    old.add("removed1")
    old.add("removed2")
    let new_ = ArrayList<String>()
    let result = diffLines(old, new_)
    if (result.hunks[0].lines.size != 2) {
        throw Exception("should have 2 deletion lines")
    }
    if (result.hunks[0].lines[0].kind != LineKind.Deletion) {
        throw Exception("first line should be Deletion")
    }
}

@Test
func testDiffLinesBothEmpty(): Unit {
    // 对齐 Rust: 两个空文件比较
    let old = ArrayList<String>()
    let new_ = ArrayList<String>()
    let result = diffLines(old, new_)
    if (result.hunks[0].lines.size != 0) {
        throw Exception("should have 0 lines")
    }
}

@Test
func testDiffLinesMixedChanges(): Unit {
    // 对齐 Rust: 混合变更（相同 + 修改 + 新增）
    let old = ArrayList<String>()
    old.add("same")
    old.add("changed")
    old.add("removed")
    let new_ = ArrayList<String>()
    new_.add("same")
    new_.add("modified")
    new_.add("added")
    let result = diffLines(old, new_)
    if (result.hunks.size != 1) {
        throw Exception("should have 1 hunk")
    }
    // 第一行相同 → Context
    if (result.hunks[0].lines[0].kind != LineKind.Context) {
        throw Exception("first line should be Context")
    }
}
