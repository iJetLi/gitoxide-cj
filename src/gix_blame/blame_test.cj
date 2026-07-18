// 文件：blame_test.cj
// 用途：gix_blame 包的单元测试，对齐 Rust gitoxide gix-blame 测试
// 所属包：gix.gix_blame
// 对齐来源：gix-blame/tests/blame.rs

package gitoxide.gix_blame

import gitoxide.gix_hash.*
import std.collection.*
import std.unittest.*

// ============================================================
// BlameResult 测试 — 对齐 gix-blame/tests/blame.rs (baseline 模块)
// ============================================================

@Test
func testBlameResultConstruct(): Unit {
    // 对齐 Rust: BlameResult::default()
    let result = BlameResult()
    if (result.entries.size != 0) {
        throw Exception("entries should be empty initially")
    }
}

@Test
func testBlameResultWithEntries(): Unit {
    // 对齐 Rust: BlameResult 包含多个 blame 条目
    let result = BlameResult()
    let id = ObjectId.null(HashKind.Sha1)
    result.entries.add(BlameEntry(1, 1, 4, id))
    result.entries.add(BlameEntry(6, 6, 4, id))
    if (result.entries.size != 2) {
        throw Exception("entries should have 2 items")
    }
}

@Test
func testBlameResultWithManyEntries(): Unit {
    // 对齐 Rust: BlameResult 包含大量条目
    let result = BlameResult()
    let id = ObjectId.null(HashKind.Sha1)
    for (i in 0..100) {
        result.entries.add(BlameEntry(i, i, 1, id))
    }
    if (result.entries.size != 100) {
        throw Exception("should have 100 entries")
    }
}

@Test
func testBlameResultEntryOrder(): Unit {
    // 对齐 Rust: BlameResult 条目按行号排序
    let result = BlameResult()
    let id = ObjectId.null(HashKind.Sha1)
    result.entries.add(BlameEntry(1, 1, 4, id))
    result.entries.add(BlameEntry(6, 6, 4, id))
    result.entries.add(BlameEntry(11, 11, 4, id))
    if (result.entries[0].startInBlamedFile != 1) {
        throw Exception("first startLine should be 1")
    }
    if (result.entries[1].startInBlamedFile != 6) {
        throw Exception("second startLine should be 6")
    }
    if (result.entries[2].startInBlamedFile != 11) {
        throw Exception("third startLine should be 11")
    }
}

// ============================================================
// BlameEntry 测试 — 对齐 gix-blame/tests/blame.rs (baseline 模块)
// ============================================================

@Test
func testBlameEntryConstruct(): Unit {
    // 对齐 Rust: BlameEntry { start_line, end_line, commit_id, ... }
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 1, 9, id)
    if (entry.startInBlamedFile != 1) {
        throw Exception("startLine should be 1")
    }
    if (entry.startInBlamedFile + entry.len != 10) {
        throw Exception("endLine should be 10")
    }
    if (!entry.sourceFileName.isNone()) {
        throw Exception("originalPath should default to None")
    }
}

@Test
func testBlameEntryWithOriginalPath(): Unit {
    // 对齐 Rust: BlameEntry 包含重命名后的原始路径
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 1, 4, id)
    entry.sourceFileName = Some("old/path.txt")
    if (let Some(p) <- entry.sourceFileName) {
        if (p != "old/path.txt") {
            throw Exception("originalPath should be 'old/path.txt'")
        }
    } else {
        throw Exception("originalPath should be Some")
    }
}

@Test
func testBlameEntryStartInSourceFile(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(5, 3, 5, id)
    if (entry.startInSourceFile != 3) {
        throw Exception("startInSourceFile should be 3")
    }
}

@Test
func testBlameEntrySingleLine(): Unit {
    // 对齐 Rust: 单行 blame 条目
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(42, 42, 1, id)
    if (entry.len != 1) {
        throw Exception("should span exactly 1 line")
    }
}

@Test
func testBlameEntryWithRealCommitId(): Unit {
    // 对齐 Rust: BlameEntry 使用真实 ObjectId
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = BlameEntry(1, 1, 4, id)
    if (entry.commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId should match")
    }
}

@Test
func testBlameEntryDifferentCommitIds(): Unit {
    // 对齐 Rust: 不同条目有不同 commitId
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("0000000000000000000000000000000000000000")
    let entry1 = BlameEntry(1, 1, 4, id1)
    let entry2 = BlameEntry(6, 6, 4, id2)
    if (entry1.commitId.toHexString() == entry2.commitId.toHexString()) {
        throw Exception("different entries should have different commitIds")
    }
}

@Test
func testBlameEntryOriginalPathReset(): Unit {
    // 对齐 Rust: BlameEntry originalPath 可重置为 None
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 1, 4, id)
    entry.sourceFileName = Some("old.txt")
    entry.sourceFileName = None
    if (!entry.sourceFileName.isNone()) {
        throw Exception("should be None after reset")
    }
}

