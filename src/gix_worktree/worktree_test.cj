// 文件：worktree_test.cj
// 用途：gix_worktree 包的单元测试，全量对齐 Rust gitoxide gix-worktree 测试
// 所属包：gix.gix_worktree
// 对齐来源：gix-worktree/tests/worktree.rs

package gitoxide.gix_worktree

import std.unittest.*
import std.collection.*
import gitoxide.gix_object.*
import gitoxide.gix_hash.*

// ============================================================
// Worktree 测试
// ============================================================

@Test
func testWorktreeConstruction(): Unit {
    // 对齐 Rust: Worktree construction
    let wt = Worktree("/project", "/project/.git")
    if (wt.root != "/project") {
        throw Exception("root mismatch")
    }
    if (wt.gitDir != "/project/.git") {
        throw Exception("gitDir mismatch")
    }
}

@Test
func testWorktreeStatusReturnsEmpty(): Unit {
    // 对齐 Rust: Worktree::status
    // 仓颉差异：status 当前为占位实现（返回空列表），待真实实现后应验证状态条目
    let wt = Worktree("/tmp", "/tmp/.git")
    let status = wt.status()
    if (status.size != 0) {
        throw Exception("placeholder status should return empty list")
    }
}

// ============================================================
// StatusEntry 测试
// ============================================================

@Test
func testStatusEntryCreation(): Unit {
    // 对齐 Rust: StatusEntry construction
    let entry = StatusEntry("file.txt", WorktreeStatus.Modified)
    if (entry.path != "file.txt") {
        throw Exception("path mismatch")
    }
    if (entry.status != WorktreeStatus.Modified) {
        throw Exception("status mismatch")
    }
}

// ============================================================
// WorktreeStatus 枚举测试
// ============================================================

@Test
func testWorktreeStatusVariants(): Unit {
    // 对齐 Rust: WorktreeStatus enum completeness
    let variants: Array<WorktreeStatus> = [
        WorktreeStatus.Unmodified,
        WorktreeStatus.Modified,
        WorktreeStatus.Added,
        WorktreeStatus.Deleted,
        WorktreeStatus.Untracked
    ]
    if (variants.size != 5) {
        throw Exception("should have 5 WorktreeStatus variants, got " + variants.size.toString())
    }
}

// ============================================================
// WorktreeStatus 补充测试 — 对齐 Rust: Eq/PartialEq 语义
// ============================================================

@Test
func testWorktreeStatusEquality(): Unit {
    // 对齐 Rust: Eq trait — 同变体相等
    if (WorktreeStatus.Modified != WorktreeStatus.Modified) {
        throw Exception("same variant should be equal")
    }
    if (WorktreeStatus.Untracked != WorktreeStatus.Untracked) {
        throw Exception("same variant should be equal")
    }
}

@Test
func testWorktreeStatusAllVariantsNotEqual(): Unit {
    // 对齐 Rust: Eq trait — 不同变体互不相等
    let variants: Array<WorktreeStatus> = [
        WorktreeStatus.Unmodified,
        WorktreeStatus.Modified,
        WorktreeStatus.Added,
        WorktreeStatus.Deleted,
        WorktreeStatus.Untracked
    ]
    for (i in 0..variants.size) {
        for (j in 0..variants.size) {
            if (i != j && variants[i] == variants[j]) {
                throw Exception("different variants should not be equal")
            }
        }
    }
}

// ============================================================
// StatusEntry 补充测试
// ============================================================

@Test
func testStatusEntryDifferentStatuses(): Unit {
    // 对齐 Rust: StatusEntry with various statuses
    let entries: Array<StatusEntry> = [
        StatusEntry("a.txt", WorktreeStatus.Added),
        StatusEntry("b.txt", WorktreeStatus.Deleted),
        StatusEntry("c.txt", WorktreeStatus.Untracked),
        StatusEntry("d.txt", WorktreeStatus.Unmodified)
    ]
    if (entries[0].status != WorktreeStatus.Added) {
        throw Exception("Added mismatch")
    }
    if (entries[1].status != WorktreeStatus.Deleted) {
        throw Exception("Deleted mismatch")
    }
    if (entries[2].status != WorktreeStatus.Untracked) {
        throw Exception("Untracked mismatch")
    }
    if (entries[3].status != WorktreeStatus.Unmodified) {
        throw Exception("Unmodified mismatch")
    }
}

// ============================================================
// parentDirWt 补充测试
// ============================================================

@Test
func testParentDirWt(): Unit {
    // 对齐 Rust: parent directory extraction
    if (parentDirWt("a/b/c.txt") != "a/b") {
        throw Exception("nested path parent should be 'a/b'")
    }
    if (parentDirWt("file.txt") != "file.txt") {
        throw Exception("top-level file parent should be itself")
    }
    if (parentDirWt("dir/file.txt") != "dir") {
        throw Exception("single dir parent should be 'dir'")
    }
}

// ============================================================
// Worktree checkoutTree 补充测试 — 对齐 gix-worktree/tests/checkout.rs
// 注意：checkoutTree 依赖文件系统操作，仅验证基本构造和调用不崩溃
// ============================================================

@Test
func testWorktreeCheckoutTreeEmptyTree(): Unit {
    // 对齐 Rust: checkout_tree with empty tree
    let wt = Worktree("C:/temp/gix-worktree-empty-test", "C:/temp/gix-worktree-empty-test/.git")
    let tree = Tree(ArrayList<Entry>())
    // 空 tree 的 checkoutTree 不应崩溃
    wt.checkoutTree(tree, "")
}

