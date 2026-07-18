// 文件：lib.cj
// 用途：提供 Git 树对象差异比较功能，计算两个树之间的文件变更
// 所属包：gix.gix_diff
// 关键类型：Change, Relation, ChangeId, Action, Recorder, RecorderChange, Location
// 关键函数：diff, diffTrees, diffTreesWithRecorder, compareEntries
// 对齐来源：gix-diff/src/lib.rs, gix-diff/src/tree/mod.rs, gix-diff/src/tree/function.rs,
//           gix-diff/src/tree/visit.rs, gix-diff/src/tree/recorder.rs

package gitoxide.gix_diff

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.ArrayList
import std.collection.HashSet
import gitoxide.gix_utils.*

// 对齐 Rust: gix_diff::tree::visit::ChangeId
public type ChangeId = UInt32

// 对齐 Rust: gix_diff::tree::visit::Relation
public enum Relation {
    | Parent(ChangeId)
    | ChildOfParent(ChangeId)
}

extend Relation <: Equatable<Relation> {
    public operator func ==(other: Relation): Bool {
        match (this) {
            case Relation.Parent(id1) => match (other) {
                case Relation.Parent(id2) => id1 == id2
                case _ => false
            }
            case Relation.ChildOfParent(id1) => match (other) {
                case Relation.ChildOfParent(id2) => id1 == id2
                case _ => false
            }
        }
    }
}

// 对齐 Rust: gix_diff::tree::visit::Action
public enum Action <: Equatable<Action> {
    | Continue
    | Break

    public operator func ==(other: Action): Bool {
        match (this) {
            case Continue => match (other) {
                case Continue => true
                case _ => false
            }
            case Break => match (other) {
                case Break => true
                case _ => false
            }
        }
    }
}

// 对齐 Rust: gix_diff::tree::visit::Change
// 使用类包装多字段变体，因为仓颉枚举不支持命名字段
public enum Change {
    | Addition(ChangeAddition)
    | Deletion(ChangeDeletion)
    | Modification(ChangeModification)
}

// 对齐 Rust: Change::Addition 的数据
public class ChangeAddition {
    public var entryMode: EntryMode
    public var oid: ObjectId
    public var relation: ?Relation

    public init(entryMode: EntryMode, oid: ObjectId, relation: ?Relation) {
        this.entryMode = entryMode
        this.oid = oid
        this.relation = relation
    }
}

// 对齐 Rust: Change::Deletion 的数据
public class ChangeDeletion {
    public var entryMode: EntryMode
    public var oid: ObjectId
    public var relation: ?Relation

    public init(entryMode: EntryMode, oid: ObjectId, relation: ?Relation) {
        this.entryMode = entryMode
        this.oid = oid
        this.relation = relation
    }
}

// 对齐 Rust: Change::Modification 的数据
public class ChangeModification {
    public var previousEntryMode: EntryMode
    public var previousOid: ObjectId
    public var entryMode: EntryMode
    public var oid: ObjectId

    public init(previousEntryMode: EntryMode, previousOid: ObjectId, entryMode: EntryMode, oid: ObjectId) {
        this.previousEntryMode = previousEntryMode
        this.previousOid = previousOid
        this.entryMode = entryMode
        this.oid = oid
    }
}

// 对齐 Rust: Change::oid()
public func changeOid(c: Change): ObjectId {
    match (c) {
        case Change.Addition(a) => a.oid
        case Change.Deletion(d) => d.oid
        case Change.Modification(m) => m.oid
    }
}

// 对齐 Rust: Change::entry_mode()
public func changeEntryMode(c: Change): EntryMode {
    match (c) {
        case Change.Addition(a) => a.entryMode
        case Change.Deletion(d) => d.entryMode
        case Change.Modification(m) => m.entryMode
    }
}

// 对齐 Rust: Change::relation()
public func changeRelation(c: Change): ?Relation {
    match (c) {
        case Change.Addition(a) => a.relation
        case Change.Deletion(d) => d.relation
        case Change.Modification(_) => None
    }
}

// 对齐 Rust: gix_diff::tree::recorder::Location
public enum Location {
    | Path
    | FileName
}

extend Location <: Equatable<Location> {
    public operator func ==(other: Location): Bool {
        match (this) {
            case Location.Path => match (other) {
                case Location.Path => true
                case _ => false
            }
            case Location.FileName => match (other) {
                case Location.FileName => true
                case _ => false
            }
        }
    }
}

// 对齐 Rust: gix_diff::tree::recorder::Change
// 使用类包装多字段变体
public enum RecorderChange {
    | Addition(RecorderAddition)
    | Deletion(RecorderDeletion)
    | Modification(RecorderModification)
}

