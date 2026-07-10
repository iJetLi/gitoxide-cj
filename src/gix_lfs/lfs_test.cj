// 文件：lfs_test.cj
// 用途：gix_lfs 包的单元测试，对齐 Rust gitoxide gix-lfs 测试
// 所属包：gix.gix_lfs
// 对齐来源：gix-lfs/tests/pointer.rs

package gitoxide.gix_lfs

import std.unittest.*

// ============================================================
// LfsPointer 解析测试 — 对齐 gix-lfs/tests/pointer.rs
// ============================================================

@Test
func testLfsPointerParseValid(): Unit {
    // 对齐 Rust: LfsPointer::parse — 标准格式
    let content = "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500\nsize 12345\n"
    let result = LfsPointer.parse(content)
    if (result.isNone()) {
        throw Exception("valid LFS pointer should parse")
    }
    let p = result.getOrThrow()
    if (p.oid != "4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500") {
        throw Exception("oid mismatch: " + p.oid)
    }
    if (p.size != 12345) {
        throw Exception("size mismatch: " + p.size.toString())
    }
}

@Test
func testLfsPointerParseMissingOid(): Unit {
    // 对齐 Rust: LfsPointer::parse — 缺少 oid 行
    let content = "version https://git-lfs.github.com/spec/v1\nsize 12345\n"
    let result = LfsPointer.parse(content)
    if (!result.isNone()) {
        throw Exception("missing oid should return None")
    }
}

@Test
func testLfsPointerParseMissingSize(): Unit {
    // 对齐 Rust: LfsPointer::parse — 缺少 size 行
    let content = "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500\n"
    let result = LfsPointer.parse(content)
    // 仓颉当前实现：有 oid 即返回，size 默认为 0
    if (result.isNone()) {
        throw Exception("pointer with oid should parse (size defaults to 0)")
    }
    let p = result.getOrThrow()
    if (p.size != 0) {
        throw Exception("missing size should default to 0, got " + p.size.toString())
    }
}

@Test
func testLfsPointerParseEmptyContent(): Unit {
    // 对齐 Rust: LfsPointer::parse — 空内容
    let result = LfsPointer.parse("")
    if (!result.isNone()) {
        throw Exception("empty content should return None")
    }
}

@Test
func testLfsPointerParseWrongOidAlgorithm(): Unit {
    // 对齐 Rust: LfsPointer::parse — 非 sha256 的 oid 行
    let content = "version https://git-lfs.github.com/spec/v1\noid sha1:abc123\nsize 100\n"
    let result = LfsPointer.parse(content)
    // 仓颉实现检查 "oid sha256:" 前缀，"oid sha1:" 不匹配
    if (!result.isNone()) {
        throw Exception("non-sha256 oid should return None")
    }
}

@Test
func testLfsPointerParseWithExtraLines(): Unit {
    // 对齐 Rust: LfsPointer::parse — 包含额外行
    let content = "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500\nsize 12345\nx-foo: bar\n"
    let result = LfsPointer.parse(content)
    if (result.isNone()) {
        throw Exception("extra lines should not prevent parsing")
    }
}

// ============================================================
// LfsPointer 序列化测试 — 对齐 gix-lfs/src/pointer.rs
// ============================================================

@Test
func testLfsPointerToString(): Unit {
    // 对齐 Rust: LfsPointer::to_string — 标准格式序列化
    let p = LfsPointer("4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500", 12345)
    let s = p.toString()
    if (!s.startsWith("version https://git-lfs.github.com/spec/v1\n")) {
        throw Exception("serialized should start with version line")
    }
    if (!s.contains("oid sha256:4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500\n")) {
        throw Exception("serialized should contain oid line")
    }
    if (!s.contains("size 12345\n")) {
        throw Exception("serialized should contain size line")
    }
}

@Test
func testLfsPointerRoundTrip(): Unit {
    // 对齐 Rust: LfsPointer parse → toString → parse 往返
    let original = "version https://git-lfs.github.com/spec/v1\noid sha256:4d7a214614ab293c7d648a7b7c87c376bd2a0e1fbc96b06f6e6cfa3b55bf0500\nsize 12345\n"
    let parsed = LfsPointer.parse(original)
    if (parsed.isNone()) {
        throw Exception("should parse")
    }
    let p = parsed.getOrThrow()
    let serialized = p.toString()
    let reparsed = LfsPointer.parse(serialized)
    if (reparsed.isNone()) {
        throw Exception("round-trip should parse")
    }
    let p2 = reparsed.getOrThrow()
    if (p.oid != p2.oid) {
        throw Exception("round-trip oid mismatch")
    }
    if (p.size != p2.size) {
        throw Exception("round-trip size mismatch")
    }
}

@Test
func testLfsPointerZeroSize(): Unit {
    // 对齐 Rust: LfsPointer — 零大小文件
    let p = LfsPointer("e3b0c44298fc1c149afbf4c8996fb92427ae41e4649b934ca495991b7852b855", 0)
    let s = p.toString()
    if (!s.contains("size 0\n")) {
        throw Exception("zero size should serialize correctly")
    }
}

@Test
func testLfsPointerLargeSize(): Unit {
    // 对齐 Rust: LfsPointer — 大文件大小
    let p = LfsPointer("abc123", 1073741824)
    if (p.size != 1073741824) {
        throw Exception("large size mismatch")
    }
    let s = p.toString()
    if (!s.contains("size 1073741824\n")) {
        throw Exception("large size should serialize correctly")
    }
}

// ============================================================
// LfsPointer 构造测试 — 对齐 gix-lfs/src/pointer.rs
// ============================================================

@Test
func testLfsPointerConstruction(): Unit {
    // 对齐 Rust: LfsPointer 构造
    let p = LfsPointer("testoid", 42)
    if (p.oid != "testoid") {
        throw Exception("oid should be 'testoid'")
    }
    if (p.size != 42) {
        throw Exception("size should be 42")
    }
}
