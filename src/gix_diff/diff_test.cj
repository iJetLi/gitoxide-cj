// 文件：diff_test.cj
// 用途：gix_diff 包的单元测试，全量对齐 Rust gitoxide gix-diff 测试
// 所属包：gix.gix_diff
// 对齐来源：gix-diff/tests/tree_diff.rs, gix-diff/src/tree/function.rs

package gitoxide.gix_diff

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.unittest.*
import std.collection.ArrayList

// ============================================================
// DiffStatus 测试
// ============================================================

@Test
func testDiffStatusVariants(): Unit {
    let statuses: Array<DiffStatus> = [DiffStatus.Added, DiffStatus.Modified, DiffStatus.Deleted, DiffStatus.Renamed,
        DiffStatus.Copied, DiffStatus.TypeChange]
    if (statuses.size != 6) {
        throw Exception("should have 6 DiffStatus variants")
    }
}

@Test
func testDiffStatusEquality(): Unit {
    if (DiffStatus.Added != DiffStatus.Added) {
        throw Exception("Added should equal Added")
    }
    if (DiffStatus.Modified == DiffStatus.Added) {
        throw Exception("Modified should not equal Added")
    }
    if (DiffStatus.Deleted == DiffStatus.Renamed) {
        throw Exception("Deleted should not equal Renamed")
    }
    if (DiffStatus.TypeChange != DiffStatus.TypeChange) {
        throw Exception("TypeChange should equal TypeChange")
    }
    if (DiffStatus.TypeChange == DiffStatus.Modified) {
        throw Exception("TypeChange should not equal Modified")
    }
}

// ============================================================
// DiffEntry 测试
// ============================================================

@Test
func testDiffEntryCreation(): Unit {
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
    let diff = diffTrees(None, None)
    if (diff.entries.size != 0) {
        throw Exception("diff of two empty trees should have 0 entries")
    }
}

@Test
func testDiffTreesOldNoneNewSome(): Unit {
    let newTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
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
    let oldTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
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
    let tree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    tree.entries.add(Entry(EntryMode(0o100644), "file.txt", id))
    let diff = diffTrees(Some(tree), Some(tree))
    if (diff.entries.size != 0) {
        throw Exception("identical trees should have 0 diff entries")
    }
}

@Test
func testDiffTreesModified(): Unit {
    let oldTree = Tree(ArrayList<Entry>())
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id1))

    let newTree = Tree(ArrayList<Entry>())
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    newTree.entries.add(Entry(EntryMode(0o100644), "file.txt", id2))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry")
    }
    if (diff.entries[0].status != DiffStatus.Modified) {
        throw Exception("entry should be Modified")
    }
}

@Test
func testDiffTreesMultipleAdditions(): Unit {
    let newTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
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
    let oldTree = Tree(ArrayList<Entry>())
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "a.txt", id))
    oldTree.entries.add(Entry(EntryMode(0o100644), "b.txt", id))
    let diff = diffTrees(Some(oldTree), None)
    if (diff.entries.size != 2) {
        throw Exception("should have 2 deleted entries")
    }
}

@Test
func testDiffTreesMixedAddDelete(): Unit {
    let oldTree = Tree(ArrayList<Entry>())
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    oldTree.entries.add(Entry(EntryMode(0o100644), "old.txt", id1))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100644), "new.txt", id1))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 2) {
        throw Exception("rename should produce 2 entries (delete + add), got " + diff.entries.size.toString())
    }
}

@Test
func testDiffTreesEmptyTreeToEmptyTree(): Unit {
    let tree1 = Tree(ArrayList<Entry>())
    let tree2 = Tree(ArrayList<Entry>())
    let diff = diffTrees(Some(tree1), Some(tree2))
    if (diff.entries.size != 0) {
        throw Exception("two empty trees should have 0 diff entries")
    }
}

@Test
func testDiffTreesUnchangedFilesNoDiff(): Unit {
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")

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

// ============================================================
// TypeChange 测试 — 对齐 Rust gix-diff
// ============================================================

@Test
func testDiffTreesTypeChangeModeOnly(): Unit {
    // 对齐 Rust: 模式变更但 OID 不变 → TypeChange
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o100644), "script.sh", id))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100755), "script.sh", id))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry for mode change, got " + diff.entries.size.toString())
    }
    if (diff.entries[0].status != DiffStatus.TypeChange) {
        throw Exception("mode-only change should be TypeChange")
    }
}

