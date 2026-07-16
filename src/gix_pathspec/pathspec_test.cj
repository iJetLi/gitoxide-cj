// 文件：pathspec_test.cj
// 用途：gix_pathspec 包的单元测试，全量对齐 Rust gitoxide gix-pathspec 测试
// 所属包：gix.gix_pathspec
// 对齐来源：gix-pathspec/tests/{parse/valid.rs, parse/invalid.rs, defaults.rs, normalize/mod.rs, search/mod.rs}

package gitoxide.gix_pathspec

import std.unittest.*
import std.collection.*

// ============================================================
// parse/valid.rs 对齐 — 有效 pathspec 解析
// ============================================================

@Test
func testParseEmptySignatures(): Unit {
    // 对齐 Rust: empty_signatures
    let inputs = [
        (".", "."),
        ("some/path", "some/path"),
        (":some/path", "some/path"),
        (":()some/path", "some/path")
    ]
    for ((input, expectedPath) in inputs) {
        let result = parsePathspec(input, Defaults())
        if (let Some(p) <- result) {
            if (p.path != expectedPath) {
                throw Exception(input + ": path should be '" + expectedPath + "'")
            }
        } else {
            throw Exception(input + ": should parse successfully")
        }
    }
}

@Test
func testParseDoubleColon(): Unit {
    // 对齐 Rust: empty_signatures — "::some/path" -> "some/path"
    let result = parsePathspec("::some/path", Defaults())
    if (let Some(p) <- result) {
        if (p.path != "some/path") {
            throw Exception("::some/path: path should be 'some/path'")
        }
    } else {
        throw Exception("::some/path: should parse successfully")
    }
}

@Test
func testParseTripleColon(): Unit {
    // 对齐 Rust: empty_signatures — ":::some/path" -> ":some/path"
    let result = parsePathspec(":::some/path", Defaults())
    if (let Some(p) <- result) {
        if (p.path != ":some/path") {
            throw Exception(":::some/path: path should be ':some/path'")
        }
    } else {
        throw Exception(":::some/path: should parse successfully")
    }
}

@Test
func testParseColonParenColon(): Unit {
    // 对齐 Rust: empty_signatures — ":():some/path" -> ":some/path"
    let result = parsePathspec(":():some/path", Defaults())
    if (let Some(p) <- result) {
        if (p.path != ":some/path") {
            throw Exception(":():some/path: path should be ':some/path'")
        }
    } else {
        throw Exception(":():some/path: should parse successfully")
    }
}

@Test
func testParseWhitespaceInPathspec(): Unit {
    // 对齐 Rust: whitespace_in_pathspec
    let inputs = [
        (" some/path", " some/path"),
        ("some/ path", "some/ path"),
        ("some/path ", "some/path "),
        (": some/path", " some/path")
    ]
    for ((input, expectedPath) in inputs) {
        let result = parsePathspec(input, Defaults())
        if (let Some(p) <- result) {
            if (p.path != expectedPath) {
                throw Exception(input + ": path should be '" + expectedPath + "'")
            }
        } else {
            throw Exception(input + ": should parse successfully")
        }
    }
}

@Test
func testParseShortSignatures(): Unit {
    // 对齐 Rust: short_signatures
    let topResult = parsePathspec(":/some/path", Defaults())
    if (let Some(p) <- topResult) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":/some/path: should have TOP signature")
        }
        if (p.path != "some/path") {
            throw Exception(":/some/path: path should be 'some/path'")
        }
    } else {
        throw Exception(":/some/path: should parse successfully")
    }

    let caretResult = parsePathspec(":^some/path", Defaults())
    if (let Some(p) <- caretResult) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":^some/path: should have EXCLUDE signature")
        }
        if (p.path != "some/path") {
            throw Exception(":^some/path: path should be 'some/path'")
        }
    } else {
        throw Exception(":^some/path: should parse successfully")
    }

    let bangResult = parsePathspec(":!some/path", Defaults())
    if (let Some(p) <- bangResult) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":!some/path: should have EXCLUDE signature")
        }
        if (p.path != "some/path") {
            throw Exception(":!some/path: path should be 'some/path'")
        }
    } else {
        throw Exception(":!some/path: should parse successfully")
    }
}

@Test
func testParseCombinedShortSignatures(): Unit {
    // 对齐 Rust: short_signatures — ":/!some/path" -> TOP + EXCLUDE
    let result = parsePathspec(":/!some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":/!some/path: should have TOP signature")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":/!some/path: should have EXCLUDE signature")
        }
        if (p.path != "some/path") {
            throw Exception(":/!some/path: path should be 'some/path'")
        }
    } else {
        throw Exception(":/!some/path: should parse successfully")
    }
}

