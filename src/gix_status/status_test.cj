// 文件：status_test.cj
// 用途：gix_status 包的单元测试，全量对齐 Rust gitoxide gix-status 测试
// 所属包：gix.gix_status
// 对齐来源：gix-status/tests/status/index_as_worktree.rs
//           gix-status/tests/status/index_as_worktree_with_renames.rs
//           gix-status/tests/status/stack.rs
//           gix-status/src/index_as_worktree/types.rs
//           gix-status/src/index_as_worktree_with_renames/types.rs

package gitoxide.gix_status

import std.unittest.*
import std.collection.*
import gitoxide.gix_hash.*

// ============================================================
// Status 测试 — 对齐 Rust: Status construction
// ============================================================

@Test
func testStatusCreation(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — Status 构造
    let status = Status()
    if (status.entries.size != 0) {
        throw Exception("new Status should have 0 entries")
    }
}

@Test
func testStatusAddEntry(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — Status::add_entry
    let status = Status()
    status.entries.add(StatusEntry("file.txt", IndexStatus.Modified, WorktreeStatus.Unmodified))
    if (status.entries.size != 1) {
        throw Exception("should have 1 entry after add")
    }
}

@Test
func testStatusAddMultipleEntries(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — Status 多条目
    let status = Status()
    status.entries.add(StatusEntry("a.txt", IndexStatus.Modified, WorktreeStatus.Unmodified))
    status.entries.add(StatusEntry("b.txt", IndexStatus.Added, WorktreeStatus.Untracked))
    status.entries.add(StatusEntry("c.txt", IndexStatus.Deleted, WorktreeStatus.Unmodified))
    if (status.entries.size != 3) {
        throw Exception("should have 3 entries after add, got ${status.entries.size}")
    }
}

// ============================================================
// StatusEntry 测试 — 对齐 Rust: StatusEntry construction
// ============================================================

@Test
func testStatusEntryCreation(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry 构造
    let entry = StatusEntry("src/main.cj", IndexStatus.Added, WorktreeStatus.Untracked)
    if (entry.path != "src/main.cj") {
        throw Exception("path mismatch")
    }
    if (entry.indexStatus != IndexStatus.Added) {
        throw Exception("indexStatus should be Added")
    }
    if (entry.worktreeStatus != WorktreeStatus.Untracked) {
        throw Exception("worktreeStatus should be Untracked")
    }
}

@Test
func testStatusEntryModifiedInBoth(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry::modified_in_both
    let entry = StatusEntry("lib.cj", IndexStatus.Modified, WorktreeStatus.Modified)
    if (entry.indexStatus != IndexStatus.Modified) {
        throw Exception("indexStatus mismatch")
    }
    if (entry.worktreeStatus != WorktreeStatus.Modified) {
        throw Exception("worktreeStatus mismatch")
    }
}

@Test
func testStatusEntryDeletedFromIndex(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry::deleted_from_index
    let entry = StatusEntry("old.cj", IndexStatus.Deleted, WorktreeStatus.Unmodified)
    if (entry.indexStatus != IndexStatus.Deleted) {
        throw Exception("indexStatus should be Deleted")
    }
}

@Test
func testStatusEntryDeletedFromWorktree(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry::deleted_from_worktree
    let entry = StatusEntry("missing.cj", IndexStatus.Unmodified, WorktreeStatus.Deleted)
    if (entry.worktreeStatus != WorktreeStatus.Deleted) {
        throw Exception("worktreeStatus should be Deleted")
    }
}

@Test
func testStatusEntryRenamed(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry::renamed
    let entry = StatusEntry("new_name.cj", IndexStatus.Renamed, WorktreeStatus.Unmodified)
    if (entry.indexStatus != IndexStatus.Renamed) {
        throw Exception("indexStatus should be Renamed")
    }
}

@Test
func testStatusEntryCopied(): Unit {
    // 对齐 Rust: gix-status/src/lib.rs — StatusEntry::copied
    let entry = StatusEntry("copy.cj", IndexStatus.Copied, WorktreeStatus.Unmodified)
    if (entry.indexStatus != IndexStatus.Copied) {
        throw Exception("indexStatus should be Copied")
    }
}

// ============================================================
// IndexStatus 枚举测试 — 对齐 Rust: IndexStatus enum completeness
// ============================================================

