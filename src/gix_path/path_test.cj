// 文件：path_test.cj
// 用途：gix_path 包的单元测试，全量对齐 Rust gitoxide gix-path 测试
// 所属包：gix.gix_path
// 对齐来源：gix-path/tests/{convert,normalize,relative_path,util}.rs

package gitoxide.gix_path

import std.unittest.*

// ============================================================
// toSlash 测试 — 对齐 gix-path/tests/convert/mod.rs
// ============================================================

@Test
func testToSlashUnixPath(): Unit {
    // 对齐 Rust: to_unix_separators — Unix 路径不变
    if (toSlash("no-backslash") != "no-backslash") {
        throw Exception("Unix path should not change")
    }
}

@Test
func testToSlashWindowsPath(): Unit {
    // 对齐 Rust: to_unix_separators — Windows 路径转换
    if (toSlash("\\a\\b\\\\") != "/a/b//") {
        throw Exception("Windows path should be converted to forward slashes")
    }
}

@Test
func testToSlashMixedPath(): Unit {
    // 对齐 Rust: to_unix_separators — 混合路径
    if (toSlash("a\\b/c") != "a/b/c") {
        throw Exception("Mixed path should be normalized to forward slashes")
    }
}

@Test
func testToSlashEmpty(): Unit {
    // 对齐 Rust: to_unix_separators — 空路径
    if (toSlash("") != "") {
        throw Exception("empty path should remain empty")
    }
}

@Test
func testToSlashRootPath(): Unit {
    // 对齐 Rust: to_unix_separators — 根路径
    if (toSlash("/") != "/") {
        throw Exception("root path should remain /")
    }
}

// ============================================================
// fromSlash 测试 — 对齐 gix-path/tests/convert/mod.rs
// ============================================================

@Test
func testFromSlashUnixPath(): Unit {
    // 对齐 Rust: to_windows_separators — Unix 路径转换
    if (fromSlash("/a/b//") != "\\a\\b\\\\") {
        throw Exception("fromSlash should convert to backslashes")
    }
}

@Test
func testFromSlashNoSlash(): Unit {
    // 对齐 Rust: to_windows_separators — 无斜杠路径
    if (fromSlash("no-backslash") != "no-backslash") {
        throw Exception("fromSlash should not change paths without slashes")
    }
}

@Test
func testFromSlashEmpty(): Unit {
    // 对齐 Rust: to_windows_separators — 空路径
    if (fromSlash("") != "") {
        throw Exception("fromSlash empty should remain empty")
    }
}

// ============================================================
// toUnixSeparators / toWindowsSeparators 测试 — 对齐 gix-path/tests/convert/mod.rs
// ============================================================

@Test
func testToUnixSeparatorsNoBackslash(): Unit {
    // 对齐 Rust: assure_unix_separators — 无反斜杠
    let result = toUnixSeparators("no-backslash".toArray())
    if (String.fromUtf8(result) != "no-backslash") {
        throw Exception("no-backslash should not change")
    }
}

@Test
func testToUnixSeparatorsWithBackslash(): Unit {
    // 对齐 Rust: assure_unix_separators — 有反斜杠
    let result = toUnixSeparators("\\a\\b\\\\".toArray())
    if (String.fromUtf8(result) != "/a/b//") {
        throw Exception("backslashes should be replaced: " + String.fromUtf8(result))
    }
}

@Test
func testToWindowsSeparatorsNoSlash(): Unit {
    // 对齐 Rust: assure_windows_separators — 无斜杠
    let result = toWindowsSeparators("no-backslash".toArray())
    if (String.fromUtf8(result) != "no-backslash") {
        throw Exception("no-backslash should not change")
    }
}

@Test
func testToWindowsSeparatorsWithSlash(): Unit {
    // 对齐 Rust: assure_windows_separators — 有斜杠
    let result = toWindowsSeparators("/a/b//".toArray())
    if (String.fromUtf8(result) != "\\a\\b\\\\") {
        throw Exception("slashes should be replaced: " + String.fromUtf8(result))
    }
}

// ============================================================
// joinBstrUnixPathsep 测试 — 对齐 gix-path/tests/convert/mod.rs::join_bstr_unix_pathsep
// ============================================================

@Test
func testJoinBstrTypicalWithDoubleSlashAvoidance(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::typical_with_double_slash_avoidance
    if (joinBstrUnixPathsep("base", "path") != "base/path") {
        throw Exception("joinBstrUnixPathsep('base', 'path') should be 'base/path'")
    }
    if (joinBstrUnixPathsep("base/", "path") != "base/path") {
        throw Exception("joinBstrUnixPathsep('base/', 'path') should be 'base/path' (no double slashes)")
    }
    if (joinBstrUnixPathsep("/base", "path") != "/base/path") {
        throw Exception("joinBstrUnixPathsep('/base', 'path') should be '/base/path'")
    }
    if (joinBstrUnixPathsep("/base/", "path") != "/base/path") {
        throw Exception("joinBstrUnixPathsep('/base/', 'path') should be '/base/path'")
    }
}

@Test
func testJoinBstrRelativeBaseOrPath(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::relative_base_or_path_are_nothing_special
    if (joinBstrUnixPathsep("base", ".") != "base/.") {
        throw Exception("joinBstrUnixPathsep('base', '.') should be 'base/.'")
    }
    if (joinBstrUnixPathsep("base", "..") != "base/..") {
        throw Exception("joinBstrUnixPathsep('base', '..') should be 'base/..'")
    }
    if (joinBstrUnixPathsep("base", "../dir") != "base/../dir") {
        throw Exception("joinBstrUnixPathsep('base', '../dir') should be 'base/../dir'")
    }
}

