// 文件：lib.cj
// 用途：提供提交和树的遍历功能，支持 BFS/DFS/拓扑排序遍历提交图和树
// 所属包：gix.gix_traverse
// 关键类型：CommitIter, Simple, Topo, TreeBreadthfirst, TreeDepthfirst, Recorder, FindObject, Visit
// 对齐来源：gix-traverse/src/lib.rs, gix-traverse/src/commit/, gix-traverse/src/tree/

package gitoxide.gix_traverse

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*

// 对齐 Rust: gix_traverse::commit::Parents
public enum Parents {
    | All
    | First

    public operator func ==(that: Parents): Bool {
        match (this) {
            case All => match (that) {
                case All => true
                case _ => false
            }
            case First => match (that) {
                case First => true
                case _ => false
            }
        }
    }

    public operator func !=(that: Parents): Bool {
        !(this == that)
    }
}

// 对齐 Rust: gix_traverse::commit::simple::Sorting
public enum Sorting {
    | BreadthFirst
    | NewestFirst
    | OldestFirst
}

// 对齐 Rust: gix_traverse::commit::simple::CommitTimeOrder
public enum CommitTimeOrder {
    | NewestFirst
    | OldestFirst
}

// 对齐 Rust: gix_traverse::FindObject
public interface FindObject {
    func findObject(id: ObjectId): ?Data
}

// 对齐 Rust: gix_traverse::tree::Visit
public interface Visit {
    func popBackTrackedPathAndSetCurrent(): Unit
    func pushBackTrackedPathComponent(component: String): Unit
    func pushPathComponent(component: String): Unit
    func popPathComponent(): Unit
    func visitTree(entry: EntryRef): Action
    func visitNontree(entry: EntryRef): Action
}

// 对齐 Rust: gix_traverse::tree::visit::Action
public enum Action {
    | Continue
    | Skip
    | Cancel
}

// ============================================================
// CommitIter — 保留旧版 DFS 遍历器（向后兼容）
// ============================================================

public class CommitIter {
    public var stack: ArrayList<ObjectId>
    public var visited: HashSet<String>
    public var finder: FindObject

    public init(start: ObjectId, finder: FindObject) {
        this.stack = ArrayList<ObjectId>()
        this.stack.add(start)
        this.visited = HashSet<String>()
        this.finder = finder
    }

    public func next(): ?Commit {
        while (stack.size > 0) {
            let id = stack[stack.size - 1]
            stack.remove(stack.size - 1..stack.size)
            let hex = id.toHexString()
            if (visited.contains(hex)) {
                continue
            }
            visited.add(hex)
            let dataOpt = finder.findObject(id)
            if (let Some(d) <- dataOpt) {
                let obj = d.decode()
                if (let Some(ObjectRef.Commit(c)) <- obj) {
                    for (parent in c.parents) {
                        stack.add(ObjectId.fromHexOrThrow(parent))
                    }
                    let owned = c.intoOwned()
                    if (let Some(commit) <- owned) {
                        return Some(commit)
                    }
                }
            }
        }
        None
    }
}

// ============================================================
// Simple — 对齐 Rust: gix_traverse::commit::Simple
// ============================================================

public class Simple {
    public var queue: ArrayList<ObjectId>
    public var visited: HashSet<String>
    public var finder: FindObject
    public var sorting: Sorting
    public var parents: Parents

    public init(finder: FindObject, sorting: Sorting, parents: Parents) {
        this.queue = ArrayList<ObjectId>()
        this.visited = HashSet<String>()
        this.finder = finder
        this.sorting = sorting
        this.parents = parents
    }

    public func push(id: ObjectId): Unit {
        queue.add(id)
    }

    public func next(): ?Commit {
        while (queue.size > 0) {
            let id = selectNext()
            let hex = id.toHexString()
            if (visited.contains(hex)) {
                continue
            }
            visited.add(hex)
            let dataOpt = finder.findObject(id)
            if (let Some(d) <- dataOpt) {
                let obj = d.decode()
                if (let Some(ObjectRef.Commit(c)) <- obj) {
                    var parentIds = ArrayList<ObjectId>()
                    for (parent in c.parents) {
                        parentIds.add(ObjectId.fromHexOrThrow(parent))
                    }
                    if (parents == Parents.First && parentIds.size > 1) {
                        var firstOnly = ArrayList<ObjectId>()
                        firstOnly.add(parentIds[0])
                        parentIds = firstOnly
                    }
                    for (parentId in parentIds) {
                        queue.add(parentId)
                    }
                    let owned = c.intoOwned()
                    if (let Some(commit) <- owned) {
                        return Some(commit)
                    }
                }
            }
        }
        None
    }

