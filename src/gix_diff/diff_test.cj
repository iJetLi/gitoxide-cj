// 文件：diff_test.cj
// 用途：gix_diff 包的单元测试，全量对齐 Rust gitoxide gix-diff 测试
// 所属包：gix.gix_diff
// 对齐来源：gix-diff/tests/tree_diff.rs

package gitoxide.gix_diff

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.unittest.*
import std.collection.*

// ============================================================
// DiffStatus 测试
// ============================================================

@Test
func testDiffStatusVariants(): Unit {
    // 对齐 Rust: DiffStatus 枚举完整性
    let statuses: Array<DiffStatus> = [DiffStatus.Added, DiffStatus.Modified, DiffStatus.Deleted, DiffStatus.Renamed,
        DiffStatus.Copied, DiffStatus.TypeChange]
    if (statuses.size != 6) {
        throw Exception("should have 6 DiffStatus variants")
    }
}

// ============================================================
// DiffEntry 测试
// ============================================================

@Test
func testDiffEntryCreation(): Unit {
    // 对齐 Rust: DiffEntry construction
    let entry = DiffEntry("src/main.cj", DiffStatus.Added)
    if (entry.path != "src/main.cj") {
        throw Exception("path mismatch")
    }
    if (entry.status != DiffStatus.Added) {
        throw Exception("status should be Added")
    }
    if (entry.oldMode.isSome()) {
        throw Exception("oldMode should be None for Added")
    }
    if (entry.newMode.isSome()) {
        throw Exception("newMode should be None initially")
    }
}

// ============================================================
// TreeDiff 测试
// ============================================================

@Test
func testTreeDiffCreation(): Unit {
    // 对齐 Rust: TreeDiff construction
    let diff = TreeDiff()
    if (diff.entries.size != 0) {
        throw Exception("new TreeDiff should have 0 entries")
    }
}

// ============================================================
// diffTrees 测试 — 对齐 gix-diff/tests/tree_diff.rs
// ============================================================

@Test
func testDiffTreesBothNone(): Unit {
    // 对齐 Rust: diff_trees(None, None) — 空树对比
    let diff = diffTrees(None, None)
    if (diff.entries.size != 0) {
        throw Exception("diff of two empty trees should have 0 entries")
    }
}

@Test
func testDiffTreesOldNoneNewSome(): Unit {
    // 对齐 Rust: diff_trees(None, tree) — 所有条目为 Added
    let newTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    newTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id))
    let diff = diffTrees(None, Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry, got " + diff.entries.size.toString())
    }
    if (diff.entries[0].status != DiffStatus.Added) {
        throw Exception("entry should be Added")
    }
    if (diff.entries[0].path != "file.txt") {
        throw Exception("path should be file.txt")
    }
}

@Test
func testDiffTreesOldSomeNewNone(): Unit {
    // 对齐 Rust: diff_trees(tree, None) — 所有条目为 Deleted
    let oldTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id))
    let diff = diffTrees(Some(oldTree), None)
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry")
    }
    if (diff.entries[0].status != DiffStatus.Deleted) {
        throw Exception("entry should be Deleted")
    }
}

@Test
func testDiffTreesIdentical(): Unit {
    // 对齐 Rust: diff_trees(tree, tree) — 相同树无差异
    let tree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tree.entries.add(Entry(EntryMode(0o100644), "file.txt", id))
    let diff = diffTrees(Some(tree), Some(tree))
    if (diff.entries.size != 0) {
        throw Exception("identical trees should have 0 diff entries")
    }
}

@Test
func testDiffTreesModified(): Unit {
    // 对齐 Rust: diff_trees — 修改文件
    let oldTree = Tree(ArrayList<Entry>())
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id1))

    let newTree = Tree(ArrayList<Entry>())
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    newTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id2))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry")
    }
    if (diff.entries[0].status != DiffStatus.Modified) {
        throw Exception("entry should be Modified")
    }
}

// ============================================================
// diffTrees 补充测试 — 对齐 gix-diff/tests/tree.rs
// ============================================================

@Test
func testDiffTreesMultipleAdditions(): Unit {
    // 对齐 Rust: many_different_states — "f added" 多文件新增
    let newTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    newTree.entries.add(Entry(EntryMode(0o100644), "a.txt", id))
    newTree.entries.add(Entry(EntryMode(0o100644), "b.txt", id))
    newTree.entries.add(Entry(EntryMode(0o100644), "c.txt", id))
    let diff = diffTrees(None, Some(newTree))
    if (diff.entries.size != 3) {
        throw Exception("should have 3 added entries, got " + diff.entries.size.toString())
    }
    for (i in 0..diff.entries.size) {
        if (diff.entries[i].status != DiffStatus.Added) {
            throw Exception("all entries should be Added")
        }
    }
}

@Test
func testDiffTreesMultipleDeletions(): Unit {
    // 对齐 Rust: "remove /c /d /e" 多文件删除
    let oldTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "a.txt", id))
    oldTree.entries.add(Entry(EntryMode(0o100644), "b.txt", id))
    let diff = diffTrees(Some(oldTree), None)
    if (diff.entries.size != 2) {
        throw Exception("should have 2 deleted entries")
    }
}

@Test
func testDiffTreesMixedAddDelete(): Unit {
    // 对齐 Rust: "a renamed to b" — 表现为删除+新增
    let oldTree = Tree(ArrayList<Entry>())
    let id1 = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "old.txt", id1))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100644), "new.txt", id1))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 2) {
        throw Exception("rename should produce 2 entries (delete + add), got " + diff.entries.size.toString())
    }
}

@Test
func testDiffStatusEquality(): Unit {
    // 对齐 Rust: DiffStatus Equatable
    if (DiffStatus.Added != DiffStatus.Added) {
        throw Exception("Added should equal Added")
    }
    if (DiffStatus.Modified == DiffStatus.Added) {
        throw Exception("Modified should not equal Added")
    }
    if (DiffStatus.Deleted == DiffStatus.Renamed) {
        throw Exception("Deleted should not equal Renamed")
    }
}

@Test
func testDiffTreesEmptyTreeToEmptyTree(): Unit {
    // 对齐 Rust: 空树对比扩展
    let tree1 = Tree(ArrayList<Entry>())
    let tree2 = Tree(ArrayList<Entry>())
    let diff = diffTrees(Some(tree1), Some(tree2))
    if (diff.entries.size != 0) {
        throw Exception("two empty trees should have 0 diff entries")
    }
}

@Test
func testDiffTreesUnchangedFilesNoDiff(): Unit {
    // 对齐 Rust: 相同文件不出现在 diff 中
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHex("4b825dc642cb6eb9a060e54bf8d69288fbee4904")

    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o100644), "same.txt", id))
    oldTree.entries.add(Entry(EntryMode(0o100644), "changed.txt", id))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100644), "same.txt", id))
    newTree.entries.add(Entry(EntryMode(0o100644), "changed.txt", id2))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("only changed file should appear in diff, got " + diff.entries.size.toString())
    }
    if (diff.entries[0].path != "changed.txt") {
        throw Exception("only 'changed.txt' should differ")
    }
}