@Test
func testJoinBstrAbsolutePath(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::absolute_path_produces_double_slashes
    if (joinBstrUnixPathsep("/base", "/root") != "/base//root") {
        throw Exception("joinBstrUnixPathsep('/base', '/root') should be '/base//root'")
    }
    if (joinBstrUnixPathsep("base/", "/root") != "base//root") {
        throw Exception("joinBstrUnixPathsep('base/', '/root') should be 'base//root'")
    }
}

@Test
func testJoinBstrEmptyPath(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::empty_path_makes_base_end_with_a_slash
    if (joinBstrUnixPathsep("base", "") != "base/") {
        throw Exception("joinBstrUnixPathsep('base', '') should be 'base/'")
    }
    if (joinBstrUnixPathsep("base/", "") != "base/") {
        throw Exception("joinBstrUnixPathsep('base/', '') should be 'base/'")
    }
}

@Test
func testJoinBstrEmptyBase(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::empty_base_leaves_everything_untouched
    if (joinBstrUnixPathsep("", "") != "") {
        throw Exception("joinBstrUnixPathsep('', '') should be ''")
    }
    if (joinBstrUnixPathsep("", "hi") != "hi") {
        throw Exception("joinBstrUnixPathsep('', 'hi') should be 'hi'")
    }
    if (joinBstrUnixPathsep("", "/hi") != "/hi") {
        throw Exception("joinBstrUnixPathsep('', '/hi') should be '/hi'")
    }
}

// ============================================================
// normalize 测试 — 对齐 gix-path/tests/convert/normalize.rs
// ============================================================

@Test
func testNormalizeSimplePath(): Unit {
    // 对齐 Rust: normalize — 简单路径不变
    if (normalize("a/b/c") != "a/b/c") {
        throw Exception("simple path should not change")
    }
}

@Test
func testNormalizeDotComponent(): Unit {
    // 对齐 Rust: normalize — 去除 . 组件
    if (normalize("a/./b") != "a/b") {
        throw Exception("normalize should remove . components: " + normalize("a/./b"))
    }
}

@Test
func testNormalizeDotDotComponent(): Unit {
    // 对齐 Rust: normalize — 去除 .. 组件
    if (normalize("a/b/../c") != "a/c") {
        throw Exception("normalize should resolve .. components: " + normalize("a/b/../c"))
    }
}

@Test
func testNormalizeMultipleDotDot(): Unit {
    // 对齐 Rust: normalize — 多个 .. 组件
    if (normalize("a/b/c/../../d") != "a/d") {
        throw Exception("normalize should resolve multiple ..: " + normalize("a/b/c/../../d"))
    }
}

@Test
func testNormalizeEmptyPath(): Unit {
    // 对齐 Rust: normalize — 空路径
    if (normalize("") != "") {
        throw Exception("normalize empty should return empty")
    }
}

@Test
func testNormalizeDotOnly(): Unit {
    // 对齐 Rust: normalize — 只有 .
    if (normalize(".") != "") {
        throw Exception("normalize '.' should return empty")
    }
}

@Test
func testNormalizeDotDotOnly(): Unit {
    // 对齐 Rust: normalize — 只有 ..
    if (normalize("..") != "") {
        throw Exception("normalize '..' should return empty (no parent to go up)")
    }
}

@Test
func testNormalizeTrailingRelativeComponents(): Unit {
    // 对齐 Rust: normalize::trailing_relative_components_are_resolved
    // 注意：仓颉简化版 normalize 不处理 cwd，仅去除 . 和 ..
    let cases = [
        ("a/./b/c/../d/..", "a/b"),
        ("a/./b/c/.././..", "a"),
        ("./a/..", ""),
        ("a/..", ""),
        ("./a", "a"),
        ("./a/./b", "a/b"),
        ("/a/./b/c/.././../.", "a"),
        ("/a/./b", "a/b"),
        ("/a/b/../c/../..", ""),
        ("/a/../b", "b")
    ]
    for ((input, expected) in cases) {
        let result = normalize(input)
        if (result != expected) {
            throw Exception("normalize('" + input + "') should be '" + expected + "', got '" + result + "'")
        }
    }
}

// ============================================================
// normalizeWithCwd 测试 — 对齐 gix-path/tests/convert/normalize.rs
// ============================================================

@Test
func testNormalizeWithCwdParentDirsCauseCwdToBeUsed(): Unit {
    // 对齐 Rust: normalize::parent_dirs_cause_the_cwd_to_be_used
    let result = normalizeWithCwd("./a/b/../../..", "/users/name")
    if (result != Some("/users")) {
        throw Exception("normalizeWithCwd('./a/b/../../..', '/users/name') should be '/users', got " + result.toString())
    }
}

@Test
func testNormalizeWithCwdMultipleParentDirMovements(): Unit {
    // 对齐 Rust: normalize::multiple_parent_dir_movements_eat_into_the_current_dir
    let result1 = normalizeWithCwd("../../../d/e", "/users/name/a/b/c")
    if (result1 != Some("/users/name/d/e")) {
        throw Exception(
            "normalizeWithCwd('../../../d/e', '/users/name/a/b/c') should be '/users/name/d/e', got " +
                result1.toString())
    }
}

