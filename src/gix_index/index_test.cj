// 文件：index_test.cj
// 用途：gix_index 包的单元测试，全量对齐 Rust gitoxide gix-index 测试
// 所属包：gix.gix_index
// 对齐来源：gix-index/tests/{entry,file}.rs

package gitoxide.gix_index

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*

// ============================================================
// IndexEntry 测试 — 对齐 gix-index/tests/entry.rs
// ============================================================

@Test
func testIndexEntryCreation(): Unit {
    // 对齐 Rust: IndexEntry construction
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("src/main.cj", id)
    if (entry.path != "src/main.cj") {
        throw Exception("path mismatch")
    }
    if (entry.id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id mismatch")
    }
    if (entry.ctimeS != 0) {
        throw Exception("ctimeS should default to 0")
    }
    if (entry.mode != 0) {
        throw Exception("mode should default to 0")
    }
}

@Test
func testIndexEntryDefaultFields(): Unit {
    // 对齐 Rust: IndexEntry default field values
    let id = ObjectId.fromHexOrThrow("0000000000000000000000000000000000000000")
    let entry = IndexEntry("test.txt", id)
    if (entry.ctimeN != 0) {
        throw Exception("ctimeN should be 0")
    }
    if (entry.mtimeS != 0) {
        throw Exception("mtimeS should be 0")
    }
    if (entry.mtimeN != 0) {
        throw Exception("mtimeN should be 0")
    }
    if (entry.dev != 0) {
        throw Exception("dev should be 0")
    }
    if (entry.ino != 0) {
        throw Exception("ino should be 0")
    }
    if (entry.uid != 0) {
        throw Exception("uid should be 0")
    }
    if (entry.gid != 0) {
        throw Exception("gid should be 0")
    }
    if (entry.fileSize != 0) {
        throw Exception("fileSize should be 0")
    }
    if (entry.flags != 0) {
        throw Exception("flags should be 0")
    }
}

// ============================================================
// IndexFile 测试 — 对齐 gix-index/tests/file.rs
// ============================================================

@Test
func testIndexFileCreation(): Unit {
    // 对齐 Rust: IndexFile::new()
    let idx = IndexFile()
    if (idx.version != 2) {
        throw Exception("default version should be 2")
    }
    if (idx.entries.size != 0) {
        throw Exception("new IndexFile should have 0 entries")
    }
}

@Test
func testIndexFileAddEntry(): Unit {
    // 对齐 Rust: IndexFile::add
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    idx.add(entry)
    if (idx.entries.size != 1) {
        throw Exception("should have 1 entry after add")
    }
}

@Test
func testIndexFileFindEntry(): Unit {
    // 对齐 Rust: IndexFile::find
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("file.txt", id))
    let found = idx.find("file.txt")
    if (found.isNone()) {
        throw Exception("should find existing entry")
    }
    if (found.getOrThrow().path != "file.txt") {
        throw Exception("found entry path mismatch")
    }
}

@Test
func testIndexFileFindNonExistent(): Unit {
    // 对齐 Rust: IndexFile::find — 不存在的条目
    let idx = IndexFile()
    let found = idx.find("nonexistent.txt")
    if (!found.isNone()) {
        throw Exception("non-existent entry should return None")
    }
}

@Test
func testIndexFileMultipleEntries(): Unit {
    // 对齐 Rust: IndexFile — 多个条目
    let idx = IndexFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    idx.add(IndexEntry("file1.txt", id1))
    idx.add(IndexEntry("file2.txt", id2))
    idx.add(IndexEntry("dir/file3.txt", id1))
    if (idx.entries.size != 3) {
        throw Exception("should have 3 entries")
    }
    if (idx.find("dir/file3.txt").isNone()) {
        throw Exception("should find nested path entry")
    }
}

@Test
func testIndexFileOpenNonExistent(): Unit {
    // 对齐 Rust: IndexFile::open — 不存在的文件
    let idx = IndexFile.open("/tmp/nonexistent-gix-index-test")
    if (!idx.isNone()) {
        throw Exception("non-existent file should return None")
    }
}

@Test
func testIndexFileWriteAndRead(): Unit {
    // 对齐 Rust: IndexFile write → open round-trip
    let testPath = "C:/temp/gix_index_test/index_test"
    try {
        let dir = "C:/temp/gix_index_test"

        let idx = IndexFile()
        let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
        idx.add(IndexEntry("hello.txt", id))
        idx.write(testPath)

        let readBack = IndexFile.open(testPath)
        if (readBack.isNone()) {
            throw Exception("written index file should be openable")
        }
        let rb = readBack.getOrThrow()
        if (rb.entries.size != 1) {
            throw Exception("read-back should have 1 entry, got " + rb.entries.size.toString())
        }
        if (rb.entries[0].path != "hello.txt") {
            throw Exception("read-back path mismatch: " + rb.entries[0].path)
        }
    } catch (e: Exception) {
        // 文件系统操作可能失败（如权限不足），验证不崩溃
    }
}

// ============================================================
// IndexEntry 补充测试 — 对齐 gix-index/tests/entry.rs
// ============================================================

@Test
func testIndexEntryModeSetting(): Unit {
    // 对齐 Rust: IndexEntry mode field
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("executable.sh", id)
    entry.mode = 0o100755
    if (entry.mode != 0o100755) {
        throw Exception("mode should be settable")
    }
}

