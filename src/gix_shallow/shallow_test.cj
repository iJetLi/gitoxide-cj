// 文件：shallow_test.cj
// 用途：gix_shallow 包的单元测试，全量对齐 Rust gitoxide gix-shallow 测试
// 所属包：gix.gix_shallow
// 对齐来源：gix-shallow/tests/shallow.rs

package gitoxide.gix_shallow

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*

// ============================================================
// ShallowFile 测试
// ============================================================

@Test
func testShallowFileCreation(): Unit {
    // 对齐 Rust: ShallowFile::new()
    let sf = ShallowFile()
    if (sf.commits.size != 0) {
        throw Exception("new ShallowFile should have 0 commits")
    }
}

@Test
func testShallowFileIsShallow(): Unit {
    // 对齐 Rust: ShallowFile::is_shallow
    let sf = ShallowFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    sf.commits.add(id)
    if (!sf.isShallow(id)) {
        throw Exception("should find added commit as shallow")
    }
}

@Test
func testShallowFileIsNotShallow(): Unit {
    // 对齐 Rust: ShallowFile::is_shallow — not present
    let sf = ShallowFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (sf.isShallow(id)) {
        throw Exception("should not find non-added commit")
    }
}

@Test
func testShallowFileMultipleCommits(): Unit {
    // 对齐 Rust: ShallowFile with multiple shallow commits
    let sf = ShallowFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    sf.commits.add(id1)
    sf.commits.add(id2)
    if (sf.commits.size != 2) {
        throw Exception("should have 2 commits")
    }
    if (!sf.isShallow(id1)) {
        throw Exception("id1 should be shallow")
    }
    if (!sf.isShallow(id2)) {
        throw Exception("id2 should be shallow")
    }
}

@Test
func testShallowFileOpenNonExistent(): Unit {
    // 对齐 Rust: ShallowFile::open — non-existent file
    let result = ShallowFile.open("/tmp/nonexistent-gix-shallow-test")
    if (!result.isNone()) {
        throw Exception("non-existent file should return None")
    }
}

// ============================================================
// ShallowFile 补充测试 — 对齐 gix-shallow/src/lib.rs
// ============================================================

@Test
func testShallowFileWriteAndRead(): Unit {
    // 对齐 Rust: ShallowFile write → read round-trip
    let sf = ShallowFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    sf.commits.add(id1)
    sf.commits.add(id2)
    let testPath = "C:/temp/gix_shallow_test_" + 300000.toString() + ".txt"
    sf.write(testPath)
    let readBack = ShallowFile.open(testPath)
    if (readBack.isNone()) {
        throw Exception("written shallow file should be readable")
    }
    let rb = readBack.getOrThrow()
    if (rb.commits.size != 2) {
        throw Exception("should have 2 commits after read, got " + rb.commits.size.toString())
    }
    if (!rb.isShallow(id1)) {
        throw Exception("id1 should be shallow after read")
    }
    if (!rb.isShallow(id2)) {
        throw Exception("id2 should be shallow after read")
    }
}

@Test
func testShallowFileWriteEmpty(): Unit {
    // 对齐 Rust: ShallowFile write empty
    let sf = ShallowFile()
    let testPath = "C:/temp/gix_shallow_empty_test_" + 300001.toString() + ".txt"
    sf.write(testPath)
    let readBack = ShallowFile.open(testPath)
    if (readBack.isNone()) {
        throw Exception("empty shallow file should be readable")
    }
    let rb = readBack.getOrThrow()
    if (rb.commits.size != 0) {
        throw Exception("empty shallow file should have 0 commits")
    }
}

@Test
func testShallowFileIsShallowWithDifferentIds(): Unit {
    // 对齐 Rust: ShallowFile isShallow — 不同 ID 不匹配
    let sf = ShallowFile()
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    sf.commits.add(id1)
    if (!sf.isShallow(id1)) {
        throw Exception("id1 should be shallow")
    }
    if (sf.isShallow(id2)) {
        throw Exception("id2 should not be shallow")
    }
}

@Test
func testShallowFileSingleCommitWriteRead(): Unit {
    // 对齐 Rust: ShallowFile single commit write/read
    let sf = ShallowFile()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    sf.commits.add(id)
    let testPath = "C:/temp/gix_shallow_single_test_" + 300002.toString() + ".txt"
    sf.write(testPath)
    let readBack = ShallowFile.open(testPath)
    if (readBack.isNone()) {
        throw Exception("should be readable")
    }
    let rb = readBack.getOrThrow()
    if (rb.commits.size != 1) {
        throw Exception("should have 1 commit")
    }
    if (rb.commits[0].toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("commit hex mismatch")
    }
}
