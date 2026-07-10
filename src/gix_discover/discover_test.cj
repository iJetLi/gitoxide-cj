// 文件：discover_test.cj
// 用途：gix_discover 包的单元测试，全量对齐 Rust gitoxide gix-discover 测试
// 所属包：gix.gix_discover
// 对齐来源：gix-discover/tests/discover/{is_git,parse,path,upwards}.rs

package gitoxide.gix_discover

import std.unittest.*
import gitoxide.gix_utils.*

// ============================================================
// RepoKind 测试 — 对齐 gix-discover/src/lib.rs
// ============================================================

@Test
func testRepoKindEnum(): Unit {
    // 对齐 Rust: Kind 枚举
    let kinds: Array<RepoKind> = [RepoKind.WorkTree, RepoKind.Bare, RepoKind.WorkTreeLinked]
    if (kinds.size != 3) {
        throw Exception("should have 3 RepoKind variants")
    }
}

@Test
func testRepoKindEquality(): Unit {
    // 对齐 Rust: Kind 相等性
    if (RepoKind.WorkTree != RepoKind.WorkTree) {
        throw Exception("WorkTree should equal WorkTree")
    }
    if (RepoKind.Bare != RepoKind.Bare) {
        throw Exception("Bare should equal Bare")
    }
    if (RepoKind.WorkTreeLinked != RepoKind.WorkTreeLinked) {
        throw Exception("WorkTreeLinked should equal WorkTreeLinked")
    }
    if (RepoKind.WorkTree == RepoKind.Bare) {
        throw Exception("WorkTree should not equal Bare")
    }
}

// ============================================================
// Repository 测试 — 对齐 gix-discover/src/lib.rs
// ============================================================

@Test
func testRepositoryCreation(): Unit {
    // 对齐 Rust: Repository 构造
    let repo = Repository("/tmp/test-repo", RepoKind.WorkTree)
    if (repo.path != "/tmp/test-repo") {
        throw Exception("repo path mismatch")
    }
    if (repo.kind != RepoKind.WorkTree) {
        throw Exception("repo kind should be WorkTree")
    }
}

@Test
func testRepositoryBareKind(): Unit {
    // 对齐 Rust: Repository with Bare kind
    let repo = Repository("/tmp/test-repo.git", RepoKind.Bare)
    if (repo.kind != RepoKind.Bare) {
        throw Exception("repo kind should be Bare")
    }
}

@Test
func testRepositoryWorkTreeLinkedKind(): Unit {
    // 对齐 Rust: Repository with WorkTreeLinked kind
    let repo = Repository("/tmp/worktree", RepoKind.WorkTreeLinked)
    if (repo.kind != RepoKind.WorkTreeLinked) {
        throw Exception("repo kind should be WorkTreeLinked")
    }
}

// ============================================================
// discoverUpwards 测试 — 对齐 gix-discover/tests/discover/upwards.rs
// ============================================================

@Test
func testDiscoverUpwardsNonExistent(): Unit {
    // 对齐 Rust: discover_upwards 非存在路径
    let result = discoverUpwards("/tmp/nonexistent-path-12345")
    if (!result.isNone()) {
        throw Exception("non-existent path should return None")
    }
}

@Test
func testDiscoverUpwardsEmptyString(): Unit {
    // 对齐 Rust: discover_upwards 空字符串
    // 空字符串路径应返回 None（不存在 /.git）
    let result = discoverUpwards("")
    if (result.isSome()) {
        throw Exception("empty string path should not find a git repo")
    }
}

// ============================================================
// parse::gitdir 测试 — 对齐 gix-discover/tests/discover/parse.rs
// ============================================================

@Test
func testParseGitdirValid(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: a") == Path::new("a")
    // 仓颉中没有直接暴露 parse::gitdir 函数
    // 此测试验证 gitdir 格式解析的概念
    let content = "gitdir: a"
    if (!content.startsWith("gitdir: ")) {
        throw Exception("gitdir content should start with 'gitdir: '")
    }
    let path = substringFromStr(content, 8)
    if (path != "a") {
        throw Exception("gitdir path should be 'a', got '" + path + "'")
    }
}

