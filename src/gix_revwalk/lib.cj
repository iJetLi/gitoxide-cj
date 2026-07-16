// 文件：lib.cj
// 用途：提供提交遍历（revwalk）功能，按拓扑顺序遍历提交图
// 所属包：gix.gix_revwalk
// 关键类型：RevWalk, ProvideCommits, Graph, CommitNode, PriorityQueue, Ancestors
// 对齐来源：gix-revwalk/src/lib.rs, gix-revwalk/src/graph/, gix-revwalk/src/queue.rs

package gitoxide.gix_revwalk

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import gitoxide.gix_hashtable.HashMap
import std.collection.ArrayList
import std.collection.HashSet

// 提交遍历器，按广度优先顺序遍历提交图
// 自动去重，避免重复访问同一提交
public class RevWalk {
    // 待访问的提交队列
    public var queue: ArrayList<ObjectId>
    // 已访问的提交集合（十六进制字符串）
    public var visited: HashSet<String>
    // 提交提供器，用于获取提交的父提交
    public var provider: ProvideCommits

    // 构造函数
    // 参数 provider：提交提供器
    public init(provider: ProvideCommits) {
        this.queue = ArrayList<ObjectId>()
        this.visited = HashSet<String>()
        this.provider = provider
    }

    // 将起始提交 ID 加入遍历队列
    // 参数 id：起始提交 ID
    // 返回值：自身，支持链式调用
    public func push(id: ObjectId): RevWalk {
        queue.add(id)
        this
    }

    // 获取下一个未访问的提交 ID
    // 返回值：有未访问提交返回 ObjectId，遍历完毕返回 None
    public func next(): ?ObjectId {
        while (queue.size > 0) {
            let id = queue[0]
            queue.remove(at: 0)
            let hex = id.toHexString()
            if (visited.contains(hex)) {
                continue
            }
            visited.add(hex)
            let parents = provider.getParents(id)
            if (let Some(p) <- parents) {
                for (parent in p) {
                    queue.add(parent)
                }
            }
            return Some(id)
        }
        None
    }
}

// 提交提供器接口，用于获取指定提交的父提交列表
public interface ProvideCommits {
    // 获取指定提交的父提交列表
    // 参数 id：提交 ID
    // 返回值：父提交列表，无父提交或不存在返回 None
    func getParents(id: ObjectId): ?ArrayList<ObjectId>
}

// ============================================================
// CommitNode — 对齐 Rust: gix_revwalk::graph::Commit
// ============================================================

// 对齐 Rust: gix_revwalk::graph::Commit<T>
// 提交节点，包含提交的元数据和关联数据
public class CommitNode {
    // 对齐 Rust: graph::Commit::id
    public var id: ObjectId
    // 对齐 Rust: graph::Commit::parents
    public var parents: Array<ObjectId>
    // 对齐 Rust: graph::Commit::generation
    // 世代号，None 表示未知
    public var generation: ?Int64
    // 对齐 Rust: graph::Commit::commit_time
    // 提交时间戳（秒）
    public var commitTime: Int64
    // 对齐 Rust: graph::Commit::data (泛型 T 在仓颉中用 UInt8 标志位替代)
    // 关联数据标志位
    public var data: UInt8

    public init(id: ObjectId) {
        this.id = id
        this.parents = []
        this.generation = None
        this.commitTime = 0
        this.data = 0
    }

    public init(id: ObjectId, parents: Array<ObjectId>, generation: ?Int64, commitTime: Int64, data: UInt8) {
        this.id = id
        this.parents = parents
        this.generation = generation
        this.commitTime = commitTime
        this.data = data
    }
}

// ============================================================
// Graph — 对齐 Rust: gix_revwalk::Graph<'find, 'cache, T>
// ============================================================

// 对齐 Rust: gix_revwalk::Graph
// 提交图，维护提交节点及其关联数据
// 仓颉差异：无 Rust 生命周期和泛型，data 使用 UInt8 标志位
public class Graph {
    // 对齐 Rust: Graph 内部的 commits HashMap
    // 提交节点映射（十六进制字符串 → CommitNode）
    public var commits: HashMap<String, CommitNode>
    // 提交提供器
    public var finder: ProvideCommits