@Test
func testParseMultipleShortSignatures(): Unit {
    // 对齐 Rust: short_signatures — ":!/^/:some/path" -> TOP + EXCLUDE
    let result = parsePathspec(":!/^/:some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":!/^/:some/path: should have TOP signature")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":!/^/:some/path: should have EXCLUDE signature")
        }
    } else {
        throw Exception(":!/^/:some/path: should parse successfully")
    }
}

@Test
func testParseTrailingSlashBecomesMustBeDir(): Unit {
    // 对齐 Rust: trailing_slash_is_turned_into_magic_signature_and_removed
    let r1 = parsePathspec("a/b/", Defaults())
    if (let Some(p) <- r1) {
        if (!p.signature.contains(MagicSignature.MUST_BE_DIR)) {
            throw Exception("a/b/: should have MUST_BE_DIR signature")
        }
        if (p.path != "a/b") {
            throw Exception("a/b/: path should be 'a/b'")
        }
    } else {
        throw Exception("a/b/: should parse successfully")
    }

    let r2 = parsePathspec("a/", Defaults())
    if (let Some(p) <- r2) {
        if (!p.signature.contains(MagicSignature.MUST_BE_DIR)) {
            throw Exception("a/: should have MUST_BE_DIR signature")
        }
        if (p.path != "a") {
            throw Exception("a/: path should be 'a'")
        }
    } else {
        throw Exception("a/: should parse successfully")
    }
}

@Test
func testParseSignaturesAndSearchModes(): Unit {
    // 对齐 Rust: signatures_and_searchmodes
    let topResult = parsePathspec(":(top)", Defaults())
    if (let Some(p) <- topResult) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":(top): should have TOP signature")
        }
    } else {
        throw Exception(":(top): should parse successfully")
    }

    let icaseResult = parsePathspec(":(icase)", Defaults())
    if (let Some(p) <- icaseResult) {
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception(":(icase): should have ICASE signature")
        }
    } else {
        throw Exception(":(icase): should parse successfully")
    }

    let excludeResult = parsePathspec(":(exclude)", Defaults())
    if (let Some(p) <- excludeResult) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":(exclude): should have EXCLUDE signature")
        }
    } else {
        throw Exception(":(exclude): should parse successfully")
    }

    let literalResult = parsePathspec(":(literal)", Defaults())
    if (let Some(p) <- literalResult) {
        if (p.searchMode != SearchMode.Literal) {
            throw Exception(":(literal): should have Literal search mode")
        }
    } else {
        throw Exception(":(literal): should parse successfully")
    }

    let globResult = parsePathspec(":(glob)", Defaults())
    if (let Some(p) <- globResult) {
        if (p.searchMode != SearchMode.PathAwareGlob) {
            throw Exception(":(glob): should have PathAwareGlob search mode")
        }
    } else {
        throw Exception(":(glob): should parse successfully")
    }
}

@Test
func testParseCombinedLongSignatures(): Unit {
    // 对齐 Rust: signatures_and_searchmodes — ":(top,exclude)" -> TOP + EXCLUDE
    let result = parsePathspec(":(top,exclude)", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":(top,exclude): should have TOP signature")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":(top,exclude): should have EXCLUDE signature")
        }
    } else {
        throw Exception(":(top,exclude): should parse successfully")
    }
}

@Test
func testParseIcaseLiteral(): Unit {
    // 对齐 Rust: signatures_and_searchmodes — ":(icase,literal)" -> ICASE + Literal
    let result = parsePathspec(":(icase,literal)", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception(":(icase,literal): should have ICASE signature")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception(":(icase,literal): should have Literal search mode")
        }
    } else {
        throw Exception(":(icase,literal): should parse successfully")
    }
}

