// 文件：lib.cj

// 用途：Git 协商器，跟踪客户端已知道的提交对象以优化 want/have 协商

// 所属包：gix.gix_negotiate

// 关键类型：Negotiator, Algorithm, Flags, Metadata

// 对齐 Rust: gix-negotiate/src/lib.rs, consecutive.rs, skipping.rs, noop.rs

package gitoxide.gix_negotiate

import gitoxide.gix_hash.*
import gitoxide.gix_hashtable.*
import std.collection.ArrayList
import std.collection.HashSet

// 协商标志位，对齐 Rust gix_negotiate::Flags

// 使用 UInt8 位域表示，仓颉无 bitflags 宏，手动实现位操?
public class Flags {
    public var value: UInt8

    public init(value: UInt8) {
        this.value = value
    }

    // 对象已存在于本地，无需从远程获?
    public static let COMPLETE: UInt8 = UInt8(1) // 1 << 0

    // 来自备用对象数据库的提交
    public static let ALTERNATE: UInt8 = UInt8(2) // 1 << 1

    // 已知与远程共有的修订
    public static let COMMON: UInt8 = UInt8(4) // 1 << 2

    // 已进入优先队列的修订
    public static let SEEN: UInt8 = UInt8(8) // 1 << 3

    // 已从主优先队列弹出的修订
    public static let POPPED: UInt8 = UInt8(16) // 1 << 4

    // 由远程跟踪引用设置的共有修订
    public static let COMMON_REF: UInt8 = UInt8(32) // 1 << 5

    // 远程告知拥有的对?
    public static let ADVERTISED: UInt8 = UInt8(64) // 1 << 6

    public static func none(): Flags {
        Flags(UInt8(0))
    }

    public static func default(): Flags {
        Flags(UInt8(0))
    }

    // 检查是否包含指定标?
    public func contains(flag: UInt8): Bool {
        (value & flag) != UInt8(0)
    }

    // 检查是否与指定标志有交?
    public func intersects(flag: UInt8): Bool {
        (value & flag) != UInt8(0)
    }

    // 添加标志?
    public func set(flag: UInt8): Unit {
        value = value | flag
    }

    // 移除标志位，对齐 Rust: flags & !flag，仓颉用 ^ 0xFF 代替 ~

    public func unset(flag: UInt8): Unit {
        value = value & (flag ^ 0xFF)
    }
}

// 提交元数据，对齐 Rust gix_negotiate::Metadata

public class Metadata {

    // 跳过协商算法使用的原?TTL

    public var originalTtl: Int64

    // 跳过协商算法使用的当?TTL

    public var ttl: Int64

    // 标志?
    public var flags: Flags

    public init() {
        originalTtl = 0

        ttl = 0

        flags = Flags.default()
    }

    public init(originalTtl: Int64, ttl: Int64, flags: Flags) {
        this.originalTtl = originalTtl

        this.ttl = ttl

        this.flags = flags
    }
}

// 图中的提交节点，对齐 Rust gix_revwalk::graph::Commit<Metadata>

public class CommitNode {

    // 提交对象 ID

    public var id: ObjectId

    // 提交时间?
    public var commitTime: Int64

    // 父提?ID 列表

    public var parents: ArrayList<ObjectId>

    // 附加元数?
    public var data: Metadata

    public init(id: ObjectId, commitTime: Int64) {
        this.id = id

        this.commitTime = commitTime

        this.parents = ArrayList<ObjectId>()

        this.data = Metadata()
    }
}

// 协商图，对齐 Rust gix_negotiate::Graph
// 仓颉 HashMap 存储提交节点（仓颉无 Rc/RefCell，用 String key 替代引用）

public class Graph {

    // 对象 ID -> 提交节点

    public var nodes: HashMap<String, CommitNode>

    public init() {
        nodes = HashMap<String, CommitNode>()
    }

    // 获取指定 ID 的提交节?
    public func get(id: ObjectId): ?CommitNode {
        nodes.get(id.toHexString())
    }