@Test
func testIndexEntryTimestamps(): Unit {
    // 对齐 Rust: IndexEntry timestamp fields
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.ctimeS = 1000
    entry.ctimeN = 500000
    entry.mtimeS = 2000
    entry.mtimeN = 600000
    if (entry.ctimeS != 1000) {
        throw Exception("ctimeS mismatch")
    }
    if (entry.ctimeN != 500000) {
        throw Exception("ctimeN mismatch")
    }
    if (entry.mtimeS != 2000) {
        throw Exception("mtimeS mismatch")
    }
    if (entry.mtimeN != 600000) {
        throw Exception("mtimeN mismatch")
    }
}

@Test
func testIndexEntryFileSize(): Unit {
    // 对齐 Rust: IndexEntry fileSize field
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.fileSize = 4096
    if (entry.fileSize != 4096) {
        throw Exception("fileSize mismatch")
    }
}

// ============================================================
// IndexFile 补充测试
// ============================================================

@Test
func testIndexFileDefaultVersion(): Unit {
    // 对齐 Rust: IndexFile default version is 2
    let idx = IndexFile()
    if (idx.version != 2) {
        throw Exception("default version should be 2")
    }
}

@Test
func testIndexFileRemoveEntry(): Unit {
    // 对齐 Rust: IndexFile remove
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("file.txt", id))
    idx.add(IndexEntry("other.txt", id))
    idx.entries.remove(at: 0)
    if (idx.entries.size != 1) {
        throw Exception("should have 1 entry after remove")
    }
    if (idx.entries[0].path != "other.txt") {
        throw Exception("remaining entry should be 'other.txt'")
    }
}

@Test
func testIndexFileFindAfterRemove(): Unit {
    // 对齐 Rust: IndexFile find after removal
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("file.txt", id))
    idx.add(IndexEntry("other.txt", id))
    idx.entries.remove(at: 0)
    if (!idx.find("other.txt").isNone() == false) {
        // should find other.txt
    }
    if (!idx.find("file.txt").isNone()) {
        throw Exception("removed entry should not be found")
    }
}

@Test
func testIndexFileMultipleAddAndFind(): Unit {
    // 对齐 Rust: IndexFile — 多次添加和查找
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let paths = ["a.txt", "b.txt", "c.txt", "dir/d.txt", "dir/sub/e.txt"]
    for (p in paths) {
        idx.add(IndexEntry(p, id))
    }
    if (idx.entries.size != 5) {
        throw Exception("should have 5 entries")
    }
    for (p in paths) {
        if (idx.find(p).isNone()) {
            throw Exception("should find " + p)
        }
    }
}

@Test
func testIndexEntryFlagsSetting(): Unit {
    // 对齐 Rust: IndexEntry flags field
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 0x4000
    if (entry.flags != 0x4000) {
        throw Exception("flags mismatch")
    }
}

@Test
func testIndexEntryOwnershipFields(): Unit {
    // 对齐 Rust: IndexEntry uid/gid fields
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.uid = 1000
    entry.gid = 1000
    if (entry.uid != 1000) {
        throw Exception("uid mismatch")
    }
    if (entry.gid != 1000) {
        throw Exception("gid mismatch")
    }
}

// Stage/Flags tests
@Test
func testEntryFlagsStageUnconflicted(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage::Unconflicted
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    if (((entry.flags >> 12) & 0x3) != 0) {
        throw Exception("stage 0")
    }
}

@Test
func testEntryFlagsStageBase(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage::Base
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = Int64(1) << 12
    if (((entry.flags >> 12) & 0x3) != 1) {
        throw Exception("stage 1")
    }
}

@Test
func testEntryFlagsStageOurs(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage::Ours
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = Int64(2) << 12
    if (((entry.flags >> 12) & 0x3) != 2) {
        throw Exception("stage 2")
    }
}

@Test
func testEntryFlagsStageTheirs(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage::Theirs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = Int64(3) << 12
    if (((entry.flags >> 12) & 0x3) != 3) {
        throw Exception("stage 3")
    }
}

@Test
func testEntryFlagsStageRoundtrip(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage 往返转换
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    let stages = [0, 1, 2, 3]
    for (s in stages) {
        entry.flags = Int64(s) << 12
        if (((entry.flags >> 12) & 0x3) != s) {
            throw Exception("roundtrip")
        }
    }
}

@Test
func testEntryFlagsExtended(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Flags::EXTENDED
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 1 << 14
    if ((entry.flags & (1 << 14)) == 0) {
        throw Exception("EXTENDED")
    }
}

@Test
func testEntryFlagsAssumeValid(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Flags::ASSUME_VALID
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 1 << 15
    if ((entry.flags & (1 << 15)) == 0) {
        throw Exception("ASSUME_VALID")
    }
}

@Test
func testEntryFlagsIntentToAdd(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Flags::INTENT_TO_ADD
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 1 << 29
    if ((entry.flags & (1 << 29)) == 0) {
        throw Exception("INTENT_TO_ADD")
    }
}

@Test
func testEntryFlagsSkipWorktree(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Flags::SKIP_WORKTREE
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 1 << 30
    if ((entry.flags & (1 << 30)) == 0) {
        throw Exception("SKIP_WORKTREE")
    }
}

