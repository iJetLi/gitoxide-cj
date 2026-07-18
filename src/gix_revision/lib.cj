// 文件：lib.cj
// 用途：提供 Git 修订规范解析、merge_base 算法、describe 算法
// 所属包：gix.gix_revision
// 关键类型：Spec, MergeBaseFlags, DescribeOptions, DescribeOutcome, DescribeFormat, ResolveRef
// 关键函数：resolve, mergeBase, mergeBaseOctopus, describe
// 对齐来源：gix-revision/src/lib.rs, gix-revision/src/merge_base/, gix-revision/src/describe.rs, gix-revision/src/spec/

package gitoxide.gix_revision

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import gitoxide.gix_revwalk.*
import std.collection.*
import std.convert.*

// ============================================================
// Spec — 对齐 Rust: gix_revision::spec::Spec
// 修订规范，表示一个 Git 引用或提交 ID 的字符串描述
// ============================================================

public class Spec {
    // 原始的修订规范字符串
    public var raw: String

    // 构造函数
    // 参数 raw：修订规范字符串
    public init(raw: String) {
        this.raw = raw
    }

    // 对齐 Rust: spec::parse::parse()
    // 解析字符串为修订规范，支持完整哈希、refs/ 前缀、HEAD、^、~N、@{N}、:path 语法
    public static func parse(s: String): ?Spec {
        Some(Spec(s))
    }
}

// 对齐 Rust: gix_revision::spec::types::Kind
// 修订规范的类型
public enum SpecKind {
    | FullHash
    | PartialHash
    | RefName
    | Parent
    | Ancestor
    | Tilde
    | Pathspec
}

// ============================================================
// resolve — 对齐 Rust: gix_revision::spec 解析和解析
// ============================================================

// 解析修订规范为对象 ID
// 支持完整哈希、refs/ 前缀引用、HEAD、^ 父提交、~N 祖先、@{N} 历史位置、:path 路径规格
public func resolve(spec: Spec, resolver: ResolveRef): ?ObjectId {
    let s = spec.raw
    if (s.size == 0) {
        return None
    }

    // 完整哈希
    if (s.size == 40 || s.size == 64) {
        return Some(ObjectId.fromHexOrThrow(s))
    }

    // ~N 语法（祖先）
    let tildeIdx = s.lastIndexOf("~")
    if (let Some(ti) <- tildeIdx) {
        if (ti > 0) {
            let baseSpec = Spec(substringStr(s, 0, ti))
            let baseId = resolve(baseSpec, resolver)
            if (baseId.isNone()) {
                return None
            }
            var n: Int64 = 1
            if (ti + 1 < s.size) {
                let numStr = substringFromStr(s, ti + 1)
                n = Int64.parse(numStr)
            }
            var current = baseId.getOrThrow()
            var step: Int64 = 0
            while (step < n) {
                let parent = resolver.resolveParent(current)
                if (parent.isNone()) {
                    return None
                }
                current = parent.getOrThrow()
                step += 1
            }
            return Some(current)
        }
    }

    // ^ 语法（父提交）
    let caretIdx = s.lastIndexOf("^")
    if (let Some(ci) <- caretIdx) {
        if (ci > 0) {
            let parentSpec = Spec(substringStr(s, 0, ci))
            let parentId = resolve(parentSpec, resolver)
            if (let Some(pid) <- parentId) {
                // ^{N} 语法：第 N 个父提交
                if (ci + 1 < s.size && s[ci + 1] == CHAR_LBRACE) {
                    let braceEnd = s.indexOf('}', ci + 2)
                    if (let Some(be) <- braceEnd) {
                        let inner = substringStr(s, ci + 2, be - ci - 2)
                        if (inner == "tree") {
                            return resolver.resolveTree(pid)
                        } else if (inner == "commit") {
                            return Some(pid)
                        } else if (inner == "blob") {
                            return None
                        } else {
                            let parentNum = Int64.parse(inner)
                            return resolver.resolveNthParent(pid, parentNum)
                        }
                    }
                }
                return resolver.resolveParent(pid)
            } else {
                return None
            }
        }
    }

    // @{N} 语法（历史位置）
    let atIdx = s.indexOf("@")
    if (let Some(ai) <- atIdx) {
        if (ai + 1 < s.size && s[ai + 1] == CHAR_LBRACE) {
            let braceEnd = s.indexOf('}', ai + 2)
            if (let Some(be) <- braceEnd) {
                let inner = substringStr(s, ai + 2, be - ai - 2)
                if (inner == "upstream" || inner == "u") {
                    return resolver.resolveUpstream(substringStr(s, 0, ai))
                } else if (inner == "push") {
                    return resolver.resolvePush(substringStr(s, 0, ai))
                } else {
                    let n = Int64.parse(inner)
                    return resolver.resolveNthPrior(substringStr(s, 0, ai), n)
                }
            }
        }
    }

    // :path 语法（路径规格）
    if (s.size > 1 && s[0] == CHAR_COLON) {
        return resolver.resolvePath(substringFromStr(s, 1))
    }

    // refs/ 前缀引用
    if (s.startsWith("refs/")) {
        return resolver.resolveRef(s)
    }

    // HEAD
    if (s == "HEAD") {
        return resolver.resolveRef("HEAD")
    }

    // 其他引用名
    resolver.resolveRef(s)
}

