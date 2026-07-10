// 文件：refspec_test.cj
// 用途：gix_refspec 包的单元测试，全量对齐 Rust gitoxide gix-refspec 测试
// 所属包：gix.gix_refspec
// 对齐来源：gix-refspec/tests/parse.rs

package gitoxide.gix_refspec

import std.unittest.*

// ============================================================
// RefSpec.parse 测试 — 对齐 gix-refspec/tests/parse.rs
// ============================================================

@Test
func testRefSpecParseFetchWithSrcDst(): Unit {
    // 对齐 Rust: parse fetch refspec with src:dst
    let rs = RefSpec.parse("refs/heads/*:refs/remotes/origin/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/heads/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/remotes/origin/*")) {
        throw Exception("dst mismatch")
    }
    if (spec.force) {
        throw Exception("should not be force")
    }
}

@Test
func testRefSpecParseForcePrefix(): Unit {
    // 对齐 Rust: parse refspec with + force prefix
    let rs = RefSpec.parse("+refs/heads/*:refs/remotes/origin/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
}

@Test
func testRefSpecParseSrcOnly(): Unit {
    // 对齐 Rust: parse refspec with src only (no colon)
    let rs = RefSpec.parse("refs/heads/main")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/heads/main")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != None) {
        throw Exception("dst should be None")
    }
}

@Test
func testRefSpecParseForceSrcOnly(): Unit {
    // 对齐 Rust: parse +src refspec
    let rs = RefSpec.parse("+HEAD")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.src != Some("HEAD")) {
        throw Exception("src should be HEAD")
    }
}

@Test
func testRefSpecParseEmptyString(): Unit {
    // 对齐 Rust: parse empty string returns None
    let rs = RefSpec.parse("")
    if (!rs.isNone()) {
        throw Exception("empty string should return None")
    }
}

@Test
func testRefSpecParseWildcardSrc(): Unit {
    // 对齐 Rust: parse refspec with wildcard in src
    let rs = RefSpec.parse("refs/tags/*:refs/tags/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/tags/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/tags/*")) {
        throw Exception("dst mismatch")
    }
}

@Test
func testRefSpecDirectionDefault(): Unit {
    // 对齐 Rust: parse — default direction is Fetch
    let rs = RefSpec.parse("refs/heads/main:refs/remotes/origin/main")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    if (rs.getOrThrow().direction != RefSpecDirection.Fetch) {
        throw Exception("default direction should be Fetch")
    }
}

// ============================================================
// RefSpec 构造测试
// ============================================================

@Test
func testRefSpecConstruction(): Unit {
    // 对齐 Rust: RefSpec construction
    let spec = RefSpec(Some("refs/heads/main"), Some("refs/remotes/origin/main"), false, RefSpecDirection.Fetch)
    if (spec.src != Some("refs/heads/main")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/remotes/origin/main")) {
        throw Exception("dst mismatch")
    }
    if (spec.force) {
        throw Exception("should not be force")
    }
    if (spec.direction != RefSpecDirection.Fetch) {
        throw Exception("direction mismatch")
    }
}

@Test
func testRefSpecConstructionPush(): Unit {
    // 对齐 Rust: RefSpec push direction
    let spec = RefSpec(Some("refs/heads/main"), None, true, RefSpecDirection.Push)
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.direction != RefSpecDirection.Push) {
        throw Exception("direction should be Push")
    }
}

// ============================================================
// RefSpec.parse 补充测试 — 对齐 gix-refspec/tests/refspec/parse/*.rs
// ============================================================