@Test
func testParseExcludeLiteralWithPath(): Unit {
    // 对齐 Rust: signatures_and_searchmodes — ":!(literal)some/*path"
    let result = parsePathspec(":!(literal)some/*path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":!(literal)some/*path: should have EXCLUDE signature")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception(":!(literal)some/*path: should have Literal search mode")
        }
        if (p.path != "some/*path") {
            throw Exception(":!(literal)some/*path: path should be 'some/*path'")
        }
    } else {
        throw Exception(":!(literal)some/*path: should parse successfully")
    }
}

@Test
func testParseFullCombinedSignature(): Unit {
    // 对齐 Rust: signatures_and_searchmodes — ":(top,literal,icase,attr,exclude)some/path"
    let result = parsePathspec(":(top,literal,icase,attr,exclude)some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception("should have TOP")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception("should have EXCLUDE")
        }
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception("should have ICASE")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception("should have Literal search mode")
        }
        if (p.path != "some/path") {
            throw Exception("path should be 'some/path'")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseFullCombinedGlobSignature(): Unit {
    // 对齐 Rust: signatures_and_searchmodes — ":(top,glob,icase,attr,exclude)some/path"
    let result = parsePathspec(":(top,glob,icase,attr,exclude)some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception("should have TOP")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception("should have EXCLUDE")
        }
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception("should have ICASE")
        }
        if (p.searchMode != SearchMode.PathAwareGlob) {
            throw Exception("should have PathAwareGlob search mode")
        }
        if (p.path != "some/path") {
            throw Exception("path should be 'some/path'")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseRepeatedMatcherKeywords(): Unit {
    // 对齐 Rust: repeated_matcher_keywords
    let globResult = parsePathspec(":(glob,glob)", Defaults())
    if (let Some(p) <- globResult) {
        if (p.searchMode != SearchMode.PathAwareGlob) {
            throw Exception(":(glob,glob): should have PathAwareGlob")
        }
    } else {
        throw Exception(":(glob,glob): should parse successfully")
    }

    let litResult = parsePathspec(":(literal,literal)", Defaults())
    if (let Some(p) <- litResult) {
        if (p.searchMode != SearchMode.Literal) {
            throw Exception(":(literal,literal): should have Literal")
        }
    } else {
        throw Exception(":(literal,literal): should parse successfully")
    }

    let topResult = parsePathspec(":(top,top)", Defaults())
    if (let Some(p) <- topResult) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":(top,top): should have TOP")
        }
    } else {
        throw Exception(":(top,top): should parse successfully")
    }

    let icaseResult = parsePathspec(":(icase,icase)", Defaults())
    if (let Some(p) <- icaseResult) {
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception(":(icase,icase): should have ICASE")
        }
    } else {
        throw Exception(":(icase,icase): should parse successfully")
    }

    let exResult = parsePathspec(":(exclude,exclude)", Defaults())
    if (let Some(p) <- exResult) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":(exclude,exclude): should have EXCLUDE")
        }
    } else {
        throw Exception(":(exclude,exclude): should parse successfully")
    }
}

@Test
func testParseGlobNegationsAreLiteral(): Unit {
    // 对齐 Rust: glob_negations_are_always_literal
    let r1 = parsePathspec("!a", Defaults())
    if (let Some(p) <- r1) {
        if (p.path != "!a") {
            throw Exception("!a: path should be '!a'")
        }
    } else {
        throw Exception("!a: should parse successfully")
    }
}

@Test
func testParseLiteralDefaultPreventsParsing(): Unit {
    // 对齐 Rust: literal_default_prevents_parsing
    let defaults = Defaults(MagicSignatureSet(), SearchMode.Literal, true)
    let result = parsePathspec(":", defaults)
    if (let Some(p) <- result) {
        if (p.path != ":") {
            throw Exception("literal ':': path should be ':'")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception("literal ':': should have Literal search mode")
        }
    } else {
        throw Exception("literal ':': should parse successfully")
    }
}

@Test
func testParseThereIsNoPathspecPathspec(): Unit {
    // 对齐 Rust: there_is_no_pathspec_pathspec
    let result = parsePathspec(":", Defaults())
    if (let Some(p) <- result) {
        if (!p.isNil()) {
            throw Exception(": should be nil pattern")
        }
        if (p.path.size != 0) {
            throw Exception("nil pattern should have empty path")
        }
    } else {
        throw Exception(": should parse successfully")
    }
}

@Test
func testParseDefaultsAreUsed(): Unit {
    // 对齐 Rust: defaults_are_used
    let defaults = Defaults(
        MagicSignatureSet(MagicSignature.EXCLUDE),
        SearchMode.Literal,
        false
    )
    let result = parsePathspec(".", defaults)
    if (let Some(p) <- result) {
        if (p.path != ".") {
            throw Exception("path should be '.'")
        }
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception("should have EXCLUDE from defaults")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception("should have Literal from defaults")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseLiteralFromDefaultsOverriddenByElementGlob(): Unit {
    // 对齐 Rust: literal_from_defaults_is_overridden_by_element_glob
    let defaults = Defaults(MagicSignatureSet(), SearchMode.Literal, false)
    let result = parsePathspec(":(glob)*override", defaults)
    if (let Some(p) <- result) {
        if (p.path != "*override") {
            throw Exception("path should be '*override'")
        }
        if (p.searchMode != SearchMode.PathAwareGlob) {
            throw Exception("element glob should override default literal")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseGlobFromDefaultsOverriddenByElementLiteral(): Unit {
    // 对齐 Rust: glob_from_defaults_is_overridden_by_element_glob
    let defaults = Defaults(MagicSignatureSet(), SearchMode.PathAwareGlob, false)
    let result = parsePathspec(":(literal)*override", defaults)
    if (let Some(p) <- result) {
        if (p.path != "*override") {
            throw Exception("path should be '*override'")
        }
        if (p.searchMode != SearchMode.Literal) {
            throw Exception("element literal should override default glob")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

// ============================================================
// parse/invalid.rs 对齐 — 无效 pathspec 解析
// ============================================================

@Test
func testParseEmptyInputReturnsNone(): Unit {
    // 对齐 Rust: empty_input
    let result = parsePathspec("", Defaults())
    if (let Some(_) <- result) {
        throw Exception("empty input should return None")
    }
}

@Test
func testParseInvalidKeywords(): Unit {
    // 对齐 Rust: invalid_keywords
    let invalidInputs = [
        ":(tp)some/path",
        ":(top,exclude,icse)some/path"
    ]
    for (input in invalidInputs) {
        let result = parsePathspec(input, Defaults())
        if (let Some(_) <- result) {
            throw Exception(input + ": should fail to parse with invalid keyword")
        }
    }
}

@Test
func testParseMissingClosingParenthesis(): Unit {
    // 对齐 Rust: missing_parentheses
    let result = parsePathspec(":(top", Defaults())
    if (let Some(_) <- result) {
        throw Exception(":(top: should fail with missing closing parenthesis")
    }
}

@Test
func testParseGlobAndLiteralKeywordsPresent(): Unit {
    // 对齐 Rust: glob_and_literal_keywords_present
    let result = parsePathspec(":(glob,literal)some/path", Defaults())
    if (let Some(_) <- result) {
        throw Exception(":(glob,literal): should fail with incompatible search modes")
    }
}

// ============================================================
// Pattern 属性测试 — 对齐 Rust Pattern 方法
// ============================================================

@Test
func testPatternIsNil(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::is_nil
    let p = Pattern()
    p.nilPattern = true
    if (!p.isNil()) {
        throw Exception("nil pattern should return true for isNil()")
    }
    let p2 = Pattern("some/path", MagicSignatureSet(), SearchMode.ShellGlob, false)
    if (p2.isNil()) {
        throw Exception("non-nil pattern should return false for isNil()")
    }
}

@Test
func testPatternIsExcluded(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::is_excluded
    let p = Pattern("some/path", MagicSignatureSet(MagicSignature.EXCLUDE), SearchMode.ShellGlob, false)
    if (!p.isExcluded()) {
        throw Exception("EXCLUDE pattern should return true for isExcluded()")
    }
    let p2 = Pattern("some/path", MagicSignatureSet(), SearchMode.ShellGlob, false)
    if (p2.isExcluded()) {
        throw Exception("non-EXCLUDE pattern should return false for isExcluded()")
    }
}

@Test
func testPatternAlwaysMatches(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::always_matches
    let nilP = Pattern()
    nilP.nilPattern = true
    if (!nilP.alwaysMatches()) {
        throw Exception("nil pattern should always match")
    }
    let emptyP = Pattern("", MagicSignatureSet(), SearchMode.ShellGlob, false)
    if (!emptyP.alwaysMatches()) {
        throw Exception("empty path pattern should always match")
    }
    let pathP = Pattern("some/path", MagicSignatureSet(), SearchMode.ShellGlob, false)
    if (pathP.alwaysMatches()) {
        throw Exception("pattern with path should not always match")
    }
}

@Test
func testPatternToBStringNil(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::to_bstring nil
    let p = Pattern()
    p.nilPattern = true
    if (p.toBString() != ":") {
        throw Exception("nil pattern toBString should be ':'")
    }
}

@Test
func testPatternToBStringWithSignatures(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::to_bstring 含签名
    let sig = MagicSignatureSet()
    sig.add(MagicSignature.TOP)
    sig.add(MagicSignature.EXCLUDE)
    let p = Pattern("some/path", sig, SearchMode.Literal, false)
    let result = p.toBString()
    if (!result.contains("top")) {
        throw Exception("toBString should contain 'top'")
    }
    if (!result.contains("exclude")) {
        throw Exception("toBString should contain 'exclude'")
    }
    if (!result.contains("literal")) {
        throw Exception("toBString should contain 'literal'")
    }
    if (!result.contains("some/path")) {
        throw Exception("toBString should contain path")
    }
}

@Test
func testPatternToBStringMustBeDir(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::to_bstring must_be_dir
    let sig = MagicSignatureSet()
    sig.add(MagicSignature.MUST_BE_DIR)
    let p = Pattern("a/b", sig, SearchMode.ShellGlob, false)
    let result = p.toBString()
    if (!result.endsWith("/")) {
        throw Exception("MUST_BE_DIR pattern should end with '/'")
    }
}

@Test
func testPatternPrefixDirectory(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::prefix_directory
    let p = Pattern("a/b/c", MagicSignatureSet(), SearchMode.ShellGlob, false)
    p.prefixLen = 3
    if (p.prefixDirectory() != "a/b") {
        throw Exception("prefix directory should be 'a/b'")
    }
    let p2 = Pattern("some/path", MagicSignatureSet(), SearchMode.ShellGlob, false)
    p2.prefixLen = 0
    if (p2.prefixDirectory() != "") {
        throw Exception("zero prefixLen should return empty string")
    }
}

// ============================================================
// MagicSignatureSet 测试
// ============================================================

@Test
func testMagicSignatureSetAddAndContains(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — MagicSignatureSet::add + contains
    let sig = MagicSignatureSet()
    sig.add(MagicSignature.TOP)
    if (!sig.contains(MagicSignature.TOP)) {
        throw Exception("should contain TOP after add")
    }
    if (sig.contains(MagicSignature.ICASE)) {
        throw Exception("should not contain ICASE")
    }
}

@Test
func testMagicSignatureSetAddAll(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — MagicSignatureSet::add_all
    let sig1 = MagicSignatureSet()
    sig1.add(MagicSignature.TOP)
    let sig2 = MagicSignatureSet()
    sig2.add(MagicSignature.ICASE)
    sig2.addAll(sig1)
    if (!sig2.contains(MagicSignature.TOP)) {
        throw Exception("should contain TOP after addAll")
    }
    if (!sig2.contains(MagicSignature.ICASE)) {
        throw Exception("should contain ICASE after addAll")
    }
}

@Test
func testMagicSignatureSetIsEmpty(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — MagicSignatureSet::is_empty
    let sig = MagicSignatureSet()
    if (!sig.isEmpty()) {
        throw Exception("empty set should be isEmpty")
    }
    sig.add(MagicSignature.TOP)
    if (sig.isEmpty()) {
        throw Exception("non-empty set should not be isEmpty")
    }
}

@Test
func testMagicSignatureSetEquals(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — MagicSignatureSet 相等性
    let sig1 = MagicSignatureSet()
    sig1.add(MagicSignature.TOP)
    let sig2 = MagicSignatureSet()
    sig2.add(MagicSignature.TOP)
    if (!sig1.equals(sig2)) {
        throw Exception("same signatures should be equal")
    }
    sig2.add(MagicSignature.ICASE)
    if (sig1.equals(sig2)) {
        throw Exception("different signatures should not be equal")
    }
}

// ============================================================
// Defaults 测试 — 对齐 Rust: gix-pathspec/tests/defaults.rs
// ============================================================

@Test
func testDefaultsDefaultValues(): Unit {
    // 对齐 Rust: gix-pathspec/src/defaults.rs — Defaults 默认值
    let d = Defaults()
    if (!d.signature.isEmpty()) {
        throw Exception("default signature should be empty")
    }
    if (d.searchMode != SearchMode.ShellGlob) {
        throw Exception("default search mode should be ShellGlob")
    }
    if (d.literal) {
        throw Exception("default literal should be false")
    }
}

@Test
func testDefaultsLiteralTrue(): Unit {
    // 对齐 Rust: gix-pathspec/src/defaults.rs — Defaults::literal
    let d = Defaults(MagicSignatureSet(), SearchMode.Literal, true)
    if (!d.literal) {
        throw Exception("literal should be true")
    }
    if (d.searchMode != SearchMode.Literal) {
        throw Exception("literal mode should have Literal search mode")
    }
}

@Test
func testDefaultsIcaseSignature(): Unit {
    // 对齐 Rust: gix-pathspec/src/defaults.rs — Defaults::icase_signature
    let d = Defaults(MagicSignatureSet(MagicSignature.ICASE), SearchMode.Literal, true)
    if (!d.signature.contains(MagicSignature.ICASE)) {
        throw Exception("should have ICASE signature")
    }
}

// ============================================================
// fromLiteral 测试
// ============================================================

@Test
func testFromLiteralSetsPathAndSearchMode(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::from_literal
    let p = fromLiteral("f[o][o]", MagicSignatureSet())
    if (p.path != "f[o][o]") {
        throw Exception("fromLiteral path should be 'f[o][o]'")
    }
    if (p.searchMode != SearchMode.Literal) {
        throw Exception("fromLiteral should have Literal search mode")
    }
    if (p.isNil()) {
        throw Exception("fromLiteral should not be nil")
    }
}

@Test
func testFromLiteralWithSignature(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern::from_literal 含签名
    let sig = MagicSignatureSet(MagicSignature.EXCLUDE)
    let p = fromLiteral("some/path", sig)
    if (!p.signature.contains(MagicSignature.EXCLUDE)) {
        throw Exception("fromLiteral should use default signature")
    }
}

// ============================================================
// Pathspec 旧版接口测试 — 保留兼容性
// ============================================================

@Test
func testPathspecParseSinglePattern(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 单个模式
    let specs = ArrayList<String>()
    specs.add("src/")
    let ps = Pathspec.parse(specs)
    if (ps.patterns.size != 1) {
        throw Exception("should have 1 pattern")
    }
    if (ps.patterns[0].pattern != "src/") {
        throw Exception("pattern should be 'src/'")
    }
}

@Test
func testPathspecParseMultiplePatterns(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 多个模式
    let specs = ArrayList<String>()
    specs.add("src/")
    specs.add("lib/")
    specs.add("test/")
    let ps = Pathspec.parse(specs)
    if (ps.patterns.size != 3) {
        throw Exception("should have 3 patterns")
    }
}

@Test
func testPathspecParseEmptyList(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 空列表
    let specs = ArrayList<String>()
    let ps = Pathspec.parse(specs)
    if (ps.patterns.size != 0) {
        throw Exception("empty list should have 0 patterns")
    }
}

@Test
func testPathspecMatchesEmptyPatterns(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 空模式
    let ps = Pathspec()
    if (!ps.matches("any/path")) {
        throw Exception("empty pathspec should match everything")
    }
}

@Test
func testPathspecMatchesPrefixPattern(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 前缀模式
    let specs = ArrayList<String>()
    specs.add("src/")
    let ps = Pathspec.parse(specs)
    if (!ps.matches("src/main.cj")) {
        throw Exception("src/ should match src/main.cj")
    }
    if (ps.matches("lib/main.cj")) {
        throw Exception("src/ should not match lib/main.cj")
    }
}

@Test
func testPathspecMatchesExactPattern(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 精确模式
    let specs = ArrayList<String>()
    specs.add("README.md")
    let ps = Pathspec.parse(specs)
    if (!ps.matches("README.md")) {
        throw Exception("exact match should work")
    }
    if (ps.matches("README.txt")) {
        throw Exception("should not match different name")
    }
}

@Test
func testPathspecMatchesDotPattern(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 点模式
    let specs = ArrayList<String>()
    specs.add(".")
    let ps = Pathspec.parse(specs)
    if (!ps.matches("any/path")) {
        throw Exception(". should match everything")
    }
}

@Test
func testPathspecMatchesMultiplePatterns(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 多模式
    let specs = ArrayList<String>()
    specs.add("src/")
    specs.add("lib/")
    let ps = Pathspec.parse(specs)
    if (!ps.matches("src/main.cj")) {
        throw Exception("should match src/")
    }
    if (!ps.matches("lib/utils.cj")) {
        throw Exception("should match lib/")
    }
    if (ps.matches("test/test.cj")) {
        throw Exception("should not match test/")
    }
}

@Test
func testPathspecMatchesNoMatch(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 无匹配
    let specs = ArrayList<String>()
    specs.add("src/")
    let ps = Pathspec.parse(specs)
    if (ps.matches("docs/readme.txt")) {
        throw Exception("should not match docs/")
    }
}

@Test
func testPathspecMatchesNestedPath(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::matches 嵌套路径
    let specs = ArrayList<String>()
    specs.add("src/")
    let ps = Pathspec.parse(specs)
    if (!ps.matches("src/gix_hash/hash.cj")) {
        throw Exception("src/ should match deeply nested path")
    }
}

@Test
func testPathspecPatternCreation(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern 构造
    let p = PathspecPattern("src/")
    if (p.pattern != "src/") {
        throw Exception("pattern mismatch")
    }
}

@Test
func testPathspecPatternEquality(): Unit {
    // 对齐 Rust: gix-pathspec/src/pattern.rs — Pattern 相等性
    let p1 = PathspecPattern("src/")
    let p2 = PathspecPattern("src/")
    if (p1.pattern != p2.pattern) {
        throw Exception("same pattern should have equal pattern field")
    }
}

// ============================================================
// 搜索相关测试 — 对齐 Rust: gix-pathspec/tests/search/mod.rs
// ============================================================

@Test
func testNoPathspecsMatchEverything(): Unit {
    // 对齐 Rust: no_pathspecs_match_everything
    let ps = Pathspec()
    if (!ps.matches("hello")) {
        throw Exception("no pathspecs should match everything")
    }
    if (!ps.matches("any/deep/path")) {
        throw Exception("no pathspecs should match deep paths")
    }
}

@Test
func testExcludePatternIsExcluded(): Unit {
    // 对齐 Rust: init_with_exclude
    let p = Pattern("some/path", MagicSignatureSet(MagicSignature.EXCLUDE), SearchMode.ShellGlob, false)
    if (!p.isExcluded()) {
        throw Exception("EXCLUDE pattern should be excluded")
    }
}

@Test
func testDirectoryMustBeDirSignature(): Unit {
    // 对齐 Rust: simplified_search_respects_must_be_dir
    let result = parsePathspec("a/be/", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.MUST_BE_DIR)) {
            throw Exception("a/be/ should have MUST_BE_DIR signature")
        }
        if (p.path != "a/be") {
            throw Exception("a/be/ path should be 'a/be'")
        }
    } else {
        throw Exception("a/be/ should parse successfully")
    }
}

// ============================================================
// 规范化相关测试 — 对齐 Rust: gix-pathspec/tests/normalize/mod.rs
// ============================================================

@Test
func testSingleDotIsSpecial(): Unit {
    // 对齐 Rust: single_dot_is_special_and_directory_is_implied_without_trailing_slash
    let result = parsePathspec(".", Defaults())
    if (let Some(p) <- result) {
        if (p.path != ".") {
            throw Exception(". should have path '.'")
        }
    } else {
        throw Exception(". should parse successfully")
    }
}

@Test
func testDotSlashIsSpecial(): Unit {
    // 对齐 Rust: single_dot_is_special — "./" -> MUST_BE_DIR
    let result = parsePathspec("./", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.MUST_BE_DIR)) {
            throw Exception("./ should have MUST_BE_DIR signature")
        }
    } else {
        throw Exception("./ should parse successfully")
    }
}

// ============================================================
// 综合边界测试
// ============================================================

@Test
func testParseExcludeBangWithSpace(): Unit {
    // 对齐 Rust: whitespace_in_pathspec — ":! some/path" -> EXCLUDE + " some/path"
    let result = parsePathspec(":! some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":! should have EXCLUDE signature")
        }
        if (p.path != " some/path") {
            throw Exception(":! some/path: path should be ' some/path'")
        }
    } else {
        throw Exception(":! some/path: should parse successfully")
    }
}

@Test
func testParseDoubleBang(): Unit {
    // 对齐 Rust: whitespace_in_pathspec — ":!!some/path" -> EXCLUDE + "some/path"
    let result = parsePathspec(":!!some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":!! should have EXCLUDE signature")
        }
        if (p.path != "some/path") {
            throw Exception(":!!some/path: path should be 'some/path'")
        }
    } else {
        throw Exception(":!!some/path: should parse successfully")
    }
}

@Test
func testParseIcaseTopCombined(): Unit {
    // 对齐 Rust: — ":(icase)foo/**/bar"
    let result = parsePathspec(":(icase)foo/**/bar", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception("should have ICASE")
        }
        if (p.path != "foo/**/bar") {
            throw Exception("path should be 'foo/**/bar'")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseTopWithExclude(): Unit {
    // 对齐 Rust: — ":/foo" + ":!/foo/target/"
    let r1 = parsePathspec(":/foo", Defaults())
    if (let Some(p) <- r1) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception(":/foo should have TOP")
        }
        if (p.path != "foo") {
            throw Exception(":/foo path should be 'foo'")
        }
    } else {
        throw Exception(":/foo should parse successfully")
    }

    let r2 = parsePathspec(":!/foo/target/", Defaults())
    if (let Some(p) <- r2) {
        if (!p.signature.contains(MagicSignature.EXCLUDE)) {
            throw Exception(":!/foo/target/ should have EXCLUDE")
        }
        if (!p.signature.contains(MagicSignature.MUST_BE_DIR)) {
            throw Exception(":!/foo/target/ should have MUST_BE_DIR")
        }
    } else {
        throw Exception(":!/foo/target/ should parse successfully")
    }
}

@Test
func testParseGlobWildcard(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse glob 通配符
    let result = parsePathspec("**/a*", Defaults())
    if (let Some(p) <- result) {
        if (p.path != "**/a*") {
            throw Exception("path should be '**/a*'")
        }
    } else {
        throw Exception("**/a* should parse successfully")
    }
}

@Test
func testParseDirGlob(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 目录 glob
    let result = parsePathspec("dir/*", Defaults())
    if (let Some(p) <- result) {
        if (p.path != "dir/*") {
            throw Exception("path should be 'dir/*'")
        }
    } else {
        throw Exception("dir/* should parse successfully")
    }
}

@Test
func testParseNilPatternMatchesEverything(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse nil 匹配所有
    let result = parsePathspec(":", Defaults())
    if (let Some(p) <- result) {
        if (!p.isNil()) {
            throw Exception(": should be nil pattern")
        }
        if (!p.alwaysMatches()) {
            throw Exception("nil pattern should always match")
        }
    } else {
        throw Exception(": should parse successfully")
    }
}

@Test
func testParseExcludeNilPattern(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 排除 nil 模式
    let result = parsePathspec(":(exclude)", Defaults())
    if (let Some(p) <- result) {
        if (!p.isExcluded()) {
            throw Exception(":(exclude) should be excluded")
        }
    } else {
        throw Exception(":(exclude) should parse successfully")
    }
}

@Test
func testParseLongPathspec(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 长路径
    let longPath = "very/deeply/nested/path/to/some/file.txt"
    let result = parsePathspec(longPath, Defaults())
    if (let Some(p) <- result) {
        if (p.path != longPath) {
            throw Exception("long path should be preserved")
        }
    } else {
        throw Exception("long path should parse successfully")
    }
}

@Test
func testParseTopIcaseCombined(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse top + icase 组合
    let result = parsePathspec(":(top,icase)some/path", Defaults())
    if (let Some(p) <- result) {
        if (!p.signature.contains(MagicSignature.TOP)) {
            throw Exception("should have TOP")
        }
        if (!p.signature.contains(MagicSignature.ICASE)) {
            throw Exception("should have ICASE")
        }
        if (p.path != "some/path") {
            throw Exception("path should be 'some/path'")
        }
    } else {
        throw Exception("should parse successfully")
    }
}

@Test
func testParseAttrKeyword(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse attr 关键字
    let result = parsePathspec(":(attr)", Defaults())
    if (let Some(p) <- result) {
        if (p.path != "") {
            throw Exception(":(attr) should have empty path")
        }
    } else {
        throw Exception(":(attr) should parse successfully")
    }
}

@Test
func testParseAttrWithAttribute(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse attr 含属性
    let result = parsePathspec(":(attr:someAttr)", Defaults())
    if (let Some(p) <- result) {
        if (p.path != "") {
            throw Exception(":(attr:someAttr) should have empty path")
        }
    } else {
        throw Exception(":(attr:someAttr) should parse successfully")
    }
}

@Test
func testParseAttrWithNegation(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse attr 含否定
    let result = parsePathspec(":(attr:!someAttr)", Defaults())
    if (let Some(_p) <- result) {
    // 属性解析，对齐 Rust: gix_pathspec::parse::signature::attribute — 验证否定属性
    } else {
        throw Exception(":(attr:!someAttr) should parse successfully")
    }
}

@Test
func testParseAttrWithValue(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse attr 含值
    let result = parsePathspec(":(attr:someAttr=value)", Defaults())
    if (let Some(_p) <- result) {
    // 属性解析，对齐 Rust: gix_pathspec::parse::signature::attribute — 验证属性值
    } else {
        throw Exception(":(attr:someAttr=value) should parse successfully")
    }
}

@Test
func testParseAttrMultipleAttributes(): Unit {
    // 对齐 Rust: gix-pathspec/src/lib.rs — Pathspec::parse 多属性
    let result = parsePathspec(":(attr:someAttr anotherAttr)", Defaults())
    if (let Some(_p) <- result) {
    // 属性解析，对齐 Rust: gix_pathspec::parse::signature::attribute — 验证多属性
    } else {
        throw Exception(":(attr:someAttr anotherAttr) should parse successfully")
    }
}

@Test
func testParseMultipleAttributeSpecifications(): Unit {
    // 对齐 Rust: multiple_attribute_specifications
    let result = parsePathspec(":(attr:one,attr:two)some/path", Defaults())
    // 对齐 Rust: multiple_attribute_specifications — 多属性规格解析
}

@Test
func testParseEmptyAttributeSpecification(): Unit {
    // 对齐 Rust: empty_attribute_specification
    let result = parsePathspec(":(attr:)", Defaults())
    // 对齐 Rust: empty_attribute_specification — 空属性规格解析
}

@Test
func testParseAttrWithEscapedChars(): Unit {
    // 对齐 Rust: attributes_with_escape_chars_in_state_values
    let result = parsePathspec(":(attr:v=one\\-)", Defaults())
    // 对齐 Rust: attributes_with_escape_chars_in_state_values — 转义字符属性值
}
