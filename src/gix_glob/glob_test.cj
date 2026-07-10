// 文件：glob_test.cj
// 用途：gix_glob 包的单元测试，全量对齐 Rust gitoxide gix-glob 测试
// 所属包：gix.gix_glob
// 对齐来源：gix-glob/tests/{parse,pattern,wildmatch,search}.rs

package gitoxide.gix_glob

import std.unittest.*

// ============================================================
// Parse 测试 — 对齐 gix-glob/tests/parse/mod.rs
// ============================================================

@Test
func testParseWhitespaceOnlyIsIgnored(): Unit {
    // 对齐 Rust: parse::whitespace_only_is_ignored
    let p = Pattern.fromBytes("\n\r\n\t\t   \n".toArray())
    if (!p.isNone()) {
        throw Exception("whitespace-only pattern should return None")
    }
}

@Test
func testParseHashSymbolsAreNotSpecial(): Unit {
    // 对齐 Rust: parse::hash_symbols_are_not_special
    let p = Pattern.fromBytes("# hello world".toArray())
    if (p.isNone()) {
        throw Exception("# hello world should parse")
    }
    let pat = p.getOrThrow()
    if (pat.text != "# hello world") {
        throw Exception("text mismatch: " + pat.text)
    }
    if (!pat.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("should be NoSubDir")
    }
}

@Test
func testParseBackslashBeforeHashIsEscape(): Unit {
    // 对齐 Rust: parse::backslashes_before_hashes_are_considered_an_escape_sequence
    let p = Pattern.fromBytes("\\#hello".toArray())
    if (p.isNone()) {
        throw Exception("\\#hello should parse")
    }
    let pat = p.getOrThrow()
    if (pat.text != "#hello") {
        throw Exception("text should be #hello, got " + pat.text)
    }
}

@Test
func testParseBackslashNotInSpecificPosition(): Unit {
    // 对齐 Rust: parse::backslashes_are_part_of_the_pattern_if_not_in_specific_positions
    let p = Pattern.fromBytes("\\hello\\world".toArray())
    if (p.isNone()) {
        throw Exception("\\hello\\world should parse")
    }
    let pat = p.getOrThrow()
    if (pat.text != "\\hello\\world") {
        throw Exception("text mismatch: " + pat.text)
    }
}

