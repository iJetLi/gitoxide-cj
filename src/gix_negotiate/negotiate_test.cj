// 文件：negotiate_test.cj
// 用途：gix_negotiate 包的单元测试，对齐 Rust gitoxide gix-negotiate 测试
// 所属包：gix.gix_negotiate
// 对齐来源：gix-negotiate/tests/negotiate.rs, gix-negotiate/tests/baseline/mod.rs

package gitoxide.gix_negotiate

import gitoxide.gix_hash.*
import std.collection.*

// ============================================================
// windowSize 测试 — 对齐 gix-negotiate/tests/negotiate.rs::window_size
// ============================================================

@Test
func testWindowSizeInitialValue(): Unit {
    // 对齐 Rust: initial_value_without_previous_window_size
    if (windowSize(false, None) != 16) {
        throw Exception("initial value should be 16")
    }
    if (windowSize(true, None) != 16) {
        throw Exception("initial value should be 16 for stateless too")
    }
}

@Test
func testWindowSizeStateless(): Unit {
    // 对齐 Rust: transport_is_stateless
    var prev: ?Int64 = Some(16)
    let expected: Array<Int64> = [32, 64, 128, 256, 512, 1024, 2048, 4096, 8192, 16384, 18022, 19824]
    for (i in 0..expected.size) {
        let sz = windowSize(true, prev)
        if (sz != expected[i]) {
            throw Exception(
                "stateless step " + i.toString() + " should be " + expected[i].toString() + ", got " + sz.toString())
        }
        prev = Some(sz)
    }
}

@Test
func testWindowSizeNotStateless(): Unit {
    // 对齐 Rust: transport_is_not_stateless
    var prev: ?Int64 = Some(16)
    let sz1 = windowSize(false, prev)
    if (sz1 != 32) {
        throw Exception("16->32, got " + sz1.toString())
    }
    prev = Some(sz1)
    let sz2 = windowSize(false, prev)
    if (sz2 != 64) {
        throw Exception("32->64, got " + sz2.toString())
    }
    prev = Some(sz2)
    let sz3 = windowSize(false, prev)
    if (sz3 != 96) {
        throw Exception("64->96, got " + sz3.toString())
    }
    prev = Some(sz3)
    let sz4 = windowSize(false, prev)
    if (sz4 != 128) {
        throw Exception("96->128, got " + sz4.toString())
    }
}

@Test
func testWindowSizeNotStatelessFromSmall(): Unit {
    // 对齐 Rust: transport_is_not_stateless 从小值开始
    var prev: ?Int64 = Some(4)
    let expected: Array<Int64> = [8, 16, 32, 64, 96]
    for (i in 0..expected.size) {
        let sz = windowSize(false, prev)
        if (sz != expected[i]) {
            throw Exception("step " + i.toString() + " should be " + expected[i].toString() + ", got " + sz.toString())
        }
        prev = Some(sz)
    }
}

// ============================================================
// Flags 测试 — 对齐 Rust gix_negotiate::Flags
// ============================================================

@Test
func testFlagsContains(): Unit {
    let f = Flags(Flags.COMMON | Flags.SEEN)
    if (!f.contains(Flags.COMMON)) {
        throw Exception("should contain COMMON")
    }
    if (!f.contains(Flags.SEEN)) {
        throw Exception("should contain SEEN")
    }
    if (f.contains(Flags.POPPED)) {
        throw Exception("should not contain POPPED")
    }
}

@Test
func testFlagsSet(): Unit {
    let f = Flags.default()
    f.set(Flags.COMMON)
    if (!f.contains(Flags.COMMON)) {
        throw Exception("should contain COMMON after set")
    }
    f.set(Flags.SEEN)
    if (!f.contains(Flags.SEEN)) {
        throw Exception("should contain SEEN after set")
    }
}

@Test
func testFlagsUnset(): Unit {
    let f = Flags(Flags.COMMON | Flags.SEEN)
    f.unset(Flags.COMMON)
    if (f.contains(Flags.COMMON)) {
        throw Exception("should not contain COMMON after unset")
    }
    if (!f.contains(Flags.SEEN)) {
        throw Exception("should still contain SEEN")
    }
}