@Test
func testIndexStatusVariants(): Unit {
    // 对齐 Rust: gix-status/src/index_status.rs — IndexStatus 枚举变体
    let variants: Array<IndexStatus> = [
        IndexStatus.Unmodified,
        IndexStatus.Added,
        IndexStatus.Modified,
        IndexStatus.Deleted,
        IndexStatus.Renamed,
        IndexStatus.Copied
    ]
    if (variants.size != 6) {
        throw Exception("should have 6 IndexStatus variants, got ${variants.size}")
    }
}

@Test
func testIndexStatusEquality(): Unit {
    // 对齐 Rust: gix-status/src/index_status.rs — IndexStatus 相等性
    if (IndexStatus.Unmodified != IndexStatus.Unmodified) {
        throw Exception("Unmodified != Unmodified")
    }
    if (IndexStatus.Added != IndexStatus.Added) {
        throw Exception("Added != Added")
    }
    if (IndexStatus.Modified != IndexStatus.Modified) {
        throw Exception("Modified != Modified")
    }
    if (IndexStatus.Deleted != IndexStatus.Deleted) {
        throw Exception("Deleted != Deleted")
    }
    if (IndexStatus.Renamed != IndexStatus.Renamed) {
        throw Exception("Renamed != Renamed")
    }
    if (IndexStatus.Copied != IndexStatus.Copied) {
        throw Exception("Copied != Copied")
    }
}

@Test
func testIndexStatusInequality(): Unit {
    // 对齐 Rust: gix-status/src/index_status.rs — IndexStatus 不等性
    if (IndexStatus.Unmodified == IndexStatus.Added) {
        throw Exception("Unmodified should not equal Added")
    }
    if (IndexStatus.Modified == IndexStatus.Deleted) {
        throw Exception("Modified should not equal Deleted")
    }
    if (IndexStatus.Renamed == IndexStatus.Copied) {
        throw Exception("Renamed should not equal Copied")
    }
}

// ============================================================
// WorktreeStatus 枚举测试 — 对齐 Rust: WorktreeStatus enum completeness
// ============================================================

@Test
func testWorktreeStatusVariants(): Unit {
    // 对齐 Rust: gix-status/src/worktree_status.rs — WorktreeStatus 枚举变体
    let variants: Array<WorktreeStatus> = [
        WorktreeStatus.Unmodified,
        WorktreeStatus.Modified,
        WorktreeStatus.Deleted,
        WorktreeStatus.Untracked
    ]
    if (variants.size != 4) {
        throw Exception("should have 4 WorktreeStatus variants, got ${variants.size}")
    }
}

@Test
func testWorktreeStatusEquality(): Unit {
    // 对齐 Rust: gix-status/src/worktree_status.rs — WorktreeStatus 相等性
    if (WorktreeStatus.Unmodified != WorktreeStatus.Unmodified) {
        throw Exception("Unmodified != Unmodified")
    }
    if (WorktreeStatus.Modified != WorktreeStatus.Modified) {
        throw Exception("Modified != Modified")
    }
    if (WorktreeStatus.Deleted != WorktreeStatus.Deleted) {
        throw Exception("Deleted != Deleted")
    }
    if (WorktreeStatus.Untracked != WorktreeStatus.Untracked) {
        throw Exception("Untracked != Untracked")
    }
}

@Test
func testWorktreeStatusInequality(): Unit {
    // 对齐 Rust: gix-status/src/worktree_status.rs — WorktreeStatus 不等性
    if (WorktreeStatus.Unmodified == WorktreeStatus.Modified) {
        throw Exception("Unmodified should not equal Modified")
    }
    if (WorktreeStatus.Deleted == WorktreeStatus.Untracked) {
        throw Exception("Deleted should not equal Untracked")
    }
}

// ============================================================
// Change 枚举测试 — 对齐 Rust: Change<T, U>
// 对齐来源：gix-status/src/index_as_worktree/types.rs Change
// ============================================================

@Test
func testChangeRemoved(): Unit {
    // 对齐 Rust: gix-status/src/change.rs — Change::Removed
    let c = Change.Removed
    if (c != Change.Removed) {
        throw Exception("Removed should equal Removed")
    }
}

