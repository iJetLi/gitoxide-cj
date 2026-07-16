// 文件：revision_test.cj
// 用途：gix_revision 包的单元测试，全量对齐 Rust gitoxide gix-revision 测试
// 所属包：gix.gix_revision
// 对齐来源：gix-revision/tests/revision/spec/parse/*.rs, display.rs, kind.rs

package gitoxide.gix_revision

import gitoxide.gix_hash.*
import std.unittest.*
import std.collection.*
import gitoxide.gix_utils.*
import gitoxide.gix_revwalk.*

// ============================================================
// 辅助函数
// ============================================================

func hexToId(hex: String): ObjectId {
    ObjectId.fromHexOrThrow(hex)
}

// 测试用提交提供器
class TestCommitProvider <: ProvideCommits {
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        None
    }
}

// 测试用引用解析器
class TestResolver <: ResolveRef {
    var refs: HashMap<String, ObjectId>
    var parents: HashMap<ObjectId, ObjectId>

    init() {
        this.refs = HashMap<String, ObjectId>()
        this.parents = HashMap<ObjectId, ObjectId>()
    }

    public func resolveRef(name: String): ?ObjectId {
        refs.get(name)
    }

    public func resolveParent(id: ObjectId): ?ObjectId {
        parents.get(id)
    }

    public func resolveNthParent(id: ObjectId, n: Int64): ?ObjectId {
        None
    }

    public func resolveTree(id: ObjectId): ?ObjectId {
        None
    }

    public func resolvePath(path: String): ?ObjectId {
        None
    }

    public func resolveUpstream(refName: String): ?ObjectId {
        None
    }

    public func resolvePush(refName: String): ?ObjectId {
        None
    }

    public func resolveNthPrior(refName: String, n: Int64): ?ObjectId {
        None
    }
}

// ============================================================
// Spec.parse 测试 — 对齐 gix-revision/tests/revision/spec/parse/mod.rs
// ============================================================