@Test
func testFlagsIntersects(): Unit {
    let f = Flags(Flags.COMMON | Flags.ADVERTISED)
    if (!f.intersects(Flags.COMMON)) {
        throw Exception("should intersect COMMON")
    }
    if (!f.intersects(Flags.ADVERTISED)) {
        throw Exception("should intersect ADVERTISED")
    }
    if (f.intersects(Flags.SEEN)) {
        throw Exception("should not intersect SEEN")
    }
}

// ============================================================
// Algorithm 测试 — 对齐 Rust gix_negotiate::Algorithm
// ============================================================

@Test
func testCreateNegotiatorNoop(): Unit {
    let n = createNegotiator(Algorithm.Noop)
    if (n.nextHave(Graph()).isSome()) {
        throw Exception("noop should return None for nextHave")
    }
}

@Test
func testCreateNegotiatorConsecutive(): Unit {
    let n = createNegotiator(Algorithm.Consecutive)
    let graph = Graph()
    // 没有添加 tip，应返回 None
    if (n.nextHave(graph).isSome()) {
        throw Exception("consecutive without tips should return None")
    }
}

@Test
func testCreateNegotiatorSkipping(): Unit {
    let n = createNegotiator(Algorithm.Skipping)
    let graph = Graph()
    if (n.nextHave(graph).isSome()) {
        throw Exception("skipping without tips should return None")
    }
}

// ============================================================
// NoopNegotiator 测试 — 对齐 Rust gix_negotiate::noop
// ============================================================

@Test
func testNoopNegotiatorKnownCommon(): Unit {
    let n = NoopNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    n.knownCommon(id, graph)
    // noop 不应改变图
    if (graph.contains(id)) {
        throw Exception("noop should not modify graph")
    }
}

@Test
func testNoopNegotiatorAddTip(): Unit {
    let n = NoopNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    n.addTip(id, graph)
    if (graph.contains(id)) {
        throw Exception("noop should not modify graph")
    }
}

@Test
func testNoopNegotiatorNextHave(): Unit {
    let n = NoopNegotiator()
    if (n.nextHave(Graph()).isSome()) {
        throw Exception("noop should always return None")
    }
}

@Test
func testNoopNegotiatorInCommonWithRemote(): Unit {
    let n = NoopNegotiator()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (n.inCommonWithRemote(id, Graph())) {
        throw Exception("noop should always return false")
    }
}

// ============================================================
// ConsecutiveNegotiator 测试 — 对齐 Rust gix_negotiate::consecutive
// ============================================================

@Test
func testConsecutiveAddTipAndNextHave(): Unit {
    let n = ConsecutiveNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.addTip(id, graph)
    let result = n.nextHave(graph)
    if (result.isNone()) {
        throw Exception("should return Some after adding tip")
    }
    if (let Some(haveId) <- result) {
        if (haveId.toHexString() != id.toHexString()) {
            throw Exception("should return the tip id")
        }
    }
}

@Test
func testConsecutiveKnownCommon(): Unit {
    let n = ConsecutiveNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.knownCommon(id, graph)
    // known common 应标记为 COMMON_REF 和 SEEN
    if (!node.data.flags.contains(Flags.COMMON_REF)) {
        throw Exception("should have COMMON_REF flag")
    }
    if (!node.data.flags.contains(Flags.SEEN)) {
        throw Exception("should have SEEN flag")
    }
}

@Test
func testConsecutiveInCommonWithRemote(): Unit {
    let n = ConsecutiveNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.addTip(id, graph)
    // 先获取 have
    let haveOpt = n.nextHave(graph)
    // 然后确认共有
    let wasCommon = n.inCommonWithRemote(id, graph)
    if (wasCommon) {
        throw Exception("was not known to be common before")
    }
    // 现在应该标记为 COMMON
    if (!node.data.flags.contains(Flags.COMMON)) {
        throw Exception("should be marked COMMON after in_common_with_remote")
    }
}

// ============================================================
// SkippingNegotiator 测试 — 对齐 Rust gix_negotiate::skipping
// ============================================================