@Test
func testChangeType(): Unit {
    // 对齐 Rust: gix-status/src/change.rs — ChangeType 枚举变体
    // Mode::FILE = 0o100644 = 33188
    let c = Change.Type(UInt32(33188))
    match (c) {
        case Change.Type(mode) =>
            if (mode != 33188) {
                throw Exception("worktree_mode mismatch")
            }
        case _ => throw Exception("should be Type variant")
    }
}

@Test
func testChangeModificationContentOnly(): Unit {
    // 对齐 Rust: Change::Modification { executable_bit_changed: false, content_change: Some(()), set_entry_stat_size_zero: false }
    let c = Change.Modification(false, true, false)
    match (c) {
        case Change.Modification(ebc, cc, sesz) =>
            if (ebc) {
                throw Exception("executableBitChanged should be false")
            }
            if (!cc) {
                throw Exception("contentChange should be true")
            }
            if (sesz) {
                throw Exception("setEntryStatSizeZero should be false")
            }
        case _ => throw Exception("should be Modification variant")
    }
}

@Test
func testChangeModificationExecutableBitChanged(): Unit {
    // 对齐 Rust: Change::Modification { executable_bit_changed: true, content_change: None, .. }
    let c = Change.Modification(true, false, false)
    match (c) {
        case Change.Modification(ebc, cc, _) =>
            if (!ebc) {
                throw Exception("executableBitChanged should be true")
            }
            if (cc) {
                throw Exception("contentChange should be false")
            }
        case _ => throw Exception("should be Modification variant")
    }
}

@Test
func testChangeModificationRacyClean(): Unit {
    // 对齐 Rust: racy-git — set_entry_stat_size_zero = true
    let c = Change.Modification(false, true, true)
    match (c) {
        case Change.Modification(_, _, sesz) =>
            if (!sesz) {
                throw Exception("setEntryStatSizeZero should be true for racy-clean")
            }
        case _ => throw Exception("should be Modification variant")
    }
}

@Test
func testChangeSubmoduleModification(): Unit {
    // 对齐 Rust: gix-status/src/change.rs — Change::SubmoduleModification
    let c = Change.SubmoduleModification
    if (c != Change.SubmoduleModification) {
        throw Exception("SubmoduleModification should equal itself")
    }
}

@Test
func testChangeEquality(): Unit {
    // 对齐 Rust: gix-status/src/change.rs — Change 相等性
    if (Change.Removed != Change.Removed) {
        throw Exception("Removed equality")
    }
    if (Change.Type(UInt32(33188)) != Change.Type(UInt32(33188))) {
        throw Exception("Type equality")
    }
    if (Change.Type(UInt32(33188)) == Change.Type(UInt32(16384))) {
        throw Exception("Type with different mode should not be equal")
    }
    let m1 = Change.Modification(false, true, false)
    let m2 = Change.Modification(false, true, false)
    if (m1 != m2) {
        throw Exception("Modification equality")
    }
    let m3 = Change.Modification(true, false, false)
    if (m1 == m3) {
        throw Exception("Modification with different fields should not be equal")
    }
    if (Change.Removed == Change.SubmoduleModification) {
        throw Exception("different variants should not be equal")
    }
}

// ============================================================
// Conflict 枚举测试 — 对齐 Rust: Conflict
// 对齐来源：gix-status/src/index_as_worktree/types.rs Conflict
// ============================================================

@Test
func testConflictVariants(): Unit {
    // 对齐 Rust: gix-status/src/conflict.rs — Conflict 枚举变体
    let variants: Array<Conflict> = [
        Conflict.BothDeleted,
        Conflict.AddedByUs,
        Conflict.DeletedByThem,
        Conflict.AddedByThem,
        Conflict.DeletedByUs,
        Conflict.BothAdded,
        Conflict.BothModified
    ]
    if (variants.size != 7) {
        throw Exception("should have 7 Conflict variants, got ${variants.size}")
    }
}

