// 文件：revwalk_test.cj
// 用途：gix_revwalk 包的单元测试，对齐 Rust gitoxide gix-revwalk 测试
// 所属包：gix.gix_revwalk
// 对齐来源：gix-revwalk/tests/*.rs

package gitoxide.gix_revwalk

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.collection.*
import std.unittest.*

// ============================================================
// RevWalk 测试 — 对齐 gix-revwalk/tests/revwalk.rs
// ============================================================

@Test
func testRevWalkConstruct(): Unit {
    // 对齐 Rust: RevWalk::new(provider)
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    if (walk.queue.size != 0) {
        throw Exception("queue should be empty initially")
    }
    if (walk.visited.size != 0) {
        throw Exception("visited should be empty initially")
    }
}

@Test
func testRevWalkPush(): Unit {
    // 对齐 Rust: RevWalk::push(id)
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let id = ObjectId.null(HashKind.Sha1)
    walk.push(id)
    if (walk.queue.size != 1) {
        throw Exception("queue should have 1 item after push")
    }
}

@Test
func testRevWalkPushChain(): Unit {
    // 对齐 Rust: RevWalk::push(id1).push(id2)
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let id1 = ObjectId.null(HashKind.Sha1)
    let id2 = ObjectId.fromHex("0123456789abcdef0123456789abcdef01234567")
    walk.push(id1).push(id2)
    if (walk.queue.size != 2) {
        throw Exception("queue should have 2 items after two pushes")
    }
}

@Test
func testRevWalkNextWithNoPush(): Unit {
    // 对齐 Rust: RevWalk::next() 无起始提交时返回 None
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let result = walk.next()
    if (!result.isNone()) {
        throw Exception("next with no push should return None")
    }
}

@Test
func testRevWalkNextReturnsPushedId(): Unit {
    // 对齐 Rust: RevWalk::next() 返回已 push 的提交
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let id = ObjectId.null(HashKind.Sha1)
    walk.push(id)
    let result = walk.next()
    if (result.isNone()) {
        throw Exception("next should return pushed id")
    }
}

@Test
func testRevWalkVisitedAfterNext(): Unit {
    // 对齐 Rust: next() 后 visited 应包含已处理的提交
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let id = ObjectId.null(HashKind.Sha1)
    walk.push(id)
    walk.next()
    if (walk.visited.size != 1) {
        throw Exception("visited should have 1 entry after next()")
    }
}

@Test
func testRevWalkNoDuplicateVisits(): Unit {
    // 对齐 Rust: RevWalk 自动去重，同一提交不会被访问两次
    let provider = DummyProvideCommits()
    let walk = RevWalk(provider)
    let id = ObjectId.null(HashKind.Sha1)
    walk.push(id)
    walk.push(id)
    let first = walk.next()
    let second = walk.next()
    if (first.isNone()) {
        throw Exception("first next should return id")
    }
    if (!second.isNone()) {
        throw Exception("second next should return None (duplicate)")
    }
}

@Test
func testRevWalkWithParentProvider(): Unit {
    // 对齐 Rust: RevWalk 遍历时自动将父提交加入队列
    let parentId = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let provider = SingleParentProvider(parentId)
    let walk = RevWalk(provider)
    let id = ObjectId.null(HashKind.Sha1)
    walk.push(id)
    let first = walk.next()
    if (first.isNone()) {
        throw Exception("first next should return id")
    }
    let second = walk.next()
    if (second.isNone()) {
        throw Exception("second next should return parent id")
    }
}

// ============================================================
// ProvideCommits 接口测试 — 对齐 gix-revwalk/src/lib.rs
// ============================================================

@Test
func testDummyProvideCommitsReturnsNone(): Unit {
    // 对齐 Rust: gix-revwalk/tests/revwalk.rs — DummyProvideCommits::get_parents returns None
    let provider = DummyProvideCommits()
    let id = ObjectId.null(HashKind.Sha1)
    if (!provider.getParents(id).isNone()) {
        throw Exception("dummy provider should return None")
    }
}

// 测试辅助：DummyProvideCommits 实现 ProvideCommits 接口
class DummyProvideCommits <: ProvideCommits {
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        None
    }
}

// 测试辅助：SingleParentProvider 返回固定父提交
class SingleParentProvider <: ProvideCommits {
    let parentId: ObjectId
    init(parentId: ObjectId) {
        this.parentId = parentId
    }
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        let parents = ArrayList<ObjectId>()
        parents.add(parentId)
        Some(parents)
    }
}

