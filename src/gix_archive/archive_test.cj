// 文件：archive_test.cj
// 用途：gix_archive 包的单元测试，对齐 Rust gitoxide gix-archive 测试
// 所属包：gix.gix_archive
// 对齐来源：gix-archive/tests/*.rs

package gitoxide.gix_archive

import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*
import std.unittest.*

// ============================================================
// Archive 测试 — 对齐 gix-archive/tests/archive.rs
// ============================================================

// 对齐 Rust: Archive::default()
@Test
func testArchiveConstruct(): Unit {
    let a = Archive()
    if (a.entries.size != 0) {
        throw Exception("entries should be empty initially")
    }
    if (a.commitId != "") {
        throw Exception("commitId should be empty initially")
    }
}

// 对齐 Rust: Archive 添加条目
@Test
func testArchiveAddEntry(): Unit {
    let a = Archive()
    a.addEntry("README.md", 0o100644, [72, 101, 108, 108, 111])
    if (a.entries.size != 1) {
        throw Exception("entries should have 1 item after addEntry")
    }
}

// 对齐 Rust: Archive 包含多个文件
@Test
func testArchiveAddMultipleEntries(): Unit {
    let a = Archive()
    a.addEntry("file1.txt", 0o100644, [65])
    a.addEntry("file2.txt", 0o100755, [66])
    a.addEntry("subdir/file3.txt", 0o100644, [67])
    if (a.entries.size != 3) {
        throw Exception("entries should have 3 items")
    }
}

// ============================================================
// ArchiveEntry 测试 — 对齐 gix-archive/tests/entry.rs
// ============================================================

// 对齐 Rust: ArchiveEntry 构造与字段访问
@Test
func testArchiveEntryConstruct(): Unit {
    let entry = ArchiveEntry("hello.txt", 0o100644, [72, 101, 108, 108, 111])
    if (entry.path != "hello.txt") {
        throw Exception("path should be hello.txt")
    }
    if (entry.mode != 0o100644) {
        throw Exception("mode should be 0o100644")
    }
    if (entry.data.size != 5) {
        throw Exception("data should have 5 bytes")
    }
}

// 对齐 Rust: ArchiveEntry 空数据
@Test
func testArchiveEntryEmptyData(): Unit {
    let entry = ArchiveEntry("empty.txt", 0o100644, [])
    if (entry.data.size != 0) {
        throw Exception("data should be empty")
    }
}

// 对齐 Rust: ArchiveEntry 可执行模式
@Test
func testArchiveEntryExecutableMode(): Unit {
    let entry = ArchiveEntry("run.sh", 0o100755, [35, 33, 47, 98, 105, 110])
    if (entry.mode != 0o100755) {
        throw Exception("mode should be 0o100755")
    }
}

// ============================================================
// writeTar 函数测试 — 对齐 gix-archive/tests/tar.rs
// ============================================================

// 对齐 Rust: writeTar 空归档
// 空归档：pax_global_header(512+512) + 结束块(1024) = 2048
@Test
func testWriteTarEmptyArchive(): Unit {
    let a = Archive()
    let result = writeTar(a)
    if (result.size != 2048) {
        throw Exception("empty archive should produce 2048 bytes (pax_global_header + end marker), got ${result.size}")
    }
}

// 对齐 Rust: writeTar 包含单个文件的归档
@Test
func testWriteTarSingleEntry(): Unit {
    let a = Archive()
    a.addEntry("hello.txt", 0o100644, [72, 101, 108, 108, 111])
    let result = writeTar(a)
    if (result.size == 0) {
        throw Exception("tar should not be empty")
    }
    // pax_global_header(1024) + file header(512) + data(5 padded to 512) + end marker(1024) = 3072
    if (result.size != 3072) {
        throw Exception("single entry tar should be 3072 bytes, got ${result.size}")
    }
}

