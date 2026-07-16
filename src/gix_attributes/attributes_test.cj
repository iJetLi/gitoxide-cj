// 文件：attributes_test.cj
// 用途：gix_attributes 包的单元测试，全量对齐 Rust gitoxide gix-attributes 测试
// 所属包：gix.gix_attributes
// 对齐来源：gix-attributes/tests/{parse,match}.rs, gix-attributes/src/parse.rs, gix-attributes/src/search/attributes.rs

package gitoxide.gix_attributes

import std.unittest.*
import std.collection.*

// ============================================================
// Attributes.parse 测试 — 对齐 gix-attributes/tests/parse.rs
// ============================================================

@Test
func testAttributesParseSimpleEntry(): Unit {
    // 对齐 Rust: parse simple attribute entry
    let content = "*.txt text"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 pattern, got " + attrs.patterns.size.toString())
    }
    if (attrs.patterns[0].pattern != "*.txt") {
        throw Exception("pattern should be '*.txt'")
    }
    if (attrs.patterns[0].assignments.size != 1) {
        throw Exception("should have 1 assignment")
    }
    if (attrs.patterns[0].assignments[0].name != "text") {
        throw Exception("assignment name should be 'text'")
    }
    if (attrs.patterns[0].assignments[0].state != AttributeState.Set) {
        throw Exception("state should be Set")
    }
}

@Test
func testAttributesParseKeyValue(): Unit {
    // 对齐 Rust: parse key=value attribute
    let content = "*.sh eol=lf"
    let attrs = Attributes.parse(content)
    if (attrs.patterns[0].assignments[0].name != "eol") {
        throw Exception("name should be 'eol'")
    }
    if (attrs.patterns[0].assignments[0].state != AttributeState.Value("lf")) {
        throw Exception("state should be Value('lf')")
    }
}

@Test
func testAttributesParseUnset(): Unit {
    // 对齐 Rust: parse -prefix unset attribute
    let content = "*.bin -diff"
    let attrs = Attributes.parse(content)
    if (attrs.patterns[0].assignments[0].name != "diff") {
        throw Exception("name should be 'diff'")
    }
    if (attrs.patterns[0].assignments[0].state != AttributeState.Unset) {
        throw Exception("state should be Unset")
    }
}

@Test
func testAttributesParseMultipleAttributes(): Unit {
    // 对齐 Rust: parse multiple attributes on one line
    let content = "*.txt text eol=lf"
    let attrs = Attributes.parse(content)
    if (attrs.patterns[0].assignments.size != 2) {
        throw Exception("should have 2 assignments, got " + attrs.patterns[0].assignments.size.toString())
    }
}

@Test
func testAttributesParseCommentLines(): Unit {
    // 对齐 Rust: parse with comment lines
    let content = "# comment\n*.txt text\n# another"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 pattern after skipping comments")
    }
}

@Test
func testAttributesParseEmptyLines(): Unit {
    // 对齐 Rust: parse with empty lines
    let content = "\n*.txt text\n\n*.sh binary\n"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 2) {
        throw Exception("should have 2 patterns after skipping empty lines")
    }
}

@Test
func testAttributesParseEmptyInput(): Unit {
    // 对齐 Rust: parse empty input
    let attrs = Attributes.parse("")
    if (attrs.patterns.size != 0) {
        throw Exception("empty input should have 0 patterns")
    }
}

@Test
func testAttributesParseNoAttributeSkipped(): Unit {
    // 对齐 Rust: parse — line with no space (pattern only) is skipped
    let content = "*.txt"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 0) {
        throw Exception("line with no space should be skipped")
    }
}

// ============================================================
// Attributes.matchPath 测试 — 对齐 gix-attributes/tests/match.rs
// ============================================================

@Test
func testAttributesMatchPathStarWildcard(): Unit {
    // 对齐 Rust: matchPath — * matches everything
    let content = "* text"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("anyfile.txt")
    if (result.size != 1) {
        throw Exception("* should match any path")
    }
}

@Test
func testAttributesMatchPathContainsPattern(): Unit {
    // 对齐 Rust: matchPath — contains-based matching
    let content = "*.txt text"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("file.txt")
    if (result.size != 1) {
        throw Exception("*.txt should match file.txt via contains")
    }
}

@Test
func testAttributesMatchPathNoMatch(): Unit {
    // 对齐 Rust: matchPath — no matching pattern
    let content = "*.sh binary"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("file.txt")
    if (result.size != 0) {
        throw Exception("*.sh should not match file.txt")
    }
}

