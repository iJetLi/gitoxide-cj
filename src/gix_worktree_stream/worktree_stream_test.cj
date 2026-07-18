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
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
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
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
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
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    stream.addEntry("script.sh", EntryMode(0o100755), id)
    if (stream.entries[0].mode.kind() != EntryKind.BlobExecutable) {
        throw Exception("mode should be BlobExecutable")
    }
}

@Test
func testStreamEntryConstruction(): Unit {
    // 对齐 Rust: StreamEntry construction
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = StreamEntry("test.txt", EntryMode(0o100644), id)
    if (entry.path != "test.txt") {
        throw Exception("path mismatch")
    }
    if (entry.id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id mismatch")
    }
}

// ============================================================
// StreamEntryKind 测试 - 对齐 gix-worktree-stream/src/entry.rs
// ============================================================

@Test
func testStreamEntryKindBlob(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let entry = StreamEntry("file.txt", EntryMode(0o100644), id)
    if (entry.kind() != StreamEntryKind.Blob) {
        throw Exception("should be Blob kind")
    }
    if (entry.isTree()) {
        throw Exception("should not be tree")
    }
    if (!entry.isBlob()) {
        throw Exception("should be blob")
    }
}

@Test
func testStreamEntryKindTree(): Unit {
    let id = ObjectId.null(HashKind.Sha1)
    let entry = StreamEntry("src", EntryMode(0o040000), id)
    if (entry.kind() != StreamEntryKind.Tree) {
        throw Exception("should be Tree kind")
    }
    if (!entry.isTree()) {
        throw Exception("should be tree")
    }
    if (entry.isBlob()) {
        throw Exception("should not be blob")
    }
}

// ============================================================
// WorktreeStream nextEntry 测试 - 对齐 gix-worktree-stream/src/lib.rs Stream::next_entry()
// ============================================================

@Test
func testWorktreeStreamNextEntry(): Unit {
    let stream = WorktreeStream()
    let id = ObjectId.null(HashKind.Sha1)
    stream.addEntry("file1.txt", EntryMode(0o100644), id)
    stream.addEntry("file2.txt", EntryMode(0o100644), id)
    if (let Some(entry) <- stream.nextEntry()) {
        if (entry.path != "file1.txt") {
            throw Exception("first entry should be file1.txt")
        }
    } else {
        throw Exception("should have first entry")
    }
    if (let Some(entry) <- stream.nextEntry()) {
        if (entry.path != "file2.txt") {
            throw Exception("second entry should be file2.txt")
        }
    } else {
        throw Exception("should have second entry")
    }
    if (stream.hasNext()) {
        throw Exception("should have no more entries")
    }
}

@Test
func testWorktreeStreamNextEntryEmpty(): Unit {
    let stream = WorktreeStream()
    if (!stream.nextEntry().isNone()) {
        throw Exception("empty stream should return None")
    }
    if (stream.hasNext()) {
        throw Exception("empty stream should not have next")
    }
}

// ============================================================
// 流协议常量 测试 - 对齐 gix-worktree-stream/src/protocol.rs
// ============================================================

@Test
func testStreamModeToByte(): Unit {
    if (streamModeToByte(EntryMode(0o040000)) != UInt8(0)) {
        throw Exception("Tree mode should map to 0")
    }
    if (streamModeToByte(EntryMode(0o100644)) != UInt8(1)) {
        throw Exception("Blob mode should map to 1")
    }
    if (streamModeToByte(EntryMode(0o120000)) != UInt8(2)) {
        throw Exception("Link mode should map to 2")
    }
    if (streamModeToByte(EntryMode(0o160000)) != UInt8(3)) {
        throw Exception("Commit mode should map to 3")
    }
}

@Test
func testStreamByteToMode(): Unit {
    if (let Some(mode) <- streamByteToMode(UInt8(0))) {
        if (!mode.isTree()) {
            throw Exception("byte 0 should be tree mode")
        }
    } else {
        throw Exception("byte 0 should be valid")
    }
    if (let Some(mode) <- streamByteToMode(UInt8(1))) {
        if (mode.kind() != EntryKind.Blob) {
            throw Exception("byte 1 should be blob mode")
        }
    } else {
        throw Exception("byte 1 should be valid")
    }
    if (let Some(mode) <- streamByteToMode(UInt8(2))) {
        if (mode.kind() != EntryKind.Link) {
            throw Exception("byte 2 should be link mode")
        }
    } else {
        throw Exception("byte 2 should be valid")
    }
    if (!streamByteToMode(UInt8(99)).isNone()) {
        throw Exception("invalid byte should return None")
    }
}

@Test
func testStreamHashKindToByte(): Unit {
    if (streamHashKindToByte(HashKind.Sha1) != UInt8(1)) {
        throw Exception("Sha1 should map to 1")
    }
    if (streamHashKindToByte(HashKind.Sha256) != UInt8(2)) {
        throw Exception("Sha256 should map to 2")
    }
}

@Test
func testStreamByteToHashKind(): Unit {
    if (streamByteToHashKind(UInt8(1)) != Some(HashKind.Sha1)) {
        throw Exception("byte 1 should be Sha1")
    }
    if (streamByteToHashKind(UInt8(2)) != Some(HashKind.Sha256)) {
        throw Exception("byte 2 should be Sha256")
    }
    if (!streamByteToHashKind(UInt8(99)).isNone()) {
        throw Exception("invalid byte should return None")
    }
}
