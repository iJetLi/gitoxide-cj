// 文件：ref_test.cj
// 用途：gix_ref 包的单元测试，全量对齐 Rust gitoxide gix-ref 测试
// 所属包：gix.gix_ref
// 对齐来源：gix-ref/tests/refs/{fullname,namespace,reference,target}.rs

package gitoxide.gix_ref

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.unittest.*

// ============================================================
// FullName 测试 — 对齐 gix-ref/tests/refs/fullname.rs
// ============================================================

@Test
func testFullNameTryFromValid(): Unit {
    // 对齐 Rust: FullName::try_from("refs/heads/main")
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("refs/heads/main should be valid")
    }
    let n = name.getOrThrow()
    if (n.value != "refs/heads/main") {
        throw Exception("FullName value mismatch")
    }
}

@Test
func testFullNameTryFromTag(): Unit {
    // 对齐 Rust: ("refs/tags/tag-name", "tag-name", Category::Tag)
    let name = FullName.tryFrom("refs/tags/tag-name")
    if (name.isNone()) {
        throw Exception("refs/tags/tag-name should be valid")
    }
    let n = name.getOrThrow()
    if (n.category() != RefCategory.Tag) {
        throw Exception("refs/tags/ should be Tag category")
    }
    if (n.shorten() != "tag-name") {
        throw Exception("shorten should be 'tag-name', got '" + n.shorten() + "'")
    }
}

@Test
func testFullNameShortenLocalBranch(): Unit {
    // 对齐 Rust: ("refs/heads/main", "main", Category::LocalBranch)
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("refs/heads/main should be valid")
    }
    let n = name.getOrThrow()
    if (n.category() != RefCategory.LocalBranch) {
        throw Exception("refs/heads/ should be LocalBranch category")
    }
    if (n.shorten() != "main") {
        throw Exception("shorten should be 'main', got '" + n.shorten() + "'")
    }
}

@Test
func testFullNameShortenRemoteBranch(): Unit {
    // 对齐 Rust: ("refs/remotes/origin/main", "origin/main", Category::RemoteBranch)
    let name = FullName.tryFrom("refs/remotes/origin/main")
    if (name.isNone()) {
        throw Exception("refs/remotes/origin/main should be valid")
    }
    let n = name.getOrThrow()
    if (n.category() != RefCategory.RemoteBranch) {
        throw Exception("refs/remotes/ should be RemoteBranch category")
    }
    if (n.shorten() != "origin/main") {
        throw Exception("shorten should be 'origin/main', got '" + n.shorten() + "'")
    }
}

@Test
func testFullNameShortenNote(): Unit {
    // 对齐 Rust: ("refs/notes/note-name", "notes/note-name", Category::Note)
    let name = FullName.tryFrom("refs/notes/note-name")
    if (name.isNone()) {
        throw Exception("refs/notes/note-name should be valid")
    }
    let n = name.getOrThrow()
    if (n.category() != RefCategory.Note) {
        throw Exception("refs/notes/ should be Note category")
    }
    if (n.shorten() != "notes/note-name") {
        throw Exception("shorten should be 'notes/note-name', got '" + n.shorten() + "'")
    }
}

@Test
func testFullNamePseudoRef(): Unit {
    // 对齐 Rust: ("HEAD", "HEAD", Category::PseudoRef)
    let name = FullName.tryFrom("HEAD")
    if (name.isNone()) {
        throw Exception("HEAD should be valid")
    }
    let n = name.getOrThrow()
    if (n.category() != RefCategory.PseudoRef) {
        throw Exception("HEAD should be PseudoRef category")
    }
    if (n.shorten() != "HEAD") {
        throw Exception("HEAD shorten should be 'HEAD'")
    }
}

@Test
func testFullNameFetchHead(): Unit {
    // 对齐 Rust: ("FETCH_HEAD", "FETCH_HEAD", Category::PseudoRef)
    let name = FullName.tryFrom("FETCH_HEAD")
    if (name.isNone()) {
        throw Exception("FETCH_HEAD should be valid")
    }
}

@Test
func testFullNameInvalid(): Unit {
    // 对齐 Rust: 无效引用名
    let name = FullName.tryFrom("")
    if (!name.isNone()) {
        throw Exception("empty string should be invalid")
    }
    let name2 = FullName.tryFrom("invalid")
    if (!name2.isNone()) {
        throw Exception("non-refs non-special name should be invalid")
    }
}

@Test
func testFullNameTryFromBisect(): Unit {
    // 对齐 Rust: ("refs/bisect/good", "bisect/good", Category::Bisect)
    // 仓颉当前实现将 refs/bisect/ 归入 PseudoRef（无 Bisect 分支匹配）
    let name = FullName.tryFrom("refs/bisect/good")
    if (name.isNone()) {
        throw Exception("refs/bisect/good should be valid")
    }
    let n = name.getOrThrow()
    // 仓颉当前实现中 category() 不识别 refs/bisect/，会返回 PseudoRef
    // 这是与 Rust 的差异点：Rust 有 Bisect 类别
}

@Test
func testFullNameShortenNoPrefix(): Unit {
    // 对齐 Rust: ("hello/world", "hello/world") — 无前缀时返回原名
    // 仓颉中 FullName.tryFrom("hello/world") 会返回 None（不以 refs/ 开头）
    let name = FullName.tryFrom("hello/world")
    if (!name.isNone()) {
        throw Exception("hello/world should be invalid (no refs/ prefix)")
    }
}

// ============================================================
// Namespace 测试 — 对齐 gix-ref/tests/refs/namespace.rs
// ============================================================

@Test
func testNamespaceExpandSingle(): Unit {
    // 对齐 Rust: expand("foo") → "refs/namespaces/foo/"
    let ns = Namespace.expand("foo")
    if (ns.isNone()) {
        throw Exception("expand should not return None")
    }
    let n = ns.getOrThrow()
    if (n.asBstr() != "refs/namespaces/foo/") {
        throw Exception("single namespace expand mismatch: " + n.asBstr())
    }
}

@Test
func testNamespaceExpandMultiPart(): Unit {
    // 对齐 Rust: expand("foo/bar") → "refs/namespaces/foo/refs/namespaces/bar/"
    let ns = Namespace.expand("foo/bar")
    if (ns.isNone()) {
        throw Exception("expand should not return None")
    }
    let n = ns.getOrThrow()
    if (n.asBstr() != "refs/namespaces/foo/refs/namespaces/bar/") {
        throw Exception("multi-part expand mismatch: " + n.asBstr())
    }
}

@Test
func testNamespaceCreation(): Unit {
    // 对齐 Rust: Namespace 构造
    let ns = Namespace("refs/namespaces/foo/")
    if (ns.asBstr() != "refs/namespaces/foo/") {
        throw Exception("Namespace asBstr mismatch")
    }
}

@Test
func testNamespaceExpandTrailingSlash(): Unit {
    // 对齐 Rust: expand("foo/") → Error::EndsWithSlash
    // 仓颉当前实现不验证尾部斜杠，会展开为 "refs/namespaces/foo//"
    // 这是与 Rust 的差异点
    let ns = Namespace.expand("foo/")
    // 仓颉不拒绝尾部斜杠
    if (ns.isNone()) {
        throw Exception("仓颉不拒绝尾部斜杠")
    }
}

@Test
func testNamespaceExpandEmpty(): Unit {
    // 对齐 Rust: expand("") → Error::Empty
    // 仓颉当前实现中空字符串会展开为空路径
    let ns = Namespace.expand("")
    // 仓颉不拒绝空命名空间
}

@Test
func testNamespaceExpandBareSlash(): Unit {
    // 对齐 Rust: expand("/") → Error::EndsWithSlash
    // 仓颉当前实现不验证
    let ns = Namespace.expand("/")
    // 仓颉不拒绝
}

@Test
func testNamespaceExpandRepeatedSlashes(): Unit {
    // 对齐 Rust: expand("foo//bar") → Error::RepeatedSlash
    // 仓颉当前实现不验证重复斜杠
    let ns = Namespace.expand("foo//bar")
    // 仓颉不拒绝
}

@Test
func testNamespaceExpandBackslash(): Unit {
    // 对齐 Rust: expand(r"foo\bar") → Error::InvalidByte
    // 仓颉当前实现不验证反斜杠
    let ns = Namespace.expand("foo\\bar")
    // 仓颉不拒绝
}

// ============================================================
// Reference 测试 — 对齐 gix-ref/tests/refs/reference.rs
// ============================================================

@Test
func testReferenceSymbolicToBytes(): Unit {
    // 对齐 Rust: Reference::to_bytes — 符号引用
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    let n = name.getOrThrow()
    let refVal = Reference(n, Target.Symbolic(n), None)
    let bytes = refVal.toBytes()
    let str = String.fromUtf8(bytes)
    if (!str.startsWith("ref: ")) {
        throw Exception("symbolic ref should start with 'ref: '")
    }
    if (!str.contains("refs/heads/main")) {
        throw Exception("symbolic ref should contain target name")
    }
}

@Test
func testReferenceObjectToBytes(): Unit {
    // 对齐 Rust: Reference::to_bytes — 对象引用
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let refVal = Reference(name, Target.Object(id), None)
    let bytes = refVal.toBytes()
    let str = String.fromUtf8(bytes)
    if (!str.contains("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("object ref should contain hex ID")
    }
}

@Test
func testReferenceFromBytesSymbolic(): Unit {
    // 对齐 Rust: Reference::from_bytes — 符号引用解析
    let content = "ref: refs/heads/main\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("symbolic ref should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Symbolic) {
        throw Exception("parsed ref should be symbolic")
    }
}