// 引用解析接口
public interface ResolveRef {
    func resolveRef(name: String): ?ObjectId
    func resolveParent(id: ObjectId): ?ObjectId
    func resolveNthParent(id: ObjectId, n: Int64): ?ObjectId
    func resolveTree(id: ObjectId): ?ObjectId
    func resolvePath(path: String): ?ObjectId
    func resolveUpstream(refName: String): ?ObjectId
    func resolvePush(refName: String): ?ObjectId
    func resolveNthPrior(refName: String, n: Int64): ?ObjectId
}

// ============================================================
// MergeBaseFlags — 对齐 Rust: gix_revision::merge_base::Flags
// ============================================================

public class MergeBaseFlags {
    public var rawValue: UInt8

    public init() {
        this.rawValue = 0
    }

    public init(rawValue: UInt8) {
        this.rawValue = rawValue
    }

    // 对齐 Rust: Flags::COMMIT1
    public static let COMMIT1: UInt8 = 1
    // 对齐 Rust: Flags::COMMIT2
    public static let COMMIT2: UInt8 = 2
    // 对齐 Rust: Flags::STALE
    public static let STALE: UInt8 = 4
    // 对齐 Rust: Flags::RESULT
    public static let RESULT: UInt8 = 8

    public func contains(flag: UInt8): Bool {
        (rawValue & flag) != 0
    }

    public func set(flag: UInt8): Unit {
        rawValue = rawValue | flag
    }

    public func clear(flag: UInt8): Unit {
        rawValue = rawValue & (flag ^ 0xFF)
    }

    public func isEmpty(): Bool {
        rawValue == 0
    }
}

// ============================================================
// mergeBase — 对齐 Rust: gix_revision::merge_base::function::merge_base
// ============================================================

// 计算两个或多个提交的 merge base
// 对齐 Rust: merge_base::function::merge_base
// 算法：paint-down-to-common + remove_redundant
public func mergeBase(first: ObjectId, others: Array<ObjectId>, graph: Graph): ?ArrayList<ObjectId> {
    // 对齐 Rust: if others.is_empty() || others.contains(&first)
    if (others.size == 0) {
        let result = ArrayList<ObjectId>()
        result.add(first)
        return Some(result)
    }
    for (other in others) {
        if (first.toHexString() == other.toHexString()) {
            let result = ArrayList<ObjectId>()
            result.add(first)
            return Some(result)
        }
    }
    // 对齐 Rust: graph.clear_commit_data(|f| *f = Flags::empty())
    graph.clearCommitData(UInt8(0))
    // 对齐 Rust: paint_down_to_common(first, others, graph)
    let bases = paintDownToCommon(first, others, graph)
    // 对齐 Rust: remove_redundant(&bases, graph)
    let reduced = removeRedundant(bases, graph)
    if (reduced.size == 0) {
        None
    } else {
        Some(reduced)
    }
}