@Test
func testParseLeadingExclamationMarkNegates(): Unit {
    // 对齐 Rust: parse::leading_exclamation_mark_negates_pattern
    let p = Pattern.fromBytes("!hello".toArray())
    if (p.isNone()) {
        throw Exception("!hello should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.mode.contains(ModeFlag.Negative)) {
        throw Exception("!hello should be Negative")
    }
    if (pat.text != "hello") {
        throw Exception("text should be hello, got " + pat.text)
    }
    // from_bytes_without_negation
    let p2 = Pattern.fromBytesWithoutNegation("!hello".toArray())
    if (p2.isNone()) {
        throw Exception("!hello without negation should parse")
    }
    let pat2 = p2.getOrThrow()
    if (pat2.mode.contains(ModeFlag.Negative)) {
        throw Exception("!hello without negation should NOT be Negative")
    }
    if (pat2.text != "!hello") {
        throw Exception("text should be !hello, got " + pat2.text)
    }
}

@Test
func testParseLeadingExclamationMarkEscapedWithBackslash(): Unit {
    // 对齐 Rust: parse::leading_exclamation_marks_can_be_escaped_with_backslash
    let p = Pattern.fromBytes("\\!hello".toArray())
    if (p.isNone()) {
        throw Exception("\\!hello should parse")
    }
    let pat = p.getOrThrow()
    if (pat.mode.contains(ModeFlag.Negative)) {
        throw Exception("\\!hello should NOT be Negative")
    }
    if (pat.text != "!hello") {
        throw Exception("text should be !hello, got " + pat.text)
    }
    // from_bytes_without_negation
    let p2 = Pattern.fromBytesWithoutNegation("\\!hello".toArray())
    if (p2.isNone()) {
        throw Exception("\\!hello without negation should parse")
    }
    let pat2 = p2.getOrThrow()
    if (pat2.text != "\\!hello") {
        throw Exception("text should be \\!hello, got " + pat2.text)
    }
}

@Test
func testParseLeadingSlashesMarkAbsolute(): Unit {
    // 对齐 Rust: parse::leading_slashes_mark_patterns_as_absolute
    let p1 = Pattern.fromBytes("/absolute".toArray())
    if (p1.isNone()) {
        throw Exception("/absolute should parse")
    }
    let pat1 = p1.getOrThrow()
    if (!pat1.mode.contains(ModeFlag.Absolute)) {
        throw Exception("/absolute should be Absolute")
    }
    if (!pat1.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("/absolute should be NoSubDir")
    }
    if (pat1.text != "absolute") {
        throw Exception("text should be absolute, got " + pat1.text)
    }

    let p2 = Pattern.fromBytes("/absolute/path".toArray())
    if (p2.isNone()) {
        throw Exception("/absolute/path should parse")
    }
    let pat2 = p2.getOrThrow()
    if (!pat2.mode.contains(ModeFlag.Absolute)) {
        throw Exception("/absolute/path should be Absolute")
    }
    if (pat2.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("/absolute/path should NOT be NoSubDir")
    }
}

@Test
func testParseAbsenceOfSubDirectoriesMarked(): Unit {
    // 对齐 Rust: parse::absence_of_sub_directories_are_marked
    let p1 = Pattern.fromBytes("a/b".toArray())
    if (p1.isNone()) {
        throw Exception("a/b should parse")
    }
    if (p1.getOrThrow().mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("a/b should NOT be NoSubDir")
    }

    let p2 = Pattern.fromBytes("ab".toArray())
    if (p2.isNone()) {
        throw Exception("ab should parse")
    }
    if (!p2.getOrThrow().mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("ab should be NoSubDir")
    }
}

@Test
func testParseTrailingSlashesMarkedAndRemoved(): Unit {
    // 对齐 Rust: parse::trailing_slashes_are_marked_and_removed
    let p1 = Pattern.fromBytes("dir/".toArray())
    if (p1.isNone()) {
        throw Exception("dir/ should parse")
    }
    let pat1 = p1.getOrThrow()
    if (!pat1.mode.contains(ModeFlag.MustBeDir)) {
        throw Exception("dir/ should be MustBeDir")
    }
    if (!pat1.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("dir/ should be NoSubDir")
    }
    if (pat1.text != "dir") {
        throw Exception("text should be dir, got " + pat1.text)
    }

    // dir/// — 只移除最后一个 /
    let p2 = Pattern.fromBytes("dir///".toArray())
    if (p2.isNone()) {
        throw Exception("dir/// should parse")
    }
    let pat2 = p2.getOrThrow()
    if (!pat2.mode.contains(ModeFlag.MustBeDir)) {
        throw Exception("dir/// should be MustBeDir")
    }
    if (pat2.text != "dir//") {
        throw Exception("text should be dir//, got " + pat2.text)
    }
}

@Test
func testParseTrailingSpacesTakenLiterally(): Unit {
    // 对齐 Rust: parse::trailing_spaces_are_taken_literally
    let p1 = Pattern.fromBytes("a   ".toArray())
    if (p1.isNone()) {
        throw Exception("a   should parse")
    }
    if (p1.getOrThrow().text != "a   ") {
        throw Exception("text should be 'a   '")
    }

    let p2 = Pattern.fromBytes("a\t\t  ".toArray())
    if (p2.isNone()) {
        throw Exception("a\\t\\t  should parse")
    }
    if (p2.getOrThrow().text != "a\t\t  ") {
        throw Exception("text should be 'a\\t\\t  '")
    }
}

@Test
func testParseEndsWithPatternSpecifically(): Unit {
    // 对齐 Rust: parse::mark_ends_with_pattern_specifically
    // *literal → EndsWith + NoSubDir
    let p1 = Pattern.fromBytes("*literal".toArray())
    if (p1.isNone()) {
        throw Exception("*literal should parse")
    }
    let pat1 = p1.getOrThrow()
    if (!pat1.mode.contains(ModeFlag.EndsWith)) {
        throw Exception("*literal should be EndsWith")
    }
    if (!pat1.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("*literal should be NoSubDir")
    }

    // **literal → NOT EndsWith (double star won't allow fast comparisons)
    let p2 = Pattern.fromBytes("**literal".toArray())
    if (p2.isNone()) {
        throw Exception("**literal should parse")
    }
    if (p2.getOrThrow().mode.contains(ModeFlag.EndsWith)) {
        throw Exception("**literal should NOT be EndsWith")
    }

    // *litera[l] → EndsWith（[l] 仍视为通配符，但 first_wildcard_pos 在 0）
    let p3 = Pattern.fromBytes("*litera[l]".toArray())
    if (p3.isNone()) {
        throw Exception("*litera[l] should parse")
    }
    if (!p3.getOrThrow().mode.contains(ModeFlag.EndsWith)) {
        throw Exception("*litera[l] should be EndsWith")
    }

    // *litera? → EndsWith
    let p4 = Pattern.fromBytes("*litera?".toArray())
    if (p4.isNone()) {
        throw Exception("*litera? should parse")
    }
    if (!p4.getOrThrow().mode.contains(ModeFlag.EndsWith)) {
        throw Exception("*litera? should be EndsWith")
    }
}

// ============================================================
// Pattern Display 测试 — 对齐 gix-glob/tests/pattern/mod.rs
// ============================================================

@Test
func testPatternDisplay(): Unit {
    // 对齐 Rust: pattern::display
    // ABSOLUTE → /a
    let m1 = Mode()
    m1.insert(ModeFlag.Absolute)
    let p1 = Pattern("a", m1, None)
    if (p1.display() != "/a") {
        throw Exception("display should be /a, got " + p1.display())
    }
    // MUST_BE_DIR → a/
    let m2 = Mode()
    m2.insert(ModeFlag.MustBeDir)
    let p2 = Pattern("a", m2, None)
    if (p2.display() != "a/") {
        throw Exception("display should be a/, got " + p2.display())
    }
    // NEGATIVE → !a
    let m3 = Mode()
    m3.insert(ModeFlag.Negative)
    let p3 = Pattern("a", m3, None)
    if (p3.display() != "!a") {
        throw Exception("display should be !a, got " + p3.display())
    }
    // ABSOLUTE | NEGATIVE | MUST_BE_DIR → !/a/
    let m4 = Mode()
    m4.insert(ModeFlag.Absolute)
    m4.insert(ModeFlag.Negative)
    m4.insert(ModeFlag.MustBeDir)
    let p4 = Pattern("a", m4, None)
    if (p4.display() != "!/a/") {
        throw Exception("display should be !/a/, got " + p4.display())
    }
}

// ============================================================
// Pattern Matching 测试 — 对齐 gix-glob/tests/pattern/matching.rs
// ============================================================

@Test
func testPatternMatchesStar(): Unit {
    // 对齐 Rust: pattern matching with *
    let p = Pattern.fromBytes("*.rs".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.matches("main.rs")) {
        throw Exception("*.rs should match main.rs")
    }
    if (!pat.matches("lib.rs")) {
        throw Exception("*.rs should match lib.rs")
    }
    if (pat.matches("main.cj")) {
        throw Exception("*.rs should not match main.cj")
    }
}

@Test
func testPatternMatchesQuestionMark(): Unit {
    // 对齐 Rust: pattern matching with ?
    let p = Pattern.fromBytes("?.rs".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.matches("a.rs")) {
        throw Exception("?.rs should match a.rs")
    }
    if (pat.matches("ab.rs")) {
        throw Exception("?.rs should not match ab.rs")
    }
}

@Test
func testPatternMatchesLiteral(): Unit {
    // 对齐 Rust: pattern matching with literal
    let p = Pattern.fromBytes("hello".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.matches("hello")) {
        throw Exception("'hello' should match 'hello'")
    }
    if (pat.matches("world")) {
        throw Exception("'hello' should not match 'world'")
    }
}

@Test
func testPatternMatchesNegated(): Unit {
    // 对齐 Rust: negated pattern matching
    let p = Pattern.fromBytes("!*.class".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (pat.matches("Main.class")) {
        throw Exception("!*.class should NOT match Main.class (negated)")
    }
    if (!pat.matches("Main.java")) {
        throw Exception("!*.class should match Main.java (negated)")
    }
}

@Test
func testPatternMatchesDoubleStar(): Unit {
    // 对齐 Rust: pattern matching with **
    let p = Pattern.fromBytes("src/**/*.rs".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.matches("src/main.rs")) {
        throw Exception("src/**/*.rs should match src/main.rs")
    }
    if (!pat.matches("src/sub/mod.rs")) {
        throw Exception("src/**/*.rs should match src/sub/mod.rs")
    }
}

@Test
func testPatternNoMatch(): Unit {
    // 对齐 Rust: pattern no match
    let p = Pattern.fromBytes("*.txt".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (pat.matches("main.rs")) {
        throw Exception("*.txt should not match main.rs")
    }
}

@Test
func testPatternMatchesStarAll(): Unit {
    // 对齐 Rust: pattern matching with *
    let p = Pattern.fromBytes("*".toArray())
    if (p.isNone()) {
        throw Exception("pattern should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.matches("anything")) {
        throw Exception("* should match anything")
    }
}

@Test
func testPatternFromBytesSimple(): Unit {
    // 对齐 Rust: Pattern::from_bytes(b"*.rs")
    let p = Pattern.fromBytes("*.rs".toArray())
    if (p.isNone()) {
        throw Exception("*.rs should parse")
    }
    let pat = p.getOrThrow()
    if (pat.text != "*.rs") {
        throw Exception("pattern text mismatch: " + pat.text)
    }
    if (!pat.mode.contains(ModeFlag.NoSubDir)) {
        throw Exception("*.rs should be NoSubDir")
    }
    if (pat.mode.contains(ModeFlag.Negative)) {
        throw Exception("*.rs should not be Negative")
    }
}

@Test
func testPatternFromBytesNegated(): Unit {
    // 对齐 Rust: Pattern::from_bytes(b"!*.class")
    let p = Pattern.fromBytes("!*.class".toArray())
    if (p.isNone()) {
        throw Exception("!*.class should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.mode.contains(ModeFlag.Negative)) {
        throw Exception("!*.class should be Negative")
    }
    if (pat.text != "*.class") {
        throw Exception("pattern text should be '*.class', got '" + pat.text + "'")
    }
}

@Test
func testPatternFromBytesEscapedNegation(): Unit {
    // 对齐 Rust: Pattern::from_bytes(b"\\!important")
    let p = Pattern.fromBytes("\\!important".toArray())
    if (p.isNone()) {
        throw Exception("\\!important should parse")
    }
    let pat = p.getOrThrow()
    if (pat.mode.contains(ModeFlag.Negative)) {
        throw Exception("\\!important should not be Negative")
    }
    if (pat.text != "!important") {
        throw Exception("pattern text should be '!important', got '" + pat.text + "'")
    }
}

@Test
func testPatternFromBytesDirectory(): Unit {
    // 对齐 Rust: Pattern::from_bytes(b"build/") → MustBeDir
    let p = Pattern.fromBytes("build/".toArray())
    if (p.isNone()) {
        throw Exception("build/ should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.mode.contains(ModeFlag.MustBeDir)) {
        throw Exception("build/ should be MustBeDir")
    }
}

@Test
func testPatternFromBytesEmpty(): Unit {
    // 对齐 Rust: Pattern::from_bytes(b"") → None
    let p = Pattern.fromBytes("".toArray())
    if (!p.isNone()) {
        throw Exception("empty pattern should return None")
    }
}

@Test
func testNonDirsForMustBeDirPatternsAreIgnored(): Unit {
    // 对齐 Rust: pattern::matching::non_dirs_for_must_be_dir_patterns_are_ignored
    let p = Pattern.fromBytes("hello/".toArray())
    if (p.isNone()) {
        throw Exception("hello/ should parse")
    }
    let pat = p.getOrThrow()
    if (!pat.mode.contains(ModeFlag.MustBeDir)) {
        throw Exception("hello/ should be MustBeDir")
    }
    if (pat.text != "hello") {
        throw Exception("text should be hello, got " + pat.text)
    }
    // is_dir=false → 不匹配
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    if (pat.matchesRepoRelativePath("hello", None, Some(false), Case.Sensitive, wmMode)) {
        throw Exception("non-dirs should not match a dir pattern")
    }
    // is_dir=true → 匹配
    if (!pat.matchesRepoRelativePath("hello", None, Some(true), Case.Sensitive, wmMode)) {
        throw Exception("dirs should match a dir pattern")
    }
}

@Test
func testBasenameMatchesFromEnd(): Unit {
    // 对齐 Rust: pattern::matching::basename_matches_from_end
    let p = Pattern.fromBytes("foo".toArray())
    if (p.isNone()) {
        throw Exception("foo should parse")
    }
    let pat = p.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    // Case.Fold
    if (!pat.matchesRepoRelativePath("FoO", None, None, Case.Fold, wmMode)) {
        throw Exception("foo should match FoO case-insensitive")
    }
    if (pat.matchesRepoRelativePath("FoOo", None, None, Case.Fold, wmMode)) {
        throw Exception("foo should not match FoOo case-insensitive")
    }
    // Case.Sensitive
    if (pat.matchesRepoRelativePath("Foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("foo should not match Foo case-sensitive")
    }
    if (!pat.matchesRepoRelativePath("foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("foo should match foo case-sensitive")
    }
    if (pat.matchesRepoRelativePath("barfoo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("foo should not match barfoo case-sensitive")
    }
}

@Test
func testAbsoluteBasenameMatchesOnlyFromBeginning(): Unit {
    // 对齐 Rust: pattern::matching::absolute_basename_matches_only_from_beginning
    let p = Pattern.fromBytes("/foo".toArray())
    if (p.isNone()) {
        throw Exception("/foo should parse")
    }
    let pat = p.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    if (!pat.matchesRepoRelativePath("FoO", None, None, Case.Fold, wmMode)) {
        throw Exception("/foo should match FoO case-fold")
    }
    if (pat.matchesRepoRelativePath("bar/Foo", None, None, Case.Fold, wmMode)) {
        throw Exception("/foo should not match bar/Foo case-fold")
    }
    if (!pat.matchesRepoRelativePath("foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("/foo should match foo case-sensitive")
    }
    if (pat.matchesRepoRelativePath("Foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("/foo should not match Foo case-sensitive")
    }
    if (pat.matchesRepoRelativePath("bar/foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("/foo should not match bar/foo case-sensitive")
    }
}

@Test
func testNamesDoNotAutomaticallyMatchEntireDirectories(): Unit {
    // 对齐 Rust: pattern::matching::names_do_not_automatically_match_entire_directories
    let p = Pattern.fromBytes("foo".toArray())
    if (p.isNone()) {
        throw Exception("foo should parse")
    }
    let pat = p.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    if (pat.matchesRepoRelativePath("foobar", None, None, Case.Sensitive, wmMode)) {
        throw Exception("foo should not match foobar")
    }
    if (pat.matchesRepoRelativePath("foo/bar", None, None, Case.Sensitive, wmMode)) {
        throw Exception("foo should not match foo/bar")
    }
}

@Test
func testNegatedPatternsAreHandledByCaller(): Unit {
    // 对齐 Rust: pattern::matching::negated_patterns_are_handled_by_caller
    let p = Pattern.fromBytes("!foo".toArray())
    if (p.isNone()) {
        throw Exception("!foo should parse")
    }
    let pat = p.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    if (!pat.matchesRepoRelativePath("foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("negative patterns match like any other")
    }
    if (!pat.isNegative()) {
        throw Exception("the caller checks for the negative flag")
    }
}

@Test
func testSinglePathsMatchAnywhere(): Unit {
    // 对齐 Rust: pattern::matching::single_paths_match_anywhere
    let p1 = Pattern.fromBytes("target".toArray())
    if (p1.isNone()) {
        throw Exception("target should parse")
    }
    let pat1 = p1.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    if (!pat1.matchesRepoRelativePath("dir/target", None, None, Case.Sensitive, wmMode)) {
        throw Exception("target should match dir/target")
    }
    if (pat1.matchesRepoRelativePath("dir/atarget", None, None, Case.Sensitive, wmMode)) {
        throw Exception("target should not match dir/atarget")
    }
    if (pat1.matchesRepoRelativePath("dir/targeta", None, None, Case.Sensitive, wmMode)) {
        throw Exception("target should not match dir/targeta")
    }
}

@Test
func testBasenameGlobAndLiteralIsEndsWith(): Unit {
    // 对齐 Rust: pattern::matching::basename_glob_and_literal_is_ends_with
    let p = Pattern.fromBytes("*foo".toArray())
    if (p.isNone()) {
        throw Exception("*foo should parse")
    }
    let pat = p.getOrThrow()
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    // Case.Fold
    if (!pat.matchesRepoRelativePath("FoO", None, None, Case.Fold, wmMode)) {
        throw Exception("*foo should match FoO case-fold")
    }
    if (!pat.matchesRepoRelativePath("BarFoO", None, None, Case.Fold, wmMode)) {
        throw Exception("*foo should match BarFoO case-fold")
    }
    if (pat.matchesRepoRelativePath("BarFoOo", None, None, Case.Fold, wmMode)) {
        throw Exception("*foo should not match BarFoOo case-fold")
    }
    // Case.Sensitive
    if (pat.matchesRepoRelativePath("Foo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("*foo should not match Foo case-sensitive")
    }
    if (!pat.matchesRepoRelativePath("barfoo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("*foo should match barfoo case-sensitive")
    }
    if (pat.matchesRepoRelativePath("barfooo", None, None, Case.Sensitive, wmMode)) {
        throw Exception("*foo should not match barfooo case-sensitive")
    }
}

@Test
func testSpecialCasesFromCorpus(): Unit {
    // 对齐 Rust: pattern::matching::special_cases_from_corpus
    let wmMode = WildmatchMode.withNoMatchSlashLiteral()
    let p1 = Pattern.fromBytes("foo*bar".toArray())
    if (p1.isNone()) {
        throw Exception("foo*bar should parse")
    }
    if (p1.getOrThrow().matchesRepoRelativePath("foo/baz/bar", None, None, Case.Sensitive, wmMode)) {
        throw Exception("asterisk does not match path separators")
    }

    let p2 = Pattern.fromBytes("*some/path/to/hello.txt".toArray())
    if (p2.isNone()) {
        throw Exception("pattern should parse")
    }
    if (p2.getOrThrow().matchesRepoRelativePath("a/bigger/some/path/to/hello.txt", None, None, Case.Sensitive, wmMode)) {
        throw Exception("asterisk doesn't match path separators")
    }
}

// ============================================================
// Wildmatch 测试 — 对齐 gix-glob/tests/wildmatch/mod.rs
// ============================================================

@Test
func testWildmatchBasicPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (basic patterns)
    let wmEmpty = WildmatchMode.empty()
    // foo == foo
    if (!wildmatch("foo", "foo", wmEmpty)) {
        throw Exception("foo should match foo")
    }
    // foo != bar
    if (wildmatch("foo", "bar", wmEmpty)) {
        throw Exception("foo should not match bar")
    }
    // foo == ???
    if (!wildmatch("???", "foo", wmEmpty)) {
        throw Exception("??? should match foo")
    }
    // foo != ??
    if (wildmatch("??", "foo", wmEmpty)) {
        throw Exception("?? should not match foo")
    }
    // foo == *
    if (!wildmatch("*", "foo", wmEmpty)) {
        throw Exception("* should match foo")
    }
    // foo == f*
    if (!wildmatch("f*", "foo", wmEmpty)) {
        throw Exception("f* should match foo")
    }
    // foo != *f
    if (wildmatch("*f", "foo", wmEmpty)) {
        throw Exception("*f should not match foo")
    }
    // foo == *foo*
    if (!wildmatch("*foo*", "foo", wmEmpty)) {
        throw Exception("*foo* should match foo")
    }
    // foobar == *ob*a*r*
    if (!wildmatch("*ob*a*r*", "foobar", wmEmpty)) {
        throw Exception("*ob*a*r* should match foobar")
    }
    // aaaaaaabababab == *ab
    if (!wildmatch("*ab", "aaaaaaabababab", wmEmpty)) {
        throw Exception("*ab should match aaaaaaabababab")
    }
}

@Test
func testWildmatchEscapedStar(): Unit {
    // 对齐 Rust: wildmatch::corpus (escaped star)
    let wmEmpty = WildmatchMode.empty()
    // foo* == foo\*
    if (!wildmatch("foo\\*", "foo*", wmEmpty)) {
        throw Exception("foo\\* should match foo*")
    }
    // foobar != foo\*bar
    if (wildmatch("foo\\*bar", "foobar", wmEmpty)) {
        throw Exception("foo\\*bar should not match foobar")
    }
    // f\oo == f\\oo
    if (!wildmatch("f\\\\oo", "f\\oo", wmEmpty)) {
        throw Exception("f\\\\oo should match f\\oo")
    }
}

@Test
func testWildmatchCharacterClasses(): Unit {
    // 对齐 Rust: wildmatch::corpus (character classes)
    let wmEmpty = WildmatchMode.empty()
    // ball == *[al]?
    if (!wildmatch("*[al]?", "ball", wmEmpty)) {
        throw Exception("*[al]? should match ball")
    }
    // ten != [ten]
    if (wildmatch("[ten]", "ten", wmEmpty)) {
        throw Exception("[ten] should not match ten")
    }
    // ten == **[!te]
    if (!wildmatch("**[!te]", "ten", wmEmpty)) {
        throw Exception("**[!te] should match ten")
    }
    // ten != **[!ten]
    if (wildmatch("**[!ten]", "ten", wmEmpty)) {
        throw Exception("**[!ten] should not match ten")
    }
    // ten == t[a-g]n
    if (!wildmatch("t[a-g]n", "ten", wmEmpty)) {
        throw Exception("t[a-g]n should match ten")
    }
    // ten != t[!a-g]n
    if (wildmatch("t[!a-g]n", "ten", wmEmpty)) {
        throw Exception("t[!a-g]n should not match ten")
    }
    // ton == t[!a-g]n
    if (!wildmatch("t[!a-g]n", "ton", wmEmpty)) {
        throw Exception("t[!a-g]n should match ton")
    }
    // ton == t[^a-g]n
    if (!wildmatch("t[^a-g]n", "ton", wmEmpty)) {
        throw Exception("t[^a-g]n should match ton")
    }
}

@Test
func testWildmatchBracketEdgeCases(): Unit {
    // 对齐 Rust: wildmatch::corpus (bracket edge cases)
    let wmEmpty = WildmatchMode.empty()
    // a]b == a[]]b
    if (!wildmatch("a[]]b", "a]b", wmEmpty)) {
        throw Exception("a[]]b should match a]b")
    }
    // a-b == a[]-]b
    if (!wildmatch("a[]-]b", "a-b", wmEmpty)) {
        throw Exception("a[]-]b should match a-b")
    }
    // a]b == a[]-]b
    if (!wildmatch("a[]-]b", "a]b", wmEmpty)) {
        throw Exception("a[]-]b should match a]b")
    }
    // aab != a[]-]b
    if (wildmatch("a[]-]b", "aab", wmEmpty)) {
        throw Exception("a[]-]b should not match aab")
    }
    // aab == a[]a-]b
    if (!wildmatch("a[]a-]b", "aab", wmEmpty)) {
        throw Exception("a[]a-]b should match aab")
    }
    // ] == ]
    if (!wildmatch("]", "]", wmEmpty)) {
        throw Exception("] should match ]")
    }
}

@Test
func testWildmatchSlashMatching(): Unit {
    // 对齐 Rust: wildmatch::corpus (slash matching)
    let wmEmpty = WildmatchMode.empty()
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    // foo/baz/bar != foo*bar (path mode)
    if (wildmatch("foo*bar", "foo/baz/bar", wmPath)) {
        throw Exception("foo*bar should not match foo/baz/bar in path mode")
    }
    // foo/baz/bar != foo**bar (path mode)
    if (wildmatch("foo**bar", "foo/baz/bar", wmPath)) {
        throw Exception("foo**bar should not match foo/baz/bar in path mode")
    }
    // foobazbar == foo**bar (non-path)
    if (!wildmatch("foo**bar", "foobazbar", wmEmpty)) {
        throw Exception("foo**bar should match foobazbar")
    }
    // foo/baz/bar == foo/**/bar
    if (!wildmatch("foo/**/bar", "foo/baz/bar", wmPath)) {
        throw Exception("foo/**/bar should match foo/baz/bar")
    }
    // foo/b/a/z/bar == foo/**/bar
    if (!wildmatch("foo/**/bar", "foo/b/a/z/bar", wmPath)) {
        throw Exception("foo/**/bar should match foo/b/a/z/bar")
    }
    // foo/bar != foo?bar (path mode)
    if (wildmatch("foo?bar", "foo/bar", wmPath)) {
        throw Exception("foo?bar should not match foo/bar in path mode")
    }
}

@Test
func testWildmatchDoubleStarPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (** patterns)
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    let wmEmpty = WildmatchMode.empty()
    // foo != **/foo (non-path) — 对齐 Rust: glob_match=0
    if (wildmatch("**/foo", "foo", wmEmpty)) {
        throw Exception("**/foo should not match foo in non-path mode")
    }
    // foo == **/foo (path mode)
    if (!wildmatch("**/foo", "foo", wmPath)) {
        throw Exception("**/foo should match foo in path mode")
    }
    // XXX/foo == **/foo (path mode)
    if (!wildmatch("**/foo", "XXX/foo", wmPath)) {
        throw Exception("**/foo should match XXX/foo")
    }
    // bar/baz/foo == **/foo (path mode)
    if (!wildmatch("**/foo", "bar/baz/foo", wmPath)) {
        throw Exception("**/foo should match bar/baz/foo")
    }
    // bar/baz/foo != */foo (path mode)
    if (wildmatch("*/foo", "bar/baz/foo", wmPath)) {
        throw Exception("*/foo should not match bar/baz/foo in path mode")
    }
    // deep/foo/bar/baz == **/bar/*
    if (!wildmatch("**/bar/*", "deep/foo/bar/baz", wmPath)) {
        throw Exception("**/bar/* should match deep/foo/bar/baz")
    }
    // deep/foo/bar/ == **/bar/**
    if (!wildmatch("**/bar/**", "deep/foo/bar/", wmPath)) {
        throw Exception("**/bar/** should match deep/foo/bar/")
    }
}

@Test
func testWildmatchRangePatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (range patterns)
    let wmEmpty = WildmatchMode.empty()
    // - == [-]
    if (!wildmatch("[-]", "-", wmEmpty)) {
        throw Exception("[-] should match -")
    }
    // - == [------]
    if (!wildmatch("[------]", "-", wmEmpty)) {
        throw Exception("[------] should match -")
    }
    // - == [---]
    if (!wildmatch("[---]", "-", wmEmpty)) {
        throw Exception("[---] should match -")
    }
    // - == [a-e-n]
    if (!wildmatch("[a-e-n]", "-", wmEmpty)) {
        throw Exception("[a-e-n] should match -")
    }
    // j != [a-e-n]
    if (wildmatch("[a-e-n]", "j", wmEmpty)) {
        throw Exception("[a-e-n] should not match j")
    }
}

@Test
func testWildmatchRecursionPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (recursion)
    let wmEmpty = WildmatchMode.empty()
    // -adobe-courier-bold-o-normal--12-120-75-75-m-70-iso8859-1
    // == -*-*-*-*-*-*-12-*-*-*-m-*-*-*
    if (!wildmatch(
        "-*-*-*-*-*-*-12-*-*-*-m-*-*-*",
        "-adobe-courier-bold-o-normal--12-120-75-75-m-70-iso8859-1",
        wmEmpty
    )) {
        throw Exception("complex wildcard should match")
    }
    // Same pattern but with X instead of m → should NOT match
    if (wildmatch(
        "-*-*-*-*-*-*-12-*-*-*-m-*-*-*",
        "-adobe-courier-bold-o-normal--12-120-75-75-X-70-iso8859-1",
        wmEmpty
    )) {
        throw Exception("complex wildcard should not match with X")
    }
}

@Test
func testWildmatchPathPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (path patterns)
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    let wmEmpty = WildmatchMode.empty()
    // foo != foo (too short)
    if (wildmatch("*/*/*", "foo", wmPath)) {
        throw Exception("*/*/* should not match foo")
    }
    if (wildmatch("*/*/*", "foo/bar", wmPath)) {
        throw Exception("*/*/* should not match foo/bar")
    }
    // foo/bba/arr == */*/*
    if (!wildmatch("*/*/*", "foo/bba/arr", wmPath)) {
        throw Exception("*/*/* should match foo/bba/arr")
    }
    // foo/bb/aa/rr == **/**/**
    if (!wildmatch("**/**/**", "foo/bb/aa/rr", wmPath)) {
        throw Exception("**/**/** should match foo/bb/aa/rr")
    }
    // abcXdefXghi == *X*i
    if (!wildmatch("*X*i", "abcXdefXghi", wmEmpty)) {
        throw Exception("*X*i should match abcXdefXghi")
    }
}

@Test
func testWildmatchExtraPathTests(): Unit {
    // 对齐 Rust: wildmatch::corpus (extra path tests)
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    let wmEmpty = WildmatchMode.empty()
    // foo != fo
    if (wildmatch("fo", "foo", wmEmpty)) {
        throw Exception("fo should not match foo")
    }
    // foo/bar == foo/bar
    if (!wildmatch("foo/bar", "foo/bar", wmPath)) {
        throw Exception("foo/bar should match foo/bar")
    }
    // foo/bar == foo/*
    if (!wildmatch("foo/*", "foo/bar", wmPath)) {
        throw Exception("foo/* should match foo/bar")
    }
    // foo/bba/arr == foo/**
    if (!wildmatch("foo/**", "foo/bba/arr", wmPath)) {
        throw Exception("foo/** should match foo/bba/arr")
    }
}

@Test
func testWildmatchCaseSensitivity(): Unit {
    // 对齐 Rust: wildmatch::corpus (case sensitivity)
    let wmEmpty = WildmatchMode.empty()
    let wmIcase = WildmatchMode.withIgnoreCase()
    // a != [A-Z] case-sensitive
    if (wildmatch("[A-Z]", "a", wmEmpty)) {
        throw Exception("[A-Z] should not match a case-sensitive")
    }
    // a == [A-Z] case-insensitive
    if (!wildmatch("[A-Z]", "a", wmIcase)) {
        throw Exception("[A-Z] should match a case-insensitive")
    }
    // A == [A-Z] case-sensitive
    if (!wildmatch("[A-Z]", "A", wmEmpty)) {
        throw Exception("[A-Z] should match A case-sensitive")
    }
    // A != [a-z] case-sensitive
    if (wildmatch("[a-z]", "A", wmEmpty)) {
        throw Exception("[a-z] should not match A case-sensitive")
    }
    // a == [a-z] case-sensitive
    if (!wildmatch("[a-z]", "a", wmEmpty)) {
        throw Exception("[a-z] should match a case-sensitive")
    }
}

@Test
func testWildmatchPosixClasses(): Unit {
    // 对齐 Rust: wildmatch::corpus (POSIX character classes)
    let wmEmpty = WildmatchMode.empty()
    // a1B == [[:alpha:]][[:digit:]][[:upper:]]
    if (!wildmatch("[[:alpha:]][[:digit:]][[:upper:]]", "a1B", wmEmpty)) {
        throw Exception("POSIX class pattern should match a1B")
    }
    // 5 == [[:xdigit:]]
    if (!wildmatch("[[:xdigit:]]", "5", wmEmpty)) {
        throw Exception("[[:xdigit:]] should match 5")
    }
    // f == [[:xdigit:]]
    if (!wildmatch("[[:xdigit:]]", "f", wmEmpty)) {
        throw Exception("[[:xdigit:]] should match f")
    }
    // D == [[:xdigit:]]
    if (!wildmatch("[[:xdigit:]]", "D", wmEmpty)) {
        throw Exception("[[:xdigit:]] should match D")
    }
}

@Test
func testWildmatchMiscPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (misc patterns)
    let wmEmpty = WildmatchMode.empty()
    // , == [,]
    if (!wildmatch("[,]", ",", wmEmpty)) {
        throw Exception("[,] should match ,")
    }
    // - == [,-.]
    if (!wildmatch("[,-.]", "-", wmEmpty)) {
        throw Exception("[,-.] should match -")
    }
    // + != [,-.]
    if (wildmatch("[,-.]", "+", wmEmpty)) {
        throw Exception("[,-.] should not match +")
    }
    // foo == @foo
    if (!wildmatch("@foo", "@foo", wmEmpty)) {
        throw Exception("@foo should match @foo")
    }
    // foo != @foo
    if (wildmatch("@foo", "foo", wmEmpty)) {
        throw Exception("@foo should not match foo")
    }
}

@Test
func testWildmatchPathglobStarPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (pathglob star patterns)
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    // abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txt == **/*a*b*g*n*t
    if (!wildmatch("**/*a*b*g*n*t", "abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txt", wmPath)) {
        throw Exception("**/*a*b*g*n*t should match long path")
    }
    // abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txtz != **/*a*b*g*n*t
    if (wildmatch("**/*a*b*g*n*t", "abcd/abcdefg/abcdefghijk/abcdefghijklmnop.txtz", wmPath)) {
        throw Exception("**/*a*b*g*n*t should not match long path with z")
    }
}

@Test
func testWildmatchEscapedBrackets(): Unit {
    // 对齐 Rust: wildmatch::corpus (escaped brackets)
    let wmEmpty = WildmatchMode.empty()
    // [ab] == \[ab]
    if (!wildmatch("\\[ab]", "[ab]", wmEmpty)) {
        throw Exception("\\[ab] should match [ab]")
    }
    // [ab] == [[]ab]
    if (!wildmatch("[[]ab]", "[ab]", wmEmpty)) {
        throw Exception("[[]ab] should match [ab]")
    }
    // ?a?b == \??\?b
    if (!wildmatch("\\??\\?b", "?a?b", wmEmpty)) {
        throw Exception("\\??\\?b should match ?a?b")
    }
    // abc == \a\b\c
    if (!wildmatch("\\a\\b\\c", "abc", wmEmpty)) {
        throw Exception("\\a\\b\\c should match abc")
    }
}

@Test
func testWildmatchBracketDashPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (bracket dash patterns)
    let wmEmpty = WildmatchMode.empty()
    // ] == [\\-^]
    if (!wildmatch("[\\\\-^]", "]", wmEmpty)) {
        throw Exception("[\\\\-^] should match ]")
    }
    // - == [\-_]
    if (!wildmatch("[\\-_]", "-", wmEmpty)) {
        throw Exception("[\\-_] should match -")
    }
    // ] == [\]]
    if (!wildmatch("[\\]]", "]", wmEmpty)) {
        throw Exception("[\\]] should match ]")
    }
    // - == [--A]
    if (!wildmatch("[--A]", "-", wmEmpty)) {
        throw Exception("[--A] should match -")
    }
    // 5 == [--A]
    if (!wildmatch("[--A]", "5", wmEmpty)) {
        throw Exception("[--A] should match 5")
    }
}

@Test
func testWildmatchMalformedPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (malformed patterns)
    let wmEmpty = WildmatchMode.empty()
    // ab != a[]b (empty bracket expression)
    if (wildmatch("a[]b", "ab", wmEmpty)) {
        throw Exception("a[]b should not match ab")
    }
    // ab != [! (malformed)
    if (wildmatch("[!", "ab", wmEmpty)) {
        throw Exception("[! should not match ab")
    }
    // ab != [- (malformed)
    if (wildmatch("[-", "ab", wmEmpty)) {
        throw Exception("[- should not match ab")
    }
    // - == [-]
    if (!wildmatch("[-]", "-", wmEmpty)) {
        throw Exception("[-] should match -")
    }
    // - != [a- (malformed)
    if (wildmatch("[a-", "-", wmEmpty)) {
        throw Exception("[a- should not match -")
    }
    // - != [!a- (malformed)
    if (wildmatch("[!a-", "-", wmEmpty)) {
        throw Exception("[!a- should not match -")
    }
}

@Test
func testWildmatchBracketsTest(): Unit {
    // 对齐 Rust: wildmatch::brackets
    let wmEmpty = WildmatchMode.empty()
    let wmIcase = WildmatchMode.withIgnoreCase()
    // A != [B-a] case-sensitive
    if (wildmatch("[B-a]", "A", wmEmpty)) {
        throw Exception("[B-a] should not match A case-sensitive")
    }
    // A == [B-a] case-insensitive
    if (!wildmatch("[B-a]", "A", wmIcase)) {
        throw Exception("[B-a] should match A case-insensitive")
    }
}

@Test
func testWildmatchMixedRangeAndClass(): Unit {
    // 对齐 Rust: wildmatch::corpus (mixed range and class)
    let wmEmpty = WildmatchMode.empty()
    // 5 == [a-c[:digit:]x-z]
    if (!wildmatch("[a-c[:digit:]x-z]", "5", wmEmpty)) {
        throw Exception("[a-c[:digit:]x-z] should match 5")
    }
    // b == [a-c[:digit:]x-z]
    if (!wildmatch("[a-c[:digit:]x-z]", "b", wmEmpty)) {
        throw Exception("[a-c[:digit:]x-z] should match b")
    }
    // y == [a-c[:digit:]x-z]
    if (!wildmatch("[a-c[:digit:]x-z]", "y", wmEmpty)) {
        throw Exception("[a-c[:digit:]x-z] should match y")
    }
    // q != [a-c[:digit:]x-z]
    if (wildmatch("[a-c[:digit:]x-z]", "q", wmEmpty)) {
        throw Exception("[a-c[:digit:]x-z] should not match q")
    }
}

@Test
func testWildmatchNegatedBracketRange(): Unit {
    // 对齐 Rust: wildmatch::corpus (negated bracket range)
    let wmEmpty = WildmatchMode.empty()
    // a == [!------]
    if (!wildmatch("[!------]", "a", wmEmpty)) {
        throw Exception("[!------] should match a")
    }
    // ^ == [a^bc]
    if (!wildmatch("[a^bc]", "^", wmEmpty)) {
        throw Exception("[a^bc] should match ^")
    }
    // -b] == [a-]b]
    if (!wildmatch("[a-]b]", "-b]", wmEmpty)) {
        throw Exception("[a-]b] should match -b]")
    }
}

@Test
func testWildmatchSlashInPattern(): Unit {
    // 对齐 Rust: wildmatch::corpus (slash in pattern)
    let wmPath = WildmatchMode.withNoMatchSlashLiteral()
    // foo/bar/baz/to == **/t[o]
    if (!wildmatch("**/t[o]", "foo/bar/baz/to", wmPath)) {
        throw Exception("**/t[o] should match foo/bar/baz/to")
    }
    // ab/cXd/efXg/hi == **/*X*/**/*i
    if (!wildmatch("**/*X*/**/*i", "ab/cXd/efXg/hi", wmPath)) {
        throw Exception("**/*X*/**/*i should match ab/cXd/efXg/hi")
    }
}

@Test
func testWildmatchBackslashPatterns(): Unit {
    // 对齐 Rust: wildmatch::corpus (backslash patterns)
    let wmEmpty = WildmatchMode.empty()
    // \ != [\]
    if (wildmatch("[\\]", "\\", wmEmpty)) {
        throw Exception("[\\] should not match \\")
    }
    // \ == [\\]
    if (!wildmatch("[\\\\]", "\\", wmEmpty)) {
        throw Exception("[\\\\] should match \\")
    }
    // \ != [!\\]
    if (wildmatch("[!\\\\]", "\\", wmEmpty)) {
        throw Exception("[!\\\\] should not match \\")
    }
    // G == [A-\\]
    if (!wildmatch("[A-\\\\]", "G", wmEmpty)) {
        throw Exception("[A-\\\\] should match G")
    }
}

// ============================================================
// Search Pattern 测试 — 对齐 gix-glob/tests/search/pattern.rs
// ============================================================

@Test
func testSearchPatternFromBytesBaseNoRoot(): Unit {
    // 对齐 Rust: search/pattern.rs::list::from_bytes_base — no root
    let list = PatternList.fromBytes(Array<Byte>(), "a/b/source", None)
    if (list.base.isSome()) {
        throw Exception("no root always means no-base")
    }
    if (list.source != "a/b/source") {
        throw Exception("source should be verbatim")
    }
}

@Test
func testSearchPatternFromBytesBaseWithRoot(): Unit {
    // 对齐 Rust: search/pattern.rs::list::from_bytes_base — with root
    let cwd = "C:/Users/test"
    let list = PatternList.fromBytes(Array<Byte>(), cwd + "/a/b/source", Some(cwd))
    if (list.base == None) {
        throw Exception("base should be set with proper root")
    }
}

@Test
func testSearchPatternFromFileNonExisting(): Unit {
    // 对齐 Rust: search/pattern.rs::list::from_file_that_does_not_exist
    let list = PatternList.fromFile("./non-existing-dir/pattern-file", None, false)
    if (list.isSome()) {
        throw Exception("non-existing file should return None")
    }
}

@Test
func testSearchPatternFromFileIsDirectory(): Unit {
    // 对齐 Rust: search/pattern.rs::list::from_file_that_is_a_directory
    let list = PatternList.fromFile("C:/Windows", None, false)
    // 目录被忽略
    if (list.isSome()) {
        throw Exception("directory should be ignored like Git does")
    }
}

@Test
func testSearchPatternStripBaseRecomputeBasenamePos(): Unit {
    // 对齐 Rust: search/pattern.rs::list::strip_base_handle_recompute_basename_pos
    let list = PatternList.fromBytes(Array<Byte>(), "a/b/source", Some(""))
    if (list.base == None) {
        throw Exception("base should be computed if root is set")
    }
    let result = list.stripBaseHandleRecomputeBasenamePos("a/b/file", Some(4), Case.Sensitive)
    if (result == None) {
        throw Exception("strip base should return Some for matching prefix")
    }
    let result2 = list.stripBaseHandleRecomputeBasenamePos("a/B/c/File", Some(6), Case.Fold)
    if (result2 == None) {
        throw Exception("strip base with case fold should return Some")
    }
}