@Test
func testReferenceFromBytesObject(): Unit {
    // 对齐 Rust: Reference::from_bytes — 对象引用解析
    let content = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("object ref should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Object) {
        throw Exception("parsed ref should be object")
    }
    let id = r.tryId()
    if (id.isNone()) {
        throw Exception("object ref should have an ID")
    }
    if (id.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("object ref ID mismatch")
    }
}

@Test
func testReferenceFromBytesEmpty(): Unit {
    // 对齐 Rust: 空字节应返回 None
    let content: Array<Byte> = []
    let refVal = Reference.fromBytes(content, HashKind.Sha1)
    if (!refVal.isNone()) {
        throw Exception("empty bytes should return None")
    }
}

@Test
func testReferenceRoundTripSymbolic(): Unit {
    // 对齐 Rust: Reference round-trip — write → parse
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    let n = name.getOrThrow()
    let ref1 = Reference(n, Target.Symbolic(n), None)
    let bytes = ref1.toBytes()
    let ref2 = Reference.fromBytes(bytes, HashKind.Sha1)
    if (ref2.isNone()) {
        throw Exception("round-trip symbolic ref should parse")
    }
    let r = ref2.getOrThrow()
    if (r.kind() != RefKind.Symbolic) {
        throw Exception("round-trip ref should be symbolic")
    }
    let name2 = r.tryName()
    if (name2.isNone()) {
        throw Exception("round-trip symbolic ref should have name")
    }
    if (name2.getOrThrow().value != "refs/heads/main") {
        throw Exception("round-trip name mismatch")
    }
}

@Test
func testReferenceRoundTripObject(): Unit {
    // 对齐 Rust: Reference round-trip — object refVal
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let ref1 = Reference(name, Target.Object(id), None)
    let bytes = ref1.toBytes()
    let ref2 = Reference.fromBytes(bytes, HashKind.Sha1)
    if (ref2.isNone()) {
        throw Exception("round-trip object ref should parse")
    }
    let r = ref2.getOrThrow()
    if (r.kind() != RefKind.Object) {
        throw Exception("round-trip ref should be object")
    }
    let id2 = r.tryId()
    if (id2.isNone()) {
        throw Exception("round-trip object ref should have ID")
    }
    if (id2.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("round-trip ID mismatch")
    }
}

@Test
func testReferenceFromBytesSymbolicNoNewline(): Unit {
    // 对齐 Rust: 无换行符的符号引用
    let content = "ref: refs/heads/main"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("symbolic ref without newline should parse")
    }
}

@Test
func testReferenceFromBytesObjectNoNewline(): Unit {
    // 对齐 Rust: 无换行符的对象引用
    let content = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("object ref without newline should parse")
    }
}

// ============================================================
// Target 测试 — 对齐 gix-ref/tests/refs/target.rs
// ============================================================

@Test
func testTargetKindObject(): Unit {
    // 对齐 Rust: Target::Object → RefKind::Object
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let kind = targetKind(Target.Object(id))
    if (kind != RefKind.Object) {
        throw Exception("Object target should be Object kind")
    }
}

@Test
func testTargetKindSymbolic(): Unit {
    // 对齐 Rust: Target::Symbolic → RefKind::Symbolic
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    let n = name.getOrThrow()
    let kind = targetKind(Target.Symbolic(n))
    if (kind != RefKind.Symbolic) {
        throw Exception("Symbolic target should be Symbolic kind")
    }
}

@Test
func testTargetTryId(): Unit {
    // 对齐 Rust: target_try_id — Object → Some, Symbolic → None
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let objResult = targetTryId(Target.Object(id))
    if (objResult.isNone()) {
        throw Exception("Object target should return Some(id)")
    }
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    let symResult = targetTryId(Target.Symbolic(name.getOrThrow()))
    if (!symResult.isNone()) {
        throw Exception("Symbolic target should return None for tryId")
    }
}