    // 获取或创建提交节?
    public func getOrInsert(id: ObjectId, commitTime: Int64): CommitNode {
        let hex = id.toHexString()

        if (let Some(node) <- nodes.get(hex)) {
            node
        } else {
            let node = CommitNode(id, commitTime)

            nodes.put(hex, node)

            node
        }
    }

    // 检查是否包含指?ID

    public func contains(id: ObjectId): Bool {
        nodes.contains(id.toHexString())
    }
}

// 协商算法类型，对?Rust gix_negotiate::Algorithm

public enum Algorithm {
    | Noop // 不发送任何信息，通常导致完整包发?
    | Consecutive // 逐个遍历提交，确保包大小最?
    | Skipping // 跳过部分提交以加速收敛，但包可能更大

}

// 计算一轮协商中可发送的 HAVE 行数

// 对齐 Rust: gix_negotiate::window_size

// 参数 stateless: 传输是否无状?
// 参数 prev: 上一轮窗口大小，None 表示初始调用

// 返回? 本轮窗口大小

public func windowSize(stateless: Bool, prev: ?Int64): Int64 {
    if (prev.isNone()) {
        return 16
    }

    let current = prev.getOrThrow()

    let pipeSafeFlush: Int64 = 32

    let largeFlush: Int64 = 16384

    if (stateless) {
        if (current < largeFlush) {
            current * 2
        } else {
            current * 11 / 10
        }
    } else if (current < pipeSafeFlush) {
        current * 2
    } else {
        current + pipeSafeFlush
    }
}

// 协商器接口，对齐 Rust gix_negotiate::Negotiator

public interface Negotiator {

    // 标记 ID 为客户端与远程共有的提交

    func knownCommon(id: ObjectId, graph: Graph): Unit

    // 添加遍历起点

    func addTip(id: ObjectId, graph: Graph): Unit

    // 产生下一?HAVE 行的对象 ID，耗尽返回 None

    func nextHave(graph: Graph): ?ObjectId

    // 标记远程确认 ID 为共有，返回之前是否已知共有

    func inCommonWithRemote(id: ObjectId, graph: Graph): Bool
}

// Noop 协商器，对齐 Rust gix_negotiate::noop::Noop

// 不发送任?HAVE，通常导致完整包传?
public class NoopNegotiator <: Negotiator {
    public init() {}

    public func knownCommon(id: ObjectId, graph: Graph): Unit {}

    public func addTip(id: ObjectId, graph: Graph): Unit {}

    public func nextHave(graph: Graph): ?ObjectId {
        None
    }

    public func inCommonWithRemote(id: ObjectId, graph: Graph): Bool {
        false
    }
}

// 优先队列?
class QueueItem {
    public var priority: Int64

    public var id: ObjectId

    public init(priority: Int64, id: ObjectId) {
        this.priority = priority

        this.id = id
    }
}

// 简单优先队列（按优先级降序，即时间戳大的先出）

class PriorityQueue {
    var items: ArrayList<QueueItem>

    public init() {
        items = ArrayList<QueueItem>()
    }

    public func insert(priority: Int64, id: ObjectId): Unit {
        items.add(QueueItem(priority, id))
    }

    public func popValue(): ?ObjectId {
        if (items.size == 0) {
            return None
        }

        var bestIdx: Int64 = 0

        var bestPriority = items[0].priority

        for (i in 1..items.size) {
            if (items[i].priority > bestPriority) {
                bestPriority = items[i].priority

                bestIdx = i
            }
        }

        let id = items[bestIdx].id

        items.remove(at: bestIdx)

        Some(id)
    }

    public func len(): Int64 {
        items.size
    }
}

// Consecutive 协商器，对齐 Rust gix_negotiate::consecutive::Algorithm

// 逐个遍历提交并检查每个，确保包大小最优但可能较慢

public class ConsecutiveNegotiator <: Negotiator {
    var revs: PriorityQueue

    var nonCommonRevs: Int64

    public init() {
        revs = PriorityQueue()

        nonCommonRevs = 0
    }

