// 文件：repository_test.cj
// 用途：repository 包胶水模块的单元测试，对齐 Rust gitoxide gitoxide-core/src/repository/ 测试
// 所属包：gix.repository
// 对齐来源：gitoxide-core/src/repository/status.rs, diff.rs, blame.rs, merge/, etc.

package gitoxide.repository

import std.unittest.*
import std.collection.*
import gitoxide.gix_hash.*
import gitoxide.gix_status.*
import gitoxide.gix_diff.*
import gitoxide.gix_blame.*
import gitoxide.gix_merge.*
import gitoxide.gix_object.*
import gitoxide.gix_index.*
import gitoxide.gix_attributes.*
import gitoxide.gix_ignore.*
import gitoxide.gix_mailmap.*
import gitoxide.gix_submodule.*
import gitoxide.gix_credentials.*
import gitoxide.gix_archive.*
import gitoxide.gix_dir.*

// ============================================================
// StatusQuery 测试 — 对齐 gitoxide-core/src/repository/status.rs
// ============================================================

@Test
func testStatusQueryConstruction(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    if (query.repo.gitDir != "/tmp/nonexistent") {
        throw Exception("StatusQuery repo mismatch")
    }
}

@Test
func testNormalizeToLfEmptyInput(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = []
    let result = query.normalizeToLf(input)
    if (result.size != 0) {
        throw Exception("empty input should produce empty output")
    }
}

@Test
func testNormalizeToLfNoCRLF(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = [72, 101, 108, 108, 111, 10]
    let result = query.normalizeToLf(input)
    if (result.size != 6) {
        throw Exception("LF-only input should not change size, got ${result.size}")
    }
    if (result[5] != 10) {
        throw Exception("LF should be preserved")
    }
}

@Test
func testNormalizeToLfCRLF(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = [72, 101, 13, 10, 87, 111, 13, 10]
    let result = query.normalizeToLf(input)
    if (result.size != 6) {
        throw Exception("CRLF→LF should shrink by CRLF count, got ${result.size}")
    }
    if (result[2] != 10) {
        throw Exception("CRLF should become LF at position 2")
    }
    if (result[5] != 10) {
        throw Exception("CRLF should become LF at position 5")
    }
}

@Test
func testNormalizeToLfMixedCRLF(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = [65, 13, 10, 66, 10, 67, 13, 10, 68]
    let result = query.normalizeToLf(input)
    if (result.size != 7) {
        throw Exception("mixed input should normalize correctly, got ${result.size}")
    }
    if (result[0] != 65) {
        throw Exception("A should be preserved")
    }
    if (result[1] != 10) {
        throw Exception("CRLF should become LF")
    }
    if (result[3] != 10) {
        throw Exception("bare LF should be preserved")
    }
}

@Test
func testNormalizeToLfStandaloneCR(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = [65, 13, 66, 10]
    let result = query.normalizeToLf(input)
    if (result.size != 4) {
        throw Exception("standalone CR should be preserved, got ${result.size}")
    }
    if (result[1] != 13) {
        throw Exception("standalone CR should not be converted")
    }
}

@Test
func testNormalizeToLfTrailingCR(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = StatusQuery(repo)
    let input: Array<Byte> = [65, 13]
    let result = query.normalizeToLf(input)
    if (result.size != 2) {
        throw Exception("trailing CR should be preserved, got ${result.size}")
    }
    if (result[1] != 13) {
        throw Exception("trailing CR should not be converted")
    }
}

// ============================================================
// DiffQuery 测试 — 对齐 gitoxide-core/src/repository/diff.rs
// ============================================================

@Test
func testDiffQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = DiffQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("DiffQuery repo mismatch")
    }
}

@Test
func testDiffQueryTreeByRevspecInvalid(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = DiffQuery(repo)
    let result = query.treeByRevspec("HEAD", "HEAD~1")
    if (result.isSome()) {
        throw Exception("invalid repo should return None")
    }
}

// ============================================================
// BlameQuery 测试 — 对齐 gitoxide-core/src/repository/blame.rs
// ============================================================

@Test
func testBlameQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = BlameQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("BlameQuery repo mismatch")
    }
}

@Test
func testBlameQueryFileInvalidRepo(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = BlameQuery(repo)
    let result = query.file("test.txt", None)
    if (result.isSome()) {
        throw Exception("invalid repo should return None for blame")
    }
}