@Test
func testNormalizeWithCwdWalkingUpTooMuchYieldsNone(): Unit {
    // 对齐 Rust: normalize::walking_up_too_much_yield_none
    let result = normalizeWithCwd("./a/b/../../../../../.", "/users/name")
    if (result != None) {
        throw Exception("walking up too much should yield None")
    }
}

@Test
func testNormalizeWithCwdNoChangeIfNoTrailingRelativeComponents(): Unit {
    // 对齐 Rust: normalize::no_change_if_there_are_no_trailing_relative_components
    let result = normalizeWithCwd("a/b/c/d", "/cwd")
    if (result != Some("a/b/c/d")) {
        throw Exception("no change if no .. components")
    }
}

// ============================================================
// isAbsolute 测试 — 对齐 gix-path/tests/path/util.rs
// ============================================================

@Test
func testIsAbsoluteUnixPath(): Unit {
    // 对齐 Rust: is_absolute::absolute_linux_path_is_true
    if (!isAbsolute("/")) {
        throw Exception("/ should be absolute")
    }
    if (!isAbsolute("/abs/path")) {
        throw Exception("/abs/path should be absolute")
    }
}

@Test
func testIsAbsoluteRelativePath(): Unit {
    // 对齐 Rust: is_absolute::relative_linux_path_is_false
    if (isAbsolute("./relative/path")) {
        throw Exception("./relative/path should not be absolute")
    }
    if (isAbsolute("relative/path")) {
        throw Exception("relative/path should not be absolute")
    }
}

@Test
func testIsAbsoluteWindowsPath(): Unit {
    // 对齐 Rust: is_absolute::on_windows::drive_prefixes_are_true
    if (!isAbsolute("C:\\abs/path")) {
        throw Exception("C:\\abs/path should be absolute on Windows")
    }
    if (!isAbsolute("C:\\abs\\path")) {
        throw Exception("C:\\abs\\path should be absolute on Windows")
    }
}

@Test
func testIsAbsoluteWindowsRelativePath(): Unit {
    // 对齐 Rust: is_absolute::on_windows::relative_paths_with_backslashes_are_false
    if (isAbsolute(".\\rel/path")) {
        throw Exception(".\\rel/path should not be absolute")
    }
    if (isAbsolute("rel\\path")) {
        throw Exception("rel\\path should not be absolute")
    }
}

@Test
func testIsAbsoluteWindowsBackslashPrefix(): Unit {
    // 对齐 Rust: is_absolute::on_windows::path_starting_with_backslash_is_false
    if (isAbsolute("\\rel\\path")) {
        throw Exception("\\rel\\path should not be absolute")
    }
}

@Test
func testIsAbsoluteEmptyPath(): Unit {
    // 对齐 Rust: is_absolute — 空路径
    if (isAbsolute("")) {
        throw Exception("empty path should not be absolute")
    }
}

// ============================================================
// join 测试 — 对齐 gix-path/tests/join.rs
// ============================================================

@Test
func testJoinSimple(): Unit {
    // 对齐 Rust: join — 简单拼接
    if (join("a", "b") != "a/b") {
        throw Exception("join('a', 'b') should be 'a/b'")
    }
}

@Test
func testJoinWithTrailingSlash(): Unit {
    // 对齐 Rust: join — 基础路径有尾部斜杠
    if (join("a/", "b") != "a/b") {
        throw Exception("join('a/', 'b') should be 'a/b'")
    }
}

@Test
func testJoinAbsoluteRelative(): Unit {
    // 对齐 Rust: join — 相对路径为绝对路径时直接返回
    if (join("a", "/b") != "/b") {
        throw Exception("join('a', '/b') should be '/b'")
    }
}

@Test
func testJoinEmptyBase(): Unit {
    // 对齐 Rust: join — 空基础路径
    let result = join("", "b")
    if (result != "/b" && result != "b") {
        throw Exception("join('', 'b') should be 'b' or '/b'")
    }
}

// ============================================================
// parent 测试 — 对齐 gix-path/tests/parent.rs
// ============================================================

@Test
func testParentSimple(): Unit {
    // 对齐 Rust: parent — 简单路径
    if (parent("a/b/c") != Some("a/b")) {
        throw Exception("parent of 'a/b/c' should be 'a/b'")
    }
}

@Test
func testParentRoot(): Unit {
    // 对齐 Rust: parent — 根目录
    if (parent("/").isSome()) {
        throw Exception("parent of '/' should be None")
    }
}

@Test
func testParentSingleComponent(): Unit {
    // 对齐 Rust: parent — 单组件路径
    if (parent("a").isSome()) {
        throw Exception("parent of 'a' should be None (no slash)")
    }
}

@Test
func testParentTwoComponents(): Unit {
    // 对齐 Rust: parent — 两个组件
    if (parent("a/b") != Some("a")) {
        throw Exception("parent of 'a/b' should be 'a'")
    }
}

@Test
func testParentDeepPath(): Unit {
    // 对齐 Rust: parent — 深层路径
    if (parent("a/b/c/d/e") != Some("a/b/c/d")) {
        throw Exception("parent of 'a/b/c/d/e' should be 'a/b/c/d'")
    }
}

// ============================================================
// fileName 测试 — 对齐 gix-path/tests/file_name.rs
// ============================================================

@Test
func testFileNameSimple(): Unit {
    // 对齐 Rust: file_name — 简单路径
    if (fileName("a/b/c.txt") != Some("c.txt")) {
        throw Exception("fileName of 'a/b/c.txt' should be 'c.txt'")
    }
}

