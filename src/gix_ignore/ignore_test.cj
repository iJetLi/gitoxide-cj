// 文件：ignore_test.cj
// 用途：gix_ignore 包的单元测试，全量对齐 Rust gitoxide gix-ignore 测试
// 所属包：gix.gix_ignore
// 对齐来源：gix-ignore/tests/{parse,search}.rs

package gitoxide.gix_ignore

import std.unittest.*
import std.collection.*

// ============================================================
// Ignore.parse 测试 — 对齐 gix-ignore/tests/parse.rs
// ============================================================

@Test
func testIgnoreParseSimplePattern(): Unit {
    // 对齐 Rust: parse simple pattern
    let ignore = Ignore.parse("*.log")
    if (ignore.patterns.size != 1) {
        throw Exception("should have 1 pattern, got " + ignore.patterns.size.toString())
    }
    if (ignore.patterns[0].pattern != "*.log") {
        throw Exception("pattern should be '*.log'")
    }
    if (ignore.patterns[0].negated) {
        throw Exception("should not be negated")
    }
}

@Test
func testIgnoreParseNegatedPattern(): Unit {
    // 对齐 Rust: parse negated pattern (! prefix)
    let ignore = Ignore.parse("!important.log")
    if (ignore.patterns.size != 1) {
        throw Exception("should have 1 pattern")
    }
    if (!ignore.patterns[0].negated) {
        throw Exception("pattern should be negated")
    }
    if (ignore.patterns[0].pattern != "important.log") {
        throw Exception("pattern should be 'important.log' without ! prefix")
    }
}

@Test
func testIgnoreParseCommentLines(): Unit {
    // 对齐 Rust: parse with comment lines (# prefix)
    let content = "# This is a comment\n*.o\n# Another comment\nbuild/"
    let ignore = Ignore.parse(content)
    if (ignore.patterns.size != 2) {
        throw Exception("should have 2 patterns after skipping comments, got " + ignore.patterns.size.toString())
    }
    if (ignore.patterns[0].pattern != "*.o") {
        throw Exception("first pattern should be '*.o'")
    }
    if (ignore.patterns[1].pattern != "build/") {
        throw Exception("second pattern should be 'build/'")
    }
}

@Test
func testIgnoreParseEmptyLines(): Unit {
    // 对齐 Rust: parse with empty lines
    let content = "\n*.log\n\n*.tmp\n"
    let ignore = Ignore.parse(content)
    if (ignore.patterns.size != 2) {
        throw Exception("should have 2 patterns after skipping empty lines")
    }
}

@Test
func testIgnoreParseEmptyInput(): Unit {
    // 对齐 Rust: parse empty input
    let ignore = Ignore.parse("")
    if (ignore.patterns.size != 0) {
        throw Exception("empty input should have 0 patterns")
    }
}

@Test
func testIgnoreParseMultiplePatterns(): Unit {
    // 对齐 Rust: parse multiple patterns
    let content = "*.log\n*.tmp\nbuild/\n!keep.log"
    let ignore = Ignore.parse(content)
    if (ignore.patterns.size != 4) {
        throw Exception("should have 4 patterns, got " + ignore.patterns.size.toString())
    }
    if (!ignore.patterns[3].negated) {
        throw Exception("last pattern should be negated")
    }
}

// ============================================================
// Ignore.isIgnored 测试 — 对齐 gix-ignore/tests/search.rs
// ============================================================

@Test
func testIgnoreIsIgnoredStarWildcard(): Unit {
    // 对齐 Rust: isIgnored — * matches everything
    let ignore = Ignore.parse("*")
    if (!ignore.isIgnored("anyfile.txt")) {
        throw Exception("* should match any file")
    }
}

@Test
func testIgnoreIsIgnoredSuffixWildcard(): Unit {
    // 对齐 Rust: isIgnored — *.log suffix match
    let ignore = Ignore.parse("*.log")
    if (!ignore.isIgnored("error.log")) {
        throw Exception("*.log should match error.log")
    }
    if (ignore.isIgnored("error.txt")) {
        throw Exception("*.log should not match error.txt")
    }
}

@Test
func testIgnoreIsIgnoredPrefixWildcard(): Unit {
    // 对齐 Rust: isIgnored — build/* prefix match
    let ignore = Ignore.parse("build/*")
    if (!ignore.isIgnored("build/output.bin")) {
        throw Exception("build/* should match build/output.bin")
    }
}

@Test
func testIgnoreIsIgnoredExactMatch(): Unit {
    // 对齐 Rust: isIgnored — exact path match
    let ignore = Ignore.parse("secret.key")
    if (!ignore.isIgnored("secret.key")) {
        throw Exception("exact match should work")
    }
}

@Test
func testIgnoreIsIgnoredNegationOverride(): Unit {
    // 对齐 Rust: isIgnored — negated pattern overrides earlier match
    let content = "*.log\n!important.log"
    let ignore = Ignore.parse(content)
    if (ignore.isIgnored("error.log")) {
    // error.log matches *.log first, then no negation match → ignored
    } else {
        throw Exception("error.log should be ignored by *.log")
    }
    // important.log matches *.log (ignored), then !important.log (negated) → not ignored
    if (ignore.isIgnored("important.log")) {
        throw Exception("important.log should not be ignored due to negation")
    }
}

@Test
func testIgnoreIsIgnoredNoMatch(): Unit {
    // 对齐 Rust: isIgnored — no matching pattern
    let ignore = Ignore.parse("*.log")
    if (ignore.isIgnored("readme.txt")) {
        throw Exception("readme.txt should not be ignored")
    }
}

@Test
func testIgnoreIsIgnoredEmptyPatterns(): Unit {
    // 对齐 Rust: isIgnored — empty ignore list
    let ignore = Ignore()
    if (ignore.isIgnored("anyfile.txt")) {
        throw Exception("empty ignore should not ignore anything")
    }
}

@Test
func testIgnoreIsIgnoredMiddleWildcard(): Unit {
    // 对齐 Rust: isIgnored — *middle* contains match
    let ignore = Ignore.parse("*test*")
    if (!ignore.isIgnored("mytestfile.txt")) {
        throw Exception("*test* should match mytestfile.txt")
    }
    if (!ignore.isIgnored("test")) {
        throw Exception("*test* should match test")
    }
}

@Test
func testIgnoreIsIgnoredPathSuffixMatch(): Unit {
    // 对齐 Rust: isIgnored — path suffix match (dir/file)
    let ignore = Ignore.parse("file.txt")
    if (!ignore.isIgnored("dir/file.txt")) {
        throw Exception("file.txt should match dir/file.txt as suffix")
    }
}

// ============================================================
// IgnorePattern 测试
// ============================================================

@Test
func testIgnorePatternCreation(): Unit {
    // 对齐 Rust: IgnorePattern construction
    let p = IgnorePattern("*.log", false)
    if (p.pattern != "*.log") {
        throw Exception("pattern mismatch")
    }
    if (p.negated) {
        throw Exception("should not be negated")
    }
}

@Test
func testIgnorePatternNegated(): Unit {
    // 对齐 Rust: IgnorePattern negated
    let p = IgnorePattern("keep.log", true)
    if (!p.negated) {
        throw Exception("should be negated")
    }
}