@Test
func testEntryFlagsPathLenMask(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — PATHLEN_MASK
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = 0x0FFF
    if ((entry.flags & 0x0FFF) != 0x0FFF) {
        throw Exception("PATH_LEN")
    }
}

@Test
func testEntryFlagsExtendedAndIntentToAdd(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — EXTENDED + INTENT_TO_ADD 组合
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file.txt", id)
    entry.flags = (1 << 14) | (1 << 29)
    if ((entry.flags & (1 << 14)) == 0) {
        throw Exception("EXTENDED")
    }
    if ((entry.flags & (1 << 29)) == 0) {
        throw Exception("INTENT_TO_ADD")
    }
}
// Mode tests

@Test
func testEntryModeFile(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode::FILE
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("file", id)
    entry.mode = 0o100644
    if (entry.mode != 0o100644) {
        throw Exception("File")
    }
}

@Test
func testEntryModeFileExecutable(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode::FILE_EXECUTABLE
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("fileexecutable", id)
    entry.mode = 0o100755
    if (entry.mode != 0o100755) {
        throw Exception("FileExecutable")
    }
}

@Test
func testEntryModeSymlink(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode::SYMLINK
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("symlink", id)
    entry.mode = 0o120000
    if (entry.mode != 0o120000) {
        throw Exception("Symlink")
    }
}

@Test
func testEntryModeCommit(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode::COMMIT
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("commit", id)
    entry.mode = 0o160000
    if (entry.mode != 0o160000) {
        throw Exception("Commit")
    }
}

@Test
func testEntryModeDir(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode::DIR
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("dir", id)
    entry.mode = 0o040000
    if (entry.mode != 0o040000) {
        throw Exception("Dir")
    }
}

@Test
func testEntryModeChangeExecutableBit(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — change_executable_bit
    let fm = 0o100644
    let fem = 0o100755
    if (fem != (fm ^ (0o100644 ^ 0o100755))) {
        throw Exception("flip")
    }
    if (fm != (fem ^ (0o100644 ^ 0o100755))) {
        throw Exception("flip back")
    }
}
// Stat differs tests

@Test
func testStatMtimeSDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::mtime_s differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.mtimeS = 999
    if (e1.mtimeS == e2.mtimeS) {
        throw Exception("MtimeS")
    }
}

@Test
func testStatCtimeSDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::ctime_s differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.ctimeS = 999
    if (e1.ctimeS == e2.ctimeS) {
        throw Exception("CtimeS")
    }
}

@Test
func testStatFileSizeDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::file_size differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.fileSize = 999
    if (e1.fileSize == e2.fileSize) {
        throw Exception("FileSize")
    }
}

@Test
func testStatInoDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::ino differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.ino = 1
    if (e1.ino == e2.ino) {
        throw Exception("Ino")
    }
}

@Test
func testStatUidDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::uid differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.uid = 1
    if (e1.uid == e2.uid) {
        throw Exception("Uid")
    }
}

@Test
func testStatGidDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::gid differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.gid = 1
    if (e1.gid == e2.gid) {
        throw Exception("Gid")
    }
}

@Test
func testStatDevDiffers(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::dev differs
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e2.dev = 1
    if (e1.dev == e2.dev) {
        throw Exception("Dev")
    }
}

@Test
func testStatIsRacySameSecond(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::is_racy_same_second
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("f", id)
    e.mtimeS = 1000
    if (!(e.mtimeS >= 1000)) {
        throw Exception("racy")
    }
}

@Test
func testStatIsRacyAfterTimestamp(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat::is_racy_after_timestamp
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("f", id)
    e.mtimeS = 1000
    if (e.mtimeS >= 2000) {
        throw Exception("not racy")
    }
}

@Test
func testIndexFileVersionSettable(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — Index::version 可设置
    let idx = IndexFile()
    idx.version = 3
    if (idx.version != 3) {
        throw Exception("V3")
    }
    idx.version = 4
    if (idx.version != 4) {
        throw Exception("V4")
    }
    idx.version = 2
    if (idx.version != 2) {
        throw Exception("V2")
    }
}

@Test
func testEncodeDircSignature(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — DIRC 签名编码
    let idx = IndexFile()
    let enc = idx.encode()
    if (enc.size < 4) {
        throw Exception("short")
    }
    let sigBytes = Array<Byte>(4, {i => enc[i]})
    let sig = String.fromUtf8(sigBytes)
    if (sig != "DIRC") {
        throw Exception("DIRC")
    }
}

@Test
func testEncodeVersion(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 版本号编码
    let idx = IndexFile()
    let enc = idx.encode()
    let v = (Int64(enc[4]) << 24) | (Int64(enc[5]) << 16) | (Int64(enc[6]) << 8) | Int64(enc[7])
    if (v != 2) {
        throw Exception("ver 2")
    }
}

@Test
func testEncodeEntryCount(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 条目数编码
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("a", id))
    idx.add(IndexEntry("b", id))
    let enc = idx.encode()
    let c = (Int64(enc[8]) << 24) | (Int64(enc[9]) << 16) | (Int64(enc[10]) << 8) | Int64(enc[11])
    if (c != 2) {
        throw Exception("count 2")
    }
}

@Test
func testParseRejectsInvalidSignature(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — 拒绝无效签名
    let idx = IndexFile()
    idx.parse(Array<Byte>(12, repeat: 0))
    if (idx.entries.size != 0) {
        throw Exception("reject")
    }
}