    public init(finder: ProvideCommits) {
        this.commits = HashMap<String, CommitNode>()
        this.finder = finder
    }

    // 对齐 Rust: Graph::get()
    // 获取指定提交的节点（只读）
    public func get(id: ObjectId): ?CommitNode {
        commits.get(id.toHexString())
    }

    // 对齐 Rust: Graph::get_mut()
    // 获取指定提交的节点（可变）
    public func getMut(id: ObjectId): ?CommitNode {
        let hex = id.toHexString()
        commits.get(hex)
    }

    // 对齐 Rust: Graph::get_or_insert_commit()
    // 获取或插入提交节点，如果不存在则通过 finder 获取并插入
    // 参数 id：提交 ID
    // 返回值：提交节点
    public func getOrInsert(id: ObjectId): ?CommitNode {
        let hex = id.toHexString()
        match (commits.get(hex)) {
            case Some(node) => return Some(node)
            case None => ()
        }
        let parentsOpt = finder.getParents(id)
        if (parentsOpt.isNone()) {
            return None
        }
        let parents = parentsOpt.getOrThrow()
        var parentArr = Array<ObjectId>(parents.size, repeat: ObjectId.null(HashKind.Sha1))
        var i: Int64 = 0
        while (i < parents.size) {
            parentArr[i] = parents[i]
            i += 1
        }
        let node = CommitNode(id, parentArr, None, 0, UInt8(0))
        commits.put(hex, node)
        Some(node)
    }

    // 对齐 Rust: Graph::get_or_insert_default()
    // 获取或插入提交节点，如果不存在则创建空节点
    public func getOrInsertDefault(id: ObjectId): CommitNode {
        let hex = id.toHexString()
        match (commits.get(hex)) {
            case Some(node) => return node
            case None => ()
        }
        let node = CommitNode(id)
        commits.put(hex, node)
        node
    }

    // 对齐 Rust: Graph::clear_commit_data()
    // 清除所有提交节点的关联数据标志位
    // 参数 reset：重置值
    public func clearCommitData(reset: UInt8): Unit {
        commits.forEachValue({ node =>
            node.data = reset
        })
    }

    // 对齐 Rust: Graph::insert_commit()
    // 插入一个提交节点
    public func insertCommit(id: ObjectId, node: CommitNode): Unit {
        commits.put(id.toHexString(), node)
    }

    // 对齐 Rust: Graph::contains()
    // 检查是否包含指定提交
    public func contains(id: ObjectId): Bool {
        commits.contains(id.toHexString())
    }
}

// ============================================================
// PriorityQueue — 对齐 Rust: gix_revwalk::PriorityQueue
// ============================================================

// 对齐 Rust: gix_revwalk::PriorityQueue<K, V>
// 优先队列，按键排序（最大优先）
// 仓颉差异：无泛型约束，使用具体类型 GenThenTime 作为键
public class PriorityQueue {
    // 对齐 Rust: queue.rs BinaryHeap
    // 内部存储（key, value）对，按 key 降序排列
    public var items: ArrayList<PQItem>

    public init() {
        this.items = ArrayList<PQItem>()
    }

    // 对齐 Rust: PriorityQueue::insert()
    // 插入一个元素，保持按 key 降序排列
    public func insert(key: GenThenTime, value: ObjectId): Unit {
        let item = PQItem(key, value)
        items.add(item)
        // 插入排序：冒泡到正确位置
        var pos = items.size - 1
        while (pos > 0 && items[pos - 1].key.compareTo(key) < 0) {
            let tmp = items[pos - 1]
            items[pos - 1] = items[pos]
            items[pos] = tmp
            pos -= 1
        }
    }

    // 对齐 Rust: PriorityQueue::pop()
    // 弹出优先级最高的元素（数组头部，key 降序排列）
    public func pop(): ?PQItem {
        if (items.size == 0) {
            return None
        }
        let item = items[0]
        items.remove(at: 0)
        Some(item)
    }