public class RecorderAddition {
    public var entryMode: EntryMode
    public var oid: ObjectId
    public var path: String
    public var relation: ?Relation

    public init(entryMode: EntryMode, oid: ObjectId, path: String, relation: ?Relation) {
        this.entryMode = entryMode
        this.oid = oid
        this.path = path
        this.relation = relation
    }
}

public class RecorderDeletion {
    public var entryMode: EntryMode
    public var oid: ObjectId
    public var path: String
    public var relation: ?Relation

    public init(entryMode: EntryMode, oid: ObjectId, path: String, relation: ?Relation) {
        this.entryMode = entryMode
        this.oid = oid
        this.path = path
        this.relation = relation
    }
}

public class RecorderModification {
    public var previousEntryMode: EntryMode
    public var previousOid: ObjectId
    public var entryMode: EntryMode
    public var oid: ObjectId
    public var path: String

    public init(previousEntryMode: EntryMode, previousOid: ObjectId, entryMode: EntryMode, oid: ObjectId, path: String) {
        this.previousEntryMode = previousEntryMode
        this.previousOid = previousOid
        this.entryMode = entryMode
        this.oid = oid
        this.path = path
    }
}

// 对齐 Rust: gix_diff::tree::State
public class DiffState {
    public var changeId: ChangeId
    public var treeQueue: ArrayList<DiffTreeInfo>

    public init() {
        this.changeId = 0
        this.treeQueue = ArrayList<DiffTreeInfo>()
    }

    public func clear(): Unit {
        changeId = 0
        treeQueue.clear()
    }
}

// 树信息元组
public class DiffTreeInfo {
    public var lhsId: ?ObjectId
    public var rhsId: ?ObjectId
    public var relation: ?Relation

    public init(lhsId: ?ObjectId, rhsId: ?ObjectId, relation: ?Relation) {
        this.lhsId = lhsId
        this.rhsId = rhsId
        this.relation = relation
    }
}

// 对齐 Rust: gix_diff::tree::Recorder
public class Recorder {
    public var records: ArrayList<RecorderChange>
    var pathDeque: ArrayList<String>
    var currentPath: String
    var location: ?Location

    public init() {
        this.records = ArrayList<RecorderChange>()
        this.pathDeque = ArrayList<String>()
        this.currentPath = ""
        this.location = Some(Location.Path)
    }

    public init(location: ?Location) {
        this.records = ArrayList<RecorderChange>()
        this.pathDeque = ArrayList<String>()
        this.currentPath = ""
        this.location = location
    }

    public func pathClone(): String {
        currentPath
    }

    func popElement(): Unit {
        let idx = currentPath.lastIndexOf('/')
        if (let Some(i) <- idx) {
            if (i > 0) {
                currentPath = currentPath[0..i]
            } else {
                currentPath = ""
            }
        } else {
            currentPath = ""
        }
    }

    func pushElement(name: String): Unit {
        if (name.size == 0) {
            return
        }
        if (currentPath.size > 0) {
            currentPath = currentPath + "/" + name
        } else {
            currentPath = name
        }
    }

    public func popFrontTrackedPathAndSetCurrent(): Unit {
        if (let Some(Location.Path) <- location) {
            if (pathDeque.size > 0) {
                currentPath = pathDeque[0]
                pathDeque.remove(at: 0)
            }
        }
    }

    public func pushBackTrackedPathComponent(component: String): Unit {
        if (let Some(loc) <- location) {
            if (loc == Location.Path) {
                pushElement(component)
                pathDeque.add(currentPath)
            } else if (loc == Location.FileName) {
                currentPath = component
            }
        }
    }

    public func pushPathComponent(component: String): Unit {
        if (let Some(loc) <- location) {
            if (loc == Location.Path) {
                pushElement(component)
            } else if (loc == Location.FileName) {
                currentPath = component
            }
        }
    }

    public func popPathComponent(): Unit {
        if (let Some(Location.Path) <- location) {
            popElement()
        }
    }

    public func visitChange(change: Change): Action {
        match (change) {
            case Change.Deletion(d) => records.add(
                RecorderChange.Deletion(RecorderDeletion(d.entryMode, d.oid, pathClone(), d.relation)))
            case Change.Addition(a) => records.add(
                RecorderChange.Addition(RecorderAddition(a.entryMode, a.oid, pathClone(), a.relation)))
            case Change.Modification(m) => records.add(
                RecorderChange.Modification(
                    RecorderModification(m.previousEntryMode, m.previousOid, m.entryMode, m.oid, pathClone())))
        }
        Action.Continue
    }
}