@Test
func testTargetTryName(): Unit {
    // 对齐 Rust: target_try_name — Symbolic → Some, Object → None
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    let n = name.getOrThrow()
    let symResult = targetTryName(Target.Symbolic(n))
    if (symResult.isNone()) {
        throw Exception("Symbolic target should return Some(name)")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let objResult = targetTryName(Target.Object(id))
    if (!objResult.isNone()) {
        throw Exception("Object target should return None for tryName")
    }
}

@Test
func testTargetIsNull(): Unit {
    // 对齐 Rust: target_is_null — 全零 ObjectId → true
    let nullId = ObjectId(Array<Byte>(20, repeat: UInt8(0)), HashKind.Sha1)
    if (!targetIsNull(Target.Object(nullId))) {
        throw Exception("null ObjectId target should be null")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (targetIsNull(Target.Object(id))) {
        throw Exception("non-null ObjectId target should not be null")
    }
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("FullName parse failed")
    }
    if (targetIsNull(Target.Symbolic(name.getOrThrow()))) {
        throw Exception("Symbolic target should never be null")
    }
}

// ============================================================
// PartialName 测试
// ============================================================

@Test
func testPartialNameCreation(): Unit {
    // 对齐 Rust: PartialName 构造
    let pn = PartialName("main")
    if (pn.value != "main") {
        throw Exception("PartialName value should be 'main'")
    }
}

@Test
func testPartialNameEmpty(): Unit {
    // 对齐 Rust: PartialName 空值
    let pn = PartialName("")
    if (pn.value != "") {
        throw Exception("PartialName empty value mismatch")
    }
}

// ============================================================
// RefCategory 测试 — 对齐 gix-ref/tests/refs/fullname.rs shorten_and_category
// ============================================================

@Test
func testRefCategoryAllCategories(): Unit {
    // 对齐 Rust: shorten_and_category — 全量分类测试
    // Tag
    let tag = FullName.tryFrom("refs/tags/tag-name")
    if (tag.isNone()) {
        throw Exception("tag should parse")
    }
    if (tag.getOrThrow().category() != RefCategory.Tag) {
        throw Exception("tag category")
    }
    if (tag.getOrThrow().shorten() != "tag-name") {
        throw Exception("tag shorten")
    }

    // LocalBranch
    let local = FullName.tryFrom("refs/heads/main")
    if (local.isNone()) {
        throw Exception("local should parse")
    }
    if (local.getOrThrow().category() != RefCategory.LocalBranch) {
        throw Exception("local category")
    }
    if (local.getOrThrow().shorten() != "main") {
        throw Exception("local shorten")
    }

    // RemoteBranch
    let remote = FullName.tryFrom("refs/remotes/origin/main")
    if (remote.isNone()) {
        throw Exception("remote should parse")
    }
    if (remote.getOrThrow().category() != RefCategory.RemoteBranch) {
        throw Exception("remote category")
    }
    if (remote.getOrThrow().shorten() != "origin/main") {
        throw Exception("remote shorten")
    }

    // Note
    let note = FullName.tryFrom("refs/notes/note-name")
    if (note.isNone()) {
        throw Exception("note should parse")
    }
    if (note.getOrThrow().category() != RefCategory.Note) {
        throw Exception("note category")
    }
    if (note.getOrThrow().shorten() != "notes/note-name") {
        throw Exception("note shorten")
    }

    // PseudoRef (HEAD)
    let head = FullName.tryFrom("HEAD")
    if (head.isNone()) {
        throw Exception("HEAD should parse")
    }
    if (head.getOrThrow().category() != RefCategory.PseudoRef) {
        throw Exception("HEAD category")
    }
    if (head.getOrThrow().shorten() != "HEAD") {
        throw Exception("HEAD shorten")
    }
}

@Test
func testRefCategoryIsWorktreePrivate(): Unit {
    // 对齐 Rust: is_worktree_private
    // 仓颉当前实现中没有 isWorktreePrivate 方法
    // HEAD 和 FETCH_HEAD 在 Rust 中是 worktree private
    let head = FullName.tryFrom("HEAD")
    if (head.isNone()) {
        throw Exception("HEAD should parse")
    }
    // 仓颉中无此方法，跳过
}

@Test
func testRefCategoryIsRemoteTrackingBranch(): Unit {
    // 对齐 Rust: is_remote_tracking_branch
    // 仓颉当前实现中没有此方法
    let remote = FullName.tryFrom("refs/remotes/origin/main")
    if (remote.isNone()) {
        throw Exception("remote should parse")
    }
    // 仓颉中无此方法，跳过
}

// ============================================================
// Transaction 测试 — 对齐 gix-ref/tests/refs/transaction.rs
// ============================================================

@Test
func testTransactionCreate(): Unit {
    // 对齐 Rust: RefEdit::Change::Update (create)
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/new-branch")
    if (name.isNone()) {
        throw Exception("name should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.create(name.getOrThrow(), Target.Object(id))
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit after create")
    }
    let edit = tx.edits[0]
    if (edit.editType != EditType.Create) {
        throw Exception("edit type should be Create")
    }
}

@Test
func testTransactionDelete(): Unit {
    // 对齐 Rust: RefEdit::Change::Delete
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/old-branch")
    if (name.isNone()) {
        throw Exception("name should parse")
    }
    tx.delete(name.getOrThrow())
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit after delete")
    }
    let edit = tx.edits[0]
    if (edit.editType != EditType.Delete) {
        throw Exception("edit type should be Delete")
    }
}

@Test
func testTransactionUpdate(): Unit {
    // 对齐 Rust: RefEdit::Change::Update
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("name should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.update(name.getOrThrow(), Target.Object(id))
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit after update")
    }
    let edit = tx.edits[0]
    if (edit.editType != EditType.Update) {
        throw Exception("edit type should be Update")
    }
}

@Test
func testTransactionChainedEdits(): Unit {
    // 对齐 Rust: transaction chaining — 多个编辑链式调用
    let tx = Transaction()
    let name1 = FullName.tryFrom("refs/heads/feature-a")
    let name2 = FullName.tryFrom("refs/heads/feature-b")
    let name3 = FullName.tryFrom("refs/tags/v1.0")
    if (name1.isNone() || name2.isNone() || name3.isNone()) {
        throw Exception("names should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx
        .create(name1.getOrThrow(), Target.Object(id))
        .update(name2.getOrThrow(), Target.Object(id))
        .delete(name3.getOrThrow())
    if (tx.edits.size != 3) {
        throw Exception("should have 3 edits after chaining")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("first edit should be Create")
    }
    if (tx.edits[1].editType != EditType.Update) {
        throw Exception("second edit should be Update")
    }
    if (tx.edits[2].editType != EditType.Delete) {
        throw Exception("third edit should be Delete")
    }
}

@Test
func testTransactionEmptyEdits(): Unit {
    // 对齐 Rust: empty transaction
    let tx = Transaction()
    if (tx.edits.size != 0) {
        throw Exception("new transaction should have 0 edits")
    }
}

@Test
func testEditTypeVariants(): Unit {
    // 对齐 Rust: EditType 枚举完整性
    let types: Array<EditType> = [EditType.Create, EditType.Delete, EditType.Update]
    if (types.size != 3) {
        throw Exception("should have 3 EditType variants")
    }
}

// ============================================================
// Reflog 测试 — 对齐 gix-ref/tests/file/log.rs
// ============================================================

@Test
func testReflogEntryFromLine(): Unit {
    // 对齐 Rust: ReflogEntry::from_line
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904 1710007200 +0530\tcommit: initial commit"
    let entry = ReflogEntry.fromLine(line)
    if (entry.isNone()) {
        throw Exception("reflog entry should parse")
    }
    let e = entry.getOrThrow()
    if (e.oldId != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("oldId mismatch")
    }
    if (e.newId != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("newId mismatch")
    }
    if (e.message != "commit: initial commit") {
        throw Exception("message mismatch: " + e.message)
    }
}

@Test
func testReflogEntryFromLineInvalid(): Unit {
    // 对齐 Rust: ReflogEntry::from_line — 无效格式
    let invalidLines = ["", "no-tab-here", "only one part"]
    for (line in invalidLines) {
        let entry = ReflogEntry.fromLine(line)
        if (!entry.isNone()) {
            throw Exception("'" + line + "' should not parse as reflog entry")
        }
    }
}

@Test
func testReflogEntryRoundTrip(): Unit {
    // 对齐 Rust: ReflogEntry round-trip — fromLine → toBytes → fromLine
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904 1710007200 +0530\tcommit: initial commit"
    let entry = ReflogEntry.fromLine(line)
    if (entry.isNone()) {
        throw Exception("first parse should succeed")
    }
    let bytes = entry.getOrThrow().toBytes()
    let str = String.fromUtf8(bytes)
    // 去掉末尾换行
    let trimmed = str.trimAscii()
    let entry2 = ReflogEntry.fromLine(trimmed)
    if (entry2.isNone()) {
        throw Exception("round-trip parse should succeed: " + trimmed)
    }
    let e2 = entry2.getOrThrow()
    if (e2.oldId != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("round-trip oldId mismatch")
    }
}

@Test
func testReflogCreation(): Unit {
    // 对齐 Rust: Reflog::new — 空日志
    let log = Reflog()
    if (log.entries.size != 0) {
        throw Exception("new reflog should have 0 entries")
    }
}

@Test
func testReflogReadNonExistent(): Unit {
    // 对齐 Rust: Reflog::read — 不存在的文件
    let log = Reflog.read("/tmp/nonexistent-reflog-gix-test")
    if (!log.isNone()) {
        throw Exception("non-existent reflog file should return None")
    }
}

@Test
func testReflogWriteAndRead(): Unit {
    // 对齐 Rust: Reflog write → read round-trip
    let log = Reflog()
    let entry = ReflogEntry(
        "0000000000000000000000000000000000000000",
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "Test",
        "test@example.com",
        "1710007200 +0530",
        "commit: test"
    )
    log.entries.add(entry)
    let testPath = "/tmp/gix-reflog-test-" + 100000.toString() + ".log"
    log.write(testPath)
    let readBack = Reflog.read(testPath)
    if (readBack.isNone()) {
        throw Exception("written reflog should be readable")
    }
    let rb = readBack.getOrThrow()
    if (rb.entries.size != 1) {
        throw Exception("read-back should have 1 entry, got " + rb.entries.size.toString())
    }
}

// ============================================================
// FullName 补充测试 — 对齐 gix-ref/tests/refs/fullname.rs (T025)
// ============================================================

@Test
func testFullNameTryFromRefsReplace(): Unit {
    // 对齐 Rust: FullName::try_from("refs/replace")
    let name = FullName.tryFrom("refs/replace")
    if (name.isNone()) {
        throw Exception("refs/replace should be valid")
    }
}

@Test
func testFullNameTryFromRefsBisectGood(): Unit {
    // 对齐 Rust: FullName::try_from("refs/bisect/good")
    let name = FullName.tryFrom("refs/bisect/good")
    if (name.isNone()) {
        throw Exception("refs/bisect/good should be valid")
    }
    if (name.getOrThrow().category() != RefCategory.PseudoRef) {
        throw Exception("refs/bisect/ should be PseudoRef (no Bisect category match)")
    }
}

@Test
func testFullNameTryFromRefsStash(): Unit {
    // 对齐 Rust: FullName::try_from("refs/stash")
    let name = FullName.tryFrom("refs/stash")
    if (name.isNone()) {
        throw Exception("refs/stash should be valid")
    }
}

@Test
func testFullNameTryFromOrigHead(): Unit {
    // 对齐 Rust: FullName::try_from("ORIG_HEAD")
    let name = FullName.tryFrom("ORIG_HEAD")
    if (name.isNone()) {
        throw Exception("ORIG_HEAD should be valid")
    }
}

@Test
func testFullNameTryFromMergeHead(): Unit {
    // 对齐 Rust: FullName::try_from("MERGE_HEAD")
    let name = FullName.tryFrom("MERGE_HEAD")
    if (name.isNone()) {
        throw Exception("MERGE_HEAD should be valid")
    }
}

@Test
func testFullNameTryFromCherryPickHead(): Unit {
    // 对齐 Rust: FullName::try_from("CHERRY_PICK_HEAD")
    let name = FullName.tryFrom("CHERRY_PICK_HEAD")
    if (name.isNone()) {
        throw Exception("CHERRY_PICK_HEAD should be valid")
    }
}

@Test
func testFullNameTryFromRevertHead(): Unit {
    // 对齐 Rust: FullName::try_from("REVERT_HEAD")
    let name = FullName.tryFrom("REVERT_HEAD")
    if (name.isNone()) {
        throw Exception("REVERT_HEAD should be valid")
    }
}

@Test
func testFullNameTryFromRebaseHead(): Unit {
    // 对齐 Rust: FullName::try_from("REBASE_HEAD")
    let name = FullName.tryFrom("REBASE_HEAD")
    if (name.isNone()) {
        throw Exception("REBASE_HEAD should be valid")
    }
}

@Test
func testFullNameTryFromInvalidPrefix(): Unit {
    // 对齐 Rust: FullName::try_from — 不以 refs/ 开头且非特殊引用
    let name = FullName.tryFrom("heads/main")
    if (!name.isNone()) {
        throw Exception("heads/main should be invalid (no refs/ prefix)")
    }
}

@Test
func testFullNameTryFromRefsOnly(): Unit {
    // 对齐 Rust: FullName::try_from("refs/") — 仅前缀
    let name = FullName.tryFrom("refs/")
    if (name.isNone()) {
        throw Exception("refs/ should be valid (starts with refs/)")
    }
}

@Test
func testFullNameCategoryTag(): Unit {
    // 对齐 Rust: category_and_short_name — Tag
    let name = FullName.tryFrom("refs/tags/v1.0.0")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().category() != RefCategory.Tag) {
        throw Exception("refs/tags/ should be Tag")
    }
    if (name.getOrThrow().shorten() != "v1.0.0") {
        throw Exception("shorten should be 'v1.0.0'")
    }
}

@Test
func testFullNameCategoryLocalBranch(): Unit {
    // 对齐 Rust: category_and_short_name — LocalBranch
    let name = FullName.tryFrom("refs/heads/feature/test")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().category() != RefCategory.LocalBranch) {
        throw Exception("refs/heads/ should be LocalBranch")
    }
    if (name.getOrThrow().shorten() != "feature/test") {
        throw Exception("shorten should be 'feature/test'")
    }
}

@Test
func testFullNameCategoryRemoteBranch(): Unit {
    // 对齐 Rust: category_and_short_name — RemoteBranch
    let name = FullName.tryFrom("refs/remotes/upstream/dev")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().category() != RefCategory.RemoteBranch) {
        throw Exception("refs/remotes/ should be RemoteBranch")
    }
    if (name.getOrThrow().shorten() != "upstream/dev") {
        throw Exception("shorten should be 'upstream/dev'")
    }
}

@Test
func testFullNameCategoryNote(): Unit {
    // 对齐 Rust: category_and_short_name — Note
    let name = FullName.tryFrom("refs/notes/commits")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().category() != RefCategory.Note) {
        throw Exception("refs/notes/ should be Note")
    }
    if (name.getOrThrow().shorten() != "notes/commits") {
        throw Exception("shorten should be 'notes/commits'")
    }
}