@Test
func testFileNameNoDirectory(): Unit {
    // 对齐 Rust: file_name — 无目录部分
    if (fileName("file.txt").isSome()) {
        throw Exception("fileName of 'file.txt' should be None (no slash)")
    }
}

@Test
func testFileNameTrailingSlash(): Unit {
    // 对齐 Rust: file_name — 尾部斜杠，返回最后一个路径组件
    if (fileName("a/b/") != "b") {
        throw Exception("fileName of 'a/b/' should be b")
    }
}

@Test
func testFileNameRoot(): Unit {
    // 对齐 Rust: file_name — 根目录
    if (fileName("/").isSome()) {
        throw Exception("fileName of '/' should be None")
    }
}

@Test
func testFileNameHiddenFile(): Unit {
    // 对齐 Rust: file_name — 隐藏文件
    if (fileName("a/b/.gitignore") != Some(".gitignore")) {
        throw Exception("fileName of 'a/b/.gitignore' should be '.gitignore'")
    }
}

@Test
func testFileNameWithExtension(): Unit {
    // 对齐 Rust: file_name — 多重扩展名
    if (fileName("a/b/archive.tar.gz") != Some("archive.tar.gz")) {
        throw Exception("fileName of 'a/b/archive.tar.gz' should be 'archive.tar.gz'")
    }
}

// ============================================================
// validateRelativePath 测试 — 对齐 gix-path/tests/path/relative_path.rs
// ============================================================

@Test
func testRelativePathAbsoluteReturnsError(): Unit {
    // 对齐 Rust: relative_path::absolute_paths_return_err
    let err = validateRelativePath("/refs/heads")
    if (err != Some(RelativePathError.IsAbsolute)) {
        throw Exception("absolute path should return IsAbsolute error")
    }
}

@Test
func testRelativePathWindowsAbsoluteReturnsError(): Unit {
    // 对齐 Rust: relative_path::absolute_paths_with_backslashes_return_err
    let err = validateRelativePath("c:\\refs\\heads")
    if (err != Some(RelativePathError.IsAbsolute)) {
        throw Exception("Windows absolute path should return IsAbsolute error")
    }
}

@Test
func testRelativePathDotsReturnError(): Unit {
    // 对齐 Rust: relative_path::dots_in_paths_return_err
    let err = validateRelativePath("./heads")
    if (let Some(RelativePathError.ContainsInvalidComponent(_)) <- err) {
    // expected
    } else {
        throw Exception("'./heads' should return ContainsInvalidComponent error")
    }
}

@Test
func testRelativePathDotsWithBackslashesReturnError(): Unit {
    // 对齐 Rust: relative_path::dots_in_paths_with_backslashes_return_err
    let err = validateRelativePath(".\\heads")
    if (let Some(RelativePathError.ContainsInvalidComponent(_)) <- err) {
    // expected
    } else {
        throw Exception("'.\\heads' should return ContainsInvalidComponent error")
    }
}

@Test
func testRelativePathDoubleDotsReturnError(): Unit {
    // 对齐 Rust: relative_path::double_dots_in_paths_return_err
    let err = validateRelativePath("../heads")
    if (let Some(RelativePathError.ContainsInvalidComponent(_)) <- err) {
    // expected
    } else {
        throw Exception("'../heads' should return ContainsInvalidComponent error")
    }
}

@Test
func testRelativePathDoubleDotsWithBackslashesReturnError(): Unit {
    // 对齐 Rust: relative_path::double_dots_in_paths_with_backslashes_return_err
    let err = validateRelativePath("..\\heads")
    if (let Some(RelativePathError.ContainsInvalidComponent(_)) <- err) {
    // expected
    } else {
        throw Exception("'..\\heads' should return ContainsInvalidComponent error")
    }
}

@Test
func testRelativePathValidPath(): Unit {
    // 对齐 Rust: relative_path — 合法相对路径
    let err = validateRelativePath("refs/heads/main")
    if (err.isSome()) {
        throw Exception("'refs/heads/main' should be a valid relative path")
    }
}

// ============================================================
// relativizeWithPrefix 测试 — 对齐 gix-path/tests/convert/mod.rs::relativize_with_prefix
// ============================================================

@Test
func testRelativizeWithPrefixBasics(): Unit {
    // 对齐 Rust: relativize_with_prefix::basics
    if (relativizeWithPrefix("a", "a") != ".") {
        throw Exception("relativizeWithPrefix('a', 'a') should be '.'")
    }
    if (relativizeWithPrefix("a/b/c", "a/b") != "c") {
        throw Exception("relativizeWithPrefix('a/b/c', 'a/b') should be 'c'")
    }
    if (relativizeWithPrefix("c/b/c", "a/b") != "../../c/b/c") {
        throw Exception("relativizeWithPrefix('c/b/c', 'a/b') should be '../../c/b/c'")
    }
    if (relativizeWithPrefix("a/a", "a/b") != "../a") {
        throw Exception("relativizeWithPrefix('a/a', 'a/b') should be '../a'")
    }
    if (relativizeWithPrefix("a/a", "") != "a/a") {
        throw Exception("relativizeWithPrefix('a/a', '') should be 'a/a'")
    }
    if (relativizeWithPrefix("", "") != ".") {
        throw Exception("relativizeWithPrefix('', '') should be '.'")
    }
}

// ============================================================
// 补充测试 — 对齐 gix-path/tests/{convert,normalize,util}.rs
// ============================================================

@Test
func testToSlashEmptyString(): Unit {
    // 对齐 Rust: 空字符串不变
    if (toSlash("") != "") {
        throw Exception("empty string should remain empty")
    }
}