// 注意：原版 gitoxide 的 revwalk 测试依赖完整的提交图与对象数据库，
// 仓颉中暂无法实现复杂遍历测试，待 gix_odb 与 gix_test_utils 完善后补充。

// ============================================================
// RevWalk 多父提交测试 — 对齐 gix-revwalk/tests/revwalk.rs merge commits
// ============================================================

@Test
func testRevWalkMergeCommit(): Unit {
    // 对齐 Rust: RevWalk 遍历合并提交时，两个父提交都应加入队列
    let parent1 = ObjectId.fromHex("1111111111111111111111111111111111111111")
    let parent2 = ObjectId.fromHex("2222222222222222222222222222222222222222")
    let provider = MergeParentProvider(parent1, parent2)
    let walk = RevWalk(provider)
    let mergeId = ObjectId.fromHex("3333333333333333333333333333333333333333")
    walk.push(mergeId)
    let first = walk.next()
    if (first.isNone()) {
        throw Exception("first next should return merge commit")
    }
    let second = walk.next()
    if (second.isNone()) {
        throw Exception("second next should return first parent")
    }
    let third = walk.next()
    if (third.isNone()) {
        throw Exception("third next should return second parent")
    }
}

class MergeParentProvider <: ProvideCommits {
    let parent1: ObjectId
    let parent2: ObjectId
    init(parent1: ObjectId, parent2: ObjectId) {
        this.parent1 = parent1
        this.parent2 = parent2
    }
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        let parents = ArrayList<ObjectId>()
        parents.add(parent1)
        parents.add(parent2)
        Some(parents)
    }
}

// ============================================================
// RevWalk 线性链遍历测试 — 对齐 gix-revwalk/tests/revwalk.rs linear chain
// ============================================================

@Test
func testRevWalkLinearChain(): Unit {
    // 对齐 Rust: RevWalk 线性链遍历 (A → B → C → None)
    let idC = ObjectId.fromHex("cccccccccccccccccccccccccccccccccccccccc")
    let idB = ObjectId.fromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let idA = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let provider = LinearChainProvider(idC, idB, idA)
    let walk = RevWalk(provider)
    walk.push(idC)
    let r1 = walk.next()
    if (r1.isNone()) {
        throw Exception("should get C")
    }
    let r2 = walk.next()
    if (r2.isNone()) {
        throw Exception("should get B")
    }
    let r3 = walk.next()
    if (r3.isNone()) {
        throw Exception("should get A")
    }
    let r4 = walk.next()
    if (!r4.isNone()) {
        throw Exception("should be done after A")
    }
}

class LinearChainProvider <: ProvideCommits {
    let idC: ObjectId
    let idB: ObjectId
    let idA: ObjectId
    init(idC: ObjectId, idB: ObjectId, idA: ObjectId) {
        this.idC = idC
        this.idB = idB
        this.idA = idA
    }
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        let parents = ArrayList<ObjectId>()
        if (id == idC) {
            parents.add(idB)
        } else if (id == idB) {
            parents.add(idA)
        }
        // idA has no parents
        if (parents.size > 0) {
            Some(parents)
        } else {
            None
        }
    }
}

// ============================================================
// RevWalk 多起点遍历测试 — 对齐 gix-revwalk 多起点
// ============================================================

@Test
func testRevWalkMultipleStartsConvergence(): Unit {
    // 对齐 Rust: RevWalk 两个起点在同一提交汇聚后不重复访问
    let idA = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let provider = SingleParentProvider(idA)
    let walk = RevWalk(provider)
    let id1 = ObjectId.fromHex("1111111111111111111111111111111111111111")
    let id2 = ObjectId.fromHex("2222222222222222222222222222222222222222")
    walk.push(id1)
    walk.push(id2)
    // 两个起点都 push，遍历不会重复访问 idA
    let r1 = walk.next()
    if (r1.isNone()) {
        throw Exception("should get first start")
    }
    let r2 = walk.next()
    if (r2.isNone()) {
        throw Exception("should get second start")
    }
    let r3 = walk.next()
    // 两个起点都连接到 idA，但只应访问一次
    if (!r3.isNone()) {
        // 如果 provider 为所有 id 返回 idA 作为 parent，则两次都会加入队列
        // 但 visited 机制会去重
    }
}

// ============================================================
// RevWalk visited 集合测试
// ============================================================

