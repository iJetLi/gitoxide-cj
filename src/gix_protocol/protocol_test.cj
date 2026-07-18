// 文件：protocol_test.cj
// 用途：gix_protocol 包的单元测试，对齐 Rust gitoxide gix-protocol 测试
// 所属包：gix.gix_protocol
// 对齐来源：gix-protocol/tests/protocol/*.rs, gix-protocol/tests/blocking-protocol.rs

package gitoxide.gix_protocol

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_negotiate.*
import std.collection.*

// ============================================================
// FetchConnection 构造测试 — 对齐 gix-protocol/tests/protocol/fetch_connection.rs
// ============================================================

@Test
func testFetchConnectionConstruct(): Unit {
    // 对齐 Rust: FetchConnection::new(transport, url)
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    if (!(conn.remoteUrl.scheme == Scheme.Https)) {
        throw Exception("scheme should be Https")
    }
}

@Test
func testFetchConnectionFetchReturnsNone(): Unit {
    // 对齐 Rust: FetchConnection::fetch — DummyClientTransport 返回 None
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    let wants = ArrayList<ObjectId>()
    let haves = ArrayList<ObjectId>()
    let result = conn.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("dummy fetch should return None")
    }
}

@Test
func testFetchConnectionTransportAccessible(): Unit {
    // 对齐 Rust: FetchConnection 保留 transport 引用
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    // 验证 transport 字段可访问
    let handshakeResult = conn.transport.handshake(url, Service.gitUploadPack())
    if (!handshakeResult.isNone()) {
        throw Exception("dummy transport handshake should return None")
    }
}

@Test
func testFetchConnectionWithSshUrl(): Unit {
    // 对齐 Rust: FetchConnection 使用 SSH URL
    let transport = DummyClientTransport()
    let url = Url(Scheme.Ssh, Some("git"), Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    if (!(conn.remoteUrl.scheme == Scheme.Ssh)) {
        throw Exception("scheme should be Ssh")
    }
}

@Test
func testFetchConnectionWithFileUrl(): Unit {
    // 对齐 Rust: FetchConnection 使用本地文件 URL
    let transport = DummyClientTransport()
    let url = Url(Scheme.File, Option<String>.None, Option<String>.None, Option<Int64>.None, "/path/to/repo.git")
    let conn = FetchConnection(transport, url)
    if (!(conn.remoteUrl.scheme == Scheme.File)) {
        throw Exception("scheme should be File")
    }
}

@Test
func testFetchConnectionFetchEmptyWantsAndHaves(): Unit {
    // 对齐 Rust: fetch 空的 wants 和 haves 列表
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/repo.git")
    let conn = FetchConnection(transport, url)
    let wants = ArrayList<ObjectId>()
    let haves = ArrayList<ObjectId>()
    let result = conn.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("should return None with dummy transport")
    }
}

@Test
func testFetchConnectionFetchWithWants(): Unit {
    // 对齐 Rust: fetch 包含 wants 列表
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/repo.git")
    let conn = FetchConnection(transport, url)
    let wants = ArrayList<ObjectId>()
    wants.add(ObjectId.null(HashKind.Sha1))
    let haves = ArrayList<ObjectId>()
    let result = conn.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("should return None with dummy transport")
    }
}

// ============================================================
// LsRemoteResult 测试 — 对齐 gix-protocol/tests/protocol/ls_remote.rs
// ============================================================

@Test
func testLsRemoteResultConstruct(): Unit {
    // 对齐 Rust: LsRemoteResult { refs, capabilities }
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    caps.add("multi_ack")
    caps.add("thin-pack")
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 0) {
        throw Exception("refs should be empty")
    }
    if (result.capabilities.size != 2) {
        throw Exception("capabilities should have 2 entries")
    }
    if (result.capabilities[0] != "multi_ack") {
        throw Exception("first capability should be 'multi_ack'")
    }
}

@Test
func testLsRemoteResultWithRefs(): Unit {
    // 对齐 Rust: LsRemoteResult 包含远程引用
    let id = ObjectId.null(HashKind.Sha1)
    let refs = ArrayList<Ref>()
    refs.add(Ref.Direct("refs/heads/main", id))
    let caps = ArrayList<String>()
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 1) {
        throw Exception("refs should have 1 entry")
    }
    if (refName(result.refs[0]) != "refs/heads/main") {
        throw Exception("ref name should be 'refs/heads/main'")
    }
}