// GenThenTime — 对齐 Rust: merge_base::function::GenThenTime
// 用于优先队列排序：先按 generation 升序，再按 commit_time 降序
class GenThenTime {
    var generation: Int64
    var time: Int64

    init(generation: Int64, time: Int64) {
        this.generation = generation
        this.time = time
    }

    // 从 CommitNode 构造
    // 对齐 Rust: impl From<&graph::Commit<Flags>> for GenThenTime
    static func fromCommit(node: CommitNode): GenThenTime {
        let gen = match (node.generation) {
            case Some(g) => g
            case None => 0x7FFFFFFF // GENERATION_NUMBER_INFINITY
        }
        GenThenTime(gen, node.commitTime)
    }
}

// paint-down-to-common 算法
// 对齐 Rust: merge_base::function::paint_down_to_common
// 使用优先队列按 GenThenTime 排序，同时从 first 和 others 开始 paint
// 找到同时标记 COMMIT1|COMMIT2 的提交
func paintDownToCommon(first: ObjectId, others: Array<ObjectId>, graph: Graph): ArrayList<(ObjectId, GenThenTime)> {
    // 对齐 Rust: let mut queue = PriorityQueue::<GenThenTime, ObjectId>::new()
    // 仓颉差异：无 PriorityQueue，使用 ArrayList 模拟（每次取最大 time 的元素）
    var queue = ArrayList<(GenThenTime, ObjectId)>()
    // 对齐 Rust: graph.get_or_insert_full_commit(first, |commit| { commit.data |= Flags::COMMIT1; queue.insert(...) })
    let firstNode = graph.getOrInsert(first)
    if (let Some(n) <- firstNode) {
        n.data = n.data | MergeBaseFlags.COMMIT1
        queue.add((GenThenTime.fromCommit(n), first))
    }
    // 对齐 Rust: for other in others { ... commit.data |= Flags::COMMIT2; queue.insert(...) }
    for (other in others) {
        let otherNode = graph.getOrInsert(other)
        if (let Some(n) <- otherNode) {
            n.data = n.data | MergeBaseFlags.COMMIT2
            queue.add((GenThenTime.fromCommit(n), other))
        }
    }
    // 对齐 Rust: while queue.iter_unordered().any(|id| !STALE) { ... }
    var out = ArrayList<(ObjectId, GenThenTime)>()
    while (hasNonStaleInQueue(queue, graph)) {
        // 对齐 Rust: let (info, commit_id) = queue.pop()
        let (info, commitId) = popBestFromQueue(queue)
        let commitOpt = graph.get(commitId)
        if (let Some(commit) <- commitOpt) {
            // 对齐 Rust: let mut flags_without_result = commit.data & (COMMIT1 | COMMIT2 | STALE)
            var flagsWithoutResult = commit.data & (MergeBaseFlags.COMMIT1 | MergeBaseFlags.COMMIT2 | MergeBaseFlags
                .STALE)
            // 对齐 Rust: if flags_without_result == (COMMIT1 | COMMIT2) { RESULT; STALE }
            if (flagsWithoutResult == (MergeBaseFlags.COMMIT1 | MergeBaseFlags.COMMIT2)) {
                if ((commit.data & MergeBaseFlags.RESULT) == UInt8(0)) {
                    commit.data = commit.data | MergeBaseFlags.RESULT
                    out.add((commitId, info))
                }
                flagsWithoutResult = flagsWithoutResult | MergeBaseFlags.STALE
            }
            // 对齐 Rust: for parent_id in commit.parents.clone() { ... }
            let parentsCopy = commit.parents
            for (parentId in parentsCopy) {
                let parentOpt = graph.getOrInsert(parentId)
                if (let Some(parent) <- parentOpt) {
                    if ((parent.data & flagsWithoutResult) != flagsWithoutResult) {
                        parent.data = parent.data | flagsWithoutResult
                        queue.add((GenThenTime.fromCommit(parent), parentId))
                    }
                }
            }
        }
    }
    out
}