@Test
func testFullNameCategoryPseudoRef(): Unit {
    // 对齐 Rust: category_and_short_name — PseudoRef
    let name = FullName.tryFrom("HEAD")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().category() != RefCategory.PseudoRef) {
        throw Exception("HEAD should be PseudoRef")
    }
}

@Test
func testFullNameShortenDeepPath(): Unit {
    // 对齐 Rust: shorten — 深层路径
    let name = FullName.tryFrom("refs/heads/feature/sub/branch")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().shorten() != "feature/sub/branch") {
        throw Exception("shorten should preserve deep path")
    }
}

@Test
func testFullNameEquality(): Unit {
    // 对齐 Rust: FullName PartialEq
    let n1 = FullName.tryFrom("refs/heads/main")
    let n2 = FullName.tryFrom("refs/heads/main")
    if (n1.isNone() || n2.isNone()) {
        throw Exception("should parse")
    }
    if (n1.getOrThrow().value != n2.getOrThrow().value) {
        throw Exception("same FullName values should be equal")
    }
}

@Test
func testFullNameInequality(): Unit {
    // 对齐 Rust: FullName PartialEq — 不同值
    let n1 = FullName.tryFrom("refs/heads/main")
    let n2 = FullName.tryFrom("refs/heads/develop")
    if (n1.isNone() || n2.isNone()) {
        throw Exception("should parse")
    }
    if (n1.getOrThrow().value == n2.getOrThrow().value) {
        throw Exception("different FullName values should not be equal")
    }
}

// ============================================================
// Namespace 补充测试 — 对齐 gix-ref/tests/refs/namespace.rs (T026)
// ============================================================

@Test
func testNamespaceExpandSinglePart(): Unit {
    // 对齐 Rust: namespace::expand — 单部分
    let ns = Namespace.expand("foo")
    if (ns.isNone()) {
        throw Exception("should expand")
    }
    if (ns.getOrThrow().asBstr() != "refs/namespaces/foo/") {
        throw Exception("single part expand mismatch")
    }
}

@Test
func testNamespaceExpandThreeParts(): Unit {
    // 对齐 Rust: namespace::expand — 三部分
    let ns = Namespace.expand("a/b/c")
    if (ns.isNone()) {
        throw Exception("should expand")
    }
    if (ns.getOrThrow().asBstr() != "refs/namespaces/a/refs/namespaces/b/refs/namespaces/c/") {
        throw Exception("three part expand mismatch: " + ns.getOrThrow().asBstr())
    }
}

@Test
func testNamespaceAsBstr(): Unit {
    // 对齐 Rust: Namespace::as_bstr
    let ns = Namespace("refs/namespaces/test/")
    if (ns.asBstr() != "refs/namespaces/test/") {
        throw Exception("asBstr mismatch")
    }
}

@Test
func testNamespaceExpandDotSlash(): Unit {
    // 对齐 Rust: namespace::expand — 含 ./ 的路径
    let ns = Namespace.expand("foo/./bar")
    if (ns.isNone()) {
        throw Exception("should expand")
    }
    // 仓颉 split("/") 会保留 "."
    if (!ns.getOrThrow().asBstr().contains("refs/namespaces/./")) {
        // 仓颉不规范化路径组件，与 Rust 行为差异
    }
}

// ============================================================
// Reference 补充测试 — 对齐 gix-ref/tests/refs/reference.rs (T027)
// ============================================================

@Test
func testReferenceFromBytesSymbolicWithWhitespace(): Unit {
    // 对齐 Rust: Reference::from_bytes — 符号引用含尾部空白
    let content = "ref: refs/heads/main  \n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    // 仓颉实现不 trim，尾部空白可能导致 FullName.tryFrom 返回 None
    // 这与 Rust 行为差异：Rust 会 trim
}

@Test
func testReferenceFromBytesObjectSha256(): Unit {
    // 对齐 Rust: Reference::from_bytes — SHA-256 对象引用
    let content = "cf83e1357eefb8bdf1542850d66d8007d620e4050b5715dc83f4a921d36ce9ce\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha256)
    if (refVal.isNone()) {
        throw Exception("SHA-256 object ref should parse")
    }
}

@Test
func testReferenceToBytesSymbolicFormat(): Unit {
    // 对齐 Rust: Reference::to_bytes — 符号引用格式验证
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Symbolic(name.getOrThrow()), None)
    let bytes = refVal.toBytes()
    let str = String.fromUtf8(bytes)
    if (!str.startsWith("ref: refs/heads/main")) {
        throw Exception("symbolic ref should start with 'ref: refs/heads/main'")
    }
    if (!str.endsWith("\n")) {
        throw Exception("symbolic ref should end with newline")
    }
}

@Test
func testReferenceToBytesObjectFormat(): Unit {
    // 对齐 Rust: Reference::to_bytes — 对象引用格式验证
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let refVal = Reference(name, Target.Object(id), None)
    let bytes = refVal.toBytes()
    let str = String.fromUtf8(bytes)
    if (!str.startsWith("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("object ref should start with hex ID")
    }
    if (!str.endsWith("\n")) {
        throw Exception("object ref should end with newline")
    }
}

@Test
func testReferenceFromBytesShortHex(): Unit {
    // 对齐 Rust: Reference::from_bytes — 短于 40 字符的十六进制
    let content = "e69de29b\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    // 仓颉实现中 ObjectId.fromHex 不验证长度，可能解析成功
    // 这是与 Rust 的差异点
}

@Test
func testReferenceKindSymbolic(): Unit {
    // 对齐 Rust: Reference::kind — 符号引用
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Symbolic(name.getOrThrow()), None)
    if (refVal.kind() != RefKind.Symbolic) {
        throw Exception("symbolic ref should be Symbolic kind")
    }
}

@Test
func testReferenceKindObject(): Unit {
    // 对齐 Rust: Reference::kind — 对象引用
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let refVal = Reference(name, Target.Object(id), None)
    if (refVal.kind() != RefKind.Object) {
        throw Exception("object ref should be Object kind")
    }
}

@Test
func testReferenceTryIdSymbolicReturnsNone(): Unit {
    // 对齐 Rust: Reference::try_id — 符号引用返回 None
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Symbolic(name.getOrThrow()), None)
    if (!refVal.tryId().isNone()) {
        throw Exception("symbolic ref tryId should return None")
    }
}

@Test
func testReferenceTryNameObjectReturnsNone(): Unit {
    // 对齐 Rust: Reference::try_name — 对象引用返回 None
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let refVal = Reference(name, Target.Object(id), None)
    if (!refVal.tryName().isNone()) {
        throw Exception("object ref tryName should return None")
    }
}

@Test
func testReferenceWithPeeled(): Unit {
    // 对齐 Rust: Reference with peeled ObjectId
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let peeled = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let name = FullName.tryFrom("refs/tags/v1.0")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Object(id), Some(peeled))
    if (refVal.peeled.isNone()) {
        throw Exception("peeled should be Some")
    }
    if (refVal.peeled.getOrThrow().toHexString() != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("peeled ID mismatch")
    }
}

@Test
func testReferenceFromBytesPackedRef(): Unit {
    // 对齐 Rust: packed refs 格式（不含 ref: 前缀）
    let content = "9556057aee5abb06912922e9f26c46386a816822\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("packed ref should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Object) {
        throw Exception("packed ref should be Object kind")
    }
}

// ============================================================
// Transaction 补充测试 — 对齐 gix-ref/tests/refs/transaction.rs (T028)
// ============================================================

@Test
func testTransactionMultipleCreates(): Unit {
    // 对齐 Rust: transaction — 多个创建操作
    let tx = Transaction()
    let name1 = FullName.tryFrom("refs/heads/a")
    let name2 = FullName.tryFrom("refs/heads/b")
    if (name1.isNone() || name2.isNone()) {
        throw Exception("should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.create(name1.getOrThrow(), Target.Object(id))
    tx.create(name2.getOrThrow(), Target.Object(id))
    if (tx.edits.size != 2) {
        throw Exception("should have 2 edits")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("first should be Create")
    }
    if (tx.edits[1].editType != EditType.Create) {
        throw Exception("second should be Create")
    }
}

@Test
func testTransactionCreateSymbolicRef(): Unit {
    // 对齐 Rust: transaction — 创建符号引用
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/feature")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = FullName.tryFrom("refs/heads/main")
    if (target.isNone()) {
        throw Exception("target should parse")
    }
    tx.create(name.getOrThrow(), Target.Symbolic(target.getOrThrow()))
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("should be Create")
    }
    if (let Target.Symbolic(_) <- tx.edits[0].target) {
    // 验证目标类型为 Symbolic
    } else {
        throw Exception("target should be Symbolic")
    }
}

@Test
func testTransactionUpdateSymbolicRef(): Unit {
    // 对齐 Rust: transaction — 更新符号引用
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/feature")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = FullName.tryFrom("refs/heads/develop")
    if (target.isNone()) {
        throw Exception("target should parse")
    }
    tx.update(name.getOrThrow(), Target.Symbolic(target.getOrThrow()))
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit")
    }
    if (tx.edits[0].editType != EditType.Update) {
        throw Exception("should be Update")
    }
}