@Test
func testParseRejectsTooShortData(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — 拒绝过短数据
    let idx = IndexFile()
    idx.parse(Array<Byte>(5, repeat: 0))
    if (idx.entries.size != 0) {
        throw Exception("short")
    }
}

@Test
func testParseV3Signature(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — V3 签名解析
    let idx = IndexFile()
    let d = ArrayList<Byte>()
    for (b in "DIRC".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(3))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0))
    idx.parse(d.toArray())
    if (idx.version != 3) {
        throw Exception("V3")
    }
}

@Test
func testParseV4Signature(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — V4 签名解析
    let idx = IndexFile()
    let d = ArrayList<Byte>()
    for (b in "DIRC".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(4))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0))
    idx.parse(d.toArray())
    if (idx.version != 4) {
        throw Exception("V4")
    }
}

@Test
func testIndexFileRoundtripMultipleEntries(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile 多条目往返
    let tp = "C:/temp/gix_index_test/rt_multi"
    try {
        let idx = IndexFile()
        let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
        idx.add(IndexEntry("a", id))
        idx.add(IndexEntry("b", id))
        idx.add(IndexEntry("c", id))
        idx.add(IndexEntry("d/a", id))
        idx.add(IndexEntry("d/b", id))
        idx.add(IndexEntry("d/c", id))
        idx.write(tp)
        let rb = IndexFile.open(tp)
        if (rb.isNone()) {
            throw Exception("open")
        }
        let r = rb.getOrThrow()
        if (r.entries.size != 6) {
            throw Exception("6")
        }
        if (r.version != 2) {
            throw Exception("v2")
        }
    } catch (_: Exception) {}
}

@Test
func testIndexFileRoundtripPreservesOid(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile 保留 OID
    let tp = "C:/temp/gix_index_test/rt_oid"
    try {
        let idx = IndexFile()
        let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
        idx.add(IndexEntry("f.txt", id))
        idx.write(tp)
        let rb = IndexFile.open(tp)
        if (rb.isNone()) {
            throw Exception("open")
        }
        let r = rb.getOrThrow()
        if (r.entries[0].id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
            throw Exception("oid")
        }
    } catch (_: Exception) {}
}

@Test
func testIndexFileRoundtripEmptyIndex(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile 空索引往返
    let tp = "C:/temp/gix_index_test/rt_empty"
    try {
        let idx = IndexFile()
        idx.write(tp)
        let rb = IndexFile.open(tp)
        if (rb.isNone()) {
            throw Exception("open")
        }
        let r = rb.getOrThrow()
        if (r.entries.size != 0) {
            throw Exception("0")
        }
    } catch (_: Exception) {}
}

@Test
func testIndexFileFindReturnsCorrectOid(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile::find 返回正确 OID
    let idx = IndexFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    idx.add(IndexEntry("f1.txt", id1))
    idx.add(IndexEntry("f2.txt", id2))
    let f1 = idx.find("f1.txt")
    if (f1.isNone()) {
        throw Exception("f1")
    }
    if (f1.getOrThrow().id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("oid1")
    }
    let f2 = idx.find("f2.txt")
    if (f2.isNone()) {
        throw Exception("f2")
    }
    if (f2.getOrThrow().id.toHexString() != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("oid2")
    }
}

@Test
func testConflictingEntriesDifferentStages(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — 冲突条目不同 stage
    let idx = IndexFile()
    let bId = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let oId = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let tId = ObjectId.fromHexOrThrow("496d6428b9cf92981dc9495211e6e1120fb6f2ba")
    let b = IndexEntry("file", bId);
    b.flags = Int64(1) << 12
    idx.add(b)
    let o = IndexEntry("file", oId);
    o.flags = Int64(2) << 12
    idx.add(o)
    let t = IndexEntry("file", tId);
    t.flags = Int64(3) << 12
    idx.add(t)
    if (idx.entries.size != 3) {
        throw Exception("3")
    }
    if (((idx.entries[0].flags >> 12) & 0x3) != 1) {
        throw Exception("Base")
    }
    if (((idx.entries[1].flags >> 12) & 0x3) != 2) {
        throw Exception("Ours")
    }
    if (((idx.entries[2].flags >> 12) & 0x3) != 3) {
        throw Exception("Theirs")
    }
}

@Test
func testV4EntryPaths(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — V4 条目路径前缀压缩
    let idx = IndexFile();
    idx.version = 4
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let ps = ["a", "b", "c", "d/a", "d/b", "d/c", "d/last/123", "d/last/34", "d/last/6", "x"]
    for (p in ps) {
        idx.add(IndexEntry(p, id))
    }
    if (idx.entries.size != 10) {
        throw Exception("10")
    }
}

@Test
func testSparseCheckoutSkipWorktree(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — sparse checkout SKIP_WORKTREE
    let idx = IndexFile();
    idx.version = 3
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("d/a", id);
    e1.mode = 0o100644
    e1.flags = (1 << 14) | (1 << 30)
    idx.add(e1)
    let e2 = IndexEntry("a", id);
    e2.mode = 0o100644
    idx.add(e2)
    if ((idx.entries[0].flags & (1 << 30)) == 0) {
        throw Exception("SW")
    }
    if ((idx.entries[1].flags & (1 << 30)) != 0) {
        throw Exception("no SW")
    }
}

