// 文件：mailmap_test.cj
// 用途：gix_mailmap 包的单元测试，全量对齐 Rust gitoxide gix-mailmap 测试
// 所属包：gix.gix_mailmap
// 对齐来源：gix-mailmap/tests/{parse,resolve}.rs

package gitoxide.gix_mailmap

import std.unittest.*

// ============================================================
// Mailmap.parse 测试 — 对齐 gix-mailmap/tests/parse.rs
// ============================================================

@Test
func testMailmapParseSimpleEntry(): Unit {
    // 对齐 Rust: parse simple mailmap entry
    let content = "Proper Name <proper@email.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 1) {
        throw Exception("should have 1 entry, got " + map.entries.size.toString())
    }
    let entry = map.entries[0]
    if (entry.toName != "Proper Name") {
        throw Exception("toName should be 'Proper Name'")
    }
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail should be 'proper@email.com'")
    }
}

@Test
func testMailmapParseMultipleEntries(): Unit {
    // 对齐 Rust: parse multiple entries
    let content = "Name1 <email1@test.com>\nName2 <email2@test.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 2) {
        throw Exception("should have 2 entries, got " + map.entries.size.toString())
    }
}

@Test
func testMailmapParseEmptyInput(): Unit {
    // 对齐 Rust: parse empty input
    let map = Mailmap.parse("")
    if (map.entries.size != 0) {
        throw Exception("empty input should have 0 entries")
    }
}

@Test
func testMailmapParseCommentLines(): Unit {
    // 对齐 Rust: parse with comments
    let content = "# This is a comment\nProper Name <proper@email.com>\n# Another comment"
    let map = Mailmap.parse(content)
    if (map.entries.size != 1) {
        throw Exception("should have 1 entry after skipping comments")
    }
}

@Test
func testMailmapParseEmptyLines(): Unit {
    // 对齐 Rust: parse with empty lines
    let content = "\n\nProper Name <proper@email.com>\n\n"
    let map = Mailmap.parse(content)
    if (map.entries.size != 1) {
        throw Exception("should have 1 entry after skipping empty lines")
    }
}

// ============================================================
// Mailmap.resolve 测试 — 对齐 gix-mailmap/tests/resolve.rs
// ============================================================

@Test
func testMailmapResolveByEmail(): Unit {
    // 对齐 Rust: resolve by email match
    let map = Mailmap.parse("Proper Name <proper@email.com>")
    let (name, email) = map.resolve("Old Name", "proper@email.com")
    if (name != "Proper Name") {
        throw Exception("resolved name should be 'Proper Name', got '" + name + "'")
    }
    if (email != "proper@email.com") {
        throw Exception("resolved email should be 'proper@email.com'")
    }
}

@Test
func testMailmapResolveNoMatch(): Unit {
    // 对齐 Rust: resolve with no matching entry
    let map = Mailmap.parse("Proper Name <proper@email.com>")
    let (name, email) = map.resolve("Original Name", "other@email.com")
    if (name != "Original Name") {
        throw Exception("unmatched name should remain unchanged")
    }
    if (email != "other@email.com") {
        throw Exception("unmatched email should remain unchanged")
    }
}

@Test
func testMailmapResolveEmptyMap(): Unit {
    // 对齐 Rust: resolve with empty mailmap
    let map = Mailmap()
    let (name, email) = map.resolve("Original Name", "original@email.com")
    if (name != "Original Name") {
        throw Exception("empty map should not change name")
    }
    if (email != "original@email.com") {
        throw Exception("empty map should not change email")
    }
}

// ============================================================
// MailmapEntry 测试
// ============================================================

@Test
func testMailmapEntryCreation(): Unit {
    // 对齐 Rust: MailmapEntry construction
    let entry = MailmapEntry("Proper Name", "proper@email.com")
    if (entry.toName != "Proper Name") {
        throw Exception("toName mismatch")
    }
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail mismatch")
    }
    if (entry.fromName != "") {
        throw Exception("fromName should default to empty")
    }
    if (entry.fromEmail != "") {
        throw Exception("fromEmail should default to empty")
    }
}

// ============================================================
// Mailmap.parse 补充测试 — 对齐 gix-mailmap/tests/parse/mod.rs
// ============================================================