@Test
func testDiffTreesTypeChangeTreeToFile(): Unit {
    // 对齐 Rust: 目录变为文件 → TypeChange
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o040000), "dir", id1))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100644), "dir", id2))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry for tree-to-file")
    }
    if (diff.entries[0].status != DiffStatus.TypeChange) {
        throw Exception("tree-to-file should be TypeChange")
    }
}

@Test
func testDiffTreesTypeChangeFileToTree(): Unit {
    // 对齐 Rust: 文件变为目录 → TypeChange
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o100644), "item", id1))

    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o040000), "item", id2))

    let diff = diffTrees(Some(oldTree), Some(newTree))
    if (diff.entries.size != 1) {
        throw Exception("should have 1 entry for file-to-tree")
    }
    if (diff.entries[0].status != DiffStatus.TypeChange) {
        throw Exception("file-to-tree should be TypeChange")
    }
}

// ============================================================
// compareEntries 测试 — 对齐 gix-diff/src/tree/function.rs::compare
// ============================================================

@Test
func testCompareEntriesEqualNames(): Unit {
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let a = Entry(EntryMode(0o100644), "file.txt", id)
    let b = Entry(EntryMode(0o100644), "file.txt", id)
    let cmp = compareEntries(a, b)
    if (!(cmp == Ordering.EQ)) {
        throw Exception("same filename should be Equal")
    }
}

@Test
func testCompareEntriesDifferentNames(): Unit {
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let a = Entry(EntryMode(0o100644), "aaa", id)
    let b = Entry(EntryMode(0o100644), "bbb", id)
    let cmp = compareEntries(a, b)
    if (!(cmp == Ordering.LT)) {
        throw Exception("aaa < bbb should be Less")
    }
}

@Test
func testCompareEntriesBlobVsTreeWithCommonPrefix(): Unit {
    // 对齐 Rust: compare_select_samples — "plumbing-cli.rs" (blob) < "plumbing" (tree)
    // 因为 "plumbing-cli.rs" 的公共前缀 "plumbing" 后下一个字符是 '-'，
    // 而 "plumbing" (tree) 追加 '/'，'-' < '/' 不成立，实际 '-'(45) < '/'(47) 成立
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let blob = Entry(EntryMode(0o100644), "plumbing-cli.rs", id)
    let tree = Entry(EntryMode(0o040000), "plumbing", id)
    let cmp = compareEntries(blob, tree)
    if (!(cmp == Ordering.LT)) {
        throw Exception("blob 'plumbing-cli.rs' should be Less than tree 'plumbing'")
    }
}

@Test
func testCompareEntriesTreeVsBlobWithCommonPrefix(): Unit {
    // 对齐 Rust: compare_select_samples — "plumbing-cli.rs" (tree) > "plumbing" (blob)
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let treeEntry = Entry(EntryMode(0o040000), "plumbing-cli.rs", id)
    let blob = Entry(EntryMode(0o100644), "plumbing", id)
    let cmp = compareEntries(treeEntry, blob)
    if (!(cmp == Ordering.GT)) {
        throw Exception("tree 'plumbing-cli.rs' should be Greater than blob 'plumbing'")
    }
}

@Test
func testCompareEntriesTreeVsTreeSameName(): Unit {
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let a = Entry(EntryMode(0o040000), "dir", id)
    let b = Entry(EntryMode(0o040000), "dir", id)
    let cmp = compareEntries(a, b)
    if (!(cmp == Ordering.EQ)) {
        throw Exception("same tree name should be Equal")
    }
}

// ============================================================
// Change/Relation/Action 类型测试 — 对齐 gix-diff/src/tree/visit.rs
// ============================================================