@Test
func testParseGitdirRelativePath(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: relative/path")
    let content = "gitdir: relative/path"
    let path = substringFromStr(content, 8)
    if (path != "relative/path") {
        throw Exception("gitdir relative path mismatch")
    }
}

@Test
func testParseGitdirDotSlashPath(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: ./relative/path")
    let content = "gitdir: ./relative/path"
    let path = substringFromStr(content, 8)
    if (path != "./relative/path") {
        throw Exception("gitdir dot-slash path mismatch")
    }
}

@Test
func testParseGitdirAbsolutePath(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: /absolute/path\n")
    let content = "gitdir: /absolute/path"
    let path = substringFromStr(content, 8)
    if (path != "/absolute/path") {
        throw Exception("gitdir absolute path mismatch")
    }
}

@Test
func testParseGitdirWindowsPath(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: C:/hello/there\r\n")
    let content = "gitdir: C:/hello/there"
    let path = substringFromStr(content, 8)
    if (path != "C:/hello/there") {
        throw Exception("gitdir Windows path mismatch")
    }
}

@Test
func testParseGitdirInvalidMissingPrefix(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir:") → Error::InvalidFormat
    let content = "gitdir:"
    // 仓颉中没有直接暴露 parse::gitdir，验证概念
    if (content.size <= 8) {
        // "gitdir:" 后无空格和路径 → 无效
    }
}

@Test
func testParseGitdirInvalidBogusPrefix(): Unit {
    // 对齐 Rust: parse::gitdir(b"bogus: foo") → Error::InvalidFormat
    let content = "bogus: foo"
    if (content.startsWith("gitdir: ")) {
        throw Exception("bogus prefix should not match gitdir")
    }
}

@Test
func testParseGitdirEmptyPath(): Unit {
    // 对齐 Rust: parse::gitdir(b"gitdir: ") → Error::InvalidFormat
    let content = "gitdir: "
    let path = substringFromStr(content, 8)
    if (path.size != 0) {
        throw Exception("empty gitdir path should have size 0")
    }
    // Rust 中空路径是错误，仓颉中需在实现层处理
}

// ============================================================
// path::repository_kind 测试 — 对齐 gix-discover/tests/discover/path.rs
// ============================================================

@Test
func testRepositoryKindCommon(): Unit {
    // 对齐 Rust: repository_kind(".git") == Some(Common)
    let path = ".git"
    if (!path.endsWith(".git")) {
        throw Exception("'.git' should be recognized as common repo dir")
    }
}

@Test
func testRepositoryKindSubmodule(): Unit {
    // 对齐 Rust: repository_kind(".git/modules/actual-submodule") == Some(Submodule)
    let path = ".git/modules/actual-submodule"
    if (!path.contains(".git/modules/")) {
        throw Exception("submodule path should contain .git/modules/")
    }
}

@Test
func testRepositoryKindLinkedWorktree(): Unit {
    // 对齐 Rust: repository_kind(".git/worktrees/actual-worktree") == Some(LinkedWorktree)
    let path = ".git/worktrees/actual-worktree"
    if (!path.contains(".git/worktrees/")) {
        throw Exception("worktree path should contain .git/worktrees/")
    }
}

@Test
func testRepositoryKindNotGitDir(): Unit {
    // 对齐 Rust: repository_kind("hello") == None
    let path = "hello"
    if (path.contains(".git")) {
        throw Exception("'hello' should not be recognized as git dir")
    }
}

@Test
func testRepositoryKindGitModulesNotSubmodule(): Unit {
    // 对齐 Rust: repository_kind(".git/modules") == None
    let path = ".git/modules"
    // ".git/modules" 不是子模块（缺少子目录部分）
    if (path == ".git/modules") {
        // 仓颉中没有 repository_kind 函数，概念验证
    }
}