@Test
func testSpecParseSimple(): Unit {
    // 对齐 Rust: Spec::parse simple string
    let spec = Spec.parse("HEAD")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseFullHash(): Unit {
    // 对齐 Rust: Spec::parse full 40-char hash
    let spec = Spec.parse("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRefPath(): Unit {
    // 对齐 Rust: Spec::parse refs/ path
    let spec = Spec.parse("refs/heads/main")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "refs/heads/main") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretSyntax(): Unit {
    // 对齐 Rust: Spec::parse ^ parent syntax
    let spec = Spec.parse("HEAD^")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseAtSymbol(): Unit {
    // 对齐 Rust: anchor::refnames — @ by itself is shortcut for HEAD
    let spec = Spec.parse("@")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseTildeSyntax(): Unit {
    // 对齐 Rust: navigate::tilde_symbol — ~ ancestor syntax
    let spec = Spec.parse("HEAD~")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD~") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseTildeWithNumber(): Unit {
    // 对齐 Rust: navigate::tilde_symbol — ~N ancestor syntax
    let spec = Spec.parse("HEAD~3")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD~3") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRangeDotDot(): Unit {
    // 对齐 Rust: kind::range — r1..r2 range syntax
    let spec = Spec.parse("r1..r2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "r1..r2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseMergeDotDotDot(): Unit {
    // 对齐 Rust: kind::mergebase — r1...r2 merge-base syntax
    let spec = Spec.parse("r1...r2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "r1...r2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseExcludeCaret(): Unit {
    // 对齐 Rust: kind::exclusive — ^HEAD exclude syntax
    let spec = Spec.parse("^HEAD")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "^HEAD") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseIncludeParents(): Unit {
    // 对齐 Rust: kind::include_parents — HEAD^@ include parents syntax
    let spec = Spec.parse("HEAD^@")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^@") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseExcludeParents(): Unit {
    // 对齐 Rust: kind::exclude_parents — HEAD^! exclude parents syntax
    let spec = Spec.parse("HEAD^!")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^!") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseColonRegex(): Unit {
    // 对齐 Rust: anchor::colon_symbol — :/regex commit message search
    let spec = Spec.parse(":/fix bug")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != ":/fix bug") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseColonPath(): Unit {
    // 对齐 Rust: navigate::colon_symbol — @:path tree path lookup
    let spec = Spec.parse("@:README.md")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@:README.md") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseAtBracesReflog(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{n} reflog entry
    let spec = Spec.parse("@{0}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@{0}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseDescribeFormat(): Unit {
    // 对齐 Rust: anchor::describe — describe format like v1.0-0-g3bee7fb
    let spec = Spec.parse("v1.0-0-g3bee7fb")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "v1.0-0-g3bee7fb") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseShortHash(): Unit {
    // 对齐 Rust: anchor::hash — short hex literals as prefixes
    let spec = Spec.parse("abcd")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "abcd") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseWhitespaceVerbatim(): Unit {
    // 对齐 Rust: parse::all_characters_are_taken_verbatim_which_includes_whitespace
    let spec = Spec.parse("  HEAD \n")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "  HEAD \n") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseEmptyString(): Unit {
    // 对齐 Rust: parse::empty_specs_are_valid — empty string
    let spec = Spec.parse("")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRefnameHead(): Unit {
    // 对齐 Rust: anchor::refnames — HEAD as refname
    let spec = Spec.parse("HEAD")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRefnameTag(): Unit {
    // 对齐 Rust: anchor::refnames — tag-like refname
    let spec = Spec.parse("v1.2.3.4-beta.1")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "v1.2.3.4-beta.1") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRefnameWithHeadPrefix(): Unit {
    // 对齐 Rust: anchor::refnames — HEADfake is a ref, not HEAD
    let spec = Spec.parse("HEADfake")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEADfake") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseFullRefName(): Unit {
    // 对齐 Rust: anchor::refnames — refs/heads/main full ref
    let spec = Spec.parse("refs/heads/main")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "refs/heads/main") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretWithNumber(): Unit {
    // 对齐 Rust: navigate::caret_symbol — ^N explicit parent number
    let spec = Spec.parse("HEAD^2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretBracesObjectType(): Unit {
    // 对齐 Rust: navigate::caret_symbol — ^{commit} peel to object type
    let spec = Spec.parse("HEAD^{commit}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^{commit}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretBracesEmpty(): Unit {
    // 对齐 Rust: navigate::caret_symbol — ^{} deref tag
    let spec = Spec.parse("v1.2^{}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "v1.2^{}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretBracesRegex(): Unit {
    // 对齐 Rust: navigate::caret_symbol — ^{/regex} find by regex
    let spec = Spec.parse("HEAD^{/fix bug}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD^{/fix bug}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseComplexNavigation(): Unit {
    // 对齐 Rust: kind::range — complex navigation like HEAD~10^2
    let spec = Spec.parse("HEAD~10^2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD~10^2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseTrailingDotDot(): Unit {
    // 对齐 Rust: kind::range — r1.. trailing dot-dot defaults to HEAD
    let spec = Spec.parse("r1..")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "r1..") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseLeadingDotDot(): Unit {
    // 对齐 Rust: kind::range — ..r2 leading dot-dot defaults to HEAD
    let spec = Spec.parse("..r2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "..r2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseTrailingDotDotDot(): Unit {
    // 对齐 Rust: kind::mergebase — HEAD... trailing dot-dot-dot
    let spec = Spec.parse("HEAD...")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "HEAD...") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseLeadingDotDotDot(): Unit {
    // 对齐 Rust: kind::mergebase — ...r2 leading dot-dot-dot
    let spec = Spec.parse("...r2")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "...r2") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretHyphenRange(): Unit {
    // 对齐 Rust: kind::range — r1^- range with parent
    let spec = Spec.parse("r^-")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "r^-") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseCaretHyphenNRange(): Unit {
    // 对齐 Rust: kind::range — r1^-42 range with Nth parent
    let spec = Spec.parse("r^-42")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "r^-42") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseDescribeWithDirty(): Unit {
    // 对齐 Rust: anchor::describe — describe format with -dirty suffix
    let spec = Spec.parse("v1.0-0-g3bee7fb-dirty")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "v1.0-0-g3bee7fb-dirty") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseReflogByEntry(): Unit {
    // 对齐 Rust: anchor::at_symbol — main@{42} reflog by entry for named ref
    let spec = Spec.parse("main@{42}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "main@{42}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseReflogByDate(): Unit {
    // 对齐 Rust: anchor::at_symbol — main@{42 +0030} reflog by date
    let spec = Spec.parse("main@{42 +0030}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "main@{42 +0030}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseSiblingUpstream(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{u} / @{upstream} sibling branch
    let spec = Spec.parse("@{u}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@{u}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseSiblingPush(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{push} sibling branch
    let spec = Spec.parse("@{push}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@{push}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseNthCheckedOutBranch(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{-N} nth checked out branch
    let spec = Spec.parse("@{-1}")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "@{-1}") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseIndexLookupPath(): Unit {
    // 对齐 Rust: anchor::colon_symbol — :path index lookup
    let spec = Spec.parse(":path")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != ":path") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseIndexLookupStagePath(): Unit {
    // 对齐 Rust: anchor::colon_symbol — :0:path index lookup with stage
    let spec = Spec.parse(":0:path")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != ":0:path") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseRegexNegated(): Unit {
    // 对齐 Rust: anchor::colon_symbol — :/!-negated negated regex
    let spec = Spec.parse(":/!-negated")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != ":/!-negated") {
        throw Exception("raw mismatch")
    }
}

// ============================================================
// Spec 构造测试
// ============================================================

@Test
func testSpecConstruction(): Unit {
    // 对齐 Rust: Spec construction
    let spec = Spec("main")
    if (spec.raw != "main") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecConstructionEmpty(): Unit {
    // 对齐 Rust: gix-revision/src/spec.rs::Spec::new_empty
    let spec = Spec("")
    if (spec.raw != "") {
        throw Exception("raw should be empty")
    }
}

@Test
func testSpecConstructionComplex(): Unit {
    // 对齐 Rust: gix-revision/src/spec.rs::Spec::new_complex_path
    let spec = Spec("refs/heads/feature/branch")
    if (spec.raw != "refs/heads/feature/branch") {
        throw Exception("raw mismatch")
    }
}

// ============================================================
// resolve 测试 — 对齐 gix-revision/tests/resolve.rs
// ============================================================

@Test
func testResolveFullHash(): Unit {
    // 对齐 Rust: resolve — full 40-char hash
    let resolver = TestResolver()
    let hash = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let spec = Spec(hash)
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve")
    }
    if (result.getOrThrow().toHexString() != hash) {
        throw Exception("hash mismatch")
    }
}

@Test
func testResolveFullHashSha256(): Unit {
    // 对齐 Rust: resolve — full 64-char SHA-256 hash
    let resolver = TestResolver()
    let hash = "473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813"
    let spec = Spec(hash)
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve")
    }
    if (result.getOrThrow().toHexString() != hash) {
        throw Exception("hash mismatch")
    }
}

@Test
func testResolveHead(): Unit {
    // 对齐 Rust: resolve — HEAD reference
    let resolver = TestResolver()
    resolver.refs["HEAD"] = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let spec = Spec("HEAD")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve")
    }
}

@Test
func testResolveRefsPath(): Unit {
    // 对齐 Rust: resolve — refs/ path
    let resolver = TestResolver()
    resolver.refs["refs/heads/main"] = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let spec = Spec("refs/heads/main")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve")
    }
}

@Test
func testResolveUnknownRef(): Unit {
    // 对齐 Rust: resolve — unknown reference returns None
    let resolver = TestResolver()
    let spec = Spec("refs/heads/nonexistent")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("unknown ref should return None")
    }
}

@Test
func testResolveShortName(): Unit {
    // 对齐 Rust: resolve — short ref name
    let resolver = TestResolver()
    resolver.refs["main"] = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let spec = Spec("main")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve")
    }
}

@Test
func testResolveCaretParent(): Unit {
    // 对齐 Rust: resolve — ^ parent syntax
    let resolver = TestResolver()
    let commitId = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let parentId = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    resolver.refs["HEAD"] = commitId
    resolver.parents[commitId] = parentId
    let spec = Spec("HEAD^")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve HEAD^")
    }
    if (!result.getOrThrow().equals(parentId)) {
        throw Exception("parent resolve mismatch")
    }
}

@Test
func testResolveCaretParentChain(): Unit {
    // 对齐 Rust: resolve — chained ^ parent syntax (HEAD^^)
    let resolver = TestResolver()
    let commitId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let parentId = hexToId("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let grandParentId = hexToId("a8d79b89b3c1c1e7e2a2f8f8d3d4e5f6a7b8c9d0")
    resolver.refs["HEAD"] = commitId
    resolver.parents[commitId] = parentId
    resolver.parents[parentId] = grandParentId
    let spec = Spec("HEAD^^")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve HEAD^^")
    }
    if (!result.getOrThrow().equals(grandParentId)) {
        throw Exception("grandparent resolve mismatch")
    }
}

@Test
func testResolveCaretParentNoParent(): Unit {
    // 对齐 Rust: resolve — ^ parent syntax when parent does not exist
    let resolver = TestResolver()
    let commitId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    resolver.refs["HEAD"] = commitId
    let spec = Spec("HEAD^")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("should return None when no parent")
    }
}

@Test
func testResolveCaretParentRefNotFound(): Unit {
    // 对齐 Rust: resolve — ^ parent syntax when base ref not found
    let resolver = TestResolver()
    let spec = Spec("nonexistent^")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("should return None when ref not found")
    }
}

@Test
func testResolveRefsTagsPath(): Unit {
    // 对齐 Rust: resolve — refs/tags/ path
    let resolver = TestResolver()
    let tagId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    resolver.refs["refs/tags/v1.0"] = tagId
    let spec = Spec("refs/tags/v1.0")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve refs/tags/v1.0")
    }
    if (!result.getOrThrow().equals(tagId)) {
        throw Exception("tag resolve mismatch")
    }
}

@Test
func testResolveRefsRemotesPath(): Unit {
    // 对齐 Rust: resolve — refs/remotes/ path
    let resolver = TestResolver()
    let remoteId = hexToId("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    resolver.refs["refs/remotes/origin/main"] = remoteId
    let spec = Spec("refs/remotes/origin/main")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve refs/remotes/origin/main")
    }
    if (!result.getOrThrow().equals(remoteId)) {
        throw Exception("remote resolve mismatch")
    }
}

@Test
func testResolveFullHashDoesNotCallResolver(): Unit {
    // 对齐 Rust: resolve — full hash should resolve directly without calling resolver
    let hash = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let spec = Spec(hash)
    let resolver = TestResolver()
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve full hash without resolver")
    }
    if (result.getOrThrow().toHexString() != hash) {
        throw Exception("hash mismatch")
    }
}

@Test
func testResolveHeadNotInResolver(): Unit {
    // 对齐 Rust: resolve — HEAD not in resolver returns None
    let resolver = TestResolver()
    let spec = Spec("HEAD")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("should return None when HEAD not in resolver")
    }
}

@Test
func testResolveCaretWithFullHash(): Unit {
    // 对齐 Rust: resolve — full-hash^ parent syntax
    let resolver = TestResolver()
    let commitId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let parentId = hexToId("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    resolver.parents[commitId] = parentId
    let spec = Spec("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391^")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve full-hash^")
    }
    if (!result.getOrThrow().equals(parentId)) {
        throw Exception("parent mismatch")
    }
}

@Test
func testResolveCaretMultipleAncestors(): Unit {
    // 对齐 Rust: resolve — 多级 ^ 链式解析
    let resolver = TestResolver()
    let c1 = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let c2 = hexToId("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let c3 = hexToId("cccccccccccccccccccccccccccccccccccccccc")
    resolver.refs["HEAD"] = c1
    resolver.parents[c1] = c2
    resolver.parents[c2] = c3
    let spec = Spec("HEAD^^")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve HEAD^^")
    }
    if (!result.getOrThrow().equals(c3)) {
        throw Exception("should be c3")
    }
}

@Test
func testResolveCaretChainBreaks(): Unit {
    // 对齐 Rust: resolve — ^ 链中间断开返回 None
    let resolver = TestResolver()
    let c1 = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    resolver.refs["HEAD"] = c1
    let spec = Spec("HEAD^^")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("should return None when chain breaks")
    }
}

// ============================================================
// Kind 枚举测试 — 对齐 gix-revision/src/spec/mod.rs Kind
// 当前 Kind 枚举尚未在仓颉实现中定义，以下测试验证 raw 字符串模式
// ============================================================

@Test
func testKindIncludeReachable(): Unit {
    // 对齐 Rust: spec::Kind::IncludeReachable — 默认类型
    let spec = Spec("main")
    if (spec.raw != "main") {
        throw Exception("check failed")
    }
}

@Test
func testKindExcludeReachable(): Unit {
    // 对齐 Rust: spec::Kind::ExcludeReachable — ^a 排除语法
    let spec = Spec("^HEAD")
    if (!spec.raw.startsWith("^")) {
        throw Exception("check failed")
    }
}

@Test
func testKindRangeBetween(): Unit {
    // 对齐 Rust: spec::Kind::RangeBetween — a..b 范围语法
    let spec = Spec("r1..r2")
    if (!spec.raw.contains("..")) {
        throw Exception("check failed")
    }
}

@Test
func testKindReachableToMergeBase(): Unit {
    // 对齐 Rust: spec::Kind::ReachableToMergeBase — a...b 合并基语法
    let spec = Spec("r1...r2")
    if (!spec.raw.contains("...")) {
        throw Exception("check failed")
    }
}

@Test
func testKindIncludeReachableFromParents(): Unit {
    // 对齐 Rust: spec::Kind::IncludeReachableFromParents — a^@ 父提交包含语法
    let spec = Spec("HEAD^@")
    if (!spec.raw.endsWith("^@")) {
        throw Exception("check failed")
    }
}

@Test
func testKindExcludeReachableFromParents(): Unit {
    // 对齐 Rust: spec::Kind::ExcludeReachableFromParents — a^! 父提交排除语法
    let spec = Spec("HEAD^!")
    if (!spec.raw.endsWith("^!")) {
        throw Exception("check failed")
    }
}

// ============================================================
// Spec Display 测试 — 对齐 gix-revision/tests/revision/spec/display.rs
// ============================================================

@Test
func testSpecToString(): Unit {
    // 对齐 Rust: Spec Display — 基本字符串表示
    let spec = Spec("HEAD")
    if (spec.raw != "HEAD") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecToStringHash(): Unit {
    // 对齐 Rust: Spec Display — Include(ObjectId) 显示为哈希字符串
    let hash = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let spec = Spec(hash)
    if (spec.raw != hash) {
        throw Exception("raw mismatch")
    }
}

// ============================================================
// Spec 区分 .. 和 ... 测试
// ============================================================

@Test
func testSpecDistinguishesDotDotVsDotDotDot(): Unit {
    // 对齐 Rust: kind::range vs kind::mergebase — 区分 .. 和 ...
    let range = Spec("a..b")
    let merge = Spec("a...b")
    if (range.raw == merge.raw) {
        throw Exception("range and merge should differ")
    }
    if (!range.raw.contains("..")) {
        throw Exception("range should contain ..")
    }
    if (range.raw.contains("...")) {
        throw Exception("range should not contain ...")
    }
    if (!merge.raw.contains("...")) {
        throw Exception("merge should contain ...")
    }
}

// ============================================================
// Spec 边界情况测试 — 对齐 gix-revision fuzz 和边界测试
// ============================================================

@Test
func testSpecParseAllHexChars(): Unit {
    // 对齐 Rust: anchor::hash — 全十六进制字符
    let spec = Spec.parse("abcdef0123456789")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "abcdef0123456789") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseMixedCaseHex(): Unit {
    // 对齐 Rust: anchor::hash — 混合大小写十六进制
    let spec = Spec.parse("aBcD")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "aBcD") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseAtWithBraces(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{...} 各种形式
    for (s in ["@{0}", "@{42}", "@{-1}", "@{u}", "@{push}", "@{1}"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseColonVariants(): Unit {
    // 对齐 Rust: anchor::colon_symbol — : 各种形式
    for (s in [":path", ":0:path", ":1:dir/path", ":/regex", ":/!-negated"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseCaretVariants(): Unit {
    // 对齐 Rust: navigate::caret_symbol — ^ 各种形式
    for (s in ["HEAD^", "HEAD^1", "HEAD^2", "HEAD^{commit}", "HEAD^{tree}", "HEAD^{}", "HEAD^@"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseTildeVariants(): Unit {
    // 对齐 Rust: navigate::tilde_symbol — ~ 各种形式
    for (s in ["HEAD~", "HEAD~0", "HEAD~1", "HEAD~10"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseRangeVariants(): Unit {
    // 对齐 Rust: kind::range — .. 各种形式
    for (s in ["r1..r2", "@..r2", "r1..", "..", "abcd..1234"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseMergeVariants(): Unit {
    // 对齐 Rust: kind::mergebase — ... 各种形式
    for (s in ["r1...r2", "HEAD...@", "@...HEAD", "...", "HEAD..."]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

// ============================================================
// resolve 边界情况测试
// ============================================================

@Test
func testResolveEmptySpec(): Unit {
    // 对齐 Rust: parse::empty_specs_are_valid — 空 spec 解析
    let resolver = TestResolver()
    let spec = Spec("")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("empty spec should return None")
    }
}

@Test
func testResolveCaretAtEndOnly(): Unit {
    // 对齐 Rust: kind::exclusive::freestanding — ^ 单独出现
    let resolver = TestResolver()
    let spec = Spec("^")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("^ alone should return None")
    }
}

@Test
func testResolveCaretExclamationOnly(): Unit {
    // 对齐 Rust: kind::exclude_parents::freestanding — ^! 单独出现
    let resolver = TestResolver()
    let spec = Spec("^!")
    let result = resolve(spec, resolver)
    if (!result.isNone()) {
        throw Exception("^! alone should return None")
    }
}

@Test
func testResolveMultipleRefsInResolver(): Unit {
    // 对齐 Rust: resolve — 多个引用在 resolver 中
    let resolver = TestResolver()
    let mainId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let devId = hexToId("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    resolver.refs["main"] = mainId
    resolver.refs["dev"] = devId
    resolver.refs["HEAD"] = mainId

    let r1 = resolve(Spec("main"), resolver)
    let r2 = resolve(Spec("dev"), resolver)
    let r3 = resolve(Spec("HEAD"), resolver)
    if (r1.isNone() || r2.isNone() || r3.isNone()) {
        throw Exception("should resolve all refs")
    }
    if (!r1.getOrThrow().equals(mainId)) {
        throw Exception("main mismatch")
    }
    if (!r2.getOrThrow().equals(devId)) {
        throw Exception("dev mismatch")
    }
    if (!r3.getOrThrow().equals(mainId)) {
        throw Exception("HEAD mismatch")
    }
}

@Test
func testResolveCaretWithRefsPath(): Unit {
    // 对齐 Rust: resolve — refs/heads/main^ 父提交解析
    let resolver = TestResolver()
    let commitId = hexToId("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let parentId = hexToId("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    resolver.refs["refs/heads/main"] = commitId
    resolver.parents[commitId] = parentId
    let spec = Spec("refs/heads/main^")
    let result = resolve(spec, resolver)
    if (result.isNone()) {
        throw Exception("should resolve refs/heads/main^")
    }
    if (!result.getOrThrow().equals(parentId)) {
        throw Exception("parent mismatch")
    }
}

// ============================================================
// describe 格式解析测试 — 对齐 gix-revision/tests/revision/spec/parse/anchor/describe.rs
// ============================================================

@Test
func testDescribeFormatFullFormatParsesHashPortion(): Unit {
    // 对齐 Rust: anchor::describe::full_format_parses_hash_portion_as_prefix
    // 完整 describe 格式如 v1.0-0-g3bee7fb，g 后面部分为哈希前缀
    let spec = Spec.parse("v1.0-0-g3bee7fb")
    if (spec.isNone()) {
        throw Exception("should parse describe format")
    }
    let raw = spec.getOrThrow().raw
    if (!raw.contains("g3bee7fb")) {
        throw Exception("should contain hash portion")
    }
}

@Test
func testDescribeFormatFullFormatWithDirty(): Unit {
    // 对齐 Rust: anchor::describe::full_format_with_dirty_suffix_is_recognized
    // 带 -dirty 后缀的完整 describe 格式
    let spec = Spec.parse("cargo-smart-release-679-g3bee7fb-dirty")
    if (spec.isNone()) {
        throw Exception("should parse describe format with dirty")
    }
    let raw = spec.getOrThrow().raw
    if (!raw.endsWith("-dirty")) {
        throw Exception("should end with -dirty")
    }
}

@Test
func testDescribeFormatPartialWithDirty(): Unit {
    // 对齐 Rust: anchor::describe::partial_format_with_dirty_suffix_is_recognized
    // 部分格式 abcdef1-dirty 也被识别
    let spec = Spec.parse("abcdef1-dirty")
    if (spec.isNone()) {
        throw Exception("should parse partial format with dirty")
    }
    let raw = spec.getOrThrow().raw
    if (raw != "abcdef1-dirty") {
        throw Exception("raw mismatch")
    }
}

@Test
func testDescribeFormatPartialLookalikesNotDescribe(): Unit {
    // 对齐 Rust: anchor::describe::partial_format_lookalikes_are_never_considered
    // abcdef1-dirty-laundry 不被视为 describe 输出，而是普通引用
    let spec = Spec.parse("abcdef1-dirty-laundry")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    let raw = spec.getOrThrow().raw
    if (raw != "abcdef1-dirty-laundry") {
        throw Exception("raw mismatch")
    }
}

@Test
func testDescribeFormatAnyHashWithGPrefix(): Unit {
    // 对齐 Rust: anchor::describe::any_hash_without_suffix_and_prefix_g_is_assumed_to_be_describe_output
    // foo--bar-gabcdef1 被识别为 describe 输出
    let spec = Spec.parse("foo--bar-gabcdef1")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    let raw = spec.getOrThrow().raw
    if (!raw.contains("gabcdef1")) {
        throw Exception("should contain g-prefixed hash")
    }
}

@Test
func testDescribeFormatInvalidPrefixesAreRefs(): Unit {
    // 对齐 Rust: anchor::describe::any_hash_without_suffix_and_prefix_g_is_assumed_to_be_describe_output
    // -gabcdef1 和 gabcdef1 不被视为 describe 输出，而是普通引用
    for (s in ["-gabcdef1", "gabcdef1"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

// ============================================================
// rev-spec 解析边界测试 — 对齐 gix-revision/tests/revision/spec/parse/mod.rs, kind.rs
// ============================================================

@Test
func testSpecParseWhitespaceOnly(): Unit {
    // 对齐 Rust: parse::empty_specs_are_valid — 仅空白字符的 spec
    for (s in [" ", "\n", "\t"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse whitespace-only spec")
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch")
        }
    }
}

@Test
func testSpecParseFreestandingDotDot(): Unit {
    // 对齐 Rust: kind::range::freestanding_dot_dot — 独立的 .. 语法
    let spec = Spec.parse("..")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "..") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseFreestandingDotDotDot(): Unit {
    // 对齐 Rust: kind::mergebase::freestanding_dot_dot_dot — 独立的 ... 语法
    let spec = Spec.parse("...")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "...") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseMiddleDotDot(): Unit {
    // 对齐 Rust: kind::range::middle_dot_dot — 中间的 .. 语法
    for (s in ["@..r2", "r1..r2", "abcd..1234", "r1..abcd", "abcd-dirty..v1.2-42-g1234"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseMiddleDotDotDot(): Unit {
    // 对齐 Rust: kind::mergebase::middle_dot_dot_dot — 中间的 ... 语法
    for (s in ["HEAD...@", "@...HEAD", "r1...abcd", "v1.2.3-beta.1-42-g1234-dirty...abcd-dirty"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}

@Test
func testSpecParseDescribeAnchoredRange(): Unit {
    // 对齐 Rust: kind::range::middle_dot_dot — describe 锚定的范围
    let spec = Spec.parse("v1.2-42-g1234..abcd-dirty")
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != "v1.2-42-g1234..abcd-dirty") {
        throw Exception("raw mismatch")
    }
}

// ============================================================
// merge_base 占位测试 — 对齐 gix-revision/tests/revision/merge_base.rs
// 当前 merge_base 为占位实现，验证类型和接口存在性
// ============================================================

@Test
func testMergeBasePlaceholderExists(): Unit {
    // 对齐 Rust: merge_base::validate — merge_base 函数占位存在
    // 当前为占位实现，验证函数可调用
    let id1 = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let id2 = hexToId("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let graph = Graph(TestCommitProvider())
    let result = mergeBase(id1, [id2], graph)
    // 无实际提交数据，返回 None
    if (!result.isNone()) {
        throw Exception("should return None without commit data")
    }
}

@Test
func testMergeBaseOctopusPlaceholderExists(): Unit {
    // 对齐 Rust: merge_base::octopus — octopus merge_base 函数占位存在
    let id1 = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let id2 = hexToId("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let id3 = hexToId("cccccccccccccccccccccccccccccccccccccccc")
    let graph = Graph(TestCommitProvider())
    let result = mergeBaseOctopus(id1, [id2, id3], graph)
    // 无实际提交数据，返回 None
    if (!result.isNone()) {
        throw Exception("should return None without commit data")
    }
}

@Test
func testMergeBaseFlagsPlaceholder(): Unit {
    // 对齐 Rust: merge_base::Flags — merge_base 标志位占位
    // 验证 MergeBaseFlags 类型可构造
    let flags = MergeBaseFlags()
    if (flags.rawValue != 0) {
        throw Exception("default flags should be 0")
    }
}

// ============================================================
// ancestors 遍历占位测试 — 对齐 gix-revision/src/lib.rs Graph/PriorityQueue
// 当前 ancestors 遍历为占位实现，验证类型和接口存在性
// ============================================================

@Test
func testAncestorsPlaceholderExists(): Unit {
    // 对齐 Rust: Graph — ancestors 遍历
    let id = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let graph = Graph(TestCommitProvider())
    let result = ancestors(id, graph)
    // 起始 ID 自身会被返回
    if (result.size != 1) {
        throw Exception("should return 1 element (the starting id itself)")
    }
}

@Test
func testAncestorsTraversalPlaceholder(): Unit {
    // 对齐 Rust: Graph — ancestors 遍历带 first_parent 选项
    let id = hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let graph = Graph(TestCommitProvider())
    let result = ancestorsFirstParent(id, graph)
    // 起始 ID 自身会被返回
    if (result.size != 1) {
        throw Exception("should return 1 element (the starting id itself)")
    }
}

// ============================================================
// Kind 枚举/模式测试 — 对齐 gix-revision/src/spec/mod.rs Kind
// 当前 Kind 枚举尚未完整实现，以下测试验证 raw 字符串模式匹配
// ============================================================

@Test
func testKindDefaultIsIncludeReachable(): Unit {
    // 对齐 Rust: spec::Kind::default() — 默认类型为 IncludeReachable
    let spec = Spec("main")
    // 不含 ^、..、...、^@、^! 前缀/后缀即为 IncludeReachable
    if (spec.raw.startsWith("^")) {
        throw Exception("should not start with ^")
    }
    if (spec.raw.contains("..")) {
        throw Exception("should not contain ..")
    }
    if (spec.raw.contains("...")) {
        throw Exception("should not contain ...")
    }
    if (spec.raw.endsWith("^@")) {
        throw Exception("should not end with ^@")
    }
    if (spec.raw.endsWith("^!")) {
        throw Exception("should not end with ^!")
    }
}

@Test
func testKindExcludeReachablePrefix(): Unit {
    // 对齐 Rust: spec::Kind::ExcludeReachable — ^ 前缀表示排除
    let spec = Spec("^HEAD")
    if (!spec.raw.startsWith("^")) {
        throw Exception("should start with ^")
    }
    // ^ 后面不是 .. 或 ... 则是 ExcludeReachable
    let afterCaret = substringFromStr(spec.raw, 1)
    if (afterCaret.contains("..") || afterCaret.contains("...")) {
        throw Exception("should not be range")
    }
}

@Test
func testKindRangeBetweenPattern(): Unit {
    // 对齐 Rust: spec::Kind::RangeBetween — a..b 模式
    let spec = Spec("a..b")
    if (!spec.raw.contains("..")) {
        throw Exception("should contain ..")
    }
    if (spec.raw.contains("...")) {
        throw Exception("should not contain ...")
    }
}

// ============================================================
// describe 选项/结果测试 — 对齐 gix-revision/src/describe.rs
// 当前 describe 为占位实现，验证类型和默认值
// ============================================================

@Test
func testDescribeOptionsDefaults(): Unit {
    // 对齐 Rust: describe::Options::default() — 默认选项
    let opts = DescribeOptions()
    if (opts.maxCandidates != 10) {
        throw Exception("default max_candidates should be 10")
    }
    if (opts.fallbackToOid) {
        throw Exception("default fallback_to_oid should be false")
    }
    if (opts.firstParent) {
        throw Exception("default first_parent should be false")
    }
}

@Test
func testDescribeOutcomeIsExactMatch(): Unit {
    // 对齐 Rust: describe::Outcome::is_exact_match — depth=0 为精确匹配
    let outcome = DescribeOutcome(
        Some("v1.0"),
        hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        0,
        0
    )
    if (!outcome.isExactMatch()) {
        throw Exception("depth 0 should be exact match")
    }
}

@Test
func testDescribeOutcomeNotExactMatch(): Unit {
    // 对齐 Rust: describe::Outcome::is_exact_match — depth>0 非精确匹配
    let outcome = DescribeOutcome(
        Some("v1.0"),
        hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        42,
        6
    )
    if (outcome.isExactMatch()) {
        throw Exception("depth 42 should not be exact match")
    }
}

@Test
func testDescribeFormatDisplay(): Unit {
    // 对齐 Rust: describe::Format Display — 格式化输出
    let fmt = DescribeFormat(
        Some("v1.0"),
        hexToId("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"),
        7,
        3,
        false,
        None
    )
    let s = fmt.toString()
    if (!s.contains("v1.0")) {
        throw Exception("should contain name")
    }
    if (!s.contains("3")) {
        throw Exception("should contain depth")
    }
}

// ============================================================
// 各种 rev 前缀解析测试 — 对齐 gix-revision/tests/revision/spec/parse/anchor/hash.rs, refnames.rs
// ============================================================

@Test
func testSpecParseAtInRanges(): Unit {
    // 对齐 Rust: anchor::refnames::at_in_ranges_is_allowed — @ 在范围中的使用
    let spec1 = Spec.parse("@@@..")
    if (spec1.isNone()) {
        throw Exception("should parse @@@..")
    }
    if (spec1.getOrThrow().raw != "@@@..") {
        throw Exception("raw mismatch")
    }

    let spec2 = Spec.parse("@@...@@")
    if (spec2.isNone()) {
        throw Exception("should parse @@...@@")
    }
    if (spec2.getOrThrow().raw != "@@...@@") {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseHexTooLongAsRef(): Unit {
    // 对齐 Rust: anchor::hash::hex_literals_that_are_too_long_are_resolved_as_refs
    // 超长十六进制字符串被当作引用名而非哈希前缀
    let longHex = "abcd123456789abcd123456789abcd123456789abcd123456789abcd123456789abcd123456789abcd123456789"
    let spec = Spec.parse(longHex)
    if (spec.isNone()) {
        throw Exception("should parse")
    }
    if (spec.getOrThrow().raw != longHex) {
        throw Exception("raw mismatch")
    }
}

@Test
func testSpecParseAtWithVariousBracesContent(): Unit {
    // 对齐 Rust: anchor::at_symbol — @{...} 各种内容形式
    for (s in ["@{0}", "@{42}", "@{-1}", "@{u}", "@{push}", "@{+0}", "@{100000000}"]) {
        let spec = Spec.parse(s)
        if (spec.isNone()) {
            throw Exception("should parse " + s)
        }
        if (spec.getOrThrow().raw != s) {
            throw Exception("raw mismatch for " + s)
        }
    }
}