    func addToQueue(id: ObjectId, mark: UInt8, graph: Graph): Unit {
        let node = graph.getOrInsert(id, 0)

        var hasMark = node.data.flags.contains(mark)

        node.data.flags.set(mark)

        var isCommon = node.data.flags.contains(Flags.COMMON)

        if (!hasMark) {
            revs.insert(node.commitTime, id)

            if (!isCommon) {
                nonCommonRevs += 1
            }
        }
    }

    func markCommon(id: ObjectId, markThisCommit: Bool, traverseAllAncestors: Bool, graph: Graph): Unit {
        let nodeOpt = graph.get(id)

        if (nodeOpt.isNone()) {
            return
        }

        if (let Some(node) <- nodeOpt) {
            var isCommon = node.data.flags.contains(Flags.COMMON)

            if (isCommon) {
                return
            }

            var queue = PriorityQueue()

            queue.insert(node.commitTime, id)

            if (markThisCommit) {
                node.data.flags.set(Flags.COMMON)

                if (node.data.flags.contains(Flags.SEEN) && !node.data.flags.contains(Flags.POPPED)) {
                    nonCommonRevs -= 1
                }
            }

            var genMap = HashMap<String, Int64>()

            genMap.put(id.toHexString(), 0)

            while (true) {
                let nextOpt = queue.popValue()

                if (nextOpt.isNone()) {
                    break
                }

                let currentId = nextOpt.getOrThrow()

                var gen: Int64 = 0

                if (let Some(g) <- genMap.get(currentId.toHexString())) {
                    gen = g
                }

                let curNodeOpt = graph.get(currentId)

                if (curNodeOpt.isNone()) {
                    continue
                }

                if (let Some(curNode) <- curNodeOpt) {
                    if (!curNode.data.flags.contains(Flags.SEEN)) {
                        addToQueue(currentId, Flags.SEEN, graph)
                    } else if (traverseAllAncestors || gen < 2) {
                        for (parentId in curNode.parents) {
                            let parentOpt = graph.getOrInsert(parentId, 0)

                            var prevFlags = Flags.default()

                            prevFlags.value = parentOpt.data.flags.value

                            parentOpt.data.flags.set(Flags.COMMON)

                            if (!prevFlags.contains(Flags.COMMON)) {
                                if (prevFlags.contains(Flags.SEEN) && !prevFlags.contains(Flags.POPPED)) {
                                    nonCommonRevs -= 1
                                }

                                queue.insert(parentOpt.commitTime, parentId)

                                genMap.put(parentId.toHexString(), gen + 1)
                            }
                        }
                    }
                }
            }
        }
    }

    public func knownCommon(id: ObjectId, graph: Graph): Unit {
        let nodeOpt = graph.get(id)

        if (let Some(node) <- nodeOpt) {
            if (node.data.flags.contains(Flags.SEEN)) {
                return
            }
        }

        addToQueue(id, Flags.COMMON_REF | Flags.SEEN, graph)

        markCommon(id, false, false, graph)
    }

    public func addTip(id: ObjectId, graph: Graph): Unit {
        addToQueue(id, Flags.SEEN, graph)
    }

    public func nextHave(graph: Graph): ?ObjectId {
        while (true) {
            if (nonCommonRevs == 0) {
                return None
            }

            let idOpt = revs.popValue()

            if (idOpt.isNone()) {
                return None
            }

            let id = idOpt.getOrThrow()

            let node = graph.getOrInsert(id, 0)

            node.data.flags.set(Flags.POPPED)

            if (!node.data.flags.contains(Flags.COMMON)) {
                nonCommonRevs -= 1
            }

            var res: ?ObjectId = None

            var mark: UInt8 = Flags.SEEN

            if (node.data.flags.contains(Flags.COMMON)) {
                mark = Flags.COMMON | Flags.SEEN
            } else if (node.data.flags.contains(Flags.COMMON_REF)) {
                res = Some(id)

                mark = Flags.COMMON | Flags.SEEN
            } else {
                res = Some(id)

                mark = Flags.SEEN
            }

            for (parentId in node.parents) {
                let parentNodeOpt = graph.get(parentId)

                if (let Some(pn) <- parentNodeOpt) {
                    if (!pn.data.flags.contains(Flags.SEEN)) {
                        addToQueue(parentId, mark, graph)
                    }
                } else {
                    addToQueue(parentId, mark, graph)
                }

                if ((mark & Flags.COMMON) != UInt8(0)) {
                    markCommon(parentId, false, true, graph)
                }
            }

            if (res.isSome()) {
                return res
            }
        }

        None
    }