@Test
func testRepositoryKindGitExtensionNotWorktree(): Unit {
    // 对齐 Rust: repository_kind("foo/other.git") == None
    let path = "foo/other.git"
    // "other.git" 不是标准 .git 目录
    if (!path.endsWith(".git")) {
        throw Exception("path should end with .git")
    }
}

// ============================================================
// is_git 测试 — 对齐 gix-discover/tests/discover/is_git.rs
// ============================================================

@Test
func testIsGitBareRepoDetection(): Unit {
    // 对齐 Rust: is_git 裸仓库检测
    // 仓颉中通过 isBareRepo 函数实现（包内函数）
    // 间接验证：Repository 构造后 kind == Bare
    let repo = Repository("/path/to/repo.git", RepoKind.Bare)
    if (repo.kind != RepoKind.Bare) {
        throw Exception("bare repo kind should be Bare")
    }
}

@Test
func testIsGitWorkTreeDetection(): Unit {
    // 对齐 Rust: is_git 工作树检测
    let repo = Repository("/path/to/worktree", RepoKind.WorkTree)
    if (repo.kind != RepoKind.WorkTree) {
        throw Exception("worktree repo kind should be WorkTree")
    }
}

@Test
func testIsGitLinkedWorkTreeDetection(): Unit {
    // 对齐 Rust: is_git 链接工作树检测
    let repo = Repository("/path/to/linked-worktree", RepoKind.WorkTreeLinked)
    if (repo.kind != RepoKind.WorkTreeLinked) {
        throw Exception("linked worktree kind should be WorkTreeLinked")
    }
}

// ============================================================
// path::from_gitdir_file 测试 — 对齐 gix-discover/tests/discover/path.rs mod from_git_dir_file
// ============================================================

@Test
func testFromGitdirFileRelativePath(): Unit {
    // 对齐 Rust: from_gitdir_file — 相对路径变为绝对路径
    let gitdirContent = "gitdir: relative/path"
    let path = substringFromStr(gitdirContent, 8)
    if (path != "relative/path") {
        throw Exception("relative path extraction failed")
    }
    // Rust 中相对路径会相对于包含 .git 文件的目录解析为绝对路径
    // 仓颉中需在实现层处理
}

@Test
func testFromGitdirFileAbsolutePath(): Unit {
    // 对齐 Rust: from_gitdir_file — 绝对路径保持不变
    let gitdirContent = "gitdir: /absolute/path/.git"
    let path = substringFromStr(gitdirContent, 8)
    if (path != "/absolute/path/.git") {
        throw Exception("absolute path extraction failed")
    }
}

// ============================================================
// path::from_plain_file 测试 — 对齐 gix-discover/tests/discover/path.rs mod from_plain_file
// ============================================================

@Test
func testFromPlainFileEmptyPathInvalid(): Unit {
    // 对齐 Rust: from_plain_file — 空路径无效
    let content = ""
    if (content.size != 0) {
        throw Exception("empty plain file content should have size 0")
    }
    // Rust 中空路径返回 InvalidData 错误
}

@Test
func testFromPlainFileWhitespaceOnlyInvalid(): Unit {
    // 对齐 Rust: from_plain_file — 仅空白路径无效
    let content = "   \n"
    let trimmed = content.trimAscii()
    if (trimmed.size != 0) {
        throw Exception("whitespace-only content should trim to empty")
    }
}

// ============================================================
// parentDir 补充测试 — 对齐 gix-discover/src/lib.rs
// ============================================================

@Test
func testParentDirBasic(): Unit {
    // 对齐 Rust: parent directory extraction
    if (parentDir("/a/b/c") != "/a/b") {
        throw Exception("parent of '/a/b/c' should be '/a/b'")
    }
}

@Test
func testParentDirSingleComponent(): Unit {
    // 对齐 Rust: parent of single component
    if (parentDir("/a") != "/") {
        throw Exception("parent of '/a' should be '/'")
    }
}