// ============================================================
// MergeQuery 测试 — 对齐 gitoxide-core/src/repository/merge/
// ============================================================

@Test
func testMergeQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = MergeQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("MergeQuery repo mismatch")
    }
}

@Test
func testMergeQueryFileCleanMerge(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = MergeQuery(repo)
    let base = "line1\nline2\n"
    let ours = "line1\nline2\nline3\n"
    let theirs = "line1\nline2\nline3\n"
    let opts = TextMergeOptions()
    let labels = Labels()
    let result = query.file(base, ours, theirs, opts, labels)
    match (result) {
        case MergeResult.Clean(content) =>
            if (!content.lines.contains("line3")) {
                throw Exception("clean merge should contain line3")
            }
        case MergeResult.Conflict(_) => throw Exception("should be clean when ours == theirs")
    }
}

// ============================================================
// DirwalkQuery 测试 — 对齐 gitoxide-core/src/repository/dirwalk.rs
// ============================================================

@Test
func testDirwalkQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = DirwalkQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("DirwalkQuery repo mismatch")
    }
}

@Test
func testDirwalkQueryBareRepo(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = DirwalkQuery(repo)
    let entries = query.collect()
    if (entries.size != 0) {
        throw Exception("bare repo should return empty dirwalk")
    }
}

// ============================================================
// CleanQuery 测试 — 对齐 gitoxide-core/src/repository/clean.rs
// ============================================================

@Test
func testCleanQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CleanQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("CleanQuery repo mismatch")
    }
}

@Test
func testCleanQueryBareRepo(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CleanQuery(repo)
    let removed = query.removeUntracked(true)
    if (removed.size != 0) {
        throw Exception("bare repo should remove nothing")
    }
}

// ============================================================
// AttributesQuery 测试 — 对齐 gitoxide-core/src/repository/attributes/
// ============================================================

@Test
func testAttributesQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = AttributesQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("AttributesQuery repo mismatch")
    }
}

@Test
func testAttributesQueryNoGitattributes(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = AttributesQuery(repo)
    let result = query.query("README.md")
    if (result.size != 0) {
        throw Exception("no .gitattributes should return empty list")
    }
}

@Test
func testAttributesQueryValidateBaselineNoFile(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = AttributesQuery(repo)
    let issues = query.validateBaseline()
    if (issues.size != 0) {
        throw Exception("no .gitattributes should have no issues")
    }
}

// ============================================================
// ExcludeQuery 测试 — 对齐 gitoxide-core/src/repository/exclude.rs
// ============================================================

@Test
func testExcludeQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = ExcludeQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("ExcludeQuery repo mismatch")
    }
}

@Test
func testExcludeQueryNoGitignore(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = ExcludeQuery(repo)
    let result = query.query("README.md")
    if (result) {
        throw Exception("no .gitignore should not match anything")
    }
}

// ============================================================
// FetchQuery 测试 — 对齐 gitoxide-core/src/repository/fetch.rs
// ============================================================

@Test
func testFetchQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = FetchQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("FetchQuery repo mismatch")
    }
}

@Test
func testFetchQueryNoConfig(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    repo.config = None
    let query = FetchQuery(repo)
    let result = query.fetch("origin")
    if (result.isSome()) {
        throw Exception("no config should return None for fetch")
    }
}

// ============================================================
// CredentialQuery 测试 — 对齐 gitoxide-core/src/repository/credential.rs
// ============================================================

@Test
func testCredentialQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CredentialQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("CredentialQuery repo mismatch")
    }
}

@Test
func testCredentialQueryFillReturnsInput(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CredentialQuery(repo)
    let cred = Credential()
    let result = query.fill(cred)
    if (result.protocol != cred.protocol) {
        throw Exception("fill should return same credential")
    }
}

// ============================================================
// ArchiveQuery 测试 — 对齐 gitoxide-core/src/repository/archive.rs
// ============================================================

@Test
func testArchiveQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = ArchiveQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("ArchiveQuery repo mismatch")
    }
}

@Test
func testArchiveQueryInvalidTreeish(): Unit {
    let repo = Repository("/tmp/nonexistent", None, HashKind.Sha1)
    let query = ArchiveQuery(repo)
    let result = query.stream("HEAD")
    if (result.isSome()) {
        throw Exception("invalid repo should return None for archive")
    }
}

// ============================================================
// SubmoduleQuery 测试 — 对齐 gitoxide-core/src/repository/submodule.rs
// ============================================================