    func selectNext(): ObjectId {
        match (sorting) {
            case BreadthFirst =>
                let id = queue[0]
                queue.remove(at: 0)
                id
            case NewestFirst =>
                var bestIdx: Int64 = 0
                var bestTime: Int64 = -1
                var i: Int64 = 0
                while (i < queue.size) {
                    let dataOpt = finder.findObject(queue[i])
                    if (let Some(d) <- dataOpt) {
                        let obj = d.decode()
                        if (let Some(ObjectRef.Commit(c)) <- obj) {
                            let sig = c.committerSignature()
                            if (let Some(s) <- sig) {
                                if (s.time.seconds > bestTime) {
                                    bestTime = s.time.seconds
                                    bestIdx = i
                                }
                            }
                        }
                    }
                    i += 1
                }
                let id = queue[bestIdx]
                queue.remove(at: bestIdx)
                id
            case OldestFirst =>
                var bestIdx: Int64 = 0
                var bestTime: Int64 = 9223372036854775807
                var i: Int64 = 0
                while (i < queue.size) {
                    let dataOpt = finder.findObject(queue[i])
                    if (let Some(d) <- dataOpt) {
                        let obj = d.decode()
                        if (let Some(ObjectRef.Commit(c)) <- obj) {
                            let sig = c.committerSignature()
                            if (let Some(s) <- sig) {
                                if (s.time.seconds < bestTime) {
                                    bestTime = s.time.seconds
                                    bestIdx = i
                                }
                            }
                        }
                    }
                    i += 1
                }
                let id = queue[bestIdx]
                queue.remove(at: bestIdx)
                id
        }
    }
}

// ============================================================
// Topo — 对齐 Rust: gix_traverse::commit::Topo
// ============================================================

public class Topo {
    public var queue: ArrayList<ObjectId>
    public var visited: HashSet<String>
    public var finder: FindObject
    public var parents: Parents

    public init(finder: FindObject, parents: Parents) {
        this.queue = ArrayList<ObjectId>()
        this.visited = HashSet<String>()
        this.finder = finder
        this.parents = parents
    }

    public func push(id: ObjectId): Unit {
        queue.add(id)
    }

    public func next(): ?Commit {
        while (queue.size > 0) {
            var idx: Int64 = 0
            while (idx < queue.size) {
                let id = queue[idx]
                let hex = id.toHexString()
                if (visited.contains(hex)) {
                    queue.remove(at: idx)
                    continue
                }
                visited.add(hex)
                queue.remove(at: idx)
                let dataOpt = finder.findObject(id)
                if (let Some(d) <- dataOpt) {
                    let obj = d.decode()
                    if (let Some(ObjectRef.Commit(c)) <- obj) {
                        var parentIds = ArrayList<ObjectId>()
                        for (parent in c.parents) {
                            parentIds.add(ObjectId.fromHexOrThrow(parent))
                        }
                        if (parents == Parents.First && parentIds.size > 1) {
                            var firstOnly = ArrayList<ObjectId>()
                            firstOnly.add(parentIds[0])
                            parentIds = firstOnly
                        }
                        for (parentId in parentIds) {
                            queue.add(parentId)
                        }
                        let owned = c.intoOwned()
                        if (let Some(commit) <- owned) {
                            return Some(commit)
                        }
                    }
                }
                idx += 1
            }
        }
        None
    }
}

// ============================================================
// TreeDepthfirst — 对齐 Rust: gix_traverse::tree::depthfirst
// ============================================================

public class TreeDepthfirst {
    public var finder: FindObject
    public var stack: ArrayList<TreeStackEntry>

    public init(finder: FindObject) {
        this.finder = finder
        this.stack = ArrayList<TreeStackEntry>()
    }

    public func traverse(root: ObjectId, delegate: Visit): Unit {
        stack.add(TreeStackEntry(root, 0))
        while (stack.size > 0) {
            let entry = stack[stack.size - 1]
            stack.remove(at: stack.size - 1)
            let dataOpt = finder.findObject(entry.treeId)
            if (dataOpt.isNone()) { continue }
            let d = dataOpt.getOrThrow()
            let obj = d.decode()
            if (let Some(ObjectRef.Tree(tree)) <- obj) {
                var entries = ArrayList<EntryRef>()
                for (e in tree.entries) {
                    entries.add(e)
                }
                var i: Int64 = entries.size - 1
                while (i >= 0) {
                    let e = entries[i]
                    let isTree = e.mode.value == 0o040000 || e.mode.value == 0o160000
                    if (isTree) {
                        let action = delegate.visitTree(e)
                        match (action) {
                            case Action.Continue =>
                                let childId = ObjectId.fromHexOrThrow(e.oid.toHexString())
                                stack.add(TreeStackEntry(childId, 0))
                            case Action.Skip => ()
                            case Action.Cancel => return
                        }
                    } else {
                        let action = delegate.visitNontree(e)
                        match (action) {
                            case Action.Cancel => return
                            case _ => ()
                        }
                    }
                    i -= 1
                }
            }
        }
    }
}