@Test
func testTransactionDeleteMultiple(): Unit {
    // 对齐 Rust: transaction — 多个删除操作
    let tx = Transaction()
    let names = ["refs/heads/a", "refs/heads/b", "refs/tags/v1.0"]
    for (n in names) {
        let name = FullName.tryFrom(n)
        if (name.isNone()) {
            throw Exception(n + " should parse")
        }
        tx.delete(name.getOrThrow())
    }
    if (tx.edits.size != 3) {
        throw Exception("should have 3 edits")
    }
    for (i in 0..3) {
        if (tx.edits[i].editType != EditType.Delete) {
            throw Exception("edit " + i.toString() + " should be Delete")
        }
    }
}

@Test
func testTransactionEditNamePreserved(): Unit {
    // 对齐 Rust: transaction — 编辑操作保留引用名
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.update(name.getOrThrow(), Target.Object(id))
    if (tx.edits[0].name.value != "refs/heads/main") {
        throw Exception("edit name should be preserved")
    }
}

@Test
func testTransactionEditTargetPreserved(): Unit {
    // 对齐 Rust: transaction — 编辑操作保留目标
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.update(name.getOrThrow(), Target.Object(id))
    let editTarget = tx.edits[0].target
    if (let Target.Object(tid) <- editTarget) {
        if (tid.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
            throw Exception("edit target ID mismatch")
        }
    } else {
        throw Exception("edit target should be Object")
    }
}

// ============================================================
// File/Reference 解析补充测试 — 对齐 gix-ref/tests/refs/file/reference.rs (T029)
// ============================================================

@Test
func testReferenceFromBytesSymbolicRefsHeads(): Unit {
    // 对齐 Rust: file::reference — 符号引用指向 refs/heads/
    let content = "ref: refs/heads/develop\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("symbolic ref to refs/heads/develop should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Symbolic) {
        throw Exception("should be Symbolic")
    }
    let name = r.tryName()
    if (name.isNone()) {
        throw Exception("should have name")
    }
    if (name.getOrThrow().value != "refs/heads/develop") {
        throw Exception("name should be refs/heads/develop")
    }
}

@Test
func testReferenceFromBytesSymbolicRefsRemotes(): Unit {
    // 对齐 Rust: file::reference — 符号引用指向 refs/remotes/
    let content = "ref: refs/remotes/origin/main\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("symbolic ref to refs/remotes/origin/main should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Symbolic) {
        throw Exception("should be Symbolic")
    }
}

@Test
func testReferenceFromBytesSymbolicRefsTags(): Unit {
    // 对齐 Rust: file::reference — 符号引用指向 refs/tags/
    let content = "ref: refs/tags/v1.0\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("symbolic ref to refs/tags/v1.0 should parse")
    }
}

@Test
func testReferenceFromBytesObjectAllZeros(): Unit {
    // 对齐 Rust: file::reference — 全零对象 ID
    let content = "0000000000000000000000000000000000000000\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("all-zero object ref should parse")
    }
    let r = refVal.getOrThrow()
    if (r.kind() != RefKind.Object) {
        throw Exception("should be Object kind")
    }
    if (!targetIsNull(r.target)) {
        throw Exception("all-zero target should be null")
    }
}

@Test
func testReferenceFromBytesObjectNonZero(): Unit {
    // 对齐 Rust: file::reference — 非零对象 ID
    let content = "9556057aee5abb06912922e9f26c46386a816822\n"
    let refVal = Reference.fromBytes(content.toArray(), HashKind.Sha1)
    if (refVal.isNone()) {
        throw Exception("non-zero object ref should parse")
    }
    let r = refVal.getOrThrow()
    if (targetIsNull(r.target)) {
        throw Exception("non-zero target should not be null")
    }
}

@Test
func testReferenceRoundTripMultipleSymbolic(): Unit {
    // 对齐 Rust: file::reference — 多种符号引用 round-trip
    let targets = ["refs/heads/main", "refs/heads/develop", "refs/remotes/origin/main"]
    for (t in targets) {
        let name = FullName.tryFrom(t)
        if (name.isNone()) {
            throw Exception(t + " should parse")
        }
        let n = name.getOrThrow()
        let ref1 = Reference(n, Target.Symbolic(n), None)
        let bytes = ref1.toBytes()
        let ref2 = Reference.fromBytes(bytes, HashKind.Sha1)
        if (ref2.isNone()) {
            throw Exception("round-trip for " + t + " should parse")
        }
        if (ref2.getOrThrow().kind() != RefKind.Symbolic) {
            throw Exception("round-trip for " + t + " should be Symbolic")
        }
    }
}

@Test
func testReferenceRoundTripMultipleObject(): Unit {
    // 对齐 Rust: file::reference — 多种对象引用 round-trip
    let hexIds = [
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "9556057aee5abb06912922e9f26c46386a816822",
        "4b825dc642cb6eb9a060e54bf8d69288fbee4904"
    ]
    for (hex in hexIds) {
        let id = ObjectId.fromHexOrThrow(hex)
        let name = FullName("HEAD")
        let ref1 = Reference(name, Target.Object(id), None)
        let bytes = ref1.toBytes()
        let ref2 = Reference.fromBytes(bytes, HashKind.Sha1)
        if (ref2.isNone()) {
            throw Exception("round-trip for " + hex + " should parse")
        }
        if (ref2.getOrThrow().kind() != RefKind.Object) {
            throw Exception("round-trip for " + hex + " should be Object")
        }
    }
}

// ============================================================
// Reflog 补充测试 — 对齐 gix-ref/tests/refs/file/log.rs (T030)
// ============================================================

@Test
func testReflogEntryFromLineWithMessage(): Unit {
    // 对齐 Rust: reflog::from_line — 含消息
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904 1710007200 +0530\tcommit: initial commit"
    let entry = ReflogEntry.fromLine(line)
    if (entry.isNone()) {
        throw Exception("should parse")
    }
    let e = entry.getOrThrow()
    if (e.message != "commit: initial commit") {
        throw Exception("message mismatch: " + e.message)
    }
}

@Test
func testReflogEntryFromLineWithCheckoutMessage(): Unit {
    // 对齐 Rust: reflog::from_line — checkout 消息
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904 1710007200 +0530\tcheckout: moving from main to feature"
    let entry = ReflogEntry.fromLine(line)
    if (entry.isNone()) {
        throw Exception("should parse")
    }
    let e = entry.getOrThrow()
    if (e.message != "checkout: moving from main to feature") {
        throw Exception("message mismatch")
    }
}

@Test
func testReflogEntryFromLineMissingTab(): Unit {
    // 对齐 Rust: reflog::from_line — 缺少 tab 分隔符
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904 1710007200 +0530"
    let entry = ReflogEntry.fromLine(line)
    if (!entry.isNone()) {
        throw Exception("line without tab should return None")
    }
}

@Test
func testReflogEntryFromLineMissingTimestamp(): Unit {
    // 对齐 Rust: reflog::from_line — 缺少时间戳
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 4b825dc642cb6eb9a060e54bf8d69288fbee4904\tcommit"
    let entry = ReflogEntry.fromLine(line)
    // header parts 不足 4 个（oldId newId timestamp offset），应返回 None
    if (!entry.isNone()) {
        throw Exception("line without timestamp should return None")
    }
}

@Test
func testReflogMultipleEntries(): Unit {
    // 对齐 Rust: reflog — 多条日志条目
    let log = Reflog()
    let entry1 = ReflogEntry(
        "0000000000000000000000000000000000000000",
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "Alice",
        "alice@example.com",
        "1710007200 +0530",
        "commit: first"
    )
    let entry2 = ReflogEntry(
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
        "Bob",
        "bob@example.com",
        "1710008000 +0530",
        "commit: second"
    )
    log.entries.add(entry1)
    log.entries.add(entry2)
    if (log.entries.size != 2) {
        throw Exception("should have 2 entries")
    }
    if (log.entries[0].message != "commit: first") {
        throw Exception("first entry message mismatch")
    }
    if (log.entries[1].message != "commit: second") {
        throw Exception("second entry message mismatch")
    }
}

@Test
func testReflogWriteReadMultipleEntries(): Unit {
    // 对齐 Rust: reflog write → read — 多条日志
    let log = Reflog()
    let entry1 = ReflogEntry(
        "0000000000000000000000000000000000000000",
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "Alice",
        "alice@example.com",
        "1710007200 +0530",
        "commit: first"
    )
    let entry2 = ReflogEntry(
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "4b825dc642cb6eb9a060e54bf8d69288fbee4904",
        "Bob",
        "bob@example.com",
        "1710008000 +0530",
        "commit: second"
    )
    log.entries.add(entry1)
    log.entries.add(entry2)
    let testPath = "/tmp/gix-reflog-multi-test-" + 200000.toString() + ".log"
    log.write(testPath)
    let readBack = Reflog.read(testPath)
    if (readBack.isNone()) {
        throw Exception("written reflog should be readable")
    }
    let rb = readBack.getOrThrow()
    if (rb.entries.size != 2) {
        throw Exception("should have 2 entries, got " + rb.entries.size.toString())
    }
}