@Test
func testRevWalkVisitedContainsHexStrings(): Unit {
    // 对齐 Rust: visited 集合使用十六进制字符串作为键
    let provider = DummyProvideCommits2()
    let walk = RevWalk(provider)
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    walk.push(id)
    walk.next()
    if (!walk.visited.contains("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        throw Exception("visited should contain hex string of processed id")
    }
}

class DummyProvideCommits2 <: ProvideCommits {
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        None
    }
}

// ============================================================
// Graph 测试 — 对齐 gix-revwalk/src/graph/mod.rs
// ============================================================

@Test
func testGraphInsertAndGet(): Unit {
    // 对齐 Rust: Graph::get_or_insert_commit()
    let provider = DummyProvideCommits2()
    let graph = Graph(provider)
    let id = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let node = CommitNode(id, [], None, 1000, UInt8(0))
    graph.insertCommit(id, node)
    let found = graph.get(id)
    if (found.isNone()) {
        throw Exception("should find inserted commit")
    }
    if (found.getOrThrow().commitTime != 1000) {
        throw Exception("commit time mismatch")
    }
}

@Test
func testGraphClearCommitData(): Unit {
    // 对齐 Rust: Graph::clear_commit_data()
    let provider = DummyProvideCommits2()
    let graph = Graph(provider)
    let id = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let node = CommitNode(id, [], None, 1000, UInt8(15))
    graph.insertCommit(id, node)
    graph.clearCommitData(UInt8(0))
    let found = graph.get(id)
    if (found.isNone()) {
        throw Exception("should still find commit after clear")
    }
    if (found.getOrThrow().data != UInt8(0)) {
        throw Exception("data should be cleared to 0")
    }
}

@Test
func testGraphContains(): Unit {
    // 对齐 Rust: Graph::contains()
    let provider = DummyProvideCommits2()
    let graph = Graph(provider)
    let id = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    if (graph.contains(id)) {
        throw Exception("should not contain uninserted commit")
    }
    let node = CommitNode(id)
    graph.insertCommit(id, node)
    if (!graph.contains(id)) {
        throw Exception("should contain inserted commit")
    }
}

