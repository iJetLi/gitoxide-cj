// 文件：fetchhead_test.cj
// 用途：gix_fetchhead 包的单元测试，全量对齐 Rust gitoxide gix-fetchhead 测试
// 所属包：gix.gix_fetchhead
// 对齐来源：gix-fetchhead/tests/parse.rs

package gitoxide.gix_fetchhead

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*

// ============================================================
// parseFetchHead 测试 — 对齐 gix-fetchhead/tests/parse.rs
// ============================================================

@Test
func testParseFetchHeadSingleEntry(): Unit {
    // 对齐 Rust: parse single FETCH_HEAD entry
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\t\trefs/heads/main of https://github.com/example/repo"
    let result = parseFetchHead(data)
    if (result.size != 1) {
        throw Exception("should have 1 entry, got " + result.size.toString())
    }
    if (result[0].id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id mismatch")
    }
}

@Test
func testParseFetchHeadEmptyInput(): Unit {
    // 对齐 Rust: parse empty FETCH_HEAD
    let result = parseFetchHead("")
    if (result.size != 0) {
        throw Exception("empty input should have 0 entries")
    }
}

@Test
func testParseFetchHeadMultipleEntries(): Unit {
    // 对齐 Rust: parse multiple FETCH_HEAD entries
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\t\trefs/heads/main of https://github.com/a\n4b825dc642cb6eb9a060e54bf8d69288fbee4904\t\trefs/heads/dev of https://github.com/b"
    let result = parseFetchHead(data)
    if (result.size != 2) {
        throw Exception("should have 2 entries, got " + result.size.toString())
    }
}

// ============================================================
// FetchHeadEntry 构造测试
// ============================================================

@Test
func testFetchHeadEntryConstruction(): Unit {
    // 对齐 Rust: FetchHeadEntry construction
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = FetchHeadEntry(id, true, Some("refs/heads/main"), Some("https://github.com/example/repo"))
    if (entry.isMerge != true) {
        throw Exception("isMerge should be true")
    }
    if (entry.refName != Some("refs/heads/main")) {
        throw Exception("refName mismatch")
    }
    if (entry.remoteUrl != Some("https://github.com/example/repo")) {
        throw Exception("remoteUrl mismatch")
    }
}

// ============================================================
// parseFetchHead 补充测试 — 对齐 gix-fetchhead/src/lib.rs
// ============================================================

@Test
func testParseFetchHeadNotForMerge(): Unit {
    // 对齐 Rust: parse FETCH_HEAD with not-for-merge marker
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\tnot-for-merge\trefs/heads/main of https://github.com/example/repo"
    let result = parseFetchHead(data)
    if (result.size != 1) {
        throw Exception("should have 1 entry, got " + result.size.toString())
    }
    if (result[0].isMerge) {
        throw Exception("not-for-merge entry should have isMerge=false")
    }
}

@Test
func testParseFetchHeadMixedMergeAndNotForMerge(): Unit {
    // 对齐 Rust: parse FETCH_HEAD with mixed merge/not-for-merge
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\t\trefs/heads/main of https://github.com/a\n4b825dc642cb6eb9a060e54bf8d69288fbee4904\tnot-for-merge\trefs/heads/dev of https://github.com/b"
    let result = parseFetchHead(data)
    if (result.size != 2) {
        throw Exception("should have 2 entries, got " + result.size.toString())
    }
    if (!result[0].isMerge) {
        throw Exception("first entry should be for merge")
    }
    if (result[1].isMerge) {
        throw Exception("second entry should not be for merge")
    }
}

@Test
func testParseFetchHeadOnlyWhitespaceLines(): Unit {
    // 对齐 Rust: parse FETCH_HEAD with only whitespace
    let result = parseFetchHead("   \n\t\n  \n")
    if (result.size != 0) {
        throw Exception("whitespace-only input should have 0 entries")
    }
}

@Test
func testParseFetchHeadTrailingNewline(): Unit {
    // 对齐 Rust: parse FETCH_HEAD with trailing newline
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\t\trefs/heads/main of https://github.com/example/repo\n"
    let result = parseFetchHead(data)
    if (result.size != 1) {
        throw Exception("should have 1 entry with trailing newline")
    }
}

@Test
func testParseFetchHeadMultipleTrailingNewlines(): Unit {
    // 对齐 Rust: parse FETCH_HEAD with multiple trailing newlines
    let data = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\t\trefs/heads/main\n\n\n"
    let result = parseFetchHead(data)
    if (result.size != 1) {
        throw Exception("should have 1 entry despite trailing newlines")
    }
}

@Test
func testFetchHeadEntryNotForMergeConstruction(): Unit {
    // 对齐 Rust: FetchHeadEntry not-for-merge construction
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = FetchHeadEntry(id, false, Some("refs/heads/dev"), Some("https://github.com/b"))
    if (entry.isMerge) {
        throw Exception("isMerge should be false")
    }
    if (entry.refName != Some("refs/heads/dev")) {
        throw Exception("refName mismatch")
    }
    if (entry.remoteUrl != Some("https://github.com/b")) {
        throw Exception("remoteUrl mismatch")
    }
}

@Test
func testFetchHeadEntryNoRefName(): Unit {
    // 对齐 Rust: FetchHeadEntry without refName
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = FetchHeadEntry(id, true, None, None)
    if (entry.refName.isSome()) {
        throw Exception("refName should be None")
    }
    if (entry.remoteUrl.isSome()) {
        throw Exception("remoteUrl should be None")
    }
}