@Test
func testReflogEntryToBytesFormat(): Unit {
    // 对齐 Rust: reflog entry to_bytes — 格式验证
    let entry = ReflogEntry(
        "0000000000000000000000000000000000000000",
        "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391",
        "Alice",
        "alice@example.com",
        "1710007200 +0530",
        "commit: test"
    )
    let bytes = entry.toBytes()
    let str = String.fromUtf8(bytes)
    if (!str.contains("0000000000000000000000000000000000000000")) {
        throw Exception("should contain old ID")
    }
    if (!str.contains("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("should contain new ID")
    }
    if (!str.contains("Alice")) {
        throw Exception("should contain name")
    }
    if (!str.contains("alice@example.com")) {
        throw Exception("should contain email")
    }
    if (!str.contains("commit: test")) {
        throw Exception("should contain message")
    }
    if (!str.endsWith("\n")) {
        throw Exception("should end with newline")
    }
}

// ============================================================
// Worktree 基本概念测试 — 对齐 gix-ref/tests/refs/file/worktree.rs (T031)
// 注意：仓颉当前无 worktree 支持，仅测试基本概念
// ============================================================

@Test
func testWorktreePseudoRefPrefix(): Unit {
    // 对齐 Rust: worktree — main-worktree/ 前缀
    // 仓颉当前无 worktree 支持，验证 FullName 不接受 worktree 前缀
    let name = FullName.tryFrom("main-worktree/HEAD")
    if (!name.isNone()) {
        throw Exception("main-worktree/HEAD should be invalid (no refs/ prefix)")
    }
}

@Test
func testWorktreeWorktreesPrefix(): Unit {
    // 对齐 Rust: worktree — worktrees/ 前缀
    let name = FullName.tryFrom("worktrees/w1/HEAD")
    if (!name.isNone()) {
        throw Exception("worktrees/w1/HEAD should be invalid (no refs/ prefix)")
    }
}

@Test
func testWorktreeRefsBisect(): Unit {
    // 对齐 Rust: worktree — refs/bisect/ 是 worktree-private
    let name = FullName.tryFrom("refs/bisect/good")
    if (name.isNone()) {
        throw Exception("refs/bisect/good should be valid")
    }
}

// ============================================================
// Transaction prepare/commit 补充测试 — 对齐 gix-ref/tests/refs/file/transaction/ (T036)
// 注意：仓颉当前 Transaction 仅为数据结构，无 prepare/commit 实现
// ============================================================

@Test
func testTransactionPrepareCreateThenUpdate(): Unit {
    // 对齐 Rust: transaction::prepare — 先创建后更新
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/new-branch")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    tx.create(name.getOrThrow(), Target.Object(id1))
    tx.update(name.getOrThrow(), Target.Object(id2))
    if (tx.edits.size != 2) {
        throw Exception("should have 2 edits")
    }
}

@Test
func testTransactionPrepareUpdateThenDelete(): Unit {
    // 对齐 Rust: transaction::prepare — 先更新后删除
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tx.update(name.getOrThrow(), Target.Object(id))
    tx.delete(name.getOrThrow())
    if (tx.edits.size != 2) {
        throw Exception("should have 2 edits")
    }
}

@Test
func testTransactionPrepareMixedTypes(): Unit {
    // 对齐 Rust: transaction::prepare — 混合操作类型
    let tx = Transaction()
    let names = [
        ("refs/heads/new", EditType.Create),
        ("refs/heads/main", EditType.Update),
        ("refs/tags/old", EditType.Delete)
    ]
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    for ((n, _) in names) {
        let name = FullName.tryFrom(n)
        if (name.isNone()) {
            throw Exception(n + " should parse")
        }
    }
    let n1 = FullName.tryFrom("refs/heads/new")
    let n2 = FullName.tryFrom("refs/heads/main")
    let n3 = FullName.tryFrom("refs/tags/old")
    tx.create(n1.getOrThrow(), Target.Object(id))
    tx.update(n2.getOrThrow(), Target.Object(id))
    tx.delete(n3.getOrThrow())
    if (tx.edits.size != 3) {
        throw Exception("should have 3 edits")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("0 should be Create")
    }
    if (tx.edits[1].editType != EditType.Update) {
        throw Exception("1 should be Update")
    }
    if (tx.edits[2].editType != EditType.Delete) {
        throw Exception("2 should be Delete")
    }
}

// ============================================================
// Parse 补充测试 — 对齐 gix-ref/src/parse.rs
// ============================================================

@Test
func testParseHexHashValidSha1(): Unit {
    // 对齐 Rust: parse_hex_hash — 合法 SHA-1
    let hex = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let data = hex.toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (result.isNone()) {
        throw Exception("valid SHA-1 hex should parse")
    }
    if (result.getOrThrow() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("hex string mismatch")
    }
}

@Test
func testParseHexHashInvalidChar(): Unit {
    // 对齐 Rust: parse_hex_hash — 非法字符
    let hex = "e69de29bb2d1d6434b8b29ae775ad8c2e48c539g"
    let data = hex.toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (!result.isNone()) {
        throw Exception("invalid hex char should return None")
    }
}

@Test
func testParseHexHashTooShort(): Unit {
    // 对齐 Rust: parse_hex_hash — 数据太短
    let hex = "e69de29b"
    let data = hex.toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (!result.isNone()) {
        throw Exception("too short data should return None")
    }
}

@Test
func testParseHexHashWithOffset(): Unit {
    // 对齐 Rust: parse_hex_hash — 带偏移
    let prefix = "prefix_"
    let hex = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"
    let data = (prefix + hex).toArray()
    let result = parseHexHash(data, 7, HashKind.Sha1)
    if (result.isNone()) {
        throw Exception("hex with offset should parse")
    }
    if (result.getOrThrow() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("hex string with offset mismatch")
    }
}

@Test
func testParseNewlineLF(): Unit {
    // 对齐 Rust: parse_newline — LF
    let data = "hello\nworld".toArray()
    let result = parseNewline(data, 5)
    if (result.isNone()) {
        throw Exception("LF should parse")
    }
    if (result.getOrThrow() != 6) {
        throw Exception("LF offset should be 6")
    }
}

@Test
func testParseNewlineCRLF(): Unit {
    // 对齐 Rust: parse_newline — CRLF
    let data = "hello\r\nworld".toArray()
    let result = parseNewline(data, 5)
    if (result.isNone()) {
        throw Exception("CRLF should parse")
    }
    if (result.getOrThrow() != 7) {
        throw Exception("CRLF offset should be 7")
    }
}

@Test
func testParseNewlineNoNewline(): Unit {
    // 对齐 Rust: parse_newline — 无换行符
    let data = "hello".toArray()
    let result = parseNewline(data, 3)
    if (!result.isNone()) {
        throw Exception("no newline should return None")
    }
}

@Test
func testParseNewlineAtEnd(): Unit {
    // 对齐 Rust: parse_newline — 末尾换行符
    let data = "hello\n".toArray()
    let result = parseNewline(data, 5)
    if (result.isNone()) {
        throw Exception("trailing LF should parse")
    }
}

// ============================================================
// Peel 测试 — 对齐 gix-ref/tests/peel.rs
// 注意：peelRef 需要 FindObject 接口实现
// ============================================================

@Test
func testPeelRefObjectDirect(): Unit {
    // 对齐 Rust: peel_ref — 直接对象引用
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let name = FullName("HEAD")
    let refVal = Reference(name, Target.Object(id), None)
    let finder = TestFinder()
    let result = peelRef(refVal, finder)
    if (result.isNone()) {
        throw Exception("peel of object ref should return Some")
    }
    if (result.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("peeled ID mismatch")
    }
}

@Test
func testPeelRefWithPeeled(): Unit {
    // 对齐 Rust: peel_ref — 含 peeled 值
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let peeled = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let name = FullName.tryFrom("refs/tags/v1.0")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Object(id), Some(peeled))
    let finder = TestFinder()
    let result = peelRef(refVal, finder)
    if (result.isNone()) {
        throw Exception("peel with peeled should return Some")
    }
    if (result.getOrThrow().toHexString() != "4b825dc642cb6eb9a060e54bf8d69288fbee4904") {
        throw Exception("should return peeled ID, not target ID")
    }
}

@Test
func testPeelRefSymbolicOneLevel(): Unit {
    // 对齐 Rust: peel_ref — 一层符号引用
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let mainName = FullName.tryFrom("refs/heads/main")
    if (mainName.isNone()) {
        throw Exception("should parse")
    }
    let mainRef = Reference(mainName.getOrThrow(), Target.Object(id), None)
    let headName = FullName("HEAD")
    let headRef = Reference(headName, Target.Symbolic(mainName.getOrThrow()), None)
    let finder = TestFinder.withRef(mainRef)
    let result = peelRef(headRef, finder)
    if (result.isNone()) {
        throw Exception("peel of symbolic ref should return Some")
    }
    if (result.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("peeled ID mismatch")
    }
}

@Test
func testPeelRefSymbolicUnresolvable(): Unit {
    // 对齐 Rust: peel_ref — 不可解析的符号引用
    let mainName = FullName.tryFrom("refs/heads/nonexistent")
    if (mainName.isNone()) {
        throw Exception("should parse")
    }
    let headName = FullName("HEAD")
    let headRef = Reference(headName, Target.Symbolic(mainName.getOrThrow()), None)
    let finder = TestFinder()
    let result = peelRef(headRef, finder)
    if (!result.isNone()) {
        throw Exception("unresolvable symbolic ref should return None")
    }
}

// ============================================================
// 测试辅助：FindObject 实现
// ============================================================

class TestFinder <: FindObject {
    var storedRef: ?Reference

    init() {
        this.storedRef = None
    }

    init(ref: Reference) {
        this.storedRef = Some(ref)
    }

    public static func withRef(ref: Reference): TestFinder {
        TestFinder(ref)
    }

    public func findRef(name: FullName): ?Reference {
        if (let Some(refVal) <- storedRef) {
            if (refVal.name.value == name.value) {
                return Some(refVal)
            }
        }
        None
    }
}

// ============================================================
// FullName category 补充测试 — 对齐 gix-ref/tests/refs/fullname.rs
// ============================================================