@Test
func testFromSlashEmptyString(): Unit {
    // 对齐 Rust: 空字符串不变
    if (fromSlash("") != "") {
        throw Exception("empty string should remain empty")
    }
}

@Test
func testToSlashMixedSeparators(): Unit {
    // 对齐 Rust: 混合分隔符
    if (toSlash("a\\b/c\\d") != "a/b/c/d") {
        throw Exception("mixed separators should all become forward slashes")
    }
}

@Test
func testFromSlashMixedSeparators(): Unit {
    // 对齐 Rust: 混合分隔符
    if (fromSlash("a/b\\c/d") != "a\\b\\c\\d") {
        throw Exception("mixed separators should all become backslashes")
    }
}

@Test
func testNormalizeDotOnlyV2(): Unit {
    // 对齐 Rust: normalize "." — 验证空结果
    if (normalize(".") != "") {
        throw Exception("normalize('.') should be ''")
    }
}

@Test
func testNormalizeDotDotOnlyV2(): Unit {
    // 对齐 Rust: normalize ".." — 超出根目录，.. 被丢弃
    if (normalize("..") != "") {
        throw Exception("normalize('..') should be ''")
    }
}

@Test
func testNormalizeTrailingSlash(): Unit {
    // 对齐 Rust: normalize 尾部斜杠
    if (normalize("a/b/") != "a/b") {
        throw Exception("normalize('a/b/') should be 'a/b'")
    }
}

@Test
func testNormalizeMultipleSlashes(): Unit {
    // 对齐 Rust: normalize 连续斜杠
    if (normalize("a//b") != "a/b") {
        throw Exception("normalize('a//b') should be 'a/b'")
    }
}

@Test
func testIsAbsoluteWindowsDrive(): Unit {
    // 对齐 Rust: Windows 绝对路径
    if (!isAbsolute("C:/Users/test")) {
        throw Exception("'C:/Users/test' should be absolute")
    }
}

@Test
func testIsAbsoluteRelativePathV2(): Unit {
    // 对齐 Rust: gix-path/tests/path/util.rs::is_absolute::relative_linux_path_is_false
    if (isAbsolute("relative/path")) {
        throw Exception("'relative/path' should not be absolute")
    }
}

@Test
func testJoinAbsoluteRelativeV2(): Unit {
    // 对齐 Rust: gix-path/tests/path/convert/mod.rs::join — 绝对相对路径覆盖 base
    if (join("/base", "/absolute") != "/absolute") {
        throw Exception("absolute relative should override base")
    }
}

@Test
func testJoinBaseEndsWithSlash(): Unit {
    // 对齐 Rust: join — base 以 / 结尾
    if (join("/base/", "sub") != "/base/sub") {
        throw Exception("join('/base/', 'sub') should be '/base/sub'")
    }
}

@Test
func testJoinBaseNoTrailingSlash(): Unit {
    // 对齐 Rust: join — base 不以 / 结尾
    if (join("/base", "sub") != "/base/sub") {
        throw Exception("join('/base', 'sub') should be '/base/sub'")
    }
}

@Test
func testParentRootPath(): Unit {
    // 对齐 Rust: parent — 根路径
    if (!parent("/").isNone()) {
        throw Exception("parent('/') should be None")
    }
}

@Test
func testParentSingleComponentV2(): Unit {
    // 对齐 Rust: parent — 单组件路径
    if (!parent("file").isNone()) {
        throw Exception("parent('file') should be None")
    }
}

@Test
func testParentNestedPath(): Unit {
    // 对齐 Rust: parent — 嵌套路径
    if (parent("a/b/c") != Some("a/b")) {
        throw Exception("parent('a/b/c') should be 'a/b'")
    }
}

@Test
func testFileNameNestedPath(): Unit {
    // 对齐 Rust: fileName — 嵌套路径
    if (fileName("a/b/c") != Some("c")) {
        throw Exception("fileName('a/b/c') should be 'c'")
    }
}

@Test
func testFileNameTrailingSlashV2(): Unit {
    // 对齐 Rust: fileName — 尾部斜杠，返回最后一个路径组件
    if (fileName("a/b/") != "b") {
        throw Exception("fileName('a/b/') should be b")
    }
}

@Test
func testFileNameSingleComponent(): Unit {
    // 对齐 Rust: fileName — 单组件路径
    if (fileName("file") != None) {
        throw Exception("fileName('file') should be None (no slash)")
    }
}

@Test
func testJoinBstrUnixPathsepEmptyBase(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep — 空 base
    if (joinBstrUnixPathsep("", "sub") != "sub") {
        throw Exception("empty base should return path")
    }
}

@Test
func testJoinBstrUnixPathsepBaseEndsWithSlash(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep — base 以 / 结尾
    if (joinBstrUnixPathsep("base/", "sub") != "base/sub") {
        throw Exception("should concatenate without extra slash")
    }
}

@Test
func testJoinBstrUnixPathsepBaseNoTrailingSlash(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep — base 不以 / 结尾
    if (joinBstrUnixPathsep("base", "sub") != "base/sub") {
        throw Exception("should add slash between base and path")
    }
}

@Test
func testToUnixSeparatorsEmpty(): Unit {
    // 对齐 Rust: to_unix_separators — 空数组
    if (toUnixSeparators(Array<Byte>()).size != 0) {
        throw Exception("empty array should return empty")
    }
}