@Test
func testLsRemoteResultWithMultipleRefs(): Unit {
    // 对齐 Rust: LsRemoteResult 包含多个远程引用
    let id = ObjectId.null(HashKind.Sha1)
    let refs = ArrayList<Ref>()
    refs.add(Ref.Direct("refs/heads/main", id))
    refs.add(Ref.Direct("refs/heads/develop", id))
    refs.add(Ref.Direct("refs/tags/v1.0", id))
    let caps = ArrayList<String>()
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 3) {
        throw Exception("should have 3 refs")
    }
    if (refName(result.refs[0]) != "refs/heads/main") {
        throw Exception("first ref mismatch")
    }
    if (refName(result.refs[1]) != "refs/heads/develop") {
        throw Exception("second ref mismatch")
    }
    if (refName(result.refs[2]) != "refs/tags/v1.0") {
        throw Exception("third ref mismatch")
    }
}

@Test
func testLsRemoteResultWithCapabilities(): Unit {
    // 对齐 Rust: LsRemoteResult 包含能力声明
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    caps.add("multi_ack_detailed")
    caps.add("no-done")
    caps.add("side-band-64k")
    caps.add("ofs-delta")
    let result = LsRemoteResult(refs, caps)
    if (result.capabilities.size != 4) {
        throw Exception("should have 4 capabilities")
    }
}

@Test
func testLsRemoteResultEmpty(): Unit {
    // 对齐 Rust: LsRemoteResult 空结果
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 0) {
        throw Exception("refs should be empty")
    }
    if (result.capabilities.size != 0) {
        throw Exception("capabilities should be empty")
    }
}

// ============================================================
// lsRemote 函数测试 — 对齐 gix-protocol/tests/protocol/ls_remote.rs
// ============================================================

@Test
func testLsRemoteWithDummyTransport(): Unit {
    // 对齐 Rust: ls_remote 需真实传输层
    // 【无法对齐】原版 ls_remote 测试依赖真实网络握手或本地 Git 服务器
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let result = lsRemote(url, transport)
    if (!result.isNone()) {
        throw Exception("dummy lsRemote should return None")
    }
}

@Test
func testLsRemoteWithReturningTransport(): Unit {
    // 对齐 Rust: ls_remote 使用返回数据的 transport
    let transport = ReturningClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let result = lsRemote(url, transport)
    if (result.isNone()) {
        throw Exception("should return Some with returning transport")
    }
    let r = result.getOrThrow()
    if (r.refs.size != 1) {
        throw Exception("should have 1 ref")
    }
    if (r.capabilities.size != 1) {
        throw Exception("should have 1 capability")
    }
}

// ============================================================
// FetchArguments 测试 — 对齐 gix-protocol/tests/protocol/fetch/arguments.rs
// ============================================================

@Test
func testFetchArgumentsConstruct(): Unit {
    let features = ArrayList<String>()
    features.add("multi_ack_detailed")
    features.add("side-band-64k")
    let args = FetchArguments(ProtocolVersion.V1, features)
    if (args.isEmpty()) {
        throw Exception("should not be empty with features")
    }
}

@Test
func testFetchArgumentsWant(): Unit {
    let features = ArrayList<String>()
    let args = FetchArguments(ProtocolVersion.V1, features)
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    args.want(id)
    if (args.isEmpty()) {
        throw Exception("should not be empty after want")
    }
    var foundWant = false
    for (a in args.allArgs()) {
        if (a.startsWith("want ")) {
            foundWant = true
        }
    }
    if (!foundWant) {
        throw Exception("should have want line")
    }
}

@Test
func testFetchArgumentsHave(): Unit {
    let features = ArrayList<String>()
    let args = FetchArguments(ProtocolVersion.V1, features)
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    args.have(id)
    var foundHave = false
    for (a in args.allArgs()) {
        if (a.startsWith("have ")) {
            foundHave = true
        }
    }
    if (!foundHave) {
        throw Exception("should have have line")
    }
}

@Test
func testFetchArgumentsWantWithFeatures(): Unit {
    // 对齐 Rust: V1 版本第一个 want 带能力声明
    let features = ArrayList<String>()
    features.add("multi_ack_detailed")
    features.add("side-band-64k")
    let args = FetchArguments(ProtocolVersion.V1, features)
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    args.want(id)
    // 第一个 want 应包含能力声明
    var firstWant = ""
    for (a in args.args) {
        if (a.startsWith("want ")) {
            firstWant = a
            break
        }
    }
    if (!firstWant.contains("multi_ack_detailed")) {
        throw Exception("first want should include capabilities")
    }
}

@Test
func testFetchArgumentsShallow(): Unit {
    let features = ArrayList<String>()
    features.add("shallow")
    let args = FetchArguments(ProtocolVersion.V1, features)
    if (!args.canUseShallow()) {
        throw Exception("should support shallow")
    }
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    args.addShallow(id)
    var foundShallow = false
    for (a in args.allArgs()) {
        if (a.startsWith("shallow ")) {
            foundShallow = true
        }
    }
    if (!foundShallow) {
        throw Exception("should have shallow line")
    }
}