    public func inCommonWithRemote(id: ObjectId, graph: Graph): Bool {
        var knownToBeCommon = false

        if (let Some(node) <- graph.get(id)) {
            knownToBeCommon = node.data.flags.contains(Flags.COMMON)
        }

        markCommon(id, true, false, graph)

        knownToBeCommon
    }
}

// Skipping 协商器，对齐 Rust gix_negotiate::skipping::Algorithm

// 跳过部分提交以加速收敛，但可能导致更大的?
public class SkippingNegotiator <: Negotiator {
    var revs: PriorityQueue

    var nonCommonRevs: Int64

    public init() {
        revs = PriorityQueue()

        nonCommonRevs = 0
    }

    func addToQueue(id: ObjectId, mark: UInt8, graph: Graph): Unit {
        let node = graph.getOrInsert(id, 0)

        node.data.flags.set(mark | Flags.SEEN)

        revs.insert(node.commitTime, id)

        if ((mark & Flags.COMMON) == UInt8(0)) {
            nonCommonRevs += 1
        }
    }

    func markCommonSkipping(id: ObjectId, graph: Graph): Unit {
        let node = graph.getOrInsert(id, 0)

        var isCommon = node.data.flags.contains(Flags.COMMON)

        node.data.flags.set(Flags.COMMON)

        if (isCommon) {
            return
        }

        var queue = PriorityQueue()

        queue.insert(node.commitTime, id)

        while (true) {
            let nextOpt = queue.popValue()

            if (nextOpt.isNone()) {
                break
            }

            let currentId = nextOpt.getOrThrow()

            let curNodeOpt = graph.get(currentId)

            if (curNodeOpt.isNone()) {
                continue
            }

            if (let Some(curNode) <- curNodeOpt) {
                if (!curNode.data.flags.contains(Flags.POPPED)) {
                    nonCommonRevs -= 1
                }

                for (parentId in curNode.parents) {
                    if (!graph.contains(parentId)) {
                        continue
                    }

                    let parentOpt = graph.getOrInsert(parentId, 0)

                    var wasUnseenOrCommon = !parentOpt.data.flags.contains(Flags.SEEN) || parentOpt
                        .data
                        .flags
                        .contains(Flags.COMMON)

                    parentOpt.data.flags.set(Flags.COMMON)

                    if (!wasUnseenOrCommon) {
                        queue.insert(parentOpt.commitTime, parentId)
                    }
                }
            }
        }
    }

    func pushParent(entry: Metadata, parentId: ObjectId, graph: Graph): Bool {
        var wasSeen = false

        let parentNodeOpt = graph.get(parentId)

        if (let Some(pn) <- parentNodeOpt) {
            wasSeen = pn.data.flags.contains(Flags.SEEN)

            if (wasSeen) {
                if (pn.data.flags.contains(Flags.POPPED)) {
                    return false
                }
            }
        }

        if (!wasSeen) {
            addToQueue(parentId, UInt8(0), graph)
        }

        if (entry.flags.contains(Flags.COMMON) || entry.flags.contains(Flags.ADVERTISED)) {
            markCommonSkipping(parentId, graph)
        } else {
            var newOriginalTtl = entry.originalTtl

            if (entry.ttl <= 0) {
                newOriginalTtl = entry.originalTtl * 3 / 2 + 1
            }

            var newTtl = entry.ttl - 1

            if (entry.ttl <= 0) {
                newTtl = newOriginalTtl
            }

            let parentNode = graph.getOrInsert(parentId, 0)

            if (parentNode.data.originalTtl < newOriginalTtl) {
                parentNode.data.originalTtl = newOriginalTtl

                parentNode.data.ttl = newTtl
            }
        }

        true
    }

    public func knownCommon(id: ObjectId, graph: Graph): Unit {
        if (let Some(node) <- graph.get(id)) {
            if (node.data.flags.contains(Flags.SEEN)) {
                return
            }
        }

        addToQueue(id, Flags.ADVERTISED, graph)
    }