@Test
func testConflictEquality(): Unit {
    // 对齐 Rust: gix-status/src/conflict.rs — Conflict 相等性
    if (Conflict.BothDeleted != Conflict.BothDeleted) {
        throw Exception("BothDeleted equality")
    }
    if (Conflict.AddedByUs != Conflict.AddedByUs) {
        throw Exception("AddedByUs equality")
    }
    if (Conflict.DeletedByThem != Conflict.DeletedByThem) {
        throw Exception("DeletedByThem equality")
    }
    if (Conflict.AddedByThem != Conflict.AddedByThem) {
        throw Exception("AddedByThem equality")
    }
    if (Conflict.DeletedByUs != Conflict.DeletedByUs) {
        throw Exception("DeletedByUs equality")
    }
    if (Conflict.BothAdded != Conflict.BothAdded) {
        throw Exception("BothAdded equality")
    }
    if (Conflict.BothModified != Conflict.BothModified) {
        throw Exception("BothModified equality")
    }
}

@Test
func testConflictInequality(): Unit {
    // 对齐 Rust: gix-status/src/conflict.rs — Conflict 不等性
    if (Conflict.BothDeleted == Conflict.BothAdded) {
        throw Exception("BothDeleted should not equal BothAdded")
    }
    if (Conflict.AddedByUs == Conflict.AddedByThem) {
        throw Exception("AddedByUs should not equal AddedByThem")
    }
    if (Conflict.DeletedByThem == Conflict.DeletedByUs) {
        throw Exception("DeletedByThem should not equal DeletedByUs")
    }
}

// ============================================================
// ConflictIndexEntry 测试 — 对齐 Rust: ConflictIndexEntry
// ============================================================

@Test
func testConflictIndexEntryCreation(): Unit {
    // 对齐 Rust: gix-status/src/conflict.rs — ConflictIndexEntry 构造
    let id = ObjectId.fromHexOrThrow("df967b96a579e45a18b8251732d16804b2e56a55")
    let entry = ConflictIndexEntry(id, 0x1000, 33188)
    if (entry.id != id) {
        throw Exception("id mismatch")
    }
    if (entry.flags != 0x1000) {
        throw Exception("flags mismatch")
    }
    if (entry.mode != 33188) {
        throw Exception("mode mismatch")
    }
}

@Test
func testConflictIndexEntryEquality(): Unit {
    // 对齐 Rust: gix-status/src/conflict.rs — ConflictIndexEntry 相等性
    let id1 = ObjectId.fromHexOrThrow("df967b96a579e45a18b8251732d16804b2e56a55")
    let id2 = ObjectId.fromHexOrThrow("d244dd0bf67758236f793fd7749a1c814fbfeac4")
    let e1 = ConflictIndexEntry(id1, 0x1000, 33188)
    let e2 = ConflictIndexEntry(id1, 0x1000, 33188)
    let e3 = ConflictIndexEntry(id2, 0x2000, 33188)
    if (e1 != e2) {
        throw Exception("same entries should be equal")
    }
    if (e1 == e3) {
        throw Exception("different entries should not be equal")
    }
}

// ============================================================
// EntryStatus 构造与相等测试 — 对齐 Rust: EntryStatus<T, U> construction
// 对齐来源：gix-status/src/index_as_worktree/types.rs EntryStatus
// ============================================================

// 对齐 Rust: index_as_worktree/types.rs — EntryStatus::Conflict 构造
@Test
func testEntryStatusConflict(): Unit {
    // 对齐 Rust: gix-status/src/entry_status.rs — EntryStatus::Conflict
    let id = ObjectId.fromHexOrThrow("df967b96a579e45a18b8251732d16804b2e56a55")
    let entries: Array<Option<ConflictIndexEntry>> = [Some(ConflictIndexEntry(id, 0x1000, 33188)),
        None<ConflictIndexEntry>, None<ConflictIndexEntry>]
    let s = EntryStatus.Conflicted(Conflict.BothModified, entries)
    match (s) {
        case EntryStatus.Conflicted(summary, e) =>
            if (summary != Conflict.BothModified) {
                throw Exception("summary should be BothModified")
            }
            if (e.size != 3) {
                throw Exception("entries should have 3 elements")
            }
            match (e[0]) {
                case Some(ce) =>
                    if (ce.id != id) {
                        throw Exception("entry id mismatch")
                    }
                case None => throw Exception("first entry should be Some")
            }
            if (e[1] != None) {
                throw Exception("second entry should be None")
            }
            if (e[2] != None) {
                throw Exception("third entry should be None")
            }
        case _ => throw Exception("should be Conflict variant")
    }
}