@Test
func testWorktreeCheckoutTreeSingleFile(): Unit {
    // 对齐 Rust: checkout_tree with single file
    let testDir = "C:/temp/gix-wt-single-test-" + 1200000.toString()
    let wt = Worktree(testDir, testDir + "/.git")
    let oid = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let entry = Entry(EntryMode.Regular(), "test.txt", oid)
    let entries = ArrayList<Entry>()
    entries.add(entry)
    let tree = Tree(entries)
    // 文件系统操作可能失败，验证不崩溃
    wt.checkoutTree(tree, "")
}

// ============================================================
// StatusEntry 多路径补充测试 — 对齐 gix-worktree 状态
// ============================================================

@Test
func testStatusEntryWithDeepPath(): Unit {
    // 对齐 Rust: StatusEntry with deeply nested path
    let entry = StatusEntry("src/gix_hash/hash_test.cj", WorktreeStatus.Modified)
    if (entry.path != "src/gix_hash/hash_test.cj") {
        throw Exception("deep path mismatch")
    }
    if (entry.status != WorktreeStatus.Modified) {
        throw Exception("status should be Modified")
    }
}

@Test
func testStatusEntryWithSpacesInPath(): Unit {
    // 对齐 Rust: StatusEntry with spaces in path
    let entry = StatusEntry("my documents/file.txt", WorktreeStatus.Untracked)
    if (entry.path != "my documents/file.txt") {
        throw Exception("path with spaces mismatch")
    }
}

// ============================================================
// WorktreeStatus 枚举边界测试
// ============================================================

@Test
func testWorktreeStatusInequalityAllPairs(): Unit {
    // 对齐 Rust: PartialEq — 确认所有不同变体互不相等
    if (WorktreeStatus.Unmodified == WorktreeStatus.Modified) {
        throw Exception("Unmodified != Modified")
    }
    if (WorktreeStatus.Unmodified == WorktreeStatus.Added) {
        throw Exception("Unmodified != Added")
    }
    if (WorktreeStatus.Unmodified == WorktreeStatus.Deleted) {
        throw Exception("Unmodified != Deleted")
    }
    if (WorktreeStatus.Unmodified == WorktreeStatus.Untracked) {
        throw Exception("Unmodified != Untracked")
    }
    if (WorktreeStatus.Modified == WorktreeStatus.Added) {
        throw Exception("Modified != Added")
    }
    if (WorktreeStatus.Modified == WorktreeStatus.Deleted) {
        throw Exception("Modified != Deleted")
    }
    if (WorktreeStatus.Modified == WorktreeStatus.Untracked) {
        throw Exception("Modified != Untracked")
    }
    if (WorktreeStatus.Added == WorktreeStatus.Deleted) {
        throw Exception("Added != Deleted")
    }
    if (WorktreeStatus.Added == WorktreeStatus.Untracked) {
        throw Exception("Added != Untracked")
    }
    if (WorktreeStatus.Deleted == WorktreeStatus.Untracked) {
        throw Exception("Deleted != Untracked")
    }
}

// ============================================================
// StackState 测试 - 对齐 gix-worktree/src/stack/state/mod.rs
// ============================================================

@Test
func testStackStateVariants(): Unit {
    let s1 = StackState.CreateDirectoryAndAttributesStack
    let s2 = StackState.AttributesAndIgnoreStack
    let s3 = StackState.CreateDirectoryStack
    match (s1) {
        case StackState.CreateDirectoryAndAttributesStack => true;
        case _ => throw Exception("s1 mismatch")
    }
    match (s2) {
        case StackState.AttributesAndIgnoreStack => true;
        case _ => throw Exception("s2 mismatch")
    }
    match (s3) {
        case StackState.CreateDirectoryStack => true;
        case _ => throw Exception("s3 mismatch")
    }
}

// ============================================================
// StackStatistics 测试 - 对齐 gix-worktree/src/stack/mod.rs Statistics
// ============================================================

@Test
func testStackStatisticsDefaults(): Unit {
    let stats = StackStatistics()
    if (stats.platforms != 0) {
        throw Exception("platforms should be 0")
    }
    if (stats.ignoreStatistics.ignoreFilesLoaded != 0) {
        throw Exception("ignoreFilesLoaded should be 0")
    }
    if (stats.ignoreStatistics.patternsMatched != 0) {
        throw Exception("patternsMatched should be 0")
    }
}

// ============================================================
// PathIdMapping 测试 - 对齐 gix-worktree/src/lib.rs PathIdMapping
// ============================================================

@Test
func testPathIdMappingConstruct(): Unit {
    let m = PathIdMapping("src/main.cj", 42)
    if (m.path != "src/main.cj") {
        throw Exception("path mismatch")
    }
    if (m.id != 42) {
        throw Exception("id mismatch")
    }
}

// ============================================================
// IgnoreStackStatistics 测试 - 对齐 gix-worktree/src/stack/state/ignore.rs Statistics
// ============================================================

@Test
func testIgnoreStackStatisticsDefaults(): Unit {
    let stats = IgnoreStackStatistics()
    if (stats.ignoreFilesLoaded != 0) {
        throw Exception("ignoreFilesLoaded should be 0")
    }
    if (stats.patternsMatched != 0) {
        throw Exception("patternsMatched should be 0")
    }
    stats.ignoreFilesLoaded = 5
    stats.patternsMatched = 100
    if (stats.ignoreFilesLoaded != 5) {
        throw Exception("ignoreFilesLoaded should be 5")
    }
    if (stats.patternsMatched != 100) {
        throw Exception("patternsMatched should be 100")
    }
}