    // 对齐 Rust: PriorityQueue::iter_unordered()
    // 无序遍历所有值
    public func iterUnordered(): ArrayList<ObjectId> {
        var result = ArrayList<ObjectId>()
        for (item in items) {
            result.add(item.value)
        }
        result
    }

    // 对齐 Rust: PriorityQueue::is_empty()
    public func isEmpty(): Bool {
        items.size == 0
    }

    // 对齐 Rust: PriorityQueue::len()
    public func len(): Int64 {
        items.size
    }

    // 对齐 Rust: PriorityQueue::clear()
    public func clear(): Unit {
        items.clear()
    }
}

// 优先队列元素
public class PQItem {
    public var key: GenThenTime
    public var value: ObjectId

    public init(key: GenThenTime, value: ObjectId) {
        this.key = key
        this.value = value
    }
}

// ============================================================
// GenThenTime — 对齐 Rust: gix_revision::merge_base::GenThenTime
// ============================================================

// 对齐 Rust: gix_revision::merge_base::GenThenTime
// 用于优先队列排序的键：先按 generation 排序，再按 time 排序
public class GenThenTime {
    // 对齐 Rust: GenThenTime::generation
    public var generation: Int64
    // 对齐 Rust: GenThenTime::time
    public var time: Int64

    public init(generation: Int64, time: Int64) {
        this.generation = generation
        this.time = time
    }

    // 对齐 Rust: GenThenTime::cmp()
    // 比较：先按 generation，再按 time
    public func compareTo(other: GenThenTime): Int64 {
        if (generation != other.generation) {
            generation - other.generation
        } else {
            time - other.time
        }
    }
}

// ============================================================
// Ancestors — 对齐 Rust: gix_revwalk::graph::Ancestors
// ============================================================

// 对齐 Rust: gix_revwalk::graph::Ancestors
// 祖先遍历迭代器，使用优先队列按 generation+time 排序
public class Ancestors {
    // 对齐 Rust: Ancestors 内部 graph
    public var graph: Graph
    // 对齐 Rust: Ancestors 内部 queue
    public var queue: PriorityQueue
    // 对齐 Rust: Ancestors 内部 visited
    public var visited: HashSet<String>
    // 对齐 Rust: Ancestors first_parent 选项
    public var firstParent: Bool

    public init(graph: Graph, firstParent: Bool) {
        this.graph = graph
        this.queue = PriorityQueue()
        this.visited = HashSet<String>()
        this.firstParent = firstParent
    }

    // 对齐 Rust: Ancestors::push()
    // 将起始提交加入遍历队列
    public func push(id: ObjectId): Unit {
        let hex = id.toHexString()
        if (visited.contains(hex)) {
            return
        }
        let node = graph.getOrInsertDefault(id)
        var gen: Int64 = 0x3FFFFFFF
        if (let Some(g) <- node.generation) {
            gen = g
        }
        let key = GenThenTime(gen, node.commitTime)
        queue.insert(key, id)
    }

    // 对齐 Rust: Ancestors::next()
    // 获取下一个未访问的祖先提交
    public func next(): ?ObjectId {
        while (!queue.isEmpty()) {
            let item = queue.pop()
            if (item.isNone()) {
                return None
            }
            let (key, id) = (item.getOrThrow().key, item.getOrThrow().value)
            let hex = id.toHexString()
            if (visited.contains(hex)) {
                continue
            }
            visited.add(hex)
            let node = graph.get(id)
            if (let Some(n) <- node) {
                var parentsToVisit = if (firstParent && n.parents.size > 0) {
                    [n.parents[0]]
                } else {
                    n.parents
                }
                for (parentId in parentsToVisit) {
                    let parentHex = parentId.toHexString()
                    if (!visited.contains(parentHex)) {
                        let parentNode = graph.getOrInsertDefault(parentId)
                        var parentGen: Int64 = 0x3FFFFFFF
                        if (let Some(g) <- parentNode.generation) {
                            parentGen = g
                        }
                        let parentKey = GenThenTime(parentGen, parentNode.commitTime)
                        queue.insert(parentKey, parentId)
                    }
                }
            }
            return Some(id)
        }
        None
    }
}