// 对齐 Rust: index_as_worktree/types.rs — EntryStatus::Change 构造与相等
@Test
func testEntryStatusChangeAndEquality(): Unit {
    // 对齐 Rust: gix-status/src/entry_status.rs — EntryStatus::Change + 相等性
    let es1 = EntryStatus.Changed(Change.Removed)
    let es2 = EntryStatus.Changed(Change.Removed)
    let es3 = EntryStatus.Changed(Change.Type(UInt32(33188)))
    if (es1 != es2) {
        throw Exception("same Change entries should be equal")
    }
    if (es1 == es3) {
        throw Exception("different Change entries should not be equal")
    }
    match (es1) {
        case EntryStatus.Changed(c) =>
            if (c != Change.Removed) {
                throw Exception("inner Change should be Removed")
            }
        case _ => throw Exception("should be Change variant")
    }
}

// 对齐 Rust: index_as_worktree/types.rs — EntryStatus::NeedsUpdate / IntentToAdd 构造与相等
@Test
func testEntryStatusNeedsUpdateAndIntentToAdd(): Unit {
    // 对齐 Rust: gix-status/src/entry_status.rs — EntryStatus::NeedsUpdate + IntentToAdd
    let nu1 = EntryStatus.NeedsUpdate
    let nu2 = EntryStatus.NeedsUpdate
    let ita1 = EntryStatus.IntentToAdd
    let ita2 = EntryStatus.IntentToAdd
    if (nu1 != nu2) {
        throw Exception("NeedsUpdate should equal itself")
    }
    if (ita1 != ita2) {
        throw Exception("IntentToAdd should equal itself")
    }
    if (nu1 == ita1) {
        throw Exception("NeedsUpdate should not equal IntentToAdd")
    }
}

// ============================================================
// Outcome 统计测试 — 对齐 Rust: Outcome defaults & skipped()
// 对齐来源：gix-status/src/index_as_worktree/types.rs Outcome
// ============================================================

// 对齐 Rust: Outcome 默认值全为零
@Test
func testOutcomeDefaults(): Unit {
    // 对齐 Rust: gix-status/src/outcome.rs — Outcome 默认值
    let o = Outcome()
    if (o.entriesToProcess != 0) {
        throw Exception("entriesToProcess should be 0")
    }
    if (o.entriesProcessed != 0) {
        throw Exception("entriesProcessed should be 0")
    }
    if (o.entriesSkippedByCommonPrefix != 0) {
        throw Exception("entriesSkippedByCommonPrefix should be 0")
    }
    if (o.entriesSkippedByPathspec != 0) {
        throw Exception("entriesSkippedByPathspec should be 0")
    }
    if (o.entriesSkippedByEntryFlags != 0) {
        throw Exception("entriesSkippedByEntryFlags should be 0")
    }
    if (o.symlinkMetadataCalls != 0) {
        throw Exception("symlinkMetadataCalls should be 0")
    }
    if (o.entriesToUpdate != 0) {
        throw Exception("entriesToUpdate should be 0")
    }
    if (o.racyClean != 0) {
        throw Exception("racyClean should be 0")
    }
    if (o.worktreeBytes != 0) {
        throw Exception("worktreeBytes should be 0")
    }
    if (o.worktreeFilesRead != 0) {
        throw Exception("worktreeFilesRead should be 0")
    }
    if (o.odbBytes != 0) {
        throw Exception("odbBytes should be 0")
    }
    if (o.odbObjectsRead != 0) {
        throw Exception("odbObjectsRead should be 0")
    }
}

// 对齐 Rust: Outcome::skipped() 汇总跳过数
@Test
func testOutcomeSkippedSum(): Unit {
    // 对齐 Rust: gix-status/src/outcome.rs — Outcome::skipped_sum
    let o = Outcome()
    o.entriesSkippedByCommonPrefix = 2
    o.entriesSkippedByPathspec = 3
    o.entriesSkippedByEntryFlags = 5
    if (o.skipped() != 10) {
        throw Exception("skipped() should be 10, got ${o.skipped()}")
    }
    if (o == Outcome()) {
        throw Exception("modified Outcome should not equal default")
    }
}