@Test
func testChangeAccessors(): Unit {
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let mode = EntryMode(0o100644)

    let addition = Change.Addition(ChangeAddition(mode, id1, None))
    if (changeOid(addition).toHexString() != id1.toHexString()) {
        throw Exception("Addition oid mismatch")
    }
    if (changeEntryMode(addition).value != mode.value) {
        throw Exception("Addition entryMode mismatch")
    }
    if (changeRelation(addition).isSome()) {
        throw Exception("Addition relation should be None")
    }

    let deletion = Change.Deletion(ChangeDeletion(mode, id2, Some(Relation.Parent(1))))
    if (changeOid(deletion).toHexString() != id2.toHexString()) {
        throw Exception("Deletion oid mismatch")
    }
    if (changeRelation(deletion).isSome()) {
        let rel = changeRelation(deletion)
        if (let Some(r) <- rel) {
            match (r) {
                case Relation.Parent(id) => if (id != 1) { throw Exception("Deletion relation id should be 1") }
                case _ => throw Exception("Deletion relation should be Parent")
            }
        }
    }

    let modification = Change.Modification(ChangeModification(mode, id1, EntryMode(0o100755), id2))
    if (changeOid(modification).toHexString() != id2.toHexString()) {
        throw Exception("Modification oid should be new oid")
    }
    if (changeRelation(modification).isSome()) {
        throw Exception("Modification relation should be None")
    }
}

@Test
func testRelationEquality(): Unit {
    if (Relation.Parent(1) != Relation.Parent(1)) {
        throw Exception("Parent(1) should equal Parent(1)")
    }
    if (Relation.Parent(1) == Relation.Parent(2)) {
        throw Exception("Parent(1) should not equal Parent(2)")
    }
    if (Relation.ChildOfParent(1) != Relation.ChildOfParent(1)) {
        throw Exception("ChildOfParent(1) should equal ChildOfParent(1)")
    }
    if (Relation.Parent(1) == Relation.ChildOfParent(1)) {
        throw Exception("Parent(1) should not equal ChildOfParent(1)")
    }
}

// ============================================================
// Recorder 测试 — 对齐 gix-diff/src/tree/recorder.rs
// ============================================================

@Test
func testRecorderCreation(): Unit {
    let recorder = Recorder()
    if (recorder.records.size != 0) {
        throw Exception("new Recorder should have 0 records")
    }
    if (recorder.pathClone() != "") {
        throw Exception("initial path should be empty")
    }
}

@Test
func testRecorderPathTracking(): Unit {
    let recorder = Recorder(Some(Location.Path))
    recorder.pushPathComponent("src")
    if (recorder.pathClone() != "src") {
        throw Exception("path should be 'src', got '" + recorder.pathClone() + "'")
    }
    recorder.pushPathComponent("main.cj")
    if (recorder.pathClone() != "src/main.cj") {
        throw Exception("path should be 'src/main.cj', got '" + recorder.pathClone() + "'")
    }
    recorder.popPathComponent()
    if (recorder.pathClone() != "src") {
        throw Exception("path should be 'src' after pop, got '" + recorder.pathClone() + "'")
    }
}

@Test
func testRecorderFileNameTracking(): Unit {
    let recorder = Recorder(Some(Location.FileName))
    recorder.pushPathComponent("src")
    if (recorder.pathClone() != "src") {
        throw Exception("FileName mode: path should be 'src'")
    }
    recorder.pushPathComponent("main.cj")
    if (recorder.pathClone() != "main.cj") {
        throw Exception("FileName mode: path should be 'main.cj'")
    }
}

@Test
func testRecorderVisitChange(): Unit {
    let recorder = Recorder(Some(Location.Path))
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")

    recorder.pushPathComponent("file.txt")
    let action = recorder.visitChange(Change.Addition(ChangeAddition(EntryMode(0o100644), id1, None)))
    if (!(action == Action.Continue)) {
        throw Exception("visitChange should return Continue")
    }
    if (recorder.records.size != 1) {
        throw Exception("should have 1 record")
    }
    recorder.popPathComponent()

    recorder.pushPathComponent("other.txt")
    recorder.visitChange(Change.Deletion(ChangeDeletion(EntryMode(0o100644), id2, None)))
    recorder.popPathComponent()

    recorder.pushPathComponent("changed.txt")
    recorder.visitChange(Change.Modification(ChangeModification(EntryMode(0o100644), id1, EntryMode(0o100755), id2)))
    recorder.popPathComponent()

    if (recorder.records.size != 3) {
        throw Exception("should have 3 records, got " + recorder.records.size.toString())
    }
}