@Test
func testRefSpecParseColonOnly(): Unit {
    // 对齐 Rust: colon_alone — ":" is valid (fetch HEAD into FETCH_HEAD)
    let rs = RefSpec.parse(":")
    if (rs.isNone()) {
        throw Exception("':' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("")) {
        throw Exception("src should be empty")
    }
    if (spec.dst != Some("")) {
        throw Exception("dst should be empty")
    }
}

@Test
func testRefSpecParseDstOnly(): Unit {
    // 对齐 Rust: empty lhs colon rhs — ":a" means HEAD→a
    let rs = RefSpec.parse(":refs/heads/main")
    if (rs.isNone()) {
        throw Exception("':refs/heads/main' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("")) {
        throw Exception("src should be empty")
    }
    if (spec.dst != Some("refs/heads/main")) {
        throw Exception("dst mismatch")
    }
}

@Test
func testRefSpecParseSrcOnlyWithColon(): Unit {
    // 对齐 Rust: lhs colon empty — "src:" fetches only
    let rs = RefSpec.parse("refs/heads/main:")
    if (rs.isNone()) {
        throw Exception("'refs/heads/main:' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/heads/main")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("")) {
        throw Exception("dst should be empty")
    }
}

@Test
func testRefSpecParseForceColonOnly(): Unit {
    // 对齐 Rust: "+:" force fetch HEAD
    let rs = RefSpec.parse("+:")
    if (rs.isNone()) {
        throw Exception("'+:' should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
}

@Test
func testRefSpecParseForceDstOnly(): Unit {
    // 对齐 Rust: "+:a" force fetch HEAD→a
    let rs = RefSpec.parse("+:refs/heads/main")
    if (rs.isNone()) {
        throw Exception("'+:refs/heads/main' should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.src != Some("")) {
        throw Exception("src should be empty")
    }
}

@Test
func testRefSpecParseForceSrcDst(): Unit {
    // 对齐 Rust: "+a:b" force fetch a→b
    let rs = RefSpec.parse("+refs/heads/*:refs/remotes/origin/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.src != Some("refs/heads/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/remotes/origin/*")) {
        throw Exception("dst mismatch")
    }
}

@Test
func testRefSpecParseComplexGlobOneSided(): Unit {
    // 对齐 Rust: complex glob patterns are allowed in one-sided refspecs
    let rs = RefSpec.parse("refs/*/foo/*")
    if (rs.isNone()) {
        throw Exception("'refs/*/foo/*' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/*/foo/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != None) {
        throw Exception("dst should be None")
    }
}

@Test
func testRefSpecParseAtSign(): Unit {
    // 对齐 Rust: @ resolves to HEAD
    let rs = RefSpec.parse("@")
    if (rs.isNone()) {
        throw Exception("'@' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("@")) {
        throw Exception("src should be '@'")
    }
}

@Test
func testRefSpecParseForceAtSign(): Unit {
    // 对齐 Rust: +@ force HEAD
    let rs = RefSpec.parse("+@")
    if (rs.isNone()) {
        throw Exception("'+@' should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.src != Some("@")) {
        throw Exception("src should be '@'")
    }
}

@Test
func testRefSpecParseObjectHashAsSrc(): Unit {
    // 对齐 Rust: object hash as source
    let rs = RefSpec.parse("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (rs.isNone()) {
        throw Exception("object hash should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("src should be the hash")
    }
}

@Test
func testRefSpecParseObjectHashWithDst(): Unit {
    // 对齐 Rust: object_hash_as_source with dst
    let rs = RefSpec.parse("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391:refs/heads/main")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("src should be hash")
    }
    if (spec.dst != Some("refs/heads/main")) {
        throw Exception("dst mismatch")
    }
}

@Test
func testRefSpecParseAtWithDst(): Unit {
    // 对齐 Rust: @:HEAD — HEAD to HEAD
    let rs = RefSpec.parse("@:HEAD")
    if (rs.isNone()) {
        throw Exception("'@:HEAD' should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("@")) {
        throw Exception("src should be '@'")
    }
    if (spec.dst != Some("HEAD")) {
        throw Exception("dst should be 'HEAD'")
    }
}

@Test
func testRefSpecParseWildcardInBothSides(): Unit {
    // 对齐 Rust: a/*:b/* — wildcard in both sides
    let rs = RefSpec.parse("refs/heads/*:refs/remotes/origin/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (spec.src != Some("refs/heads/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/remotes/origin/*")) {
        throw Exception("dst mismatch")
    }
}

@Test
func testRefSpecParseForceWildcardBothSides(): Unit {
    // 对齐 Rust: +a/*:b/* — force wildcard both sides
    let rs = RefSpec.parse("+refs/tags/*:refs/tags/*")
    if (rs.isNone()) {
        throw Exception("should parse")
    }
    let spec = rs.getOrThrow()
    if (!spec.force) {
        throw Exception("should be force")
    }
    if (spec.src != Some("refs/tags/*")) {
        throw Exception("src mismatch")
    }
    if (spec.dst != Some("refs/tags/*")) {
        throw Exception("dst mismatch")
    }
}