@Test
func testFetchArgumentsFilter(): Unit {
    let features = ArrayList<String>()
    features.add("filter")
    let args = FetchArguments(ProtocolVersion.V1, features)
    if (!args.canUseFilter()) {
        throw Exception("should support filter")
    }
}

@Test
func testFetchArgumentsIsStateless(): Unit {
    let features = ArrayList<String>()
    let args = FetchArguments(ProtocolVersion.V2, features)
    if (!args.isStateless(false)) {
        throw Exception("V2 should always be stateless")
    }
    let argsV1 = FetchArguments(ProtocolVersion.V1, features)
    if (argsV1.isStateless(false)) {
        throw Exception("V1 with stateful transport should not be stateless")
    }
    if (!argsV1.isStateless(true)) {
        throw Exception("V1 with stateless transport should be stateless")
    }
}

// ============================================================
// handshake 函数测试 — 对齐 gix-protocol::handshake
// ============================================================

@Test
func testHandshakeWithDummyTransport(): Unit {
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let result = handshake(transport, url, Service.gitUploadPack())
    if (!result.isNone()) {
        throw Exception("dummy handshake should return None")
    }
}

@Test
func testHandshakeWithReturningTransport(): Unit {
    let transport = ReturningClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let result = handshake(transport, url, Service.gitUploadPack())
    if (result.isNone()) {
        throw Exception("should return Some with returning transport")
    }
    if (let Some(h) <- result) {
        if (h.serverProtocolVersion != ProtocolVersion.V2) {
            throw Exception("should be V2")
        }
        if (h.refs.isSome()) {
            throw Exception("V2 should not have refs in handshake")
        }
    }
}

@Test
func testHandshakeV1WithReturningTransport(): Unit {
    let transport = ReturningV1ClientTransport()
    let url = Url(Scheme.Https, Option<String>.None, Some("github.com"), Option<Int64>.None, "/user/repo.git")
    let result = handshake(transport, url, Service.gitUploadPack())
    if (result.isNone()) {
        throw Exception("should return Some")
    }
    if (let Some(h) <- result) {
        if (h.serverProtocolVersion != ProtocolVersion.V1) {
            throw Exception("should be V1")
        }
        if (h.refs.isNone()) {
            throw Exception("V1 should have refs in handshake")
        }
    }
}

// ============================================================
// oneRound 测试 — 对齐 gix_protocol::fetch::negotiate::one_round
// ============================================================

@Test
func testOneRoundNoPreviousResponse(): Unit {
    let negotiator = ConsecutiveNegotiator()
    let graph = Graph()
    let state = NegotiateState(false)
    let features = ArrayList<String>()
    let args = FetchArguments(ProtocolVersion.V1, features)
    let (round, isDone) = oneRound(negotiator, graph, state, args, Option<Response>.None)
    if (round.havesSent != 0) {
        throw Exception("no tips, should send 0 haves")
    }
    if (!isDone) {
        throw Exception("should be done when no haves sent")
    }
}

@Test
func testOneRoundWithTip(): Unit {
    let negotiator = ConsecutiveNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let _ = graph.getOrInsert(id, 1000)
    negotiator.addTip(id, graph)
    let state = NegotiateState(false)
    let features = ArrayList<String>()
    let args = FetchArguments(ProtocolVersion.V1, features)
    let (round, isDone) = oneRound(negotiator, graph, state, args, Option<Response>.None)
    if (round.havesSent == 0) {
        throw Exception("should send at least 1 have")
    }
}

@Test
func testOneRoundWithPreviousResponse(): Unit {
    let negotiator = ConsecutiveNegotiator()
    let graph = Graph()
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let _ = graph.getOrInsert(id, 1000)
    negotiator.addTip(id, graph)
    // 先执行一轮获取 have
    let state1 = NegotiateState(false)
    let features1 = ArrayList<String>()
    let args1 = FetchArguments(ProtocolVersion.V1, features1)
    let _ = oneRound(negotiator, graph, state1, args1, Option<Response>.None)
    // 模拟远程响应
    var acks = ArrayList<Acknowledgement>()
    acks.add(Acknowledgement.Common(id))
    var shallows = ArrayList<ShallowUpdate>()
    let prevResponse = Response(acks, shallows, false)
    let state2 = NegotiateState(false)
    let features2 = ArrayList<String>()
    let args2 = FetchArguments(ProtocolVersion.V1, features2)
    let (round2, _) = oneRound(negotiator, graph, state2, args2, Some(prevResponse))
    if (!round2.previousResponseHadAtLeastOneInCommon) {
        throw Exception("should have seen ack")
    }
}