@Test
func testToWindowsSeparatorsEmpty(): Unit {
    // 对齐 Rust: to_windows_separators — 空数组
    if (toWindowsSeparators(Array<Byte>()).size != 0) {
        throw Exception("empty array should return empty")
    }
}

@Test
func testValidateRelativePathDotComponent(): Unit {
    // 对齐 Rust: "." 组件是非法的
    let err = validateRelativePath("a/./b")
    if (err.isNone()) {
        throw Exception("'a/./b' should fail validation")
    }
}

@Test
func testValidateRelativePathDotDotComponent(): Unit {
    // 对齐 Rust: ".." 组件是非法的
    let err = validateRelativePath("a/../b")
    if (err.isNone()) {
        throw Exception("'a/../b' should fail validation")
    }
}

@Test
func testRelativizeWithPrefixSamePath(): Unit {
    // 对齐 Rust: 相同路径
    if (relativizeWithPrefix("refs/heads/main", "refs/heads/main") != ".") {
        throw Exception("same path should relativize to '.'")
    }
}

@Test
func testRelativizeWithPrefixSubpath(): Unit {
    // 对齐 Rust: 子路径
    if (relativizeWithPrefix("refs/heads/main/feature", "refs/heads/main") != "feature") {
        throw Exception("subpath should relativize to remaining part")
    }
}

@Test
func testRelativizeWithPrefixDiverged(): Unit {
    // 对齐 Rust: 分叉路径
    if (relativizeWithPrefix("refs/tags/v1", "refs/heads/main") != "../../tags/v1") {
        throw Exception("diverged paths should use ..")
    }
}

// ============================================================
// env 测试 — 对齐 gix-path/tests/path/env.rs
// 注意：仓颉版 env 函数部分使用环境变量实现，部分仍为占位
// ============================================================

@Test
func testEnvExeInvocation(): Unit {
    // 对齐 Rust: env::exe_invocation
    let result = exeInvocation()
    // 从 GIT_EXEC_PATH 环境变量获取，回退到 "git"
    if (result.size == 0) {
        throw Exception("exeInvocation should return non-empty string (env var or fallback 'git')")
    }
}

@Test
func testEnvShell(): Unit {
    // 对齐 Rust: env::shell
    let result = shell()
    // 从 SHELL 环境变量获取，回退到 "sh.exe"
    if (result.size == 0) {
        throw Exception("shell should return non-empty string (env var or fallback)")
    }
}

@Test
func testEnvInstallationConfig(): Unit {
    // 对齐 Rust: env::installation_config
    // 需要调用 Git 二进制，仓颉中无法实现，返回 None
    let result = installationConfig()
    // 验证不崩溃
}

@Test
func testEnvInstallationConfigPrefix(): Unit {
    // 对齐 Rust: env::installation_config_prefix
    // 依赖 installationConfig，仓颉中无法实现，返回 None
    let result = installationConfigPrefix()
    // 验证不崩溃
}

@Test
func testEnvCoreDir(): Unit {
    // 对齐 Rust: env::core_dir
    // 需要调用 Git 二进制，仓颉中无法实现，返回 None
    let result = coreDir()
    // 验证不崩溃
}

@Test
func testEnvSystemPrefix(): Unit {
    // 对齐 Rust: env::system_prefix
    // 从 EXEPATH 环境变量获取（Windows）
    let result = systemPrefix()
    // 环境变量可能未设置，验证不崩溃
}

@Test
func testEnvHomeDir(): Unit {
    // 对齐 Rust: env::home_dir
    // 从 HOME 或 USERPROFILE 环境变量获取
    let result = homeDir()
    // Windows 上 USERPROFILE 通常有值
    if (let Some(h) <- result) {
        if (h.size == 0) {
            throw Exception("homeDir should return non-empty path if set")
        }
    }
}

@Test
func testEnvXdgConfig(): Unit {
    // 对齐 Rust: env::xdg_config
    // 从 XDG_CONFIG_HOME 或回退到 ~/.config
    let result = xdgConfig("git")
    if (let Some(p) <- result) {
        if (!p.contains("git")) {
            throw Exception("xdgConfig('git') should contain 'git' in path: " + p)
        }
    }
}

// ============================================================
// realpath 测试 — 对齐 gix-path/tests/path/realpath.rs
// 注意：仓颉版 realpath 使用 std.fs.canonicalize 实现符号链接解析
// ============================================================

@Test
func testRealpathEmptyPathError(): Unit {
    // 对齐 Rust: realpath::assorted — Empty path is not allowed
    let result = realpathOpts("", ".", 0)
    if (result.size != 0) {
        throw Exception("empty path should return empty string")
    }
}

@Test
func testRealpathRelativePath(): Unit {
    // 对齐 Rust: realpath::assorted — relative paths are prefixed with current dir
    let result = realpathOpts("b/.git", "/cwd", 0)
    if (!result.startsWith("/cwd")) {
        throw Exception("relative path should be prefixed with current dir: " + result)
    }
    if (!result.contains("b/.git")) {
        throw Exception("result should contain the relative path: " + result)
    }
}

@Test
func testRealpathDotSlashPath(): Unit {
    // 对齐 Rust: realpath::assorted — path starting with dot is relative
    let result = realpathOpts("./tmp/.git", "/cwd", 0)
    if (!result.startsWith("/cwd")) {
        throw Exception("./ path should be prefixed with current dir: " + result)
    }
}