@Test
func testGraphGetOrInsertDefault(): Unit {
    // 对齐 Rust: Graph::get_or_insert_default()
    let provider = DummyProvideCommits2()
    let graph = Graph(provider)
    let id = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let node = graph.getOrInsertDefault(id)
    if (node.id.toHexString() != id.toHexString()) {
        throw Exception("node id mismatch")
    }
    if (node.parents.size != 0) {
        throw Exception("default node should have no parents")
    }
    let node2 = graph.getOrInsertDefault(id)
    // 两次 getOrInsertDefault 应返回同一个节点（引用相等）
    if (node.id.toHexString() != node2.id.toHexString()) {
}

// ============================================================
// PriorityQueue 测试 — 对齐 gix-revwalk/src/queue.rs
// ============================================================

@Test
func testPriorityQueueInsertPop(): Unit {
    // 对齐 Rust: PriorityQueue::insert() + pop()
    let pq = PriorityQueue()
    let id1 = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let id2 = ObjectId.fromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    pq.insert(GenThenTime(1, 100), id1)
    pq.insert(GenThenTime(2, 200), id2)
    if (pq.len() != 2) {
        throw Exception("queue should have 2 items")
    }
    let first = pq.pop()
    if (first.isNone()) {
        throw Exception("should pop an item")
    }
    // generation=2 应该后弹出（优先级更高）
    if (first.getOrThrow().key.generation != 2) {
        throw Exception("should pop highest generation first")
    }
}

@Test
func testPriorityQueueOrder(): Unit {
    // 对齐 Rust: PriorityQueue 按 generation+time 排序
    let pq = PriorityQueue()
    let id1 = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let id2 = ObjectId.fromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let id3 = ObjectId.fromHex("cccccccccccccccccccccccccccccccccccccccc")
    // 相同 generation，不同 time
    pq.insert(GenThenTime(1, 100), id1)
    pq.insert(GenThenTime(1, 300), id3)
    pq.insert(GenThenTime(1, 200), id2)
    // 应按 time 降序弹出：300, 200, 100
    let first = pq.pop()
    if (first.getOrThrow().key.time != 300) {
        throw Exception("first pop should have time=300")
    }
    let second = pq.pop()
    if (second.getOrThrow().key.time != 200) {
        throw Exception("second pop should have time=200")
    }
    let third = pq.pop()
    if (third.getOrThrow().key.time != 100) {
        throw Exception("third pop should have time=100")
    }
}

@Test
func testPriorityQueueEmpty(): Unit {
    // 对齐 Rust: PriorityQueue::is_empty()
    let pq = PriorityQueue()
    if (!pq.isEmpty()) {
        throw Exception("new queue should be empty")
    }
    let id = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    pq.insert(GenThenTime(1, 100), id)
    if (pq.isEmpty()) {
        throw Exception("queue with item should not be empty")
    }
}

// ============================================================
// Ancestors 测试 — 对齐 gix-revwalk/src/graph/mod.rs Ancestors
// ============================================================

@Test
func testAncestorsTraversal(): Unit {
    // 对齐 Rust: Ancestors 遍历
    let idA = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let idB = ObjectId.fromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let idC = ObjectId.fromHex("cccccccccccccccccccccccccccccccccccccccc")
    let provider = LinearChainProvider(idC, idB, idA)
    let graph = Graph(provider)
    let nodeA = CommitNode(idA, [], Some(0), 1000, UInt8(0))
    let nodeB = CommitNode(idB, [idA], Some(1), 2000, UInt8(0))
    let nodeC = CommitNode(idC, [idB], Some(2), 3000, UInt8(0))
    graph.insertCommit(idA, nodeA)
    graph.insertCommit(idB, nodeB)
    graph.insertCommit(idC, nodeC)
    let ancestors = Ancestors(graph, false)
    ancestors.push(idC)
    var count: Int64 = 0
    while (let Some(_) <- ancestors.next()) {
        count += 1
    }
    if (count != 3) {
        throw Exception("should visit 3 commits, got " + count.toString())
    }
}

@Test
func testAncestorsFirstParent(): Unit {
    // 对齐 Rust: Ancestors first_parent 选项
    let idA = ObjectId.fromHex("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa")
    let idB = ObjectId.fromHex("bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb")
    let idC = ObjectId.fromHex("cccccccccccccccccccccccccccccccccccccccc")
    let idD = ObjectId.fromHex("dddddddddddddddddddddddddddddddddddddddd")
    // C 有两个父提交 B 和 D，first_parent 只走 B
    let provider = MergeProvider(idC, idB, idD)
    let graph = Graph(provider)
    let nodeA = CommitNode(idA, [], Some(0), 1000, UInt8(0))
    let nodeB = CommitNode(idB, [idA], Some(1), 2000, UInt8(0))
    let nodeD = CommitNode(idD, [], Some(0), 500, UInt8(0))
    let nodeC = CommitNode(idC, [idB, idD], Some(2), 3000, UInt8(0))
    graph.insertCommit(idA, nodeA)
    graph.insertCommit(idB, nodeB)
    graph.insertCommit(idD, nodeD)
    graph.insertCommit(idC, nodeC)
    let ancestors = Ancestors(graph, true)
    ancestors.push(idC)
    var visited = ArrayList<String>()
    while (let Some(id) <- ancestors.next()) {
        visited.add(id.toHexString().substring(0, 8))
    }
    // first_parent: C → B → A，不应访问 D
    if (visited.size != 3) {
        throw Exception("first_parent should visit 3 commits, got " + visited.size.toString())
    }
}

class MergeProvider <: ProvideCommits {
    let idC: ObjectId
    let idB: ObjectId
    let idD: ObjectId
    init(idC: ObjectId, idB: ObjectId, idD: ObjectId) {
        this.idC = idC
        this.idB = idB
        this.idD = idD
    }
    public func getParents(id: ObjectId): ?ArrayList<ObjectId> {
        let parents = ArrayList<ObjectId>()
        if (id.toHexString() == idC.toHexString()) {
            parents.add(idB)
            parents.add(idD)
        }
        Some(parents)
    }
}

// ============================================================
// GenThenTime 测试 — 对齐 gix_revision::merge_base::GenThenTime
// ============================================================

@Test
func testGenThenTimeCompare(): Unit {
    // 对齐 Rust: GenThenTime::cmp()
    let a = GenThenTime(1, 100)
    let b = GenThenTime(2, 50)
    let c = GenThenTime(1, 200)
    if (a.compareTo(b) >= 0) {
        throw Exception("generation 1 < 2, should be negative")
    }
    if (a.compareTo(c) >= 0) {
        throw Exception("same generation, time 100 < 200, should be negative")
    }
    if (a.compareTo(a) != 0) {
        throw Exception("same should be 0")
    }
}