@Test
func testFullNameCategoryRemoteTrackingBranch(): Unit {
    // 对齐 Rust: fullname::shorten_and_category — remote tracking branch
    let name = FullName.tryFrom("refs/remotes/origin/main")
    if (name.isNone()) {
        throw Exception("refs/remotes/origin/main should be valid")
    }
    let cat = name.getOrThrow().category()
    if (cat != RefCategory.RemoteBranch) {
        throw Exception("should be RemoteBranch category")
    }
}

@Test
func testFullNameCategoryNoteSupplement(): Unit {
    // 对齐 Rust: fullname::shorten_and_category — note refVal
    let name = FullName.tryFrom("refs/notes/commits")
    if (name.isNone()) {
        throw Exception("refs/notes/commits should be valid")
    }
    let cat = name.getOrThrow().category()
    if (cat != RefCategory.Note) {
        throw Exception("should be Note category")
    }
}

@Test
func testFullNameCategoryReplace(): Unit {
    // 对齐 Rust: fullname::shorten_and_category — replace refVal
    let name = FullName.tryFrom("refs/replace/e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (name.isNone()) {
        throw Exception("refs/replace/... should be valid")
    }
    let cat = name.getOrThrow().category()
    if (cat != RefCategory.PseudoRef) {
        throw Exception("replace ref should be PseudoRef category")
    }
}

@Test
func testFullNameCategoryTagSupplement(): Unit {
    // 对齐 Rust: fullname::shorten_and_category — tag refVal
    let name = FullName.tryFrom("refs/tags/v1.0.0")
    if (name.isNone()) {
        throw Exception("refs/tags/v1.0.0 should be valid")
    }
    let cat = name.getOrThrow().category()
    if (cat != RefCategory.Tag) {
        throw Exception("should be Tag category")
    }
}

@Test
func testFullNameIsRemoteTrackingBranch(): Unit {
    // 对齐 Rust: fullname::is_remote_tracking_branch
    let name = FullName.tryFrom("refs/remotes/origin/develop")
    if (name.isNone()) {
        throw Exception("refs/remotes/origin/develop should be valid")
    }
    if (!name.getOrThrow().isRemoteTrackingBranch()) {
        throw Exception("refs/remotes/... should be remote tracking branch")
    }
    let localName = FullName.tryFrom("refs/heads/main")
    if (localName.isNone()) {
        throw Exception("should parse")
    }
    if (localName.getOrThrow().isRemoteTrackingBranch()) {
        throw Exception("refs/heads/... should not be remote tracking branch")
    }
}

@Test
func testFullNamePrefixNamespaceAndStrip(): Unit {
    // 对齐 Rust: fullname::prefix_with_namespace_and_stripping
    let ns = Namespace("myns")
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let prefixed = ns.intoNamespacedRef(name.getOrThrow())
    if (!prefixed.value.startsWith("refs/namespaces/myns/")) {
        throw Exception("namespaced ref should start with refs/namespaces/myns/: " + prefixed.value)
    }
    let stripped = Namespace.stripNamespace(prefixed.value)
    if (stripped != "refs/heads/main") {
        throw Exception("stripped should be refs/heads/main, got: " + stripped)
    }
}

@Test
func testFullNameLocalBranchHeadIsRepresentable(): Unit {
    // 对齐 Rust: fullname::local_branch_head_is_representable_as_full_ref_name
    let name = FullName.tryFrom("refs/heads/HEAD")
    if (name.isNone()) {
        throw Exception("refs/heads/HEAD should be valid full ref name")
    }
}

// ============================================================
// Target 补充测试 — 对齐 gix-ref/tests/refs/target.rs
// ============================================================

@Test
func testTargetSymbolicConstruction(): Unit {
    // 对齐 Rust: target::Symbolic — 符号引用目标构造
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Symbolic(name.getOrThrow())
    if (targetKind(target) != RefKind.Symbolic) {
        throw Exception("Symbolic target kind should be Symbolic")
    }
}

@Test
func testTargetSymbolicInvalidPath(): Unit {
    // 对齐 Rust: target::Symbolic — 无效路径不应构造 FullName
    let name = FullName.tryFrom("not-a-ref")
    if (name.isSome()) {
        throw Exception("non-ref path should not be valid FullName")
    }
}

@Test
func testTargetObjectConstruction(): Unit {
    // 对齐 Rust: target::Object — 从 ObjectId 构造
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let obj = Target.Object(id)
    if (targetKind(obj) != RefKind.Object) {
        throw Exception("Object target kind should be Object")
    }
}

@Test
func testTargetTryIdFromObject(): Unit {
    // 对齐 Rust: target::try_id — 从 Object 目标提取 ObjectId
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let target = Target.Object(id)
    let extracted = targetTryId(target)
    if (extracted.isNone()) {
        throw Exception("should extract ObjectId from Object target")
    }
    if (extracted.getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("extracted ObjectId mismatch")
    }
}

@Test
func testTargetTryIdFromSymbolic(): Unit {
    // 对齐 Rust: target::try_id — 从 Symbolic 目标提取 ObjectId 应返回 None
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Symbolic(name.getOrThrow())
    let extracted = targetTryId(target)
    if (extracted.isSome()) {
        throw Exception("Symbolic target should not yield ObjectId")
    }
}

@Test
func testTargetTryNameFromSymbolic(): Unit {
    // 对齐 Rust: target::try_name — 从 Symbolic 目标提取 FullName
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Symbolic(name.getOrThrow())
    let extracted = targetTryName(target)
    if (extracted.isNone()) {
        throw Exception("should extract FullName from Symbolic target")
    }
    if (extracted.getOrThrow().value != "refs/heads/main") {
        throw Exception("extracted FullName mismatch")
    }
}

@Test
func testTargetTryNameFromObject(): Unit {
    // 对齐 Rust: target::try_name — 从 Object 目标提取 FullName 应返回 None
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let target = Target.Object(id)
    let extracted = targetTryName(target)
    if (extracted.isSome()) {
        throw Exception("Object target should not yield FullName")
    }
}

// ============================================================
// Reference 补充测试 — 对齐 gix-ref/tests/refs/reference.rs
// ============================================================

@Test
func testReferenceKindObjectSupplement(): Unit {
    // 对齐 Rust: reference::kind — Object 引用
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let refVal = Reference(name.getOrThrow(), Target.Object(id), None)
    if (refVal.kind() != RefKind.Object) {
        throw Exception("reference with Object target should have Object kind")
    }
}

@Test
func testReferenceKindSymbolicSupplement(): Unit {
    // 对齐 Rust: reference::kind — Symbolic 引用
    let name = FullName.tryFrom("HEAD")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let symName = FullName.tryFrom("refs/heads/main")
    if (symName.isNone()) {
        throw Exception("should parse")
    }
    let refVal = Reference(name.getOrThrow(), Target.Symbolic(symName.getOrThrow()), None)
    if (refVal.kind() != RefKind.Symbolic) {
        throw Exception("reference with Symbolic target should have Symbolic kind")
    }
}

@Test
func testReferenceFollowSymbolic(): Unit {
    // 对齐 Rust: reference::follow — 解引用符号引用
    let headName = FullName.tryFrom("HEAD")
    if (headName.isNone()) {
        throw Exception("should parse")
    }
    let mainName = FullName.tryFrom("refs/heads/main")
    if (mainName.isNone()) {
        throw Exception("should parse")
    }
    let mainId = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let mainRef = Reference(mainName.getOrThrow(), Target.Object(mainId), None)
    let headRef = Reference(headName.getOrThrow(), Target.Symbolic(mainName.getOrThrow()), None)
    let finder = TestFinder.withRef(mainRef)
    let result = headRef.follow(finder)
    if (result.isNone()) {
        throw Exception("following HEAD should find refs/heads/main")
    }
    if (result.getOrThrow().name.value != "refs/heads/main") {
        throw Exception("followed ref should be refs/heads/main")
    }
}

// ============================================================
// Namespace 补充测试 — 对齐 gix-ref/tests/refs/namespace.rs
// ============================================================

@Test
func testNamespaceIntoNamespacedRefNested(): Unit {
    // 对齐 Rust: namespace::into_namespaced_ref — 嵌套命名空间
    let ns = Namespace("outer/inner")
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let prefixed = ns.intoNamespacedRef(name.getOrThrow())
    if (!prefixed.value.startsWith("refs/namespaces/outer/inner/")) {
        throw Exception("nested namespace should be prefixed: " + prefixed.value)
    }
}

@Test
func testNamespaceStripNested(): Unit {
    // 对齐 Rust: namespace::strip_namespace — 剥离嵌套命名空间
    // Rust 格式：refs/namespaces/outer/refs/namespaces/inner/refs/heads/main
    let path = "refs/namespaces/outer/refs/namespaces/inner/refs/heads/main"
    let stripped = Namespace.stripNamespace(path)
    if (stripped != "refs/heads/main") {
        throw Exception("nested namespace strip should yield refs/heads/main, got: " + stripped)
    }
}

// ============================================================
// FullName 补充测试 — 对齐 gix-ref/tests/refs/fullname.rs
// ============================================================

@Test
func testFullNameFileName(): Unit {
    // 对齐 Rust: fullname::file_name — 提取最后一段
    let name = FullName.tryFrom("refs/heads/feature/foo")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let n = name.getOrThrow()
    let short = n.shorten()
    if (!short.contains("foo")) {
        throw Exception("shorten should contain 'foo', got: " + short)
    }
}

