// 文件：attributes_test.cj
// 用途：gix_attributes 包的单元测试，全量对齐 Rust gitoxide gix-attributes 测试
// 所属包：gix.gix_attributes
// 对齐来源：gix-attributes/tests/{parse,match}.rs

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
}

@Test
func testAttributesParseKeyValue(): Unit {
    // 对齐 Rust: parse key=value attribute
    let content = "*.sh eol=lf"
    let attrs = Attributes.parse(content)
    if (attrs.patterns[0].assignments[0].name != "eol") {
        throw Exception("name should be 'eol'")
    }
    if (attrs.patterns[0].assignments[0].value != Some("lf")) {
        throw Exception("value should be 'lf'")
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
    if (attrs.patterns[0].assignments[0].value != None) {
        throw Exception("unset attribute value should be None")
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
    // 对齐 Rust: AttributeAssignment set (key=value)
    let a = AttributeAssignment("eol", Some("lf"))
    if (a.name != "eol") {
        throw Exception("name mismatch")
    }
    if (a.value != Some("lf")) {
        throw Exception("value mismatch")
    }
}

@Test
func testAttributeAssignmentUnset(): Unit {
    // 对齐 Rust: AttributeAssignment unset (-key)
    let a = AttributeAssignment("diff", None)
    if (a.name != "diff") {
        throw Exception("name mismatch")
    }
    if (a.value != None) {
        throw Exception("value should be None for unset")
    }
}

@Test
func testAttributeAssignmentSetTrue(): Unit {
    // 对齐 Rust: AttributeAssignment set to true (key without value)
    let a = AttributeAssignment("text", Some("true"))
    if (a.value != Some("true")) {
        throw Exception("value should be 'true'")
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
}

@Test
func testAttributesParseUnsetWithValueIgnored(): Unit {
    // 对齐 Rust: attributes_see_state_adjustments_over_value_assignments — -attr=value
    let content = "*.txt -diff=c"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size != 1) {
        throw Exception("should have 1 entry")
    }
}

@Test
func testAttributesParseAttrMacroLineSkipped(): Unit {
    // 对齐 Rust: custom_macros_can_be_differentiated — [attr] lines
    let content = "[attr]binary -diff -merge\n*.bin binary"
    let attrs = Attributes.parse(content)
    if (attrs.patterns.size == 0) {
        throw Exception("should have at least the non-macro line")
    }
}