@Test
func testRecorderPushBackTrackedPathComponent(): Unit {
    let recorder = Recorder(Some(Location.Path))
    recorder.pushBackTrackedPathComponent("dir")
    if (recorder.pathClone() != "dir") {
        throw Exception("path should be 'dir'")
    }
    if (recorder.pathDeque.size != 1) {
        throw Exception("pathDeque should have 1 entry")
    }
    recorder.pushPathComponent("file.txt")
    if (recorder.pathClone() != "dir/file.txt") {
        throw Exception("path should be 'dir/file.txt'")
    }
    recorder.popPathComponent()
    recorder.popFrontTrackedPathAndSetCurrent()
    if (recorder.pathClone() != "dir") {
        throw Exception("path should be 'dir' after pop front")
    }
}

// ============================================================
// diffTreesWithRecorder 测试 — 对齐 gix-diff/tests/tree.rs
// ============================================================

@Test
func testDiffTreesWithRecorderRecordsPaths(): Unit {
    let id1 = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let id2 = ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o100644), "a.txt", id1))
    let newTree = Tree(ArrayList<Entry>())
    newTree.entries.add(Entry(EntryMode(0o100644), "a.txt", id2))
    newTree.entries.add(Entry(EntryMode(0o100644), "b.txt", id1))

    let recorder = Recorder(Some(Location.Path))
    let diffResult = diffTreesWithRecorder(Some(oldTree), Some(newTree), recorder)
    if (recorder.records.size != 2) {
        throw Exception("should have 2 records, got " + recorder.records.size.toString())
    }

    // 检查 Modification 记录
    match (recorder.records[0]) {
        case RecorderChange.Modification(m) =>
            if (m.path != "a.txt") {
                throw Exception("modification path should be 'a.txt', got '" + m.path + "'")
            }
        case _ => throw Exception("first record should be Modification")
    }

    // 检查 Addition 记录
    match (recorder.records[1]) {
        case RecorderChange.Addition(a) =>
            if (a.path != "b.txt") {
                throw Exception("addition path should be 'b.txt', got '" + a.path + "'")
            }
        case _ => throw Exception("second record should be Addition")
    }
}

@Test
func testDiffTreesWithRecorderDeletionPath(): Unit {
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let oldTree = Tree(ArrayList<Entry>())
    oldTree.entries.add(Entry(EntryMode(0o100644), "gone.txt", id))

    let recorder = Recorder(Some(Location.Path))
    let diffResult = diffTreesWithRecorder(Some(oldTree), None, recorder)
    if (recorder.records.size != 1) {
        throw Exception("should have 1 record")
    }
    match (recorder.records[0]) {
        case RecorderChange.Deletion(d) =>
            if (d.path != "gone.txt") {
                throw Exception("deletion path should be 'gone.txt'")
            }
        case _ => throw Exception("record should be Deletion")
    }
}

// ============================================================
// DiffState 测试
// ============================================================

@Test
func testDiffStateCreation(): Unit {
    let state = DiffState()
    if (state.changeId != 0) {
        throw Exception("initial changeId should be 0")
    }
    if (state.treeQueue.size != 0) {
        throw Exception("initial treeQueue should be empty")
    }
}

@Test
func testDiffStateClear(): Unit {
    let state = DiffState()
    state.changeId = 5
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    state.treeQueue.add(DiffTreeInfo(Some(id), None, None))
    state.clear()
    if (state.changeId != 0) {
        throw Exception("changeId should be 0 after clear")
    }
    if (state.treeQueue.size != 0) {
        throw Exception("treeQueue should be empty after clear")
    }
}

// ============================================================
// Ordering 测试
// ============================================================

@Test
func testOrderingVariants(): Unit {
    let variants: Array<Ordering> = [Ordering.LT, Ordering.EQ, Ordering.GT]
    if (variants.size != 3) {
        throw Exception("should have 3 Ordering variants")
    }
}