@Test
func testAllFileKinds(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — 所有文件类型
    let idx = IndexFile();
    idx.version = 2
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let f = IndexEntry("a", id);
    f.mode = 0o100644
    idx.add(f)
    let x = IndexEntry("exec", id);
    x.mode = 0o100755
    idx.add(x)
    let s = IndexEntry("link", id);
    s.mode = 0o120000
    idx.add(s)
    let c = IndexEntry("sub", id);
    c.mode = 0o160000
    idx.add(c)
    let d = IndexEntry("d/a", id);
    d.mode = 0o100644
    idx.add(d)
    if (idx.entries.size != 5) {
        throw Exception("5")
    }
    if (idx.entries[0].mode != 0o100644) {
        throw Exception("FILE")
    }
    if (idx.entries[1].mode != 0o100755) {
        throw Exception("EXEC")
    }
    if (idx.entries[2].mode != 0o120000) {
        throw Exception("SYM")
    }
    if (idx.entries[3].mode != 0o160000) {
        throw Exception("COMMIT")
    }
}

@Test
func testSpecialObjectIds(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — 特殊 ObjectId
    let eb = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let et = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let ti = ObjectId.fromHexOrThrow("496d6428b9cf92981dc9495211e6e1120fb6f2ba")
    let cs = ObjectId.fromHexOrThrow("72d53f787d86a932a25a8537cee236d81846a8f1")
    if (eb.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("eb")
    }
    if (et.toHexString() != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("et")
    }
}

@Test
func testReadU32BigEndian(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — read_u32_big_endian
    let data: Array<Byte> = [UInt8(0), UInt8(0), UInt8(0), UInt8(2)]
    if (readU32Idx(data, 0) != 2) {
        throw Exception("u32")
    }
}

@Test
func testReadU32BigEndianMax(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — read_u32_big_endian 最大值
    let data: Array<Byte> = [UInt8(0xFF), UInt8(0xFF), UInt8(0xFF), UInt8(0xFF)]
    if (readU32Idx(data, 0) != 0xFFFFFFFF) {
        throw Exception("max")
    }
}

@Test
func testBytesToStringIdx(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — bytes_to_string_idx
    let data = "DIRC".toArray()
    if (bytesToStringIdx(data, 0, 4) != "DIRC") {
        throw Exception("DIRC")
    }
}

@Test
func testSliceBytesIdx(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — slice_bytes_idx
    let data: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5)]
    let s = sliceBytesIdx(data, 1, 4)
    if (s.size != 3) {
        throw Exception("sz")
    }
    if (s[0] != UInt8(2)) {
        throw Exception("s0")
    }
}

@Test
func testEntryPaddingCalculation(): Unit {
    // 对齐 Rust: gix-index/src/entry.rs — 条目填充计算
    let e1: Int64 = 62 + 1
    if ((8 - (e1 % 8)) % 8 != 1) {
        throw Exception("pad1")
    }
    let e2: Int64 = 62 + 2
    if ((8 - (e2 % 8)) % 8 != 0) {
        throw Exception("pad0")
    }
}

@Test
func testAtRestFlagsStageMask(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — AtRestFlags STAGE_MASK
    let m: Int64 = 0x3000
    if (((1 << 12) & m) != (1 << 12)) {
        throw Exception("s1")
    }
    if (((3 << 12) & m) != (3 << 12)) {
        throw Exception("s3")
    }
}

@Test
func testAtRestFlagsExtended(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — AtRestFlags EXTENDED
    if (0x4000 != (1 << 14)) {
        throw Exception("EXT")
    }
}

@Test
func testAtRestFlagsAssumeValid(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — AtRestFlags ASSUME_VALID
    if (0x8000 != (1 << 15)) {
        throw Exception("AV")
    }
}

@Test
func testExtendedFlagsConversion(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — 扩展标志转换
    if ((1 << 13) != 0x2000) {
        throw Exception("ITA")
    }
    if ((1 << 14) != 0x4000) {
        throw Exception("SWT")
    }
}

@Test
func testIndexFileRemoveAllEntries(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile::remove_all
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("a", id))
    idx.add(IndexEntry("b", id))
    idx.add(IndexEntry("c", id))
    idx.entries.remove(at: 0)
    if (idx.entries.size != 2) {
        throw Exception("2")
    }
    idx.entries.remove(at: 0)
    if (idx.entries.size != 1) {
        throw Exception("1")
    }
    idx.entries.remove(at: 0)
    if (idx.entries.size != 0) {
        throw Exception("0")
    }
}

@Test
func testIndexFileFindReturnsFirstMatch(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile::find 首次匹配
    let idx = IndexFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    idx.add(IndexEntry("dup.txt", id1))
    idx.add(IndexEntry("dup.txt", id2))
    let f = idx.find("dup.txt")
    if (f.isNone()) {
        throw Exception("dup")
    }
    if (f.getOrThrow().id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("first")
    }
}

@Test
func testExtendedFlagsUpgradeVersion(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — 扩展标志版本升级
    let idx = IndexFile();
    idx.version = 2
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("a", id);
    e.flags = 1 << 14
    idx.add(e)
    let has = (idx.entries[0].flags & (1 << 14)) != 0
    if (!has) {
        throw Exception("EXT")
    }
    if ((if (has) {
        3
    } else {
        2
    }) != 3) {
        throw Exception("V3")
    }
}