// ============================================================
// NegotiateAction 测试
// ============================================================

@Test
func testNegotiateActionMatch(): Unit {
    let action = NegotiateAction.NoChange
    match (action) {
        case NegotiateAction.NoChange => ()
        case _ => throw Exception("should be NoChange")
    }
    let action2 = NegotiateAction.SkipToRefUpdate
    match (action2) {
        case NegotiateAction.SkipToRefUpdate => ()
        case _ => throw Exception("should be SkipToRefUpdate")
    }
    let action3 = NegotiateAction.MustNegotiate
    match (action3) {
        case NegotiateAction.MustNegotiate => ()
        case _ => throw Exception("should be MustNegotiate")
    }
}

// ============================================================
// RefMap 测试
// ============================================================

@Test
func testRefMapConstruct(): Unit {
    let refMap = RefMap()
    if (refMap.mappings.size != 0) {
        throw Exception("mappings should be empty")
    }
    if (refMap.remoteRefs.size != 0) {
        throw Exception("remoteRefs should be empty")
    }
}

@Test
func testRefMapWithMappings(): Unit {
    let refMap = RefMap()
    let id = ObjectId.null(HashKind.Sha1)
    let remote = Ref.Direct("refs/heads/main", id)
    refMap.mappings.add(Mapping(remote, Some("refs/remotes/origin/main")))
    if (refMap.mappings.size != 1) {
        throw Exception("should have 1 mapping")
    }
    if (refName(refMap.mappings[0].remote) != "refs/heads/main") {
        throw Exception("remote name mismatch")
    }
}

// ============================================================
// Handshake 测试 — 对齐 Rust gix_protocol::handshake::hero::Handshake
// ============================================================

@Test
func testHandshakeConstruct(): Unit {
    let refs = ArrayList<Ref>()
    let caps = Capabilities()
    let h = Handshake(ProtocolVersion.V2, Option<ArrayList<Ref>>.None, Option<ArrayList<ShallowUpdate>>.None, caps)
    if (!(h.serverProtocolVersion == ProtocolVersion.V2)) {
        throw Exception("should be V2")
    }
    if (h.refs.isSome()) {
        throw Exception("refs should be None")
    }
}

@Test
func testHandshakeWithV1Refs(): Unit {
    let refs = ArrayList<Ref>()
    refs.add(Ref.Direct("HEAD", ObjectId.null(HashKind.Sha1)))
    let caps = Capabilities()
    let h = Handshake(ProtocolVersion.V1, Some(refs), Option<ArrayList<ShallowUpdate>>.None, caps)
    if (h.refs.isNone()) {
        throw Exception("V1 should have refs")
    }
    if (let Some(r) <- h.refs) {
        if (r.size != 1) {
            throw Exception("should have 1 ref")
        }
    }
}

// ============================================================
// commandAsStr 测试
// ============================================================

@Test
func testCommandAsStr(): Unit {
    if (commandAsStr(Command.LsRefs) != "ls-refs") {
        throw Exception("LsRefs should be 'ls-refs'")
    }
    if (commandAsStr(Command.Fetch) != "fetch") {
        throw Exception("Fetch should be 'fetch'")
    }
}

// ============================================================
// 测试辅助：DummyClientTransport 实现 ClientTransport 接口
// ============================================================

class DummyClientTransport <: ClientTransport {
    public func handshake(url: Url, service: Service): ?HandshakeResult {
        None
    }
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        None
    }
    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        None
    }
}

// 返回数据的 V2 transport 实现
class ReturningClientTransport <: ClientTransport {
    public func handshake(url: Url, service: Service): ?HandshakeResult {
        let refs = ArrayList<Ref>()
        refs.add(Ref.Direct("refs/heads/main", ObjectId.null(HashKind.Sha1)))
        let caps = ArrayList<String>()
        caps.add("multi_ack")
        Some(HandshakeResult(refs, ProtocolVersion.V2, caps))
    }
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        None
    }
    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        None
    }
}

// 返回 V1 数据的 transport 实现
class ReturningV1ClientTransport <: ClientTransport {
    public func handshake(url: Url, service: Service): ?HandshakeResult {
        let refs = ArrayList<Ref>()
        refs.add(Ref.Direct("HEAD", ObjectId.null(HashKind.Sha1)))
        refs.add(Ref.Direct("refs/heads/main", ObjectId.null(HashKind.Sha1)))
        let caps = ArrayList<String>()
        caps.add("multi_ack_detailed")
        caps.add("side-band-64k")
        Some(HandshakeResult(refs, ProtocolVersion.V1, caps))
    }
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        None
    }
    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        None
    }
}