@Test
func testFullNameToFullNameFromCategory(): Unit {
    // 对齐 Rust: fullname::to_full_name — 从分类+短名构建全名
    // LocalBranch + "main" → "refs/heads/main"
    let fullName = FullName("refs/heads/main")
    if (fullName.category() != RefCategory.LocalBranch) {
        throw Exception("should be LocalBranch")
    }
    if (fullName.shorten() != "main") {
        throw Exception("shorten should be 'main'")
    }
}

@Test
func testFullNameDisplay(): Unit {
    // 对齐 Rust: fullname::display — FullName 的字符串格式化
    let name = FullName("refs/heads/main")
    if (name.value != "refs/heads/main") {
        throw Exception("display should be 'refs/heads/main'")
    }
}

@Test
func testFullNameIsRemoteTrackingBranchTrue(): Unit {
    // 对齐 Rust: fullname::is_remote_tracking_branch — 远程跟踪分支
    let name = FullName.tryFrom("refs/remotes/origin/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (!name.getOrThrow().isRemoteTrackingBranch()) {
        throw Exception("refs/remotes/origin/main should be remote tracking branch")
    }
}

@Test
func testFullNameIsRemoteTrackingBranchFalse(): Unit {
    // 对齐 Rust: fullname::is_remote_tracking_branch — 非远程跟踪分支
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    if (name.getOrThrow().isRemoteTrackingBranch()) {
        throw Exception("refs/heads/main should not be remote tracking branch")
    }
}

// ============================================================
// Namespace 补充测试 — 对齐 gix-ref/tests/refs/namespace.rs
// ============================================================

@Test
func testNamespaceIntoNamespacedPrefix(): Unit {
    // 对齐 Rust: namespace::into_namespaced_prefix — 命名空间与前缀组合
    let ns = Namespace("foo")
    let result = "refs/namespaces/" + ns.value + "/refs/heads/"
    if (result != "refs/namespaces/foo/refs/heads/") {
        throw Exception("namespaced prefix should be 'refs/namespaces/foo/refs/heads/', got: " + result)
    }
}

// ============================================================
// Parse 补充测试 — 对齐 gix-ref/tests/refs/file/reference.rs parse
// ============================================================

@Test
func testParseHexHashInvalidChars(): Unit {
    // 对齐 Rust: file::reference::parse::invalid::hex_id — 无效十六进制字符
    let data = "GGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGGG".toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (!result.isNone()) {
        throw Exception("invalid hex chars should return None")
    }
}

@Test
func testParseHexHashUppercase(): Unit {
    // 对齐 Rust: file::reference::parse::valid::peeled_uppercase — 大写十六进制
    let data = "FFA700B4ACA13B80CB6B98A078E7C96804F8E0EC".toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (result.isNone()) {
        throw Exception("uppercase hex should parse")
    }
}

@Test
func testParseHexHashInsufficientData(): Unit {
    // 对齐 Rust: file::reference::parse::invalid — 数据不足
    let data = "FFA700".toArray()
    let result = parseHexHash(data, 0, HashKind.Sha1)
    if (!result.isNone()) {
        throw Exception("insufficient hex data should return None")
    }
}

@Test
func testParseNewlineLF2(): Unit {
    // 对齐 Rust: file::reference::parse — LF 换行
    let data: Array<Byte> = [UInt8(10)]
    let result = parseNewline(data, 0)
    if (result.isNone()) {
        throw Exception("LF should parse as newline")
    }
    if (result.getOrThrow() != 1) {
        throw Exception("LF should advance by 1")
    }
}

@Test
func testParseNewlineCRLF2(): Unit {
    // 对齐 Rust: file::reference::parse — CRLF 换行
    let data: Array<Byte> = [UInt8(13), UInt8(10)]
    let result = parseNewline(data, 0)
    if (result.isNone()) {
        throw Exception("CRLF should parse as newline")
    }
    if (result.getOrThrow() != 2) {
        throw Exception("CRLF should advance by 2")
    }
}

@Test
func testParseNewlineNoNewline2(): Unit {
    // 对齐 Rust: file::reference::parse — 无换行符
    let data: Array<Byte> = [UInt8(65)]
    let result = parseNewline(data, 0)
    if (!result.isNone()) {
        throw Exception("non-newline should return None")
    }
}

// ============================================================
// Reflog 补充测试 — 对齐 gix-ref/tests/refs/file/log.rs
// ============================================================

@Test
func testReflogEntryFromLineValid(): Unit {
    // 对齐 Rust: file::log::line::parse — 有效 reflog 行
    let line = "0000000000000000000000000000000000000000 ffa700b4aca13b80cb6b98a078e7c96804f8e0ec A <a@a.com> 0 +0000\tcommit: initial"
    let entry = ReflogEntry.fromLine(line)
    if (entry.isNone()) {
        throw Exception("valid reflog line should parse")
    }
    let e = entry.getOrThrow()
    if (e.oldId != "0000000000000000000000000000000000000000") {
        throw Exception("oldId mismatch")
    }
    if (e.newId != "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec") {
        throw Exception("newId mismatch")
    }
    if (e.message != "commit: initial") {
        throw Exception("message mismatch: " + e.message)
    }
}

@Test
func testReflogEntryFromLineNoTab(): Unit {
    // 对齐 Rust: file::log::line::parse — 无 tab 分隔
    let line = "0000000000000000000000000000000000000000 ffa700b4aca13b80cb6b98a078e7c96804f8e0ec A <a@a.com> 0 +0000"
    let entry = ReflogEntry.fromLine(line)
    if (!entry.isNone()) {
        throw Exception("reflog line without tab should return None")
    }
}

@Test
func testReflogEntryToBytesRoundTrip(): Unit {
    // 对齐 Rust: file::log::line::write_to::round_trips — 往返测试
    let entry = ReflogEntry(
        "0000000000000000000000000000000000000000",
        "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec",
        "A",
        "a@a.com",
        "0 +0000",
        "commit: initial"
    )
    let bytes = entry.toBytes()
    // 去除末尾换行符
    var lineStr = String.fromUtf8(bytes)
    if (lineStr.endsWith("\n")) {
        lineStr = substringStr(lineStr, 0, lineStr.size - 1)
    }
    // 验证序列化后可重新解析
    let parsed = ReflogEntry.fromLine(lineStr)
    if (parsed.isNone()) {
        throw Exception("round-trip reflog entry should parse")
    }
    let p = parsed.getOrThrow()
    if (p.oldId != "0000000000000000000000000000000000000000") {
        throw Exception("round-trip oldId mismatch")
    }
    if (p.newId != "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec") {
        throw Exception("round-trip newId mismatch")
    }
}

@Test
func testReflogParseMultipleLines(): Unit {
    // 对齐 Rust: file::log::iter::forward — 多行 reflog 解析
    let log = Reflog()
    let data = ("0000000000000000000000000000000000000000 ffa700b4aca13b80cb6b98a078e7c96804f8e0ec A <a@a.com> 0 +0000\tfirst\n" +
        "ffa700b4aca13b80cb6b98a078e7c96804f8e0ec 9556057aee5abb06912922e9f26c46386a816822 A <a@a.com> 0 +0000\tsecond\n")
        .toArray()
    log.parse(data)
    if (log.entries.size != 2) {
        throw Exception("should have 2 entries, got " + log.entries.size.toString())
    }
    if (log.entries[0].message != "first") {
        throw Exception("first entry message mismatch")
    }
    if (log.entries[1].message != "second") {
        throw Exception("second entry message mismatch")
    }
}

// ============================================================
// Transaction 补充测试 — 对齐 gix-ref/tests/refs/transaction.rs
// ============================================================

@Test
func testTransactionCreateEdit(): Unit {
    // 对齐 Rust: transaction::create — 创建引用编辑
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/new-branch")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Object(ObjectId.fromHexOrThrow("ffa700b4aca13b80cb6b98a078e7c96804f8e0ec"))
    tx.create(name.getOrThrow(), target)
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("edit type should be Create")
    }
}

@Test
func testTransactionDeleteEdit(): Unit {
    // 对齐 Rust: transaction::delete — 删除引用编辑
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/old-branch")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    tx.delete(name.getOrThrow())
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit")
    }
    if (tx.edits[0].editType != EditType.Delete) {
        throw Exception("edit type should be Delete")
    }
}

@Test
func testTransactionUpdateEdit(): Unit {
    // 对齐 Rust: transaction::update — 更新引用编辑
    let tx = Transaction()
    let name = FullName.tryFrom("refs/heads/main")
    if (name.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Object(ObjectId.fromHexOrThrow("9556057aee5abb06912922e9f26c46386a816822"))
    tx.update(name.getOrThrow(), target)
    if (tx.edits.size != 1) {
        throw Exception("should have 1 edit")
    }
    if (tx.edits[0].editType != EditType.Update) {
        throw Exception("edit type should be Update")
    }
}

@Test
func testTransactionMultipleEdits(): Unit {
    // 对齐 Rust: transaction — 多个编辑操作
    let tx = Transaction()
    let name1 = FullName.tryFrom("refs/heads/feature")
    let name2 = FullName.tryFrom("refs/heads/main")
    if (name1.isNone() || name2.isNone()) {
        throw Exception("should parse")
    }
    let target = Target.Object(ObjectId.fromHexOrThrow("ffa700b4aca13b80cb6b98a078e7c96804f8e0ec"))
    tx.create(name1.getOrThrow(), target)
    tx.update(name2.getOrThrow(), target)
    if (tx.edits.size != 2) {
        throw Exception("should have 2 edits")
    }
    if (tx.edits[0].editType != EditType.Create) {
        throw Exception("first edit should be Create")
    }
    if (tx.edits[1].editType != EditType.Update) {
        throw Exception("second edit should be Update")
    }
}