@Test
func testSubmoduleQueryConstruction(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = SubmoduleQuery(repo)
    if (query.repo.gitDir != "/tmp/test") {
        throw Exception("SubmoduleQuery repo mismatch")
    }
}

@Test
func testSubmoduleQueryBareRepo(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = SubmoduleQuery(repo)
    let result = query.list()
    if (result.size != 0) {
        throw Exception("bare repo should have no submodules")
    }
}

@Test
func testCommitSignQueryVerifyUnsigned(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CommitSignQuery(repo)
    let result = query.verify("HEAD")
    if (!result.startsWith("Error:")) {
        throw Exception("verify on bare repo should return error, got: " + result)
    }
}

@Test
func testCommitSignQuerySignNoGpg(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = CommitSignQuery(repo)
    let result = query.sign("HEAD")
    if (!result.isNone()) {
        throw Exception("sign on bare repo without GPG should return None")
    }
}

@Test
func testRemoteQueryUrlNoConfig(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let urls = query.url("origin", false, false)
    if (urls.size != 0) {
        throw Exception("bare repo without config should have no URLs")
    }
}

@Test
func testRemoteQueryUrlPushNoConfig(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let urls = query.url("origin", true, false)
    if (urls.size != 0) {
        throw Exception("bare repo without config should have no push URLs")
    }
}

@Test
func testRemoteQueryUrlAllNoConfig(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let urls = query.url("origin", false, true)
    if (urls.size != 0) {
        throw Exception("bare repo without config should have no URLs (all)")
    }
}

@Test
func testRemoteQueryRefsNoNetwork(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let result = query.refs("origin", false)
    if (!result.isNone()) {
        throw Exception("refs without network should return None")
    }
}

@Test
func testRemoteQueryRefMapNoNetwork(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let result = query.refMap("origin", false)
    if (!result.isNone()) {
        throw Exception("ref-map without network should return None")
    }
}

@Test
func testRemoteQueryResolveUrlDirect(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("https://github.com/example/repo.git")
    if (url.isNone()) {
        throw Exception("direct URL should be resolved")
    }
    if (let Some(u) <- url) {
        if (u != "https://github.com/example/repo.git") {
            throw Exception("direct URL should be returned as-is, got: " + u)
        }
    }
}

@Test
func testRemoteQueryResolveUrlSsh(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("ssh://git@github.com/example/repo.git")
    if (url.isNone()) {
        throw Exception("SSH URL should be resolved")
    }
}

@Test
func testRemoteQueryResolveUrlGit(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("git://github.com/example/repo.git")
    if (url.isNone()) {
        throw Exception("git:// URL should be resolved")
    }
}

@Test
func testRemoteQueryResolveUrlFile(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("file:///tmp/repo.git")
    if (url.isNone()) {
        throw Exception("file:// URL should be resolved")
    }
}

@Test
func testRemoteQueryResolveUrlHttp(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("http://example.com/repo.git")
    if (url.isNone()) {
        throw Exception("http:// URL should be resolved")
    }
}

@Test
func testRemoteQueryResolveNameNoConfig(): Unit {
    let repo = Repository("/tmp/test", None, HashKind.Sha1)
    let query = RemoteQuery(repo)
    let url = query.resolveRemoteUrl("origin")
    if (!url.isNone()) {
        throw Exception("remote name without config should return None")
    }
}

@Test
func testRefMappingCreation(): Unit {
    let mapping = RefMapping("refs/heads/main", "refs/remotes/origin/main", "[new]", true, None)
    if (mapping.remoteRef != "refs/heads/main") {
        throw Exception("remoteRef mismatch")
    }
    if (mapping.localRef != "refs/remotes/origin/main") {
        throw Exception("localRef mismatch")
    }
    if (mapping.status != "[new]") {
        throw Exception("status mismatch")
    }
    if (!mapping.forced) {
        throw Exception("forced should be true")
    }
}

@Test
func testRefMappingWithOid(): Unit {
    let oid = ObjectId.fromHexOrThrow("1fca93d7da9194216eeb77ae04c19559bbffb1c5")
    let mapping = RefMapping("refs/heads/main", "refs/remotes/origin/main", "[up-to-date]", false, Some(oid))
    if (mapping.objectId.isNone()) {
        throw Exception("objectId should be present")
    }
    if (mapping.status != "[up-to-date]") {
        throw Exception("status should be [up-to-date]")
    }
}