// 对齐 Rust: writeTar 包含多个文件的归档
@Test
func testWriteTarMultipleEntries(): Unit {
    let a = Archive()
    a.addEntry("a.txt", 0o100644, [65])
    a.addEntry("b.txt", 0o100644, [66])
    let result = writeTar(a)
    if (result.size == 0) {
        throw Exception("tar should not be empty")
    }
}

// 对齐 Rust: tar 头部前 100 字节为文件名
// pax_global_header 在前 1024 字节，文件条目从 offset 1024 开始
@Test
func testWriteTarHeaderStructure(): Unit {
    let a = Archive()
    a.addEntry("test.txt", 0o100644, [84])
    let result = writeTar(a)
    // 文件名 "test.txt" 出现在 offset 1024 处（pax_global_header 之后）
    let paxSize = 1024
    let name = "test.txt".toArray()
    var nameMatch = true
    for (i in 0..name.size) {
        if (result[paxSize + i] != name[i]) {
            nameMatch = false
        }
    }
    if (!nameMatch) {
        throw Exception("tar header at offset 1024 should start with filename")
    }
}

// 对齐 Rust: tar 数据填充到 512 字节边界
// pax_global_header(1024) + header(512) + data 3 padded to 512 + end marker(1024) = 3072
@Test
func testWriteTarPadding(): Unit {
    let a = Archive()
    a.addEntry("pad.txt", 0o100644, [1, 2, 3])
    let result = writeTar(a)
    if (result.size != 3072) {
        throw Exception(
            "tar with 3-byte data should be 3072 bytes (pax + header + data block + end), got ${result.size}")
    }
}

// 对齐 Rust: 数据恰好为 512 字节时无需额外填充
// pax_global_header(1024) + header(512) + data 512 + end marker(1024) = 3072
@Test
func testWriteTarExactBlockData(): Unit {
    let a = Archive()
    var data = ArrayList<Byte>()
    for (i in 0..512) {
        data.add(UInt8(i % 256))
    }
    a.addEntry("full.txt", 0o100644, data.toArray())
    let result = writeTar(a)
    if (result.size != 3072) {
        throw Exception("tar with 512-byte data should be 3072 bytes (pax + header + data + end), got ${result.size}")
    }
}

// 对齐 Rust: pax_global_header 包含 commit SHA-1 作为 comment
@Test
func testWriteTarPaxGlobalHeader(): Unit {
    let a = Archive()
    a.commitId = "abc123"
    let result = writeTar(a)
    // pax_global_header 的 typeflag 应为 'g' (103)
    if (result[156] != UInt8(103)) {
        throw Exception("pax_global_header typeflag should be 'g'")
    }
    // pax 数据区应包含 "comment=abc123"
    var found = false
    var paxData = ArrayList<Byte>()
    for (i in 512..1024) {
        if (result[i] != UInt8(0)) {
            paxData.add(result[i])
        }
    }
    var paxStr = String.fromUtf8(paxData.toArray())
    if (paxStr.contains("comment=abc123")) {
        found = true
    }
    if (!found) {
        throw Exception("pax data should contain comment=abc123, got: ${paxStr}")
    }
}

// 对齐 Rust: tar mode 仅保留权限位（0o100644 -> 0o644）
@Test
func testWriteTarModeStripped(): Unit {
    let a = Archive()
    a.addEntry("mode.txt", 0o100644, [65])
    let result = writeTar(a)
    // 文件 header 从 offset 1024 开始，mode 字段在 offset 100-108
    let fileHeaderStart = 1024
    let modeStart = fileHeaderStart + 100
    var modeStr = StringBuilder()
    for (i in 0..8) {
        if (result[modeStart + i] != UInt8(0)) {
            modeStr.append(Rune(result[modeStart + i]))
        }
    }
    if (!modeStr.toString().contains("644")) {
        throw Exception("tar mode should contain 644 (permission bits only), got: ${modeStr.toString()}")
    }
}