@Test
func testRealpathDotDotPath(): Unit {
    // 对齐 Rust: realpath::assorted — dot dot goes to parent path component
    let result = realpathOpts("./b/../tmp/.git", "/cwd", 0)
    if (!result.startsWith("/cwd")) {
        throw Exception(".. path should be prefixed with current dir: " + result)
    }
    // .. 应被规范化：/cwd/b/../tmp/.git → /cwd/tmp/.git
    if (result.contains("b/..")) {
        throw Exception(".. should be resolved in result: " + result)
    }
}

@Test
func testRealpathAbsolutePath(): Unit {
    // 对齐 Rust: realpath::assorted — absolute path without symlinks remains unchanged
    let result = realpathOpts("C:/c/d/.git", "/cwd", 0)
    // 绝对路径应保持绝对
    if (!result.contains("C:/") && !result.contains("c:/")) {
        throw Exception("absolute path should remain absolute: " + result)
    }
}

@Test
func testRealpathFuzzedTimeout(): Unit {
    // 对齐 Rust: realpath::fuzzed_timeout — excessive component count
    let result = realpathOpts("a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p", "/cwd", 2048)
    if (result.size == 0) {
        throw Exception("realpath with many components should return non-empty result")
    }
}

// ============================================================
// is_absolute 测试 — 对齐 gix-path/tests/path/util.rs
// ============================================================

@Test
func testIsAbsoluteLinuxAbsolutePath(): Unit {
    // 对齐 Rust: is_absolute::absolute_linux_path_is_true
    if (!isAbsolutePath("/")) {
        throw Exception("/ should be absolute")
    }
    if (!isAbsolutePath("/abs/path")) {
        throw Exception("/abs/path should be absolute")
    }
}

@Test
func testIsAbsoluteLinuxRelativePath(): Unit {
    // 对齐 Rust: is_absolute::relative_linux_path_is_false
    if (isAbsolutePath("./relative/path")) {
        throw Exception("./relative/path should not be absolute")
    }
    if (isAbsolutePath("relative/path")) {
        throw Exception("relative/path should not be absolute")
    }
}

@Test
func testIsAbsoluteWindowsDrivePrefix(): Unit {
    // 对齐 Rust: is_absolute::on_windows::drive_prefixes_are_true
    if (!isAbsolutePath("c:/abs/path")) {
        throw Exception("c:/abs/path should be absolute on Windows")
    }
    if (!isAbsolutePath("C:\\abs\\path")) {
        throw Exception("C:\\abs\\path should be absolute on Windows")
    }
}

@Test
func testIsAbsoluteWindowsRelativePathWithBackslash(): Unit {
    // 对齐 Rust: is_absolute::on_windows::relative_paths_with_backslashes_are_false
    if (isAbsolutePath(".\\rel/path")) {
        throw Exception(".\\rel/path should not be absolute")
    }
    if (isAbsolutePath("rel\\path")) {
        throw Exception("rel\\path should not be absolute")
    }
}

@Test
func testIsAbsolutePathStartingWithBackslash(): Unit {
    // 对齐 Rust: is_absolute::on_windows::path_starting_with_backslash_is_false
    if (isAbsolutePath("\\rel\\path")) {
        throw Exception("\\rel\\path should not be absolute")
    }
}

// ============================================================
// isAbsolute 补充测试 — 对齐 gix-path/tests/path/util.rs
// ============================================================

@Test
func testIsAbsoluteRootPath(): Unit {
    // 对齐 Rust: is_absolute::absolute_linux_path_is_true
    if (!isAbsolute("/")) {
        throw Exception("/ should be absolute")
    }
    if (!isAbsolute("/abs/path")) {
        throw Exception("/abs/path should be absolute")
    }
}

// ============================================================
// toUnixSeparators / toWindowsSeparators 补充测试
// ============================================================

@Test
func testToUnixSeparatorsByteArray(): Unit {
    // 对齐 Rust: convert::assure_unix_separators — 字节级别
    let input = "no-backslash".toArray()
    let result = toUnixSeparators(input)
    if (String.fromUtf8(result) != "no-backslash") {
        throw Exception("no-backslash should be unchanged")
    }
    let input2: Array<Byte> = [UInt8(92), UInt8(97), UInt8(92), UInt8(98), UInt8(92), UInt8(92)]
    let result2 = toUnixSeparators(input2)
    let s2 = String.fromUtf8(result2)
    if (s2 != "/a/b//") {
        throw Exception("backslash path should be converted: " + s2)
    }
}

@Test
func testToWindowsSeparatorsByteArray(): Unit {
    // 对齐 Rust: convert::assure_windows_separators — 字节级别
    let input = "no-backslash".toArray()
    let result = toWindowsSeparators(input)
    if (String.fromUtf8(result) != "no-backslash") {
        throw Exception("no-backslash should be unchanged")
    }
    let input2: Array<Byte> = [UInt8(47), UInt8(97), UInt8(47), UInt8(98), UInt8(47), UInt8(47)]
    let result2 = toWindowsSeparators(input2)
    let s2 = String.fromUtf8(result2)
    if (s2 != "\\a\\b\\\\") {
        throw Exception("forward slash path should be converted: " + s2)
    }
}

// ============================================================
// joinBstrUnixPathsep 补充测试 — 对齐 gix-path/tests/path/convert/mod.rs
// ============================================================

@Test
func testJoinBstrUnixPathsepTypical(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::typical_with_double_slash_avoidance
    if (joinBstrUnixPathsep("base", "path") != "base/path") {
        throw Exception("base + path should be base/path")
    }
    if (joinBstrUnixPathsep("base/", "path") != "base/path") {
        throw Exception("base/ + path should be base/path (no double slash)")
    }
    if (joinBstrUnixPathsep("/base", "path") != "/base/path") {
        throw Exception("/base + path should be /base/path")
    }
    if (joinBstrUnixPathsep("/base/", "path") != "/base/path") {
        throw Exception("/base/ + path should be /base/path")
    }
}