@Test
func testMailmapParseChangeNameByEmail(): Unit {
    // 对齐 Rust: valid_entries — change_name_by_email
    let map = Mailmap.parse("Proper Name <proper@email.com>")
    let entry = map.entries[0]
    if (entry.toName != "Proper Name") {
        throw Exception("toName should be 'Proper Name'")
    }
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail should be 'proper@email.com'")
    }
    if (entry.fromEmail != "") {
        throw Exception("fromEmail should be empty")
    }
}

@Test
func testMailmapParseChangeEmailByEmail(): Unit {
    // 对齐 Rust: valid_entries — change_email_by_email: <new_email> <old_email>
    let map = Mailmap.parse("<proper@email.com> <old@email.com>")
    let entry = map.entries[0]
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail should be 'proper@email.com'")
    }
    if (entry.fromEmail != "old@email.com") {
        throw Exception("fromEmail should be 'old@email.com'")
    }
}

@Test
func testMailmapParseChangeNameAndEmailByEmail(): Unit {
    // 对齐 Rust: valid_entries — change_name_and_email_by_email: Proper Name <proper@email.com> Old Name <old@email.com>
    let map = Mailmap.parse("Proper Name <proper@email.com> Old Name <old@email.com>")
    let entry = map.entries[0]
    if (entry.toName != "Proper Name") {
        throw Exception("toName should be 'Proper Name'")
    }
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail should be 'proper@email.com'")
    }
    if (entry.fromName != "Old Name") {
        throw Exception("fromName should be 'Old Name'")
    }
    if (entry.fromEmail != "old@email.com") {
        throw Exception("fromEmail should be 'old@email.com'")
    }
}

@Test
func testMailmapParseChangeEmailByNameAndEmail(): Unit {
    // 对齐 Rust: valid_entries — change_email_by_name_and_email: <proper@email.com> Old Name <old@email.com>
    let map = Mailmap.parse("<proper@email.com> Old Name <old@email.com>")
    let entry = map.entries[0]
    if (entry.toEmail != "proper@email.com") {
        throw Exception("toEmail should be 'proper@email.com'")
    }
    if (entry.fromName != "Old Name") {
        throw Exception("fromName should be 'Old Name'")
    }
    if (entry.fromEmail != "old@email.com") {
        throw Exception("fromEmail should be 'old@email.com'")
    }
}

@Test
func testMailmapParseHashBeforeName(): Unit {
    // 对齐 Rust: hash_before_name_counts_as_name — "# this is a name <email>"
    let map = Mailmap.parse(" # this is a name <email@test.com>")
    if (map.entries.size != 1) {
        throw Exception("should have 1 entry, got " + map.entries.size.toString())
    }
    let entry = map.entries[0]
    if (entry.toName != "# this is a name") {
        throw Exception("toName should be '# this is a name', got '" + entry.toName + "'")
    }
}

@Test
func testMailmapParseWindowsLineEndings(): Unit {
    // 对齐 Rust: windows_and_unix_line_endings_are_supported
    let content = "Name1 <email1@test.com>\r\nName2 <email2@test.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 2) {
        throw Exception("should have 2 entries with CRLF, got " + map.entries.size.toString())
    }
}

// ============================================================
// Mailmap.resolve 补充测试 — 对齐 gix-mailmap/tests/snapshot/mod.rs
// ============================================================

@Test
func testMailmapResolveCaseInsensitive(): Unit {
    // 对齐 Rust: try_resolve — 大小写不敏感匹配
    let map = Mailmap.parse("Jane Doe <jane@example.com> <bugs@example.com>")
    let (name, email) = map.resolve("Any Name", "BUGS@EXAMPLE.COM")
    if (name != "Jane Doe") {
        throw Exception("resolved name should be 'Jane Doe', got '" + name + "'")
    }
    if (email != "jane@example.com") {
        throw Exception("resolved email should be 'jane@example.com'")
    }
}

@Test
func testMailmapResolveByNameAndEmail(): Unit {
    // 对齐 Rust: try_resolve — 按 name+email 匹配
    let map = Mailmap.parse("Proper Name <proper@email.com> Old Name <old@email.com>")
    let (name, email) = map.resolve("Old Name", "old@email.com")
    if (name != "Proper Name") {
        throw Exception("resolved name should be 'Proper Name', got '" + name + "'")
    }
    if (email != "proper@email.com") {
        throw Exception("resolved email should be 'proper@email.com'")
    }
}