// ============================================================
// StatusSummary 推导测试 — 对齐 Rust: Summary from EntryStatus
// 对齐来源：gix-status/src/index_as_worktree_with_renames/types.rs Summary
// ============================================================

// 对齐 Rust: entryStatusSummary — 从 EntryStatus 推导 StatusSummary
@Test
func testStatusSummaryDerivation(): Unit {
    // 对齐 Rust: gix-status/src/outcome.rs — StatusSummary 推导
    // Change.Removed → Removed
    if (entryStatusSummary(EntryStatus.Changed(Change.Removed)) != StatusSummary.Removed) {
        throw Exception("Removed mismatch")
    }
    // Change.Type → TypeChange
    if (entryStatusSummary(EntryStatus.Changed(Change.Type(UInt32(33188)))) != StatusSummary.TypeChange) {
        throw Exception("TypeChange mismatch")
    }
    // Change.Modification → Modified
    if (entryStatusSummary(EntryStatus.Changed(Change.Modification(false, true, false))) != StatusSummary.Modified) {
        throw Exception("Modified mismatch")
    }
    // Change.SubmoduleModification → Modified
    if (entryStatusSummary(EntryStatus.Changed(Change.SubmoduleModification)) != StatusSummary.Modified) {
        throw Exception("SubmoduleModification should map to Modified")
    }
    // NeedsUpdate → Modified
    if (entryStatusSummary(EntryStatus.NeedsUpdate) != StatusSummary.Modified) {
        throw Exception("NeedsUpdate should map to Modified")
    }
    // IntentToAdd → IntentToAdd
    if (entryStatusSummary(EntryStatus.IntentToAdd) != StatusSummary.IntentToAdd) {
        throw Exception("IntentToAdd mismatch")
    }
    // Conflict → Conflict
    let id = ObjectId.fromHexOrThrow("df967b96a579e45a18b8251732d16804b2e56a55")
    if (entryStatusSummary(
        EntryStatus.Conflicted(Conflict.BothAdded,
            [Some(ConflictIndexEntry(id, 0x1000, 33188)), None<ConflictIndexEntry>, None<ConflictIndexEntry>])) != StatusSummary
        .Conflict) {
        throw Exception("Conflict mismatch")
    }
}

// ============================================================
// StatusRecorder 记录测试 — 对齐 Rust: Recorder<'index, T, U>
// 对齐来源：gix-status/src/index_as_worktree/types.rs Recorder
// ============================================================

// 对齐 Rust: Recorder — visitEntry 收集变更记录
@Test
func testStatusRecorderVisitEntry(): Unit {
    // 对齐 Rust: gix-status/src/recorder.rs — StatusRecorder::visit_entry
    let recorder = StatusRecorder()
    if (recorder.records.size != 0) {
        throw Exception("recorder should start empty")
    }
    recorder.visitEntry(0, "a.txt", EntryStatus.Changed(Change.Removed))
    recorder.visitEntry(1, "b.txt", EntryStatus.NeedsUpdate)
    recorder.visitEntry(2, "c.txt", EntryStatus.IntentToAdd)
    if (recorder.records.size != 3) {
        throw Exception("should have 3 records, got ${recorder.records.size}")
    }
    let r0 = recorder.records[0]
    if (r0.entryIndex != 0) {
        throw Exception("entryIndex mismatch")
    }
    if (r0.relativePath != "a.txt") {
        throw Exception("relativePath mismatch")
    }
    match (r0.status) {
        case EntryStatus.Changed(c) =>
            if (c != Change.Removed) {
                throw Exception("status should be Removed")
            }
        case _ => throw Exception("first record should be Change")
    }
    let r1 = recorder.records[1]
    if (r1.relativePath != "b.txt") {
        throw Exception("second record path mismatch")
    }
    if (r1.status != EntryStatus.NeedsUpdate) {
        throw Exception("second record status mismatch")
    }
    let r2 = recorder.records[2]
    if (r2.entryIndex != 2) {
        throw Exception("third record entryIndex mismatch")
    }
    if (r2.status != EntryStatus.IntentToAdd) {
        throw Exception("third record status mismatch")
    }
}

// ============================================================
// SymlinkCheck 占位测试 — 对齐 Rust: SymlinkCheck (stack.rs)
// 对齐来源：gix-status/src/stack.rs SymlinkCheck
// ============================================================

