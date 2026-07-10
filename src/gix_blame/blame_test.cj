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
    result.entries.add(BlameEntry(1, 5, id))
    result.entries.add(BlameEntry(6, 10, id))
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
        result.entries.add(BlameEntry(i, i + 1, id))
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
    result.entries.add(BlameEntry(1, 5, id))
    result.entries.add(BlameEntry(6, 10, id))
    result.entries.add(BlameEntry(11, 15, id))
    if (result.entries[0].startLine != 1) {
        throw Exception("first startLine should be 1")
    }
    if (result.entries[1].startLine != 6) {
        throw Exception("second startLine should be 6")
    }
    if (result.entries[2].startLine != 11) {
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
    let entry = BlameEntry(1, 10, id)
    if (entry.startLine != 1) {
        throw Exception("startLine should be 1")
    }
    if (entry.endLine != 10) {
        throw Exception("endLine should be 10")
    }
    if (!entry.originalPath.isNone()) {
        throw Exception("originalPath should default to None")
    }
    if (entry.originalStartLine != 1) {
        throw Exception("originalStartLine should default to startLine")
    }
}

@Test
func testBlameEntryWithOriginalPath(): Unit {
    // 对齐 Rust: BlameEntry 包含重命名后的原始路径
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 5, id)
    entry.originalPath = Some("old/path.txt")
    if (let Some(p) <- entry.originalPath) {
        if (p != "old/path.txt") {
            throw Exception("originalPath should be 'old/path.txt'")
        }
    } else {
        throw Exception("originalPath should be Some")
    }
}

@Test
func testBlameEntryOriginalStartLine(): Unit {
    // 对齐 Rust: BlameEntry::original_start_line
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(5, 10, id)
    if (entry.originalStartLine != 5) {
        throw Exception("originalStartLine should default to startLine")
    }
    entry.originalStartLine = 3
    if (entry.originalStartLine != 3) {
        throw Exception("originalStartLine should be 3 after update")
    }
}

@Test
func testBlameEntrySingleLine(): Unit {
    // 对齐 Rust: 单行 blame 条目
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(42, 43, id)
    if (entry.endLine - entry.startLine != 1) {
        throw Exception("should span exactly 1 line")
    }
}

@Test
func testBlameEntryWithRealCommitId(): Unit {
    // 对齐 Rust: BlameEntry 使用真实 ObjectId
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = BlameEntry(1, 5, id)
    if (entry.commitId.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commitId should match")
    }
}

@Test
func testBlameEntryDifferentCommitIds(): Unit {
    // 对齐 Rust: 不同条目有不同 commitId
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("0000000000000000000000000000000000000000")
    let entry1 = BlameEntry(1, 5, id1)
    let entry2 = BlameEntry(6, 10, id2)
    if (entry1.commitId.toHexString() == entry2.commitId.toHexString()) {
        throw Exception("different entries should have different commitIds")
    }
}

@Test
func testBlameEntryOriginalPathReset(): Unit {
    // 对齐 Rust: BlameEntry originalPath 可重置为 None
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 5, id)
    entry.originalPath = Some("old.txt")
    entry.originalPath = None
    if (!entry.originalPath.isNone()) {
        throw Exception("should be None after reset")
    }
}

@Test
func testBlameEntryMultiLine(): Unit {
    // 对齐 Rust: BlameEntry 多行条目
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(1, 100, id)
    if (entry.endLine - entry.startLine != 99) {
        throw Exception("should span 99 lines")
    }
}

@Test
func testBlameEntryStartLineZero(): Unit {
    // 对齐 Rust: BlameEntry 起始行号为 0（边界值）
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(0, 1, id)
    if (entry.startLine != 0) {
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
    let entry = BlameEntry(1, 1000000, id)
    if (entry.endLine - entry.startLine != 999999) {
        throw Exception("should span 999999 lines")
    }
}

@Test
func testBlameEntryOriginalStartLineIndependent(): Unit {
    // 对齐 Rust: BlameEntry originalStartLine 独立于 startLine
    let id = ObjectId.null(HashKind.Sha1)
    let entry = BlameEntry(10, 20, id)
    entry.originalStartLine = 5
    if (entry.startLine != 10) {
        throw Exception("startLine should stay 10")
    }
    if (entry.originalStartLine != 5) {
        throw Exception("originalStartLine should be 5")
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
    result.entries.add(BlameEntry(1, 5, id))
    result.entries.clear()
    if (result.entries.size != 0) {
        throw Exception("entries should be empty after clear")
    }
}