// 检查队列中是否有非 STALE 的提交
// 对齐 Rust: queue.iter_unordered().any(|id| graph.get(id).is_some_and(|c| !c.data.contains(Flags::STALE)))
func hasNonStaleInQueue(queue: ArrayList<(GenThenTime, ObjectId)>, graph: Graph): Bool {
    for ((_, id) in queue) {
        let nodeOpt = graph.get(id)
        if (let Some(n) <- nodeOpt) {
            if ((n.data & MergeBaseFlags.STALE) == UInt8(0)) {
                return true
            }
        }
    }
    false
}

// 从队列中弹出最优元素（generation 最大、time 最大的优先）
// 对齐 Rust: PriorityQueue::pop() — 按 GenThenTime 降序
// 仓颉差异：无 PriorityQueue，线性扫描找最优
func popBestFromQueue(queue: ArrayList<(GenThenTime, ObjectId)>): (GenThenTime, ObjectId) {
    var bestIdx: Int64 = 0
    var bestGen: Int64 = -1
    var bestTime: Int64 = -1
    for (i in 0..queue.size) {
        let (gt, _) = queue[i]
        // 优先选 generation 小的（更近的提交），generation 相同选 time 大的
        if (gt.generation < bestGen || (gt.generation == bestGen && gt.time > bestTime) || bestGen < 0) {
            bestGen = gt.generation
            bestTime = gt.time
            bestIdx = i
        }
    }
    let result = queue[bestIdx]
    queue.remove(at: bestIdx)
    result
}

// 移除冗余的 merge base（被其他 merge base 的历史包含的提交）
// 对齐 Rust: merge_base::function::remove_redundant
// 算法：按 generation 排序，使用 STALE 标记被包含的提交
func removeRedundant(commits: ArrayList<(ObjectId, GenThenTime)>, graph: Graph): ArrayList<ObjectId> {
    if (commits.size == 0) {
        return ArrayList<ObjectId>()
    }
    // 对齐 Rust: graph.clear_commit_data(|f| *f = Flags::empty())
    graph.clearCommitData(UInt8(0))
    // 对齐 Rust: sorted_commits — 按 GenThenTime 排序
    var sorted = ArrayList<(ObjectId, GenThenTime)>()
    for (c in commits) {
        sorted.add(c)
    }
    // 按 generation 升序排序（简单的选择排序）
    for (i in 0..sorted.size) {
        var minIdx = i
        for (j in (i + 1)..sorted.size) {
            let (_, gtj) = sorted[j]
            let (_, gti) = sorted[minIdx]
            if (gtj.generation < gti.generation) {
                minIdx = j
            }
        }
        if (minIdx != i) {
            let tmp = sorted[i]
            sorted[i] = sorted[minIdx]
            sorted[minIdx] = tmp
        }
    }
    // 对齐 Rust: 标记所有 commits 为 RESULT，将它们的父节点加入 walk_start
    var walkStart = ArrayList<ObjectId>()
    for ((id, _) in sorted) {
        let commitOpt = graph.get(id)
        if (let Some(commit) <- commitOpt) {
            commit.data = commit.data | MergeBaseFlags.RESULT
            for (parentId in commit.parents) {
                let parentOpt = graph.getOrInsert(parentId)
                if (let Some(parent) <- parentOpt) {
                    if ((parent.data & MergeBaseFlags.STALE) == UInt8(0)) {
                        parent.data = parent.data | MergeBaseFlags.STALE
                        walkStart.add(parentId)
                    }
                }
            }
        }
    }
    // 对齐 Rust: 使用栈遍历，标记 STALE
    var minGenPos: Int64 = 0
    let (_, minGt) = sorted[minGenPos]
    var minGen = minGt.generation
    var countStillIndependent = sorted.size
    // 对齐 Rust: while let Some((commit_id, commit_info)) = stack.last().copied()
    var stack = ArrayList<(ObjectId, GenThenTime)>()
    for (id in walkStart) {
        let nodeOpt = graph.get(id)
        if (let Some(n) <- nodeOpt) {
            stack.add((id, GenThenTime.fromCommit(n)))
        }
    }
    while (stack.size > 0 && countStillIndependent > 1) {
        let (commitId, commitInfo) = stack[stack.size - 1]
        let commitOpt = graph.get(commitId)
        if (let Some(commit) <- commitOpt) {
            if ((commit.data & MergeBaseFlags.RESULT) != UInt8(0)) {
                commit.data = commit.data & (MergeBaseFlags.RESULT ^ 0xFF)
                countStillIndependent -= 1
                if (countStillIndependent <= 1) {
                    break
                }
                // 对齐 Rust: 更新 min_gen_pos
                let (sortedId0, _) = sorted[minGenPos]
                if (commitId.toHexString() == sortedId0.toHexString()) {
                    while (minGenPos < sorted.size - 1) {
                        let (nextId, _) = sorted[minGenPos]
                        let nextNodeOpt = graph.get(nextId)
                        if (let Some(nextNode) <- nextNodeOpt) {
                            if ((nextNode.data & MergeBaseFlags.STALE) != UInt8(0)) {
                                minGenPos += 1
                            } else {
                                break
                            }
                        } else {
                            break
                        }
                    }
                    let (_, updatedGt) = sorted[minGenPos]
                    minGen = updatedGt.generation
                }
            }
            if (commitInfo.generation < minGen) {
                stack.remove(at: stack.size - 1)
                continue
            }
            let parentsCopy = commit.parents
            var previousLen = stack.size
            for (parentId in parentsCopy) {
                let parentOpt = graph.getOrInsert(parentId)
                if (let Some(parent) <- parentOpt) {
                    if ((parent.data & MergeBaseFlags.STALE) == UInt8(0)) {
                        parent.data = parent.data | MergeBaseFlags.STALE
                        stack.add((parentId, GenThenTime.fromCommit(parent)))
                    }
                }
            }
            if (stack.size == previousLen) {
                stack.remove(at: stack.size - 1)
            }
        } else {
            stack.remove(at: stack.size - 1)
        }
    }
    // 对齐 Rust: 过滤非 STALE 的提交
    var result = ArrayList<ObjectId>()
    for ((id, _) in sorted) {
        let nodeOpt = graph.get(id)
        if (let Some(n) <- nodeOpt) {
            if ((n.data & MergeBaseFlags.STALE) == UInt8(0)) {
                result.add(id)
            }
        }
    }
    result
}