public class TreeStackEntry {
    public var treeId: ObjectId
    public var index: Int64

    public init(treeId: ObjectId, index: Int64) {
        this.treeId = treeId
        this.index = index
    }
}

// ============================================================
// TreeBreadthfirst — 对齐 Rust: gix_traverse::tree::breadthfirst
// ============================================================

public class TreeBreadthfirst {
    public var finder: FindObject
    public var queue: ArrayList<ObjectId>

    public init(finder: FindObject) {
        this.finder = finder
        this.queue = ArrayList<ObjectId>()
    }

    public func traverse(root: ObjectId, delegate: Visit): Unit {
        queue.add(root)
        while (queue.size > 0) {
            let treeId = queue[0]
            queue.remove(at: 0)
            let dataOpt = finder.findObject(treeId)
            if (dataOpt.isNone()) { continue }
            let d = dataOpt.getOrThrow()
            let obj = d.decode()
            if (let Some(ObjectRef.Tree(tree)) <- obj) {
                for (e in tree.entries) {
                    let isTree = e.mode.value == 0o040000 || e.mode.value == 0o160000
                    if (isTree) {
                        let action = delegate.visitTree(e)
                        match (action) {
                            case Action.Continue =>
                                queue.add(ObjectId.fromHexOrThrow(e.oid.toHexString()))
                            case Action.Skip => ()
                            case Action.Cancel => return
                        }
                    } else {
                        let action = delegate.visitNontree(e)
                        match (action) {
                            case Action.Cancel => return
                            case _ => ()
                        }
                    }
                }
            }
        }
    }
}

// ============================================================
// Recorder — 对齐 Rust: gix_traverse::tree::Recorder
// ============================================================

public class Recorder <: Visit {
    public var entries: ArrayList<RecorderEntry>
    public var pathDeque: ArrayList<String>
    public var location: RecorderLocation

    public init() {
        this.entries = ArrayList<RecorderEntry>()
        this.pathDeque = ArrayList<String>()
        this.location = RecorderLocation.Path
    }

    public init(location: RecorderLocation) {
        this.entries = ArrayList<RecorderEntry>()
        this.pathDeque = ArrayList<String>()
        this.location = location
    }

    public func popBackTrackedPathAndSetCurrent(): Unit {
        if (pathDeque.size > 0) {
            pathDeque.remove(at: pathDeque.size - 1)
        }
    }

    public func pushBackTrackedPathComponent(component: String): Unit {
        pathDeque.add(component)
    }

    public func pushPathComponent(component: String): Unit {
        pathDeque.add(component)
    }

    public func popPathComponent(): Unit {
        if (pathDeque.size > 0) {
            pathDeque.remove(at: pathDeque.size - 1)
        }
    }

    public func visitTree(entry: EntryRef): Action {
        let path = currentPath()
        entries.add(RecorderEntry(entry.mode, path, ObjectId.fromHexOrThrow(entry.oid.toHexString())))
        pushPathComponent(entry.filename)
        Action.Continue
    }

    public func visitNontree(entry: EntryRef): Action {
        let path = currentPath()
        entries.add(RecorderEntry(entry.mode, path, ObjectId.fromHexOrThrow(entry.oid.toHexString())))
        Action.Continue
    }

    func currentPath(): String {
        if (pathDeque.size == 0) {
            ""
        } else {
            var result = ""
            var i: Int64 = 0
            while (i < pathDeque.size) {
                if (i > 0) { result += "/" }
                result += pathDeque[i]
                i += 1
            }
            result
        }
    }
}

// 对齐 Rust: gix_traverse::tree::recorder::Location
public enum RecorderLocation {
    | Path
    | FileName
}

// 对齐 Rust: gix_traverse::tree::recorder::Entry
public class RecorderEntry {
    public var mode: EntryMode
    public var filepath: String
    public var oid: ObjectId

    public init(mode: EntryMode, filepath: String, oid: ObjectId) {
        this.mode = mode
        this.filepath = filepath
        this.oid = oid
    }
}