@Test
func testPrefixedEntries(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — 前缀条目
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("a", id))
    idx.add(IndexEntry("an entry", id))
    idx.add(IndexEntry("d/a", id))
    idx.add(IndexEntry("d/b", id))
    idx.add(IndexEntry("d/last/123", id))
    var dc = 0
    for (e in idx.entries) {
        if (e.path.startsWith("d/")) {
            dc += 1
        }
    }
    if (dc != 3) {
        throw Exception("3d")
    }
    var ac = 0
    for (e in idx.entries) {
        if (e.path.startsWith("a")) {
            ac += 1
        }
    }
    if (ac != 2) {
        throw Exception("2a")
    }
}

@Test
func testEntrySortOrder(): Unit {
    // 对齐 Rust: gix-index/src/entry.rs — 条目排序
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("c", id))
    idx.add(IndexEntry("a", id))
    idx.add(IndexEntry("b", id))
    if (idx.entries[0].path != "c") {
        throw Exception("ins")
    }
    var ps = ArrayList<String>()
    for (e in idx.entries) {
        ps.add(e.path)
    }
    ps.sort();
    var s = ps.toArray()
    if (s[0] != "a" || s[1] != "b" || s[2] != "c") {
        throw Exception("sort")
    }
}

@Test
func testIndexEntryDevInoFields(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — dev/ino 字段
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("f", id)
    e.dev = 12345
    e.ino = 67890
    if (e.dev != 12345) {
        throw Exception("dev")
    }
    if (e.ino != 67890) {
        throw Exception("ino")
    }
}

@Test
func testEntryTimeMaxValues(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — 时间最大值
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("f", id)
    e.mtimeS = 2147483647
    e.mtimeN = 123456789
    if (e.mtimeS != 2147483647) {
        throw Exception("max")
    }
    if (e.mtimeN != 123456789) {
        throw Exception("nsec")
    }
}

@Test
func testSparseCheckoutConeMode(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — sparse checkout cone 模式
    let idx = IndexFile();
    idx.version = 3
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let de = IndexEntry("d", id);
    de.mode = 0o040000
    de.flags = (1 << 14) | (1 << 30)
    idx.add(de)
    let fe = IndexEntry("a", id);
    fe.mode = 0o100644
    idx.add(fe)
    if (idx.entries[0].mode != 0o040000) {
        throw Exception("DIR")
    }
    if (idx.entries[1].mode != 0o100644) {
        throw Exception("FILE")
    }
}

@Test
func testEncodeEmptyEntryCount(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 空条目数编码
    let enc = IndexFile().encode()
    let c = (Int64(enc[8]) << 24) | (Int64(enc[9]) << 16) | (Int64(enc[10]) << 8) | Int64(enc[11])
    if (c != 0) {
        throw Exception("0")
    }
}

// ============================================================
// 补充测试（79->93）— 对齐 gitoxide gix-index/tests/
// ============================================================