@Test
func testBlameEntryMultiLine(): Unit {
    // 对齐 Rust: BlameEntry 多行条目
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 1, 99, id)
    if (entry.len != 99) {
        throw Exception("should span 99 lines")
    }
}

@Test
func testBlameEntryStartLineZero(): Unit {
    // 对齐 Rust: BlameEntry 起始行号为 0（边界值）
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(0, 0, 1, id)
    if (entry.startInBlamedFile != 0) {
        throw Exception("startLine should be 0")
    }
}

// ============================================================
// BlameRanges / baseline 对齐测试 — 对齐 gix-blame/tests/blame.rs
// ============================================================
// 【无法对齐】原版 blame 测试大量依赖完整 Git 仓库夹具和 git baseline 输出，
// 验证 blame 算法的正确性（包括行级追踪、重命名检测、边界提交等）。
// 具体缺失的测试包括：
// - baseline::collect — 从 git porcelain 输出解析 BlameEntry
// - baseline::verify — 对比仓颉 blame 结果与 git baseline
// - simple_file — 单文件 blame
// - renamed_file — 重命名文件 blame
// - multiple_commits — 多提交 blame
// - boundary_commit — 边界提交标记
// 仓颉中未实现 blame 算法（BlameResult/BlameEntry 仅为数据结构），
// 且无 git baseline 工具支持，无法实现这些测试。

// ============================================================
// BlameEntry 边界补充测试 — 对齐 gix-blame 数据结构边界
// ============================================================

@Test
func testBlameEntryLargeLineRange(): Unit {
    // 对齐 Rust: BlameEntry 大行范围
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 1, 999999, id)
    if (entry.len != 999999) {
        throw Exception("should span 999999 lines")
    }
}

// ============================================================
// BlameResult 条目操作补充测试
// ============================================================

@Test
func testBlameResultEntriesCleared(): Unit {
    // 对齐 Rust: BlameResult 条目清空
    let result = BlameResult()
    let id = ObjectId.null(HashKind.Sha1)
    result.entries.add(BlameEntry(1, 1, 4, id))
    result.entries.clear()
    if (result.entries.size != 0) {
        throw Exception("entries should be empty after clear")
    }
}

// ============================================================
// BlameOutcome 测试 - 对齐 gix-blame/src/types.rs Outcome
// ============================================================

@Test
func testBlameOutcomeConstruct(): Unit {
    let outcome = BlameOutcome()
    if (outcome.entries.size != 0) {
        throw Exception("entries should be empty")
    }
    if (outcome.blob.size != 0) {
        throw Exception("blob should be empty")
    }
    if (!outcome.blamePath.isNone()) {
        throw Exception("blamePath should be None")
    }
}

@Test
func testBlameOutcomeStatistics(): Unit {
    let stats = BlameStatistics()
    if (stats.commitsTraversed != 0) {
        throw Exception("commitsTraversed should be 0")
    }
    if (stats.treesDecoded != 0) {
        throw Exception("treesDecoded should be 0")
    }
    if (stats.blobsDiffed != 0) {
        throw Exception("blobsDiffed should be 0")
    }
}

// ============================================================
// BlameRanges 测试 - 对齐 gix-blame/src/types.rs BlameRanges
// ============================================================

@Test
func testBlameRangesDefault(): Unit {
    let opts = BlameOptions()
    match (opts.ranges) {
        case BlameRanges.WholeFile => true;
        case _ => throw Exception("default ranges should be WholeFile")
    }
}

// ============================================================
// BlameChange 测试 - 对齐 gix-blame/src/types.rs Change
// ============================================================

@Test
func testBlameChangeUnchanged(): Unit {
    let c = BlameChange.Unchanged(0..5)
    match (c) {
        case BlameChange.Unchanged(r) =>
            if (r.start != 0 || r.end != 5) {
                throw Exception("range mismatch")
            }
        case _ => throw Exception("should be Unchanged")
    }
}

@Test
func testBlameChangeAddedOrReplaced(): Unit {
    let c = BlameChange.AddedOrReplaced(2..4, 3)
    match (c) {
        case BlameChange.AddedOrReplaced(r, deleted) =>
            if (r.start != 2 || r.end != 4) {
                throw Exception("range mismatch")
            }
            if (deleted != 3) {
                throw Exception("deleted count mismatch")
            }
        case _ => throw Exception("should be AddedOrReplaced")
    }
}

@Test
func testBlameChangeDeleted(): Unit {
    let c = BlameChange.Deleted(10, 5)
    match (c) {
        case BlameChange.Deleted(line, count) =>
            if (line != 10) {
                throw Exception("line number mismatch")
            }
            if (count != 5) {
                throw Exception("count mismatch")
            }
        case _ => throw Exception("should be Deleted")
    }
}