    public func addTip(id: ObjectId, graph: Graph): Unit {
        if (let Some(node) <- graph.get(id)) {
            if (node.data.flags.contains(Flags.SEEN)) {
                return
            }
        }

        addToQueue(id, UInt8(0), graph)
    }

    public func nextHave(graph: Graph): ?ObjectId {
        while (true) {
            if (nonCommonRevs == 0) {
                return None
            }

            let idOpt = revs.popValue()

            if (idOpt.isNone()) {
                return None
            }

            let id = idOpt.getOrThrow()

            let node = graph.getOrInsert(id, 0)

            node.data.flags.set(Flags.POPPED)

            if (!node.data.flags.contains(Flags.COMMON)) {
                nonCommonRevs -= 1
            }

            var toSend: ?ObjectId = None

            if (!node.data.flags.contains(Flags.COMMON) && node.data.ttl == 0) {
                toSend = Some(id)
            }

            let data = node.data

            var parentPushed = false

            for (parentId in node.parents) {
                var pushed = pushParent(data, parentId, graph)

                if (pushed) {
                    parentPushed = true
                }
            }

            if (!data.flags.contains(Flags.COMMON) && !parentPushed) {
                toSend = Some(id)
            }

            if (toSend.isSome()) {
                return toSend
            }
        }

        None
    }

    public func inCommonWithRemote(id: ObjectId, graph: Graph): Bool {
        var wasSeen = false

        var knownToBeCommon = false

        if (let Some(node) <- graph.get(id)) {
            wasSeen = node.data.flags.contains(Flags.SEEN)

            knownToBeCommon = node.data.flags.contains(Flags.COMMON)
        }

        markCommonSkipping(id, graph)

        knownToBeCommon
    }
}

// 根据算法类型创建对应的协商器

// 对齐 Rust: Algorithm::into_negotiator

public func createNegotiator(algo: Algorithm): Negotiator {
    match (algo) {
        case Algorithm.Noop => NoopNegotiator()

        case Algorithm.Consecutive => ConsecutiveNegotiator()

        case Algorithm.Skipping => SkippingNegotiator()
    }
}

// 协商轮次信息，对?Rust gix_protocol::fetch::negotiate::Round

public class Round {

    // 本轮发送的 HAVE 行数

    public var havesSent: Int64

    // 累计未获确认?HAVE ?
    public var inVain: Int64

    // 本轮应发送的 HAVE ?
    public var havesToSend: Int64

    // 上一轮响应是否至少有一个共有提?
    public var previousResponseHadAtLeastOneInCommon: Bool

    public init(havesSent: Int64, inVain: Int64, havesToSend: Int64, previousResponseHadAtLeastOneInCommon: Bool) {
        this.havesSent = havesSent

        this.inVain = inVain

        this.havesToSend = havesToSend

        this.previousResponseHadAtLeastOneInCommon = previousResponseHadAtLeastOneInCommon
    }
}

// 协商轮次状态，对齐 Rust gix_protocol::fetch::negotiate::one_round::State

public class NegotiateState {

    // 下一轮要发送的 HAVE ?
    public var havesToSend: Int64

    // 远程是否确认了至少一个共有提?
    public var seenAck: Bool

    // 未获确认?HAVE 累计?
    public var inVain: Int64

    // 无状态连接时保存的共有提交列?
    public var commonCommits: ?ArrayList<ObjectId>

    public init(connectionIsStateless: Bool) {
        havesToSend = windowSize(connectionIsStateless, None)

        seenAck = false

        inVain = 0

        if (connectionIsStateless) {
            commonCommits = Some(ArrayList<ObjectId>())
        } else {
            commonCommits = None
        }
    }

    // 调整下一轮窗口大?
    public func adjustWindowSize(): Unit {
        let stateless = connectionIsStateless()

        havesToSend = windowSize(stateless, Some(havesToSend))
    }

    // 连接是否无状?
    public func connectionIsStateless(): Bool {
        commonCommits.isSome()
    }
}