@Test
func testAttributesMatchPathMultiplePatterns(): Unit {
    // 对齐 Rust: matchPath — multiple patterns match same path
    let content = "*.txt text\n* binary"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("readme.txt")
    if (result.size != 2) {
        throw Exception("should match both patterns, got " + result.size.toString())
    }
}

// ============================================================
// AttributeAssignment 测试
// ============================================================

@Test
func testAttributeAssignmentSet(): Unit {
    // 对齐 Rust: AttributeAssignment set (key)
    let a = AttributeAssignment("eol", AttributeState.Value("lf"))
    if (a.name != "eol") {
        throw Exception("name mismatch")
    }
    if (a.state != AttributeState.Value("lf")) {
        throw Exception("state mismatch")
    }
}

@Test
func testAttributeAssignmentUnset(): Unit {
    // 对齐 Rust: AttributeAssignment unset (-key)
    let a = AttributeAssignment("diff", AttributeState.Unset)
    if (a.name != "diff") {
        throw Exception("name mismatch")
    }
    if (a.state != AttributeState.Unset) {
        throw Exception("state should be Unset")
    }
}

@Test
func testAttributeAssignmentSetTrue(): Unit {
    // 对齐 Rust: AttributeAssignment set to true (key without value)
    let a = AttributeAssignment("text", AttributeState.Set)
    if (a.state != AttributeState.Set) {
        throw Exception("state should be Set")
    }
    if (a.value() != Some("true")) {
        throw Exception("value() should return 'true'")
    }
}

@Test
func testAttributeAssignmentUnspecified(): Unit {
    // 对齐 Rust: AttributeAssignment unspecified (!key)
    let a = AttributeAssignment("diff", AttributeState.Unspecified)
    if (a.state != AttributeState.Unspecified) {
        throw Exception("state should be Unspecified")
    }
    if (a.value().isSome()) {
        throw Exception("value() should return None for Unspecified")
    }
}

// ============================================================
// Attributes.parse 补充测试 — 对齐 gix-attributes/tests/parse.rs
// ============================================================

@Test
func testAttributesParseWindowsLineEndings(): Unit {
    // 对齐 Rust: line_endings_can_be_windows_or_unix
    let content = "*.txt text\r\n*.md markdown"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 2) {
        throw Exception("should have 2 entries with CRLF, got " + attrs.patterns.size.toString())
    }
}

@Test
func testAttributesParseLeadingWhitespace(): Unit {
    // 对齐 Rust: leading_whitespace_is_ignored
    let content = "  *.txt text"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 entry with leading whitespace")
    }
}

@Test
func testAttributesParseTrailingWhitespace(): Unit {
    // 对齐 Rust: trailing_whitespace_in_attributes_is_ignored
    let content = "*.txt text  "
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 entry with trailing whitespace")
    }
}

@Test
func testAttributesParseUnspecifiedPrefix(): Unit {
    // 对齐 Rust: attributes_come_in_different_flavors_due_to_prefixes — ! prefix (unspecified)
    let content = "*.txt !diff"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 entry")
    }
    if (attrs.patterns[0].assignments.size != 1) {
        throw Exception("should have 1 assignment")
    }
    if (attrs.patterns[0].assignments[0].state != AttributeState.Unspecified) {
        throw Exception("state should be Unspecified")
    }
}

@Test
func testAttributesParseUnsetWithValueIgnored(): Unit {
    // 对齐 Rust: attributes_see_state_adjustments_over_value_assignments — -attr=value
    let content = "*.txt -diff=c"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 entry")
    }
    // -diff=c 应视为 Unset，对齐 Rust
    if (attrs.patterns[0].assignments[0].state != AttributeState.Unset) {
        throw Exception("-diff=c should be Unset")
    }
}

// ============================================================
// 宏属性测试 — 对齐 Rust gix-attributes/tests/parse.rs, gix-attributes/src/search/attributes.rs
// ============================================================

@Test
func testAttributesParseMacroDefinition(): Unit {
    // 对齐 Rust: custom_macros_can_be_differentiated — [attr] lines
    let content = "[attr]binary -diff -merge\n*.bin binary"
    let attrs = Attributes.parse(content)
    if (attrs.macros.size != 1) {
        throw Exception("should have 1 macro, got " + attrs.macros.size.toString())
    }
    if (attrs.macros[0].name != "binary") {
        throw Exception("macro name should be 'binary'")
    }
    if (attrs.macros[0].assignments.size != 2) {
        throw Exception("macro should have 2 assignments")
    }
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 pattern")
    }
}

@Test
func testAttributesMacroExpansion(): Unit {
    // 对齐 Rust: macro expansion when matching
    let content = "[attr]binary -diff -merge\n*.bin binary"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("file.bin")
    // 宏展开后应有 2 个属性
    if (result.size < 2) {
        throw Exception("macro should expand to at least 2 assignments, got " + result.size.toString())
    }
}