// ============================================================
// BlameOffset 测试 - 对齐 gix-blame/src/types.rs Offset
// ============================================================

@Test
func testBlameOffsetShiftedRangeAdded(): Unit {
    let offset = BlameOffset.Added(3)
    let range = 5..10
    let shifted = offsetShiftedRange(offset, range)
    if (shifted.start != 2 || shifted.end != 7) {
        throw Exception("Added offset shift mismatch")
    }
}

@Test
func testBlameOffsetShiftedRangeDeleted(): Unit {
    let offset = BlameOffset.Deleted(3)
    let range = 5..10
    let shifted = offsetShiftedRange(offset, range)
    if (shifted.start != 8 || shifted.end != 13) {
        throw Exception("Deleted offset shift mismatch")
    }
}

// ============================================================
// UnblamedHunk 测试 - 对齐 gix-blame/src/types.rs UnblamedHunk
// ============================================================

@Test
func testUnblamedHunkConstruct(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let hunk = UnblamedHunk(0..10, id)
    if (hunk.rangeInBlamedFile.start != 0 || hunk.rangeInBlamedFile.end != 10) {
        throw Exception("rangeInBlamedFile mismatch")
    }
    if (!hunk.hasSuspect(id)) {
        throw Exception("should have suspect")
    }
}

@Test
func testUnblamedHunkPassBlame(): Unit {
    let id1 = ObjectId.null(HashKind.Sha1)
    let id2 = ObjectId.fromHexOrThrow("1111111111111111111111111111111111111111")
    let hunk = UnblamedHunk(0..10, id1)
    hunk.passBlame(id1, id2)
    if (hunk.hasSuspect(id1)) {
        throw Exception("should no longer have old suspect")
    }
    if (!hunk.hasSuspect(id2)) {
        throw Exception("should have new suspect")
    }
}

@Test
func testUnblamedHunkGetRange(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let hunk = UnblamedHunk(0..10, id)
    if (let Some(range) <- hunk.getRange(id)) {
        if (range.start != 0 || range.end != 10) {
            throw Exception("range mismatch")
        }
    } else {
        throw Exception("should find range for suspect")
    }
}

@Test
func testUnblamedHunkRemoveBlame(): Unit {
    let id1 = ObjectId.null(HashKind.Sha1)
    let id2 = ObjectId.fromHexOrThrow("1111111111111111111111111111111111111111")
    let hunk = UnblamedHunk(0..10, id1)
    hunk.cloneBlame(id1, id2)
    if (!hunk.hasSuspect(id1) || !hunk.hasSuspect(id2)) {
        throw Exception("should have both suspects after clone")
    }
    hunk.removeBlame(id1)
    if (hunk.hasSuspect(id1)) {
        throw Exception("should no longer have id1 after remove")
    }
    if (!hunk.hasSuspect(id2)) {
        throw Exception("should still have id2")
    }
}

// ============================================================
// BlameError 测试 - 对齐 gix-blame/src/error.rs Error
// ============================================================

@Test
func testBlameErrorVariants(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let e1 = BlameError.EmptyTraversal
    let e2 = BlameError.FileMissing("test.txt", id)
    let e3 = BlameError.InvalidOneBasedLineRange
    let e4 = BlameError.FindObject("not found")
    let e5 = BlameError.Traverse("traverse failed")
    let e6 = BlameError.DiffTree("diff failed")
    let e7 = BlameError.DecodeCommit("decode failed")
}

// ============================================================
// BlamePathEntry 测试 - 对齐 gix-blame/src/types.rs BlamePathEntry
// ============================================================

@Test
func testBlamePathEntryConstruct(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let blobId = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = BlamePathEntry("src/main.cj", id, blobId)
    if (entry.sourceFilePath != "src/main.cj") {
        throw Exception("sourceFilePath mismatch")
    }
    if (entry.previousSourceFilePath != None) {
        throw Exception("previousSourceFilePath should default to None")
    }
    if (entry.commitId != id) {
        throw Exception("commitId mismatch")
    }
    if (entry.blobId != blobId) {
        throw Exception("blobId mismatch")
    }
    if (entry.parentIndex != 0) {
        throw Exception("parentIndex should default to 0")
    }
}

// ============================================================
// BlameEntry rangeInBlamedFile/rangeInSourceFile 测试
// ============================================================

@Test
func testBlameEntryRangeInBlamedFile(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(5, 3, 10, id)
    let range = entry.rangeInBlamedFile()
    if (range.start != 5) {
        throw Exception("range start should be 5")
    }
    if (range.end != 15) {
        throw Exception("range end should be 15")
    }
}

@Test
func testBlameEntryRangeInSourceFile(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(5, 3, 10, id)
    let range = entry.rangeInSourceFile()
    if (range.start != 3) {
        throw Exception("range start should be 3")
    }
    if (range.end != 13) {
        throw Exception("range end should be 13")
    }
}