// ============================================================
// mergeBaseOctopus — 对齐 Rust: gix_revision::merge_base::octopus
// ============================================================

public func mergeBaseOctopus(first: ObjectId, others: Array<ObjectId>, graph: Graph): ?ObjectId {
    if (others.size == 0) {
        return Some(first)
    }
    var current = first
    for (other in others) {
        let bases = mergeBase(current, [other], graph)
        if (bases.isNone()) {
            return None
        }
        let basesList = bases.getOrThrow()
        if (basesList.size == 0) {
            return None
        }
        current = basesList[0]
    }
    Some(current)
}

// ============================================================
// ancestors — 对齐 Rust: gix_revision Graph 遍历
// ============================================================

public func ancestors(id: ObjectId, graph: Graph): Array<ObjectId> {
    ancestorsImpl(id, graph, false)
}

public func ancestorsFirstParent(id: ObjectId, graph: Graph): Array<ObjectId> {
    ancestorsImpl(id, graph, true)
}

func ancestorsImpl(id: ObjectId, graph: Graph, firstParent: Bool): Array<ObjectId> {
    let anc = Ancestors(graph, firstParent)
    anc.push(id)
    var result = ArrayList<ObjectId>()
    while (let Some(nextId) <- anc.next()) {
        result.add(nextId)
    }
    var arr = Array<ObjectId>(result.size, repeat: ObjectId.null(HashKind.Sha1))
    var i: Int64 = 0
    while (i < result.size) {
        arr[i] = result[i]
        i += 1
    }
    arr
}

// ============================================================
// describe — 对齐 Rust: gix_revision::describe
// ============================================================

// describe 选项 — 对齐 Rust: describe::Options
public class DescribeOptions {
    public var maxCandidates: Int64
    public var fallbackToOid: Bool
    public var firstParent: Bool