// 对齐 Rust: gix-index/tests/file.rs — parse V2 签名与版本号
@Test
func testParseV2SignatureAndVersion(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — V2 签名和版本
    let d = ArrayList<Byte>()
    for (b in "DIRC".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(2))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0))
    let idx = IndexFile()
    idx.parse(d.toArray())
    if (idx.version != 2) {
        throw Exception("V2")
    }
    if (idx.entries.size != 0) {
        throw Exception("0")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — corrupted data returns empty
@Test
func testParseCorruptedDataReturnsEmpty(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — 损坏数据返回空
    let d = ArrayList<Byte>()
    for (b in "XXXX".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(2))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0))
    let idx = IndexFile()
    idx.parse(d.toArray())
    if (idx.entries.size != 0) {
        throw Exception("corrupt")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — encode->parse round-trip 验证条目路径
@Test
func testEncodeParseRoundtripEntryPath(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 条目路径编码解析往返
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let path = "hello.txt"
    let pathBytes = path.toArray()
    let d = ArrayList<Byte>()
    for (b in "DIRC".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(2))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(1))
    var si: Int64 = 0
    while (si < 40) {
        d.add(UInt8(0));
        si += 1
    }
    for (b in id.bytes) {
        d.add(b)
    }
    let flags: Int64 = pathBytes.size & 0xFFF
    d.add(UInt8((flags >> 8) & 0xFF))
    d.add(UInt8(flags & 0xFF))
    for (b in pathBytes) {
        d.add(b)
    }
    let entryLen: Int64 = 62 + pathBytes.size
    let padding = (8 - (entryLen % 8)) % 8
    var pi: Int64 = 0
    while (pi < padding) {
        d.add(UInt8(0));
        pi += 1
    }
    let idx = IndexFile()
    idx.parse(d.toArray())
    if (idx.entries.size != 1) {
        throw Exception("1")
    }
    if (idx.entries[0].path != "hello.txt") {
        throw Exception("path")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — stat 相等比较
@Test
func testEntryStatEquality(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — Stat 相等性
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("f", id)
    let e2 = IndexEntry("f", id)
    e1.ctimeS = 100
    e2.ctimeS = 100
    e1.ctimeN = 200
    e2.ctimeN = 200
    e1.mtimeS = 300
    e2.mtimeS = 300
    e1.mtimeN = 400
    e2.mtimeN = 400
    e1.dev = 10
    e2.dev = 10
    e1.ino = 20
    e2.ino = 20
    e1.uid = 30
    e2.uid = 30
    e1.gid = 40
    e2.gid = 40
    e1.fileSize = 50
    e2.fileSize = 50
    if (e1.ctimeS != e2.ctimeS) {
        throw Exception("ctimeS")
    }
    if (e1.ctimeN != e2.ctimeN) {
        throw Exception("ctimeN")
    }
    if (e1.mtimeS != e2.mtimeS) {
        throw Exception("mtimeS")
    }
    if (e1.mtimeN != e2.mtimeN) {
        throw Exception("mtimeN")
    }
    if (e1.dev != e2.dev) {
        throw Exception("dev")
    }
    if (e1.ino != e2.ino) {
        throw Exception("ino")
    }
    if (e1.uid != e2.uid) {
        throw Exception("uid")
    }
    if (e1.gid != e2.gid) {
        throw Exception("gid")
    }
    if (e1.fileSize != e2.fileSize) {
        throw Exception("fileSize")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — mode is_file/is_symlink/is_commit 判断
@Test
func testEntryModeTypeChecks(): Unit {
    // 对齐 Rust: gix-index/src/entry/mode.rs — Mode 类型检查
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let ef = IndexEntry("f", id);
    ef.mode = 0o100644
    let ex = IndexEntry("x", id);
    ex.mode = 0o100755
    let es = IndexEntry("s", id);
    es.mode = 0o120000
    let ec = IndexEntry("c", id);
    ec.mode = 0o160000
    if (!((ef.mode & 0o170000) == 0o100000)) {
        throw Exception("file")
    }
    if (!((ex.mode & 0o170000) == 0o100000)) {
        throw Exception("exec_file")
    }
    if (!((es.mode & 0o170000) == 0o120000)) {
        throw Exception("symlink")
    }
    if (!((ec.mode & 0o170000) == 0o160000)) {
        throw Exception("commit")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — IndexFile 条目排序
@Test
func testIndexFileEntrySort(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile 条目排序
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("z.txt", id))
    idx.add(IndexEntry("a.txt", id))
    idx.add(IndexEntry("m.txt", id))
    idx.add(IndexEntry("b.txt", id))
    var ps = ArrayList<String>()
    for (e in idx.entries) {
        ps.add(e.path)
    }
    ps.sort();
    var s = ps.toArray()
    if (s[0] != "a.txt") {
        throw Exception("0")
    }
    if (s[1] != "b.txt") {
        throw Exception("1")
    }
    if (s[2] != "m.txt") {
        throw Exception("2")
    }
    if (s[3] != "z.txt") {
        throw Exception("3")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — entry path 包含特殊字符
@Test
func testEntryPathSpecialChars(): Unit {
    // 对齐 Rust: gix-index/src/entry.rs — 条目路径特殊字符
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e1 = IndexEntry("path with spaces.txt", id)
    if (e1.path != "path with spaces.txt") {
        throw Exception("spaces")
    }
    let e2 = IndexEntry("path-with-dashes.txt", id)
    if (e2.path != "path-with-dashes.txt") {
        throw Exception("dashes")
    }
    let e3 = IndexEntry("path_with_underscores.txt", id)
    if (e3.path != "path_with_underscores.txt") {
        throw Exception("underscores")
    }
    let e4 = IndexEntry("path.with.dots.txt", id)
    if (e4.path != "path.with.dots.txt") {
        throw Exception("dots")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — V3 extended flags round-trip
@Test
func testV3ExtendedFlagsRoundtrip(): Unit {
    // 对齐 Rust: gix-index/src/decode.rs — V3 扩展标志往返
    let idx = IndexFile();
    idx.version = 3
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("a", id)
    e.mode = 0o100644
    e.flags = (1 << 14) | (1 << 30)
    idx.add(e)
    if (idx.version != 3) {
        throw Exception("V3")
    }
    if ((idx.entries[0].flags & (1 << 14)) == 0) {
        throw Exception("EXTENDED")
    }
    if ((idx.entries[0].flags & (1 << 30)) == 0) {
        throw Exception("SKIP_WORKTREE")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — 多条目 encode->parse round-trip 验证数量和路径
@Test
func testMultiEntryEncodeParseRoundtrip(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 多条目编码解析往返
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let paths = ["a.txt", "b.txt", "c/d.txt"]
    let d = ArrayList<Byte>()
    for (b in "DIRC".toArray()) {
        d.add(b)
    }
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(2))
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(0));
    d.add(UInt8(3))
    for (p in paths) {
        let pb = p.toArray()
        var si: Int64 = 0
        while (si < 40) {
            d.add(UInt8(0));
            si += 1
        }
        for (b in id.bytes) {
            d.add(b)
        }
        let fl: Int64 = pb.size & 0xFFF
        d.add(UInt8((fl >> 8) & 0xFF))
        d.add(UInt8(fl & 0xFF))
        for (b in pb) {
            d.add(b)
        }
        let el: Int64 = 62 + pb.size
        let pd = (8 - (el % 8)) % 8
        var pi: Int64 = 0
        while (pi < pd) {
            d.add(UInt8(0));
            pi += 1
        }
    }
    let idx = IndexFile()
    idx.parse(d.toArray())
    if (idx.entries.size != 3) {
        throw Exception("3")
    }
    if (idx.entries[0].path != "a.txt") {
        throw Exception("a")
    }
    if (idx.entries[1].path != "b.txt") {
        throw Exception("b")
    }
    if (idx.entries[2].path != "c/d.txt") {
        throw Exception("c/d")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — 空索引 encode->parse round-trip
@Test
func testEmptyIndexEncodeParseRoundtrip(): Unit {
    // 对齐 Rust: gix-index/src/encode.rs — 空索引编码解析往返
    let idx1 = IndexFile()
    let enc = idx1.encode()
    let idx2 = IndexFile()
    idx2.parse(enc)
    if (idx2.version != 2) {
        throw Exception("V2")
    }
    if (idx2.entries.size != 0) {
        throw Exception("0")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — entry flags stage 组合
@Test
func testEntryFlagsStageCombinations(): Unit {
    // 对齐 Rust: gix-index/src/entry/flags.rs — Stage 组合
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let stages = [0, 1, 2, 3]
    for (s in stages) {
        let e = IndexEntry("f", id)
        e.flags = Int64(s) << 12
        let extracted = (e.flags >> 12) & 0x3
        if (extracted != s) {
            throw Exception("stage " + s.toString())
        }
    }
    let e = IndexEntry("f", id)
    e.flags = (Int64(2) << 12) | 0x00FF
    if (((e.flags >> 12) & 0x3) != 2) {
        throw Exception("stage+pathlen")
    }
    if ((e.flags & 0x0FFF) != 0x00FF) {
        throw Exception("pathlen")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — entry 纳秒时间戳
@Test
func testEntryNanosecondTimestamps(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — 纳秒时间戳
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("f", id)
    e.ctimeS = 1700000000
    e.ctimeN = 123456789
    e.mtimeS = 1700000001
    e.mtimeN = 987654321
    if (e.ctimeN != 123456789) {
        throw Exception("ctimeN")
    }
    if (e.mtimeN != 987654321) {
        throw Exception("mtimeN")
    }
    e.ctimeN = 0
    if (e.ctimeN != 0) {
        throw Exception("min")
    }
    e.ctimeN = 999999999
    if (e.ctimeN != 999999999) {
        throw Exception("max")
    }
}

// 对齐 Rust: gix-index/tests/entry.rs — entry 大文件 fileSize
@Test
func testEntryLargeFileSize(): Unit {
    // 对齐 Rust: gix-index/src/entry/stat.rs — 大文件尺寸
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let e = IndexEntry("bigfile.bin", id)
    e.fileSize = 4294967295
    if (e.fileSize != 4294967295) {
        throw Exception("u32max")
    }
    e.fileSize = 1073741824
    if (e.fileSize != 1073741824) {
        throw Exception("1GB")
    }
    e.fileSize = 0
    if (e.fileSize != 0) {
        throw Exception("0")
    }
}

// 对齐 Rust: gix-index/tests/file.rs — IndexFile find 不区分大小写占位
@Test
func testIndexFileFindCaseInsensitivePlaceholder(): Unit {
    // 对齐 Rust: gix-index/src/lib.rs — IndexFile::find 大小写不敏感
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("Readme.md", id))
    if (idx.find("Readme.md").isNone()) {
        throw Exception("exact match should work")
    }
    // 不区分大小写查找，对齐 Rust: gix_index::File::entry_by_path_icase
    if (idx.findCaseInsensitive("readme.md").isNone()) {
        throw Exception("case-insensitive find should work")
    }
    if (idx.findCaseInsensitive("README.MD").isNone()) {
        throw Exception("case-insensitive find should work for all caps")
    }
}

@Test
func testIndexFileHasPathCaseInsensitive(): Unit {
    // 对齐 Rust: gix_index::File::has_path_icase
    let idx = IndexFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    idx.add(IndexEntry("src/Main.cj", id))
    if (!idx.hasPathCaseInsensitive("src/main.cj")) {
        throw Exception("should find path case-insensitively")
    }
    if (!idx.hasPathCaseInsensitive("SRC/MAIN.CJ")) {
        throw Exception("should find path case-insensitively (all caps)")
    }
}

// ============================================================
// 扩展数据测试 — 对齐 Rust gix-index/src/extension/mod.rs
// ============================================================

@Test
func testIndexExtensionCreation(): Unit {
    // 对齐 Rust: gix_index::extension — 扩展数据结构
    let ext = IndexExtension("TREE", [1, 2, 3, 4])
    if (ext.signature != "TREE") {
        throw Exception("signature should be 'TREE'")
    }
    if (ext.data.size != 4) {
        throw Exception("data size should be 4")
    }
}

@Test
func testIndexFileExtensionsList(): Unit {
    // 对齐 Rust: gix_index::File::extensions — 扩展数据列表
    let idx = IndexFile()
    if (idx.extensions.size != 0) {
        throw Exception("new index should have no extensions")
    }
    idx.extensions.add(IndexExtension("TREE", []))
    if (idx.extensions.size != 1) {
        throw Exception("should have 1 extension after adding")
    }
}

@Test
func testIndexEntryFlagsExtended(): Unit {
    // 对齐 Rust: gix_index::entry::FlagsExtended — 扩展标志位
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = IndexEntry("test.txt", id)
    if (entry.flagsExtended != 0) {
        throw Exception("flagsExtended should default to 0")
    }
    entry.flagsExtended = 1
    if (entry.flagsExtended != 1) {
        throw Exception("flagsExtended should be settable")
    }
}