@Test
func testMailmapResolveByNameAndEmailNotMatchingName(): Unit {
    // 对齐 Rust: try_resolve — name+email 匹配时 name 不匹配则不命中
    let map = Mailmap.parse("Proper Name <proper@email.com> Old Name <old@email.com>")
    let (name, email) = map.resolve("Different Name", "old@email.com")
    if (name != "Different Name") {
        throw Exception("should not match when name differs")
    }
}

@Test
func testMailmapResolveOverwriteEntries(): Unit {
    // 对齐 Rust: overwrite_entries — 后出现的同名条目覆盖前面的
    let map = Mailmap.parse(
        "First Name <first@email.com> <old@email.com>\nSecond Name <second@email.com> <old@email.com>")
    let (name, email) = map.resolve("Any", "old@email.com")
    if (name != "First Name") {
        throw Exception("first matching entry should win, got '" + name + "'")
    }
}

@Test
func testMailmapResolveByEmailOnly(): Unit {
    // 对齐 Rust: try_resolve — 仅按 email 匹配（fromEmail 有值，fromName 为空）
    let map = Mailmap.parse("<proper@email.com> <old@email.com>")
    let (name, email) = map.resolve("Any Name", "old@email.com")
    if (email != "proper@email.com") {
        throw Exception("resolved email should be 'proper@email.com', got '" + email + "'")
    }
    if (name != "Any Name") {
        throw Exception("name should remain unchanged when toName is empty")
    }
}

// ============================================================
// 续行测试 — 对齐 Rust gix_mailmap::parse::Lines
// ============================================================

@Test
func testMailmapParseContinuationLine(): Unit {
    // 对齐 Rust: continuation lines — 反斜杠行尾续行
    let content = "Proper Name <proper@email.com> \\\nOld Name <old@email.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 1) {
        throw Exception("continuation should produce 1 entry, got " + map.entries.size.toString())
    }
    let entry = map.entries[0]
    if (entry.toName != "Proper Name") {
        throw Exception("toName should be 'Proper Name'")
    }
    if (entry.fromName != "Old Name") {
        throw Exception("fromName should be 'Old Name'")
    }
}

@Test
func testMailmapParseMultipleContinuationLines(): Unit {
    // 对齐 Rust: 多行续行
    let content = "Proper \\\nName <proper@email.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 1) {
        throw Exception("multi-line continuation should produce 1 entry, got " + map.entries.size.toString())
    }
}

// ============================================================
// 大小写规范化测试 — 对齐 Rust gix_mailmap::Snapshot::try_resolve
// ============================================================

@Test
func testMailmapResolveCaseInsensitiveEmail(): Unit {
    // 对齐 Rust: try_resolve — 邮箱大小写不敏感
    let map = Mailmap.parse("Jane Doe <jane@example.com> <bugs@example.com>")
    let (name1, email1) = map.resolve("Any Name", "BUGS@EXAMPLE.COM")
    if (name1 != "Jane Doe") {
        throw Exception("should match case-insensitive email, got '" + name1 + "'")
    }
    let (name2, email2) = map.resolve("Any Name", "Bugs@Example.Com")
    if (name2 != "Jane Doe") {
        throw Exception("should match mixed case email, got '" + name2 + "'")
    }
}

@Test
func testMailmapResolveCaseInsensitiveNameMatch(): Unit {
    // 对齐 Rust: try_resolve — 名称大小写不敏感匹配
    let map = Mailmap.parse("Proper Name <proper@email.com> old name <old@email.com>")
    let (name, email) = map.resolve("Old Name", "old@email.com")
    if (name != "Proper Name") {
        throw Exception("should match case-insensitive name, got '" + name + "'")
    }
}

@Test
func testMailmapParseVariousFormats(): Unit {
    // 对齐 Rust: valid_entries — 各种格式混合
    let content = "Jane <jane@proper.com>\n<proper@proper.com> <improper@proper.com>\nJane <jane@proper.com> Jane <jane@improper.com>"
    let map = Mailmap.parse(content)
    if (map.entries.size != 3) {
        throw Exception("should have 3 entries, got " + map.entries.size.toString())
    }
}