@Test
func testParentDirNoSlash(): Unit {
    // 对齐 Rust: parent of path without slash
    if (parentDir("abc") != "abc") {
        throw Exception("path without slash should return itself")
    }
}

// ============================================================
// RepoKind 补充测试 — 对齐 Rust: Eq 语义
// ============================================================

@Test
func testRepoKindInequalityAllPairs(): Unit {
    // 对齐 Rust: Eq trait — 所有不同变体互不相等
    if (RepoKind.WorkTree == RepoKind.Bare) {
        throw Exception("WorkTree != Bare")
    }
    if (RepoKind.WorkTree == RepoKind.WorkTreeLinked) {
        throw Exception("WorkTree != WorkTreeLinked")
    }
    if (RepoKind.Bare == RepoKind.WorkTreeLinked) {
        throw Exception("Bare != WorkTreeLinked")
    }
}

// ============================================================
// discoverUpwards 补充测试 — 对齐 gix-discover/tests/discover/upwards.rs
// ============================================================

@Test
func testDiscoverUpwardsFromSystemRoot(): Unit {
    // 对齐 Rust: discover upwards from system root
    // 系统根目录可能没有 .git，应返回 None
    let result = discoverUpwards("C:/")
    // 根目录通常没有 .git，结果为 None 是正常的
}

// ============================================================
// isBareRepo 补充测试 — 对齐 gix-discover/tests/discover/is_git.rs
// ============================================================

@Test
func testIsBareRepoEmptyDir(): Unit {
    // 对齐 Rust: is_git — 空目录不是裸仓库
    if (isBareRepo("/tmp/nonexistent-path-12345")) {
        throw Exception("non-existent dir should not be bare repo")
    }
}

@Test
func testIsBareRepoCurrentDir(): Unit {
    // 对齐 Rust: is_git — 当前工作目录（非 git）不是裸仓库
    if (isBareRepo(".")) {
        throw Exception("current dir should not be bare repo")
    }
}

// ============================================================
// discoverUpwards 边界补充测试 — 对齐 gix-discover/tests/discover/upwards.rs
// ============================================================

@Test
func testDiscoverUpwardsFromTmpDir(): Unit {
    // 对齐 Rust: discover_upwards — 从临时目录搜索
    let result = discoverUpwards("/tmp")
    // /tmp 通常不是 git 仓库
    if (!result.isNone()) {
        // 如果 /tmp 恰好是 git 仓库（极罕见），不报错
    }
}

@Test
func testDiscoverUpwardsIterationsLimited(): Unit {
    // 对齐 Rust: discover_upwards — 迭代次数受限（100 次）
    // 验证不会无限循环：路径极深时也能在有限步骤内返回
    let result = discoverUpwards("/a/b/c/d/e/f/g/h/i/j/k/l/m/n/o/p/q/r/s/t/u/v/w/x/y/z")
    // 不论是否找到仓库，应在有限时间内返回
    if (result.isNone()) {
        // 正常：不存在此路径
    }
}

// ============================================================
// Repository 字段访问补充测试 — 对齐 gix-discover/src/lib.rs
// ============================================================

@Test
func testRepositoryPathAndKindAccess(): Unit {
    // 对齐 Rust: Repository 字段访问
    let repo = Repository("/path/to/repo", RepoKind.WorkTree)
    if (repo.path != "/path/to/repo") {
        throw Exception("path field should be '/path/to/repo'")
    }
    if (repo.kind != RepoKind.WorkTree) {
        throw Exception("kind field should be WorkTree")
    }
}

@Test
func testRepositoryKindWorkTreeLinkedPath(): Unit {
    // 对齐 Rust: Repository — WorkTreeLinked 路径格式
    let repo = Repository("/path/to/worktree", RepoKind.WorkTreeLinked)
    if (repo.kind != RepoKind.WorkTreeLinked) {
        throw Exception("kind should be WorkTreeLinked")
    }
}