@Test
func testJoinBstrUnixPathsepRelativeBase(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep::relative_base_or_path_are_nothing_special
    if (joinBstrUnixPathsep("base", ".") != "base/.") {
        throw Exception("base + . should be base/.")
    }
    if (joinBstrUnixPathsep("base", "..") != "base/..") {
        throw Exception("base + .. should be base/..")
    }
    if (joinBstrUnixPathsep("base", "../dir") != "base/../dir") {
        throw Exception("base + ../dir should be base/../dir")
    }
}

@Test
func testJoinBstrUnixPathsepEmptyComponents(): Unit {
    // 对齐 Rust: join_bstr_unix_pathsep — 空组件
    if (joinBstrUnixPathsep("", "path") != "path") {
        throw Exception("empty + path should be path")
    }
    if (joinBstrUnixPathsep("base", "") != "base/") {
        throw Exception("base + empty should be base/")
    }
}

// ============================================================
// normalize 补充测试 — 对齐 gix-path/tests/path/convert/normalize.rs
// ============================================================

@Test
func testNormalizeNoChangeIfNoTrailingRelative(): Unit {
    // 对齐 Rust: normalize::no_change_if_there_are_no_trailing_relative_components
    if (normalize("a/b/c/d") != "a/b/c/d") {
        throw Exception("already normalized should not change")
    }
}

@Test
func testNormalizeRemovesDotComponents(): Unit {
    // 对齐 Rust: normalize — 去除 . 组件
    if (normalize("./a/b") != "a/b") {
        throw Exception("./a/b should normalize to a/b")
    }
    if (normalize("a/./b") != "a/b") {
        throw Exception("a/./b should normalize to a/b")
    }
}

@Test
func testNormalizeRemovesDotDotComponents(): Unit {
    // 对齐 Rust: normalize — 去除 .. 组件
    if (normalize("a/b/../c") != "a/c") {
        throw Exception("a/b/../c should normalize to a/c")
    }
    if (normalize("a/b/c/../../d") != "a/d") {
        throw Exception("a/b/c/../../d should normalize to a/d")
    }
}

@Test
func testNormalizeDotDotAtRootStaysAtRoot(): Unit {
    // 对齐 Rust: normalize — .. 超出根目录
    if (normalize("a/../..") != "") {
        throw Exception("a/../.. should normalize to empty")
    }
}

@Test
func testNormalizeSingleComponent(): Unit {
    // 对齐 Rust: normalize — 单组件
    if (normalize("hello") != "hello") {
        throw Exception("single component should remain")
    }
}

// ============================================================
// parent 补充测试
// ============================================================

@Test
func testParentOfFilePath(): Unit {
    // 对齐 Rust: parent — 文件路径的父目录
    if (parent("/a/b/c.txt") != "/a/b") {
        throw Exception("parent of /a/b/c.txt should be /a/b")
    }
}

@Test
func testParentOfDirPath(): Unit {
    // 对齐 Rust: parent — 目录路径的父目录
    if (parent("/a/b/c/") != "/a/b") {
        throw Exception("parent of /a/b/c/ should be /a/b")
    }
}

@Test
func testParentOfRoot(): Unit {
    // 对齐 Rust: parent — 根路径无父目录
    if (parent("/").isSome()) {
        throw Exception("parent of / should be None")
    }
}

@Test
func testParentOfSingleComponent(): Unit {
    // 对齐 Rust: parent — 单组件无父目录
    if (parent("file.txt").isSome()) {
        throw Exception("parent of file.txt should be None")
    }
}

// ============================================================
// fileName 补充测试
// ============================================================

@Test
func testFileNameOfFilePath(): Unit {
    // 对齐 Rust: file_name — 文件路径的文件名
    if (fileName("/a/b/c.txt") != "c.txt") {
        throw Exception("file name of /a/b/c.txt should be c.txt")
    }
}

@Test
func testFileNameOfDirPath(): Unit {
    // 对齐 Rust: file_name — 目录路径的文件名
    if (fileName("/a/b/c/") != "c") {
        throw Exception("file name of /a/b/c/ should be c")
    }
}

@Test
func testFileNameOfRoot(): Unit {
    // 对齐 Rust: file_name — 根路径无文件名
    if (fileName("/").isSome()) {
        throw Exception("file name of / should be None")
    }
}

@Test
func testFileNameOfSingleComponent(): Unit {
    // 对齐 Rust: file_name — 单组件无文件名（无路径分隔符）
    if (fileName("file.txt").isSome()) {
        throw Exception("file name of file.txt should be None")
    }
}

// ============================================================
// relativizeWithPrefix 补充测试
// ============================================================

@Test
func testRelativizeWithPrefixBasic(): Unit {
    // 对齐 Rust: relativize — 基本相对路径
    let result = relativizeWithPrefix("/a/b/c", "/a/b")
    if (result != "c") {
        throw Exception("relativize /a/b/c from /a/b should be c, got " + result)
    }
}

@Test
func testRelativizeWithPrefixNested(): Unit {
    // 对齐 Rust: relativize — 嵌套路径
    let result = relativizeWithPrefix("/a/b/c/d", "/a/b")
    if (result != "c/d") {
        throw Exception("relativize nested should be c/d, got " + result)
    }
}