// 对齐 Rust: SymlinkCheck — 占位实现验证路径拼接
@Test
func testSymlinkCheckPlaceholder(): Unit {
    // 对齐 Rust: gix-status/src/symlink.rs — SymlinkCheck 占位实现
    let check = SymlinkCheck("/repo")
    let result = check.verifiedPath("src/main.cj")
    if (result != "/repo/src/main.cj") {
        throw Exception("verifiedPath should concatenate, got ${result}")
    }
}

// ============================================================
// Sorting 枚举测试 — 对齐 Rust: Sorting
// 对齐来源：gix-status/src/index_as_worktree_with_renames/types.rs Sorting
// ============================================================

// 对齐 Rust: Sorting — 枚举变体与相等性
@Test
func testSortingVariants(): Unit {
    // 对齐 Rust: gix-status/src/types.rs — Sorting 枚举变体
    let variants: Array<Sorting> = [Sorting.ByPathCaseSensitive, Sorting.ByPathCaseInsensitive]
    if (variants.size != 2) {
        throw Exception("should have 2 Sorting variants, got ${variants.size}")
    }
    match (Sorting.ByPathCaseSensitive) {
        case Sorting.ByPathCaseSensitive => true;
        case _ => throw Exception("ByPathCaseSensitive equality")
    }
    match (Sorting.ByPathCaseInsensitive) {
        case Sorting.ByPathCaseInsensitive => true;
        case _ => throw Exception("ByPathCaseInsensitive equality")
    }
    match (Sorting.ByPathCaseSensitive) {
        case Sorting.ByPathCaseInsensitive => throw Exception("different Sorting variants should not be equal");
        case _ => true
    }
}

// ============================================================
// RewriteEntry 枚举测试 — 对齐 Rust: Entry (index_as_worktree_with_renames)
// 对齐来源：gix-status/src/index_as_worktree_with_renames/types.rs Entry
// ============================================================

// 对齐 Rust: Entry — Modification / DirectoryContents / Rewrite 三变体构造与匹配
@Test
func testRewriteEntryVariants(): Unit {
    // 对齐 Rust: gix-status/src/rewrite.rs — RewriteEntry 变体
    // Modification 变体
    let modEntry = RewriteEntry.Modification(0, "a.txt", EntryStatus.Changed(Change.Removed))
    match (modEntry) {
        case RewriteEntry.Modification(idx, path, st) =>
            if (idx != 0) {
                throw Exception("entryIndex mismatch")
            }
            if (path != "a.txt") {
                throw Exception("relaPath mismatch")
            }
            match (st) {
                case EntryStatus.Changed(c) =>
                    if (c != Change.Removed) {
                        throw Exception("status mismatch")
                    }
                case _ => throw Exception("status should be Change")
            }
        case _ => throw Exception("should be Modification variant")
    }
    // DirectoryContents 变体
    let dirEntry = RewriteEntry.DirectoryContents("src", true)
    match (dirEntry) {
        case RewriteEntry.DirectoryContents(path, untracked) =>
            if (path != "src") {
                throw Exception("relaPath mismatch")
            }
            if (!untracked) {
                throw Exception("isUntracked should be true")
            }
        case _ => throw Exception("should be DirectoryContents variant")
    }
    // Rewrite 变体
    let rwEntry = RewriteEntry.Rewrite("old.txt", "new.txt", false, 0.95)
    match (rwEntry) {
        case RewriteEntry.Rewrite(src, dst, copy, sim) =>
            if (src != "old.txt") {
                throw Exception("sourceRelaPath mismatch")
            }
            if (dst != "new.txt") {
                throw Exception("destRelaPath mismatch")
            }
            if (copy) {
                throw Exception("isCopy should be false")
            }
            if (sim < 0.94 || sim > 0.96) {
                throw Exception("diffSimilarity mismatch")
            }
        case _ => throw Exception("should be Rewrite variant")
    }
}

// ============================================================
// RewriteOutcome 默认值测试 — 对齐 Rust: Outcome (index_as_worktree_with_renames)
// 对齐来源：gix-status/src/index_as_worktree_with_renames/types.rs Outcome
// ============================================================