    public init() {
        this.maxCandidates = 10
        this.fallbackToOid = false
        this.firstParent = false
    }

    public init(maxCandidates: Int64, fallbackToOid: Bool, firstParent: Bool) {
        this.maxCandidates = maxCandidates
        this.fallbackToOid = fallbackToOid
        this.firstParent = firstParent
    }
}

// describe 结果 — 对齐 Rust: describe::Outcome
public class DescribeOutcome {
    public var name: ?String
    public var id: ObjectId
    public var depth: Int64
    public var commitsSeen: Int64

    public init(name: ?String, id: ObjectId, depth: Int64, commitsSeen: Int64) {
        this.name = name
        this.id = id
        this.depth = depth
        this.commitsSeen = commitsSeen
    }

    // 对齐 Rust: describe::Outcome::is_exact_match
    public func isExactMatch(): Bool {
        depth == 0
    }

    // 对齐 Rust: describe::Outcome::into_format()
    public func intoFormat(hexLen: Int64): DescribeFormat {
        DescribeFormat(name, id, hexLen, depth, false, None)
    }
}

// describe 格式化输出 — 对齐 Rust: describe::Format
public class DescribeFormat {
    public var name: ?String
    public var id: ObjectId
    public var hexLen: Int64
    public var depth: Int64
    public var long: Bool
    public var dirtySuffix: ?String

    public init(name: ?String, id: ObjectId, hexLen: Int64, depth: Int64, long: Bool, dirtySuffix: ?String) {
        this.name = name
        this.id = id
        this.hexLen = hexLen
        this.depth = depth
        this.long = long
        this.dirtySuffix = dirtySuffix
    }

    // 对齐 Rust: describe::Format Display
    public func toString(): String {
        var base = ""
        if (let Some(n) <- name) {
            if (!long && depth == 0) {
                base = n
            } else {
                base = n + "-" + depth.toString() + "-g" + substringStr(id.toHexString(), 0, hexLen)
            }
        } else {
            base = substringStr(id.toHexString(), 0, hexLen)
        }
        if (let Some(suffix) <- dirtySuffix) {
            base = base + "-" + suffix
        }
        base
    }
}

// describe 函数 — 对齐 Rust: describe::function::describe
// BFS 查找最近的 tag/branch 名称
public func describe(id: ObjectId, find: DescribeNameFinder, options: DescribeOptions): DescribeOutcome {
    let visited = HashSet<String>()
    let queue = ArrayList<DescribeQueueEntry>()
    queue.add(DescribeQueueEntry(id, 0))
    var commitsSeen: Int64 = 0
    var candidates = ArrayList<DescribeOutcome>()
    while (queue.size > 0) {
        let entry = queue[0]
        queue.remove(at: 0)
        let hex = entry.id.toHexString()
        if (visited.contains(hex)) {
            continue
        }
        visited.add(hex)
        commitsSeen += 1
        // 检查此提交是否有名称
        let nameOpt = find.findName(entry.id)
        if (let Some(name) <- nameOpt) {
            candidates.add(DescribeOutcome(Some(name), entry.id, entry.depth, commitsSeen))
            if (candidates.size >= options.maxCandidates) {
                break
            }
            continue
        }
        // 添加父提交到队列
        let parents = find.getParents(entry.id)
        if (let Some(ps) <- parents) {
            for (parent in ps) {
                queue.add(DescribeQueueEntry(parent, entry.depth + 1))
            }
        }
    }
    if (candidates.size > 0) {
        return candidates[0]
    }
    if (options.fallbackToOid) {
        return DescribeOutcome(None, id, 0, commitsSeen)
    }
    DescribeOutcome(None, id, 0, commitsSeen)
}

// describe 队列条目
class DescribeQueueEntry {
    var id: ObjectId
    var depth: Int64

    init(id: ObjectId, depth: Int64) {
        this.id = id
        this.depth = depth
    }
}

// describe 名称查找接口 — 对齐 Rust: describe::function 中的 find 回调
public interface DescribeNameFinder {
    func findName(id: ObjectId): ?String
    func getParents(id: ObjectId): ?Array<ObjectId>
}
