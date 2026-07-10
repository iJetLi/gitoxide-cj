// 文件：worktree_stream_test.cj
// 用途：gix_worktree_stream 包的单元测试，对齐 Rust gitoxide gix-worktree-stream 测试
// 所属包：gix.gix_worktree_stream
// 对齐来源：gix-worktree-stream/tests/*.rs

package gitoxide.gix_worktree_stream

import gitoxide.gix_object.*
import gitoxide.gix_hash.*
import std.collection.*
import std.unittest.*

// ============================================================
// WorktreeStream 测试 — 对齐 gix-worktree-stream/tests/stream.rs
// ============================================================

@Test
func testWorktreeStreamConstruct(): Unit {
    // 对齐 Rust: WorktreeStream::new()
    let stream = WorktreeStream()
    if (stream.entries.size != 0) {
        throw Exception("entries should be empty initially")
    }
}

@Test
func testWorktreeStreamAddEntry(): Unit {
    // 对齐 Rust: WorktreeStream 添加条目
    let stream = WorktreeStream()
    let id = ObjectId.null(HashKind.Sha1)
    stream.addEntry("src/main.cj", EntryMode(0o100644), id)
    if (stream.entries.size != 1) {
        throw Exception("entries should have 1 item after addEntry")
    }
}

@Test
func testWorktreeStreamAddMultipleEntries(): Unit {
    // 对齐 Rust: WorktreeStream 添加多个条目
    let stream = WorktreeStream()
    let id = ObjectId.null(HashKind.Sha1)
    stream.addEntry("file1.txt", EntryMode(0o100644), id)
    stream.addEntry("file2.txt", EntryMode(0o100755), id)
    stream.addEntry("subdir", EntryMode(0o040000), id)
    if (stream.entries.size != 3) {
        throw Exception("entries should have 3 items")
    }
}

// ============================================================
// StreamEntry 测试 — 对齐 gix-worktree-stream/tests/entry.rs
// ============================================================

@Test
func testStreamEntryConstruct(): Unit {
    // 对齐 Rust: StreamEntry { path, mode, id }
    let id = ObjectId.null(HashKind.Sha1)
    let entry = StreamEntry("README.md", EntryMode(0o100644), id)
    if (entry.path != "README.md") {
        throw Exception("path should be 'README.md'")
    }
    if (entry.mode.value != 0o100644) {
        throw Exception("mode should be 0o100644")
    }
}

@Test
func testStreamEntryDirectoryMode(): Unit {
    // 对齐 Rust: StreamEntry 目录模式
    let id = ObjectId.null(HashKind.Sha1)
    let entry = StreamEntry("src", EntryMode(0o040000), id)
    if (entry.path != "src") {
        throw Exception("path should be 'src'")
    }
}

@Test
func testStreamEntrySymlinkMode(): Unit {
    // 对齐 Rust: StreamEntry 符号链接模式
    let id = ObjectId.null(HashKind.Sha1)
    let entry = StreamEntry("link", EntryMode(0o120000), id)
    if (entry.path != "link") {
        throw Exception("path should be 'link'")
    }
}

// 注意：原版 gitoxide 的 worktree-stream 测试依赖树对象解析与 checkout 流程，
// 仓颉中暂无法实现流式检出的集成测试，待 gix_odb 与 gix_test_utils 完善后补充。

// ============================================================
// WorktreeStream 补充测试 — 对齐 gix-worktree-stream/src/lib.rs
// ============================================================

@Test
func testWorktreeStreamMultipleEntries(): Unit {
    // 对齐 Rust: WorktreeStream with multiple entries
    let stream = WorktreeStream()
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    stream.addEntry("file1.txt", EntryMode(0o100644), id1)
    stream.addEntry("dir/file2.txt", EntryMode(0o100644), id2)
    if (stream.entries.size != 2) {
        throw Exception("should have 2 entries")
    }
    if (stream.entries[0].path != "file1.txt") {
        throw Exception("first path mismatch")
    }
    if (stream.entries[1].path != "dir/file2.txt") {
        throw Exception("second path mismatch")
    }
}

@Test
func testWorktreeStreamEntryWithTreeMode(): Unit {
    // 对齐 Rust: WorktreeStream entry with tree mode
    let stream = WorktreeStream()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    stream.addEntry("subdir", EntryMode(0o040000), id)
    if (stream.entries.size != 1) {
        throw Exception("should have 1 entry")
    }
    if (!stream.entries[0].mode.isTree()) {
        throw Exception("mode should be tree")
    }
}

@Test
func testWorktreeStreamEntryWithExecutableMode(): Unit {
    // 对齐 Rust: WorktreeStream entry with executable mode
    let stream = WorktreeStream()
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    stream.addEntry("script.sh", EntryMode(0o100755), id)
    if (stream.entries[0].mode.kind() != EntryKind.BlobExecutable) {
        throw Exception("mode should be BlobExecutable")
    }
}

@Test
func testStreamEntryConstruction(): Unit {
    // 对齐 Rust: StreamEntry construction
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = StreamEntry("test.txt", EntryMode(0o100644), id)
    if (entry.path != "test.txt") {
        throw Exception("path mismatch")
    }
    if (entry.id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id mismatch")
    }
}
