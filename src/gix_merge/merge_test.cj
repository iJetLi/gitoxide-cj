// 文件：merge_test.cj
// 用途：gix_merge 包的单元测试，全量对齐 Rust gitoxide gix-merge 测试
// 所属包：gix.gix_merge
// 对齐来源：gix-merge/tests/merge.rs

package gitoxide.gix_merge

import std.unittest.*
import std.collection.*

// ============================================================
// threeWayMerge 测试 — 对齐 gix-merge/tests/merge.rs
// ============================================================

@Test
func testThreeWayMergeOursSameAsTheirs(): Unit {
    // 对齐 Rust: three-way merge — ours == theirs → clean merge
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    theirs.add("line2")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines, got " + mc.lines.size.toString())
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean merge when ours == theirs")
    }
}

@Test
func testThreeWayMergeOursChanged(): Unit {
    // 对齐 Rust: three-way merge — ours changed, theirs same as base → take ours
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines from ours")
            }
            if (mc.lines[1] != "line2") {
                throw Exception("second line should be 'line2'")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when only ours changed")
    }
}

@Test
func testThreeWayMergeTheirsChanged(): Unit {
    // 对齐 Rust: three-way merge — theirs changed, ours same as base → take theirs
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    theirs.add("line3")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 2) {
                throw Exception("should have 2 lines from theirs")
            }
            if (mc.lines[1] != "line3") {
                throw Exception("second line should be 'line3'")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when only theirs changed")
    }
}

@Test
func testThreeWayMergeBothChangedDifferently(): Unit {
    // 对齐 Rust: three-way merge — both changed differently → conflict
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line2")
    let theirs = ArrayList<String>()
    theirs.add("line3")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(_) => throw Exception("should be conflict when both changed differently")
        case MergeResult.Conflict(cc) =>
            if (cc.conflicts.size != 1) {
                throw Exception("should have 1 conflict")
            }
    }
}

@Test
func testThreeWayMergeNoChanges(): Unit {
    // 对齐 Rust: three-way merge — no changes from base → clean merge
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    ours.add("line1")
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1) {
                throw Exception("should have 1 line")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when no changes")
    }
}

// ============================================================
// MergeResult/Conflict 类型测试
// ============================================================

@Test
func testConflictConstruction(): Unit {
    // 对齐 Rust: Conflict construction
    let c = Conflict(0, 5, 10, 3)
    if (c.oursStart != 0) {
        throw Exception("oursStart mismatch")
    }
    if (c.oursLen != 5) {
        throw Exception("oursLen mismatch")
    }
    if (c.theirsStart != 10) {
        throw Exception("theirsStart mismatch")
    }
    if (c.theirsLen != 3) {
        throw Exception("theirsLen mismatch")
    }
}

@Test
func testMergedContentCreation(): Unit {
    // 对齐 Rust: MergedContent construction
    let mc = MergedContent()
    if (mc.lines.size != 0) {
        throw Exception("new MergedContent should have 0 lines")
    }
    mc.lines.add("merged line")
    if (mc.lines.size != 1) {
        throw Exception("should have 1 line after add")
    }
}

@Test
func testConflictContentCreation(): Unit {
    // 对齐 Rust: ConflictContent construction
    let cc = ConflictContent()
    if (cc.lines.size != 0) {
        throw Exception("lines should be empty")
    }
    if (cc.conflicts.size != 0) {
        throw Exception("conflicts should be empty")
    }
}

// ============================================================
// threeWayMerge 补充测试 — 对齐 gix-merge/tests/blob/builtin_driver.rs
// ============================================================

@Test
func testThreeWayMergeBothSameChanges(): Unit {
    // 对齐 Rust: both_sides_same_changes_are_conflict_free
    let base = ArrayList<String>()
    base.add("old")
    let ours = ArrayList<String>()
    ours.add("new")
    let theirs = ArrayList<String>()
    theirs.add("new")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1 || mc.lines[0] != "new") {
                throw Exception("same changes should merge cleanly to 'new'")
            }
        case MergeResult.Conflict(_) => throw Exception("same changes should not conflict")
    }
}

@Test
func testThreeWayMergeEmptyAllInputs(): Unit {
    // 对齐 Rust: missing_buffers_are_empty_buffers — all empty
    let base = ArrayList<String>()
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("all empty should merge to empty")
            }
        case MergeResult.Conflict(_) => throw Exception("all empty should not conflict")
    }
}

@Test
func testThreeWayMergeEmptyBaseBothSidesSame(): Unit {
    // 对齐 Rust: same_binaries_do_not_count_as_conflicted
    let base = ArrayList<String>()
    let ours = ArrayList<String>()
    ours.add("content")
    let theirs = ArrayList<String>()
    theirs.add("content")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 1 || mc.lines[0] != "content") {
                throw Exception("same sides should merge cleanly")
            }
        case MergeResult.Conflict(_) => throw Exception("same sides should not conflict")
    }
}

@Test
func testThreeWayMergeOursDeletedTheirsUnchanged(): Unit {
    // 对齐 Rust: modify/delete scenario — ours deleted, theirs == base
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    theirs.add("line1")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("ours deleted should result in empty")
            }
        case MergeResult.Conflict(_) => throw Exception("ours delete + theirs unchanged should be clean")
    }
}

@Test
func testThreeWayMergeBothDeleted(): Unit {
    // 对齐 Rust: both sides deleted
    let base = ArrayList<String>()
    base.add("line1")
    let ours = ArrayList<String>()
    let theirs = ArrayList<String>()
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines.size != 0) {
                throw Exception("both deleted should result in empty")
            }
        case MergeResult.Conflict(_) => throw Exception("both deleted should not conflict")
    }
}

@Test
func testThreeWayMergeSingleLineIdenticalChange(): Unit {
    // 对齐 Rust: both_sides_same_changes_are_conflict_free — single line
    let base = ArrayList<String>()
    base.add("a")
    let ours = ArrayList<String>()
    ours.add("b")
    let theirs = ArrayList<String>()
    theirs.add("b")
    let result = threeWayMerge(base, ours, theirs)
    match (result) {
        case MergeResult.Clean(mc) =>
            if (mc.lines[0] != "b") {
                throw Exception("identical change should merge to 'b'")
            }
        case MergeResult.Conflict(_) => throw Exception("identical change should not conflict")
    }
}