@Test
func testSkippingAddTipAndNextHave(): Unit {
    let n = SkippingNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.addTip(id, graph)
    let result = n.nextHave(graph)
    if (result.isNone()) {
        throw Exception("should return Some after adding tip")
    }
}

@Test
func testSkippingKnownCommon(): Unit {
    let n = SkippingNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.knownCommon(id, graph)
    if (!node.data.flags.contains(Flags.ADVERTISED)) {
        throw Exception("should have ADVERTISED flag")
    }
    if (!node.data.flags.contains(Flags.SEEN)) {
        throw Exception("should have SEEN flag")
    }
}

@Test
func testSkippingInCommonWithRemote(): Unit {
    let n = SkippingNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    n.addTip(id, graph)
    let _ = n.nextHave(graph)
    let wasCommon = n.inCommonWithRemote(id, graph)
    if (wasCommon) {
        throw Exception("was not known to be common before")
    }
    if (!node.data.flags.contains(Flags.COMMON)) {
        throw Exception("should be marked COMMON after in_common_with_remote")
    }
}

@Test
func testSkippingAlreadySeenTip(): Unit {
    let n = SkippingNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 1000)
    node.data.flags.set(Flags.SEEN)
    n.addTip(id, graph)
    // 已经 SEEN 的 tip 不应重复添加
    // 但这里主要验证不会崩溃
}

// ============================================================
// Graph 测试
// ============================================================

@Test
func testGraphGetOrInsert(): Unit {
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let node = graph.getOrInsert(id, 500)
    if (node.commitTime != 500) {
        throw Exception("commit time should be 500")
    }
    let node2 = graph.getOrInsert(id, 999)
    // 已存在的节点不应被覆盖
    if (node2.commitTime != 500) {
        throw Exception("existing node should not be overwritten")
    }
}

@Test
func testGraphContains(): Unit {
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    if (graph.contains(id)) {
        throw Exception("should not contain id before insertion")
    }
    let _ = graph.getOrInsert(id, 0)
    if (!graph.contains(id)) {
        throw Exception("should contain id after insertion")
    }
}

// ============================================================
// NegotiateState 测试 — 对齐 Rust gix_protocol::fetch::negotiate::one_round::State
// ============================================================

@Test
func testNegotiateStateCreation(): Unit {
    let state = NegotiateState(false)
    if (state.havesToSend != 16) {
        throw Exception("initial havesToSend should be 16")
    }
    if (state.seenAck) {
        throw Exception("initial seenAck should be false")
    }
    if (state.inVain != 0) {
        throw Exception("initial inVain should be 0")
    }
    if (state.commonCommits.isSome()) {
        throw Exception("stateful connection should have None commonCommits")
    }
}

@Test
func testNegotiateStateCreationStateless(): Unit {
    let state = NegotiateState(true)
    if (state.commonCommits.isNone()) {
        throw Exception("stateless connection should have Some commonCommits")
    }
}

@Test
func testNegotiateStateAdjustWindowSize(): Unit {
    let state = NegotiateState(false)
    state.adjustWindowSize()
    if (state.havesToSend != 32) {
        throw Exception("16->32, got " + state.havesToSend.toString())
    }
}

@Test
func testNegotiateStateConnectionIsStateless(): Unit {
    let stateful = NegotiateState(false)
    if (stateful.connectionIsStateless()) {
        throw Exception("should not be stateless")
    }
    let stateless = NegotiateState(true)
    if (!stateless.connectionIsStateless()) {
        throw Exception("should be stateless")
    }
}

// ============================================================
// Round 测试
// ============================================================

@Test
func testRoundConstruct(): Unit {
    let r = Round(5, 10, 16, true)
    if (r.havesSent != 5) {
        throw Exception("havesSent should be 5")
    }
    if (r.inVain != 10) {
        throw Exception("inVain should be 10")
    }
    if (r.havesToSend != 16) {
        throw Exception("havesToSend should be 16")
    }
    if (!r.previousResponseHadAtLeastOneInCommon) {
        throw Exception("previousResponseHadAtLeastOneInCommon should be true")
    }
}