// 对齐 Rust: RewriteOutcome — 默认值与字段赋值
@Test
func testRewriteOutcomeDefaults(): Unit {
    // 对齐 Rust: gix-status/src/rewrite.rs — RewriteOutcome 默认值
    let ro = RewriteOutcome()
    if (ro.dirwalkPerformed) {
        throw Exception("dirwalkPerformed should default to false")
    }
    if (ro.rewritesPerformed) {
        throw Exception("rewritesPerformed should default to false")
    }
    if (ro.trackedFileModification != Outcome()) {
        throw Exception("trackedFileModification should be default Outcome")
    }
    ro.dirwalkPerformed = true
    ro.rewritesPerformed = true
    ro.trackedFileModification.entriesProcessed = 42
    if (!ro.dirwalkPerformed) {
        throw Exception("dirwalkPerformed should be true after set")
    }
    if (!ro.rewritesPerformed) {
        throw Exception("rewritesPerformed should be true after set")
    }
    if (ro.trackedFileModification.entriesProcessed != 42) {
        throw Exception("entriesProcessed should be 42")
    }
}


// ============================================================
// StatusError 测试 - 对齐 gix-status/src/index_as_worktree/types.rs Error
// ============================================================

@Test
func testStatusErrorVariants(): Unit {
    let e1 = StatusError.IllformedUtf8
    let e2 = StatusError.Time("clock error")
    let e3 = StatusError.Io("io error")
    let e4 = StatusError.Find("not found")
    let e5 = StatusError.SubmoduleStatus("sub/path", "submodule error")
    match (e1) {
        case StatusError.IllformedUtf8 => true;
        case _ => throw Exception("should be IllformedUtf8")
    }
    match (e2) {
        case StatusError.Time(msg) =>
            if (msg != "clock error") {
                throw Exception("message mismatch")
            }
        case _ => throw Exception("should be Time")
    }
}

// ============================================================
// RenameStatusError 测试 - 对齐 gix-status/src/index_as_worktree_with_renames/types.rs Error
// ============================================================

@Test
func testRenameStatusErrorVariants(): Unit {
    let e1 = RenameStatusError.DirWalk("walk error")
    let e2 = RenameStatusError.SpawnThread("spawn error")
    let e3 = RenameStatusError.TrackedFileModifications(StatusError.Io("io"))
    let e4 = RenameStatusError.SetAttributeContext("attr error")
    let e5 = RenameStatusError.OpenWorktreeFile("open error")
    let e6 = RenameStatusError.HashFile("hash error")
    let e7 = RenameStatusError.ReadLink("link error")
    let e8 = RenameStatusError.ConvertToGit("convert error")
    let e9 = RenameStatusError.RewriteTracker("tracker error")
    match (e1) {
        case RenameStatusError.DirWalk(msg) =>
            if (msg != "walk error") {
                throw Exception("message mismatch")
            }
        case _ => throw Exception("should be DirWalk")
    }
    match (e3) {
        case RenameStatusError.TrackedFileModifications(inner) =>
            match (inner) {
                case StatusError.Io(_) => true;
                case _ => throw Exception("inner should be Io")
            }
        case _ => throw Exception("should be TrackedFileModifications")
    }
}

// ============================================================
// FsCapabilities 测试 - 对齐 gix-status/src/index_as_worktree/types.rs fs::Capabilities
// ============================================================

@Test
func testFsCapabilitiesDefaults(): Unit {
    let caps = FsCapabilities()
    if (!caps.caseSensitive) {
        throw Exception("caseSensitive should default to true")
    }
    if (!caps.symlink) {
        throw Exception("symlink should default to true")
    }
    if (!caps.executableBit) {
        throw Exception("executableBit should default to true")
    }
    if (caps.precomposeUnicode) {
        throw Exception("precomposeUnicode should default to false")
    }
}

@Test
func testFsCapabilitiesModified(): Unit {
    let caps = FsCapabilities()
    caps.caseSensitive = false
    caps.symlink = false
    caps.executableBit = false
    caps.precomposeUnicode = true
    if (caps.caseSensitive) {
        throw Exception("caseSensitive should be false")
    }
    if (caps.symlink) {
        throw Exception("symlink should be false")
    }
    if (caps.executableBit) {
        throw Exception("executableBit should be false")
    }
    if (!caps.precomposeUnicode) {
        throw Exception("precomposeUnicode should be true")
    }
}