// 对齐 Rust: gix_diff::tree::function::compare
// Git 树条目排序比较
public func compareEntries(a: Entry, b: Entry): Ordering {
    let aName = a.filename
    let bName = b.filename
    // 对齐 Rust: 同名条目（无论类型）应返回 EQ，由 handleEqualFilenames 处理类型变更
    if (aName == bName) {
        return Ordering.EQ
    }
    let common = if (aName.size < bName.size) {
        aName.size
    } else {
        bName.size
    }
    var i: Int64 = 0
    while (i < common) {
        let ac = UInt8(aName[i])
        let bc = UInt8(bName[i])
        if (ac < bc) {
            return Ordering.LT
        }
        if (ac > bc) {
            return Ordering.GT
        }
        i += 1
    }
    let aSuffix: ?UInt8 = if (aName.size > common) {
        Some(aName[common])
    } else if (a.mode.isTree()) {
        Some(CHAR_SLASH)
    } else {
        None
    }
    let bSuffix: ?UInt8 = if (bName.size > common) {
        Some(bName[common])
    } else if (b.mode.isTree()) {
        Some(CHAR_SLASH)
    } else {
        None
    }
    if (let Some(av) <- aSuffix) {
        if (let Some(bv) <- bSuffix) {
            if (av < bv) {
                Ordering.LT
            } else if (av > bv) {
                Ordering.GT
            } else {
                Ordering.EQ
            }
        } else {
            Ordering.GT
        }
    } else {
        if (let Some(_) <- bSuffix) {
            Ordering.LT
        } else {
            Ordering.EQ
        }
    }
}

// 排序结果 — 使用仓颉 std.core.Ordering (LT/GT/EQ)
// Rust 使用 Less/Equal/Greater，映射: Less→LT, Equal→EQ, Greater→GT

// 对齐 Rust: gix_diff::tree::function::diff
// 核心树差异比较算法
public func diff(lhsEntries: ArrayList<Entry>, rhsEntries: ArrayList<Entry>, recorder: ?Recorder): TreeDiff {
    let result = TreeDiff()
    var li: Int64 = 0
    var ri: Int64 = 0

    while (li < lhsEntries.size && ri < rhsEntries.size) {
        let lhs = lhsEntries[li]
        let rhs = rhsEntries[ri]
        let cmp = compareEntries(lhs, rhs)
        match (cmp) {
            case Ordering.EQ =>
                let de = handleEqualFilenames(lhs, rhs, recorder)
                if (let Some(e) <- de) {
                    result.entries.add(e)
                }
                li += 1
                ri += 1
            case Ordering.LT =>
                let de = deleteEntry(lhs, recorder)
                result.entries.add(de)
                li += 1
            case Ordering.GT =>
                let de = addEntry(rhs, recorder)
                result.entries.add(de)
                ri += 1
        }
    }

    while (li < lhsEntries.size) {
        let de = deleteEntry(lhsEntries[li], recorder)
        result.entries.add(de)
        li += 1
    }

    while (ri < rhsEntries.size) {
        let de = addEntry(rhsEntries[ri], recorder)
        result.entries.add(de)
        ri += 1
    }

    result
}

func deleteEntry(entry: Entry, recorder: ?Recorder): DiffEntry {
    if (let Some(r) <- recorder) {
        r.pushPathComponent(entry.filename)
        r.visitChange(Change.Deletion(ChangeDeletion(entry.mode, entry.oid, None)))
        r.popPathComponent()
    }
    let de = DiffEntry(entry.filename, DiffStatus.Deleted)
    de.oldMode = Some(entry.mode)
    de.oldId = Some(entry.oid)
    de
}

func addEntry(entry: Entry, recorder: ?Recorder): DiffEntry {
    if (let Some(r) <- recorder) {
        r.pushPathComponent(entry.filename)
        r.visitChange(Change.Addition(ChangeAddition(entry.mode, entry.oid, None)))
        r.popPathComponent()
    }
    let de = DiffEntry(entry.filename, DiffStatus.Added)
    de.newMode = Some(entry.mode)
    de.newId = Some(entry.oid)
    de
}