// ============================================================
// glob 模式匹配测试 — 对齐 Rust gix-attributes/tests/match.rs
// ============================================================

@Test
func testAttributesMatchPathDoubleStar(): Unit {
    // 对齐 Rust: ** 递归匹配
    let r1 = matchPattern("src/**/*.rs", "src/main.rs")
    if (!r1) {
        throw Exception("src/**/*.rs should match src/main.rs")
    }
    let r2 = matchPattern("**.rs", "main.rs")
    if (!r2) {
        throw Exception("**.rs should match main.rs")
    }
    let r3 = matchPattern("src/**/*.rs", "src/deep/nested/file.rs")
    if (!r3) {
        throw Exception("src/**/*.rs should match src/deep/nested/file.rs")
    }
    let r4 = matchPattern("src/**/*.rs", "lib.rs")
    if (r4) {
        throw Exception("src/**/*.rs should NOT match lib.rs")
    }
}

@Test
func testAttributesMatchPathDirectoryOnlyPattern(): Unit {
    // 对齐 Rust: directory_only_pattern — / 后缀模式
    let content = "docs/ text"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("docs/readme.md")
    if (result.size != 1) {
        throw Exception("docs/ should match docs/readme.md")
    }
}

@Test
func testAttributesMatchPathNegationPattern(): Unit {
    // 对齐 Rust: negation_pattern — ! 前缀模式
    let content = "!secret.key text"
    let attrs = Attributes.parse(content)
    // 否定模式匹配时反转结果
    let result = attrs.matchPath("secret.key")
    if (result.size != 0) {
        throw Exception("negation pattern should not produce assignments")
    }
}

@Test
func testAttributesMatchPathQuestionMark(): Unit {
    // 对齐 Rust: ? 单字符匹配
    let content = "file?.txt text"
    let attrs = Attributes.parse(content)
    let result = attrs.matchPath("file1.txt")
    if (result.size != 1) {
        throw Exception("file?.txt should match file1.txt")
    }
}

@Test
func testAttributesValidAttributeName(): Unit {
    // 对齐 Rust: gix_attributes::name::attr_valid
    if (!Attributes.isValidAttributeName("text")) {
        throw Exception("text should be valid")
    }
    if (!Attributes.isValidAttributeName("eol")) {
        throw Exception("eol should be valid")
    }
    if (!Attributes.isValidAttributeName("my-attr")) {
        throw Exception("my-attr should be valid")
    }
    if (!Attributes.isValidAttributeName("attr_1")) {
        throw Exception("attr_1 should be valid")
    }
    if (Attributes.isValidAttributeName("-diff")) {
        throw Exception("-diff should not be valid (starts with -)")
    }
    if (Attributes.isValidAttributeName("attr with space")) {
        throw Exception("attr with space should not be valid")
    }
}

// ============================================================
// AttributeState 测试 — 对齐 Rust gix_attributes::State
// ============================================================

@Test
func testAttributeStateEquality(): Unit {
    if (AttributeState.Set != AttributeState.Set) {
        throw Exception("Set should equal Set")
    }
    if (AttributeState.Unset != AttributeState.Unset) {
        throw Exception("Unset should equal Unset")
    }
    if (AttributeState.Value("lf") != AttributeState.Value("lf")) {
        throw Exception("Value(lf) should equal Value(lf)")
    }
    if (AttributeState.Unspecified != AttributeState.Unspecified) {
        throw Exception("Unspecified should equal Unspecified")
    }
    if (AttributeState.Set == AttributeState.Unset) {
        throw Exception("Set should not equal Unset")
    }
    if (AttributeState.Value("lf") == AttributeState.Value("crlf")) {
        throw Exception("Value(lf) should not equal Value(crlf)")
    }
}

@Test
func testAttributeStateValueMethod(): Unit {
    // 对齐 Rust: AttributeAssignment.value() 兼容方法
    let set = AttributeAssignment("text", AttributeState.Set)
    if (set.value() != Some("true")) {
        throw Exception("Set value() should return 'true'")
    }
    let unset = AttributeAssignment("diff", AttributeState.Unset)
    if (unset.value().isSome()) {
        throw Exception("Unset value() should return None")
    }
    let val = AttributeAssignment("eol", AttributeState.Value("lf"))
    if (val.value() != Some("lf")) {
        throw Exception("Value(lf) value() should return 'lf'")
    }
    let unspecified = AttributeAssignment("merge", AttributeState.Unspecified)
    if (unspecified.value().isSome()) {
        throw Exception("Unspecified value() should return None")
    }
}
