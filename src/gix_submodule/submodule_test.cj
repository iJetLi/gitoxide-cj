// 文件：submodule_test.cj
// 用途：gix_submodule 包的单元测试，全量对齐 Rust gitoxide gix-submodule 测试
// 所属包：gix.gix_submodule
// 对齐来源：gix-submodule/tests/parse.rs

package gitoxide.gix_submodule

import std.unittest.*
import std.collection.*

// ============================================================
// parseGitmodules 测试 — 对齐 gix-submodule/tests/parse.rs
// ============================================================

@Test
func testParseGitmodulesSingleSubmodule(): Unit {
    // 对齐 Rust: parse single submodule
    let content = "[submodule \"dep\"]\n\tpath = dep\n\turl = https://github.com/example/dep"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule, got " + result.size.toString())
    }
    if (result[0].name != "dep") {
        throw Exception("name should be 'dep'")
    }
    if (result[0].path != "dep") {
        throw Exception("path should be 'dep'")
    }
    if (result[0].url != "https://github.com/example/dep") {
        throw Exception("url mismatch")
    }
}

@Test
func testParseGitmodulesWithBranch(): Unit {
    // 对齐 Rust: parse submodule with branch
    let content = "[submodule \"lib\"]\n\tpath = lib\n\turl = https://github.com/example/lib\n\tbranch = main"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].branch != Some("main")) {
        throw Exception("branch should be 'main'")
    }
}

@Test
func testParseGitmodulesMultipleSubmodules(): Unit {
    // 对齐 Rust: parse multiple submodules
    let content = "[submodule \"a\"]\n\tpath = a\n\turl = https://example.com/a\n[submodule \"b\"]\n\tpath = b\n\turl = https://example.com/b"
    let result = parseGitmodules(content)
    if (result.size != 2) {
        throw Exception("should have 2 submodules, got " + result.size.toString())
    }
    if (result[0].name != "a") {
        throw Exception("first name should be 'a'")
    }
    if (result[1].name != "b") {
        throw Exception("second name should be 'b'")
    }
}

@Test
func testParseGitmodulesEmptyContent(): Unit {
    // 对齐 Rust: parse empty content
    let result = parseGitmodules("")
    if (result.size != 0) {
        throw Exception("empty content should have 0 submodules")
    }
}

// ============================================================
// Submodule 构造测试
// ============================================================

@Test
func testSubmoduleConstruction(): Unit {
    // 对齐 Rust: Submodule construction
    let sub = Submodule("mylib", "libs/mylib", "https://example.com/mylib")
    if (sub.name != "mylib") {
        throw Exception("name mismatch")
    }
    if (sub.path != "libs/mylib") {
        throw Exception("path mismatch")
    }
    if (sub.url != "https://example.com/mylib") {
        throw Exception("url mismatch")
    }
    if (sub.branch != None) {
        throw Exception("branch should default to None")
    }
}

// ============================================================
// parseGitmodules 补充测试 — 对齐 gix-submodule/tests/{path,url}.rs
// ============================================================

@Test
func testPathValid(): Unit {
    // 对齐 Rust: path::valid — 解析合法相对路径
    let content = "[submodule \"a\"]\n\tpath = relative/path/submodule\n\turl = https://example.com/repo"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].path != "relative/path/submodule") {
        throw Exception("path should be 'relative/path/submodule', got '" + result[0].path + "'")
    }
}

@Test
func testUrlValid(): Unit {
    // 对齐 Rust: url::valid — 解析合法 URL
    let content = "[submodule \"a\"]\n\tpath = a\n\turl = path-to-repo"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].url != "path-to-repo") {
        throw Exception("url should be 'path-to-repo'")
    }
}

@Test
func testPathMissing(): Unit {
    // 对齐 Rust: path::validate — 缺 path 时 path 为空串
    let content = "[submodule \"a\"]\n\turl = https://example.com/repo"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].path.size != 0) {
        throw Exception("missing path should be empty string")
    }
}

@Test
func testUrlMissing(): Unit {
    // 对齐 Rust: url::validate — 缺 url 时 url 为空串
    let content = "[submodule \"a\"]\n\tpath = a"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].url.size != 0) {
        throw Exception("missing url should be empty string")
    }
}

@Test
func testParseGitmodulesNameWithSpecialChars(): Unit {
    // 对齐 Rust: baseline — 特殊名称
    let content = "[submodule \"a/..c\"]\n\tpath = ac\n\turl = https://example.com/repo"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].name != "a/..c") {
        throw Exception("name should be 'a/..c'")
    }
}

// ============================================================
// parseGitmodules 补充测试 2 — 对齐 gix-submodule 更多场景
// ============================================================

@Test
func testParseGitmodulesSshUrl(): Unit {
    // 对齐 Rust: submodule with SSH URL
    let content = "[submodule \"upstream\"]\n\tpath = upstream\n\turl = git@github.com:example/repo.git"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].url != "git@github.com:example/repo.git") {
        throw Exception("SSH URL mismatch: " + result[0].url)
    }
}

@Test
func testParseGitmodulesRelativeUrl(): Unit {
    // 对齐 Rust: submodule with relative URL
    let content = "[submodule \"rel\"]\n\tpath = rel\n\turl = ../other-repo"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].url != "../other-repo") {
        throw Exception("relative URL mismatch")
    }
}

@Test
func testParseGitmodulesBranchOverride(): Unit {
    // 对齐 Rust: submodule with explicit branch tracking
    let content = "[submodule \"tracked\"]\n\tpath = tracked\n\turl = https://example.com/repo\n\tbranch = v2.0"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule")
    }
    if (result[0].branch != Some("v2.0")) {
        throw Exception("branch should be 'v2.0'")
    }
}

@Test
func testParseGitmodulesCommentsIgnored(): Unit {
    // 对齐 Rust: .gitmodules 中 # 开头的注释行被忽略
    let content = "# This is a comment\n[submodule \"a\"]\n\tpath = a\n\turl = https://example.com/a"
    let result = parseGitmodules(content)
    if (result.size != 1) {
        throw Exception("should have 1 submodule after skipping comments")
    }
}

@Test
func testSubmoduleBranchFieldMutable(): Unit {
    // 对齐 Rust: Submodule branch 字段可变
    let sub = Submodule("test", "test", "https://example.com/test")
    if (!sub.branch.isNone()) {
        throw Exception("branch should default to None")
    }
    sub.branch = Some("develop")
    if (sub.branch != Some("develop")) {
        throw Exception("branch should be 'develop'")
    }
    sub.branch = None
    if (!sub.branch.isNone()) {
        throw Exception("branch should be None after reset")
    }
}