func handleEqualFilenames(lhs: Entry, rhs: Entry, recorder: ?Recorder): ?DiffEntry {
    let lhsIsTree = lhs.mode.isTree()
    let rhsIsTree = rhs.mode.isTree()
    if (lhsIsTree && rhsIsTree) {
        if (lhs.oid.toHexString() == rhs.oid.toHexString()) {
            if (let Some(r) <- recorder) {
                r.pushPathComponent(lhs.filename)
                r.popPathComponent()
            }
            return None
        }
        if (let Some(r) <- recorder) {
            r.pushBackTrackedPathComponent(lhs.filename)
            r.visitChange(Change.Modification(ChangeModification(lhs.mode, lhs.oid, rhs.mode, rhs.oid)))
        }
        let de = DiffEntry(lhs.filename, DiffStatus.Modified)
        de.oldMode = Some(lhs.mode)
        de.oldId = Some(lhs.oid)
        de.newMode = Some(rhs.mode)
        de.newId = Some(rhs.oid)
        return Some(de)
    }
    if ((!lhsIsTree) && (!rhsIsTree)) {
        if (lhs.oid.toHexString() != rhs.oid.toHexString() || lhs.mode.value != rhs.mode.value) {
            if (let Some(r) <- recorder) {
                r.pushPathComponent(lhs.filename)
                r.visitChange(Change.Modification(ChangeModification(lhs.mode, lhs.oid, rhs.mode, rhs.oid)))
                r.popPathComponent()
            }
            let status = if (lhs.mode.value != rhs.mode.value) {
                DiffStatus.TypeChange
            } else {
                DiffStatus.Modified
            }
            let de = DiffEntry(lhs.filename, status)
            de.oldMode = Some(lhs.mode)
            de.oldId = Some(lhs.oid)
            de.newMode = Some(rhs.mode)
            de.newId = Some(rhs.oid)
            return Some(de)
        }
        if (let Some(r) <- recorder) {
            r.pushPathComponent(lhs.filename)
            r.popPathComponent()
        }
        return None
    }
    if (let Some(r) <- recorder) {
        r.pushBackTrackedPathComponent(lhs.filename)
        r.visitChange(Change.Deletion(ChangeDeletion(lhs.mode, lhs.oid, None)))
        r.visitChange(Change.Addition(ChangeAddition(rhs.mode, rhs.oid, None)))
    }
    let de = DiffEntry(lhs.filename, DiffStatus.TypeChange)
    de.oldMode = Some(lhs.mode)
    de.oldId = Some(lhs.oid)
    de.newMode = Some(rhs.mode)
    de.newId = Some(rhs.oid)
    return Some(de)
}

// 树差异比较结果
public class TreeDiff {
    public var entries: ArrayList<DiffEntry>

    public init() {
        this.entries = ArrayList<DiffEntry>()
    }
}

// 单个差异条目
public class DiffEntry {
    public var path: String
    public var oldMode: ?EntryMode
    public var newMode: ?EntryMode
    public var oldId: ?ObjectId
    public var newId: ?ObjectId
    public var status: DiffStatus

    public init(path: String, status: DiffStatus) {
        this.path = path
        this.oldMode = None
        this.newMode = None
        this.oldId = None
        this.newId = None
        this.status = status
    }
}

// 差异状态枚举
public enum DiffStatus {
    | Added
    | Modified
    | Deleted
    | Renamed
    | Copied
    | TypeChange
}

extend DiffStatus <: Equatable<DiffStatus> {
    public operator func ==(other: DiffStatus): Bool {
        match (this) {
            case DiffStatus.Added => match (other) {
                case DiffStatus.Added => true
                case _ => false
            }
            case DiffStatus.Modified => match (other) {
                case DiffStatus.Modified => true
                case _ => false
            }
            case DiffStatus.Deleted => match (other) {
                case DiffStatus.Deleted => true
                case _ => false
            }
            case DiffStatus.Renamed => match (other) {
                case DiffStatus.Renamed => true
                case _ => false
            }
            case DiffStatus.Copied => match (other) {
                case DiffStatus.Copied => true
                case _ => false
            }
            case DiffStatus.TypeChange => match (other) {
                case DiffStatus.TypeChange => true
                case _ => false
            }
        }
    }

    public operator func !=(other: DiffStatus): Bool {
        !(this == other)
    }
}

// 比较两个树对象的差异
public func diffTrees(oldTree: ?Tree, newTree: ?Tree): TreeDiff {
    let recorder: ?Recorder = None
    let oldEntries = ArrayList<Entry>()
    let newEntries = ArrayList<Entry>()

    if (let Some(t) <- oldTree) {
        for (entry in t.entries) {
            oldEntries.add(entry)
        }
    }
    if (let Some(t) <- newTree) {
        for (entry in t.entries) {
            newEntries.add(entry)
        }
    }

    diff(oldEntries, newEntries, recorder)
}

// 比较两个树对象的差异（带 Recorder 版本）
public func diffTreesWithRecorder(oldTree: ?Tree, newTree: ?Tree, recorder: Recorder): TreeDiff {
    let oldEntries = ArrayList<Entry>()
    let newEntries = ArrayList<Entry>()

    if (let Some(t) <- oldTree) {
        for (entry in t.entries) {
            oldEntries.add(entry)
        }
    }
    if (let Some(t) <- newTree) {
        for (entry in t.entries) {
            newEntries.add(entry)
        }
    }

    diff(oldEntries, newEntries, Some(recorder))
}
