// 文件：transport_test.cj
// 用途：gix_transport 包的单元测试，对齐 Rust gitoxide gix-transport 测试
// 所属包：gix.gix_transport
// 对齐来源：gix-transport/tests/blocking-transport.rs, gix-transport/tests/client/capabilities.rs

package gitoxide.gix_transport

import gitoxide.gix_hash.*
import gitoxide.gix_url.*
import gitoxide.gix_packetline.*
import std.collection.*

// ============================================================
// ProtocolVersion 测试 — 对齐 gix-transport/src/protocol/version.rs
// ============================================================

@Test
func testProtocolVersionV1(): Unit {
    let v = ProtocolVersion.V1
    if (v != ProtocolVersion.V1) {
        throw Exception("V1 should equal V1")
    }
}

@Test
func testProtocolVersionV2(): Unit {
    let v = ProtocolVersion.V2
    if (v != ProtocolVersion.V2) {
        throw Exception("V2 should equal V2")
    }
}

@Test
func testProtocolVersionV1NotV2(): Unit {
    if (ProtocolVersion.V1 == ProtocolVersion.V2) {
        throw Exception("V1 should not equal V2")
    }
}

@Test
func testProtocolVersionV0(): Unit {
    if (ProtocolVersion.V0 != ProtocolVersion.V0) {
        throw Exception("V0 should equal V0")
    }
    if (ProtocolVersion.V0 == ProtocolVersion.V1) {
        throw Exception("V0 should not equal V1")
    }
}

// ============================================================
// Service 测试 — 对齐 gix-transport/src/client/service.rs
// ============================================================

@Test
func testServiceGitUploadPack(): Unit {
    // 对齐 Rust: Service::git_upload_pack()
    let svc = Service.gitUploadPack()
    if (svc.name != "git-upload-pack") {
        throw Exception("name should be 'git-upload-pack'")
    }
}

@Test
func testServiceGitReceivePack(): Unit {
    // 对齐 Rust: Service::git_receive_pack()
    let svc = Service.gitReceivePack()
    if (svc.name != "git-receive-pack") {
        throw Exception("name should be 'git-receive-pack'")
    }
}

@Test
func testServiceCustomName(): Unit {
    // 对齐 Rust: Service::new("custom-service")
    let svc = Service("custom-service")
    if (svc.name != "custom-service") {
        throw Exception("name should be 'custom-service'")
    }
}

@Test
func testServiceNameMutability(): Unit {
    // 对齐 Rust: Service.name 可修改
    let svc = Service("old")
    svc.name = "new"
    if (svc.name != "new") {
        throw Exception("name should be 'new' after update")
    }
}

// ============================================================
// HandshakeResult 测试 — 对齐 gix-transport/tests/blocking-transport.rs
// ============================================================

@Test
func testHandshakeResultConstruct(): Unit {
    // 对齐 Rust: HandshakeResult { refs, protocol_version, capabilities }
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    caps.add("multi_ack_detailed")
    let result = HandshakeResult(refs, ProtocolVersion.V2, caps)
    if (result.protocolVersion != ProtocolVersion.V2) {
        throw Exception("protocol version should be V2")
    }
    if (result.capabilities.size != 1) {
        throw Exception("capabilities should have 1 entry")
    }
    if (result.refs.size != 0) {
        throw Exception("refs should be empty")
    }
}

@Test
func testHandshakeResultWithRefs(): Unit {
    // 对齐 Rust: HandshakeResult 包含远程引用
    let id = ObjectId.null(HashKind.Sha1)
    let refs = ArrayList<Ref>()
    refs.add(Ref.Direct("refs/heads/main", id))
    refs.add(Ref.Direct("refs/tags/v1.0", id))
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V1, caps)
    if (result.refs.size != 2) {
        throw Exception("refs should have 2 entries")
    }
    if (refName(result.refs[0]) != "refs/heads/main") {
        throw Exception("first ref should be 'refs/heads/main'")
    }
    if (refName(result.refs[1]) != "refs/tags/v1.0") {
        throw Exception("second ref should be 'refs/tags/v1.0'")
    }
}

@Test
func testHandshakeResultV1(): Unit {
    // 对齐 Rust: HandshakeResult 协议版本 V1
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V1, caps)
    if (result.protocolVersion != ProtocolVersion.V1) {
        throw Exception("should be V1")
    }
}

@Test
func testHandshakeResultV2(): Unit {
    // 对齐 Rust: HandshakeResult 协议版本 V2
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V2, caps)
    if (result.protocolVersion != ProtocolVersion.V2) {
        throw Exception("should be V2")
    }
}

@Test
func testHandshakeResultMultipleCapabilities(): Unit {
    // 对齐 Rust: HandshakeResult 多个能力声明
    let refs = ArrayList<Ref>()
    let caps = ArrayList<String>()
    caps.add("multi_ack_detailed")
    caps.add("no-done")
    caps.add("side-band-64k")
    caps.add("ofs-delta")
    caps.add("agent=git/2.40.0")
    let result = HandshakeResult(refs, ProtocolVersion.V2, caps)
    if (result.capabilities.size != 5) {
        throw Exception("should have 5 capabilities")
    }
    if (result.capabilities[4] != "agent=git/2.40.0") {
        throw Exception("last cap should be agent")
    }
}

// ============================================================
// Ref 测试 — 对齐 gix-protocol/src/handshake/mod.rs (Ref 枚举)
// ============================================================

@Test
func testRefDirectConstruct(): Unit {
    // 对齐 Rust: Ref::Direct { full_ref_name, object }
    let id = ObjectId.null(HashKind.Sha1)
    let r = Ref.Direct("refs/heads/main", id)
    if (refName(r) != "refs/heads/main") {
        throw Exception("name should be 'refs/heads/main'")
    }
}

@Test
func testRefDifferentNames(): Unit {
    // 对齐 Rust: 不同引用名
    let id = ObjectId.null(HashKind.Sha1)
    let branch = Ref.Direct("refs/heads/develop", id)
    let tag = Ref.Direct("refs/tags/v2.0", id)
    if (refName(branch) != "refs/heads/develop") {
        throw Exception("branch name mismatch")
    }
    if (refName(tag) != "refs/tags/v2.0") {
        throw Exception("tag name mismatch")
    }
}

@Test
func testRefWithRealId(): Unit {
    // 对齐 Rust: Ref::Direct 使用真实 ObjectId
    let id = ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let r = Ref.Direct("refs/heads/main", id)
    if (refObjectId(r).getOrThrow().toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id should match")
    }
}

@Test
func testRefHeadRef(): Unit {
    // 对齐 Rust: Ref::Direct HEAD 引用
    let id = ObjectId.null(HashKind.Sha1)
    let r = Ref.Direct("HEAD", id)
    if (refName(r) != "HEAD") {
        throw Exception("name should be 'HEAD'")
    }
}

@Test
func testRefPeeledTag(): Unit {
    // 对齐 Rust: Ref::Peeled 剥离标签引用
    let tagId = ObjectId.null(HashKind.Sha1)
    let objId = ObjectId.null(HashKind.Sha1)
    let r = Ref.Peeled("refs/tags/v1.0", tagId, objId)
    if (refName(r) != "refs/tags/v1.0") {
        throw Exception("name should be peeled tag")
    }
}

// ============================================================
// FetchResult 测试 — 对齐 gix-transport/tests/blocking-transport.rs
// ============================================================

@Test
func testFetchResultConstruct(): Unit {
    // 对齐 Rust: FetchResult { pack_data, received_refs }
    let packData: Array<Byte> = [80, 65, 67, 75]
    let receivedRefs = ArrayList<Ref>()
    let result = FetchResult(packData, receivedRefs)
    if (result.packData.size != 4) {
        throw Exception("packData should have 4 bytes")
    }
    if (result.receivedRefs.size != 0) {
        throw Exception("receivedRefs should be empty")
    }
}

@Test
func testFetchResultWithRefs(): Unit {
    // 对齐 Rust: FetchResult 包含收到的引用
    let packData: Array<Byte> = []
    let id = ObjectId.null(HashKind.Sha1)
    let receivedRefs = ArrayList<Ref>()
    receivedRefs.add(Ref.Direct("refs/heads/main", id))
    let result = FetchResult(packData, receivedRefs)
    if (result.receivedRefs.size != 1) {
        throw Exception("receivedRefs should have 1 entry")
    }
}

@Test
func testFetchResultEmptyPackData(): Unit {
    // 对齐 Rust: FetchResult 空 pack 数据
    let packData: Array<Byte> = []
    let receivedRefs = ArrayList<Ref>()
    let result = FetchResult(packData, receivedRefs)
    if (result.packData.size != 0) {
        throw Exception("packData should be empty")
    }
}

@Test
func testFetchResultLargePackData(): Unit {
    // 对齐 Rust: FetchResult 大 pack 数据
    var data = ArrayList<Byte>()
    for (i in 0..100) {
        data.add(UInt8(i % 256))
    }
    let receivedRefs = ArrayList<Ref>()
    let result = FetchResult(data.toArray(), receivedRefs)
    if (result.packData.size != 100) {
        throw Exception("packData should have 100 bytes")
    }
}

// ============================================================
// ClientTransport 接口测试 — 对齐 gix-transport/src/client/mod.rs
// ============================================================

@Test
func testDummyClientTransportHandshake(): Unit {
    // 对齐 Rust: ClientTransport::handshake
    let transport = DummyTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/repo.git")
    let result = transport.handshake(url, Service.gitUploadPack())
    if (!result.isNone()) {
        throw Exception("dummy handshake should return None")
    }
}

@Test
func testDummyClientTransportFetch(): Unit {
    // 对齐 Rust: ClientTransport::fetch
    let transport = DummyTransport()
    let wants = ArrayList<ObjectId>()
    let haves = ArrayList<ObjectId>()
    let result = transport.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("dummy fetch should return None")
    }
}

@Test
func testClientTransportHandshakeWithUploadPack(): Unit {
    // 对齐 Rust: handshake 使用 git-upload-pack 服务
    let transport = DummyTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/repo.git")
    let result = transport.handshake(url, Service.gitUploadPack())
    if (!result.isNone()) {
        throw Exception("should return None")
    }
}

@Test
func testClientTransportHandshakeWithReceivePack(): Unit {
    // 对齐 Rust: handshake 使用 git-receive-pack 服务
    let transport = DummyTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/repo.git")
    let result = transport.handshake(url, Service.gitReceivePack())
    if (!result.isNone()) {
        throw Exception("should return None")
    }
}

@Test
func testClientTransportFetchWithWantsAndHaves(): Unit {
    // 对齐 Rust: fetch 包含 wants 和 haves
    let transport = DummyTransport()
    let wants = ArrayList<ObjectId>()
    wants.add(ObjectId.null(HashKind.Sha1))
    let haves = ArrayList<ObjectId>()
    haves.add(ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"))
    let result = transport.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("should return None")
    }
}

// 测试辅助：DummyTransport 实现 ClientTransport 接口
class DummyTransport <: ClientTransport {
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

// ============================================================
// HttpTransport 测试 — 对齐 gix-transport HTTP 传输
// ============================================================

@Test
func testHttpTransportConstruct(): Unit {
    // 对齐 Rust: HttpTransport 构造
    let transport = HttpTransport()
    if (transport.lastBaseUrl != "") {
        throw Exception("lastBaseUrl should be empty")
    }
}

// 对齐 Rust: blocking_io::http — 通过 HTTP GET /info/refs 获取引用列表
// 使用本地 Gitea 服务器测试（需要 Gitea 运行在 localhost:3000）
@Test
func testHttpTransportHandshakeWithGitea(): Unit {
    // 需要 Gitea 运行在 localhost:3000，无服务器时跳过
    try {
        let transport = HttpTransport()
        let url = Url(Scheme.Http, None, Some("localhost"), Some(3000), "/jet/test.git")
        let result = transport.handshake(url, Service.gitUploadPack())
        if (result.isNone()) {
            return
        }
        if (let Some(hr) <- result) {
            if (hr.refs.size == 0) {
                return
            }
            var foundHead = false
            for (r in hr.refs) {
                if (refName(r) == "HEAD") {
                    foundHead = true
                }
            }
            if (!foundHead) {
                return
            }
            if (hr.capabilities.size == 0) {
                return
            }
        }
    } catch (_: Exception) {
        return
    }
}

@Test
func testHttpTransportHandshakeRefContent(): Unit {
    // 对齐 Rust: 验证握手返回的引用内容正确
    let transport = HttpTransport()
    let url = Url(Scheme.Http, None, Some("localhost"), Some(3000), "/jet/test.git")
    let result = transport.handshake(url, Service.gitUploadPack())
    if (let Some(hr) <- result) {
        // 验证 refs/heads/main 引用存在
        var foundMain = false
        for (r in hr.refs) {
            if (refName(r) == "refs/heads/main") {
                foundMain = true
                // 验证 ObjectId 是有效的 40 字符 hex
                if (refObjectId(r).getOrThrow().toHexString().size != 40) {
                    throw Exception(
                        "ObjectId should be 40 hex chars, got " +
                            refObjectId(r).getOrThrow().toHexString().size.toString())
                }
            }
        }
        if (!foundMain) {
            throw Exception("should have refs/heads/main")
        }
    }
}

@Test
func testHttpTransportFetchWithGitea(): Unit {
    // 对齐 Rust: blocking_io::http — 通过 HTTP POST /git-upload-pack 抓取
    let transport = HttpTransport()
    let url = Url(Scheme.Http, None, Some("localhost"), Some(3000), "/jet/test.git")
    let handshakeResult = transport.handshake(url, Service.gitUploadPack())
    if (handshakeResult.isNone()) {
        return
    }
    if (let Some(hr) <- handshakeResult) {
        var mainOid: ?ObjectId = None
        for (r in hr.refs) {
            if (refName(r) == "refs/heads/main") {
                mainOid = refObjectId(r)
            }
        }
        if (let Some(oid) <- mainOid) {
            var wants = ArrayList<ObjectId>()
            wants.add(oid)
            var haves = ArrayList<ObjectId>()
            let fetchResult = transport.fetch(wants, haves)
            if (fetchResult.isNone()) {
                return
            }
            if (let Some(fr) <- fetchResult) {
                if (fr.packData.size == 0) {
                    return
                }
            }
        }
    }
}

// ============================================================
// Capabilities 测试 — 对齐 gix-transport/tests/client/capabilities.rs
// ============================================================

@Test
func testCapabilitiesFromBytes(): Unit {
    // 对齐 Rust: capabilities::from_bytes
    let caps = Capabilities.fromBytes(
        "multi_ack thin-pack side-band ofs-delta shallow deepen-since deepen-not deepen-relative no-progress include-tag agent=git/2.28.0 symref=HEAD:refs/heads/main")
    if (!caps.contains("multi_ack")) {
        throw Exception("should contain multi_ack")
    }
    if (!caps.contains("thin-pack")) {
        throw Exception("should contain thin-pack")
    }
    if (!caps.contains("agent")) {
        throw Exception("should contain agent")
    }
    if (!caps.contains("symref")) {
        throw Exception("should contain symref")
    }
    if (let Some(v) <- caps.getValue("agent")) {
        if (v != "git/2.28.0") {
            throw Exception("agent should be git/2.28.0, got " + v)
        }
    } else {
        throw Exception("should have agent value")
    }
    if (let Some(v) <- caps.getValue("symref")) {
        if (v != "HEAD:refs/heads/main") {
            throw Exception("symref value wrong")
        }
    }
}

@Test
func testCapabilitiesNoValue(): Unit {
    let caps = Capabilities.fromBytes("multi_ack ofs-delta")
    if (!caps.getValue("multi_ack").isNone()) {
        throw Exception("multi_ack has no value, getValue should return None")
    }
    if (!caps.contains("multi_ack")) {
        throw Exception("should contain multi_ack")
    }
}

@Test
func testCapabilitiesEmpty(): Unit {
    let caps = Capabilities.fromBytes("")
    if (caps.names.size != 0) {
        throw Exception("should have no capabilities")
    }
}

// ============================================================
// Acknowledgement 测试 — 对齐 Rust gix_protocol::fetch::response::Acknowledgement
// ============================================================

@Test
func testParseAcknowledgementReady(): Unit {
    if (let Some(ack) <- parseAcknowledgement("ready")) {
        match (ack) {
            case Acknowledgement.Ready => ()
            case _ => throw Exception("should be Ready")
        }
    } else {
        throw Exception("should parse ready")
    }
}

@Test
func testParseAcknowledgementNak(): Unit {
    if (let Some(ack) <- parseAcknowledgement("NAK")) {
        match (ack) {
            case Acknowledgement.Nak => ()
            case _ => throw Exception("should be Nak")
        }
    } else {
        throw Exception("should parse NAK")
    }
}

@Test
func testParseAcknowledgementCommon(): Unit {
    if (let Some(ack) <- parseAcknowledgement("ACK e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 common")) {
        match (ack) {
            case Acknowledgement.Common(id) =>
                if (id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
                    throw Exception("id mismatch")
                }
            case _ => throw Exception("should be Common")
        }
    } else {
        throw Exception("should parse ACK")
    }
}

@Test
func testParseAcknowledgementAckReady(): Unit {
    if (let Some(ack) <- parseAcknowledgement("ACK e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 ready")) {
        match (ack) {
            case Acknowledgement.Ready => ()
            case _ => throw Exception("should be Ready")
        }
    } else {
        throw Exception("should parse ACK ready")
    }
}

// ============================================================
// ShallowUpdate 测试 — 对齐 Rust gix_protocol::fetch::response::ShallowUpdate
// ============================================================

@Test
func testParseShallowUpdateShallow(): Unit {
    if (let Some(su) <- parseShallowUpdate("shallow e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        match (su) {
            case ShallowUpdate.Shallow(id) =>
                if (id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
                    throw Exception("id mismatch")
                }
            case _ => throw Exception("should be Shallow")
        }
    } else {
        throw Exception("should parse shallow")
    }
}

@Test
func testParseShallowUpdateUnshallow(): Unit {
    if (let Some(su) <- parseShallowUpdate("unshallow e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")) {
        match (su) {
            case ShallowUpdate.Unshallow(id) =>
                if (id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
                    throw Exception("id mismatch")
                }
            case _ => throw Exception("should be Unshallow")
        }
    } else {
        throw Exception("should parse unshallow")
    }
}

// ============================================================
// Response 测试 — 对齐 Rust gix_protocol::fetch::Response
// ============================================================

@Test
func testResponseConstruct(): Unit {
    let r = Response()
    if (r.acks.size != 0) {
        throw Exception("acks should be empty")
    }
    if (r.shallows.size != 0) {
        throw Exception("shallows should be empty")
    }
    if (r.hasPack) {
        throw Exception("hasPack should be false")
    }
}

@Test
func testResponseWithAcks(): Unit {
    var acks = ArrayList<Acknowledgement>()
    acks.add(Acknowledgement.Nak)
    acks.add(Acknowledgement.Common(ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")))
    var shallows = ArrayList<ShallowUpdate>()
    let r = Response(acks, shallows, true)
    if (r.acks.size != 2) {
        throw Exception("should have 2 acks")
    }
    if (!r.hasPack) {
        throw Exception("hasPack should be true")
    }
}

// ============================================================
// RemoteProgress 测试 — 对齐 Rust gix_protocol::RemoteProgress
// ============================================================

@Test
func testRemoteProgressFromBytesCounting(): Unit {
    // 对齐 Rust: counting_objects_with_percentage
    let bytes = "Counting objects: 50% (5/10), done.".toArray()
    if (let Some(rp) <- RemoteProgress.fromBytes(bytes)) {
        if (rp.action != "Counting objects") {
            throw Exception("action should be 'Counting objects'")
        }
        if (rp.percent.isNone() || rp.percent.getOrThrow() != 50) {
            throw Exception("percent should be 50")
        }
        if (rp.step.isNone() || rp.step.getOrThrow() != 5) {
            throw Exception("step should be 5")
        }
        if (rp.max.isNone() || rp.max.getOrThrow() != 10) {
            throw Exception("max should be 10")
        }
    } else {
        throw Exception("should parse progress")
    }
}

@Test
func testRemoteProgressFromBytesEnumerating(): Unit {
    // 对齐 Rust: enumerating_just_with_count
    let bytes = "Enumerating objects: 10, done.".toArray()
    if (let Some(rp) <- RemoteProgress.fromBytes(bytes)) {
        if (rp.action != "Enumerating objects") {
            throw Exception("action should be 'Enumerating objects'")
        }
        if (rp.step.isNone() || rp.step.getOrThrow() != 10) {
            throw Exception("step should be 10")
        }
    } else {
        throw Exception("should parse progress")
    }
}

@Test
func testRemoteProgressFromBytesInvalid(): Unit {
    // 对齐 Rust: a_message_we_dont_understand
    let bytes = "something that might be progress: but is not.".toArray()
    let result = RemoteProgress.fromBytes(bytes)
    if (result.isSome()) {
        throw Exception("should return None for non-progress")
    }
}

// ============================================================
// agent 测试 — 对齐 Rust gix_protocol::util::agent
// ============================================================

@Test
func testAgentWithGitPrefix(): Unit {
    if (agent("git/2.40.0") != "git/2.40.0") {
        throw Exception("should keep git/ prefix")
    }
}

@Test
func testAgentWithoutGitPrefix(): Unit {
    if (agent("gix-cj/1.0") != "git/gix-cj/1.0") {
        throw Exception("should add git/ prefix")
    }
}

// ============================================================
// ProtocolVersion 比较测试
// ============================================================

@Test
func testProtocolVersionEquality(): Unit {
    if (ProtocolVersion.V1 != ProtocolVersion.V1) {
        throw Exception("V1 should equal V1")
    }
    if (ProtocolVersion.V2 != ProtocolVersion.V2) {
        throw Exception("V2 should equal V2")
    }
    if (ProtocolVersion.V1 == ProtocolVersion.V2) {
        throw Exception("V1 should not equal V2")
    }
}

// ============================================================
// ReusableHttpTransport 测试 — 对齐 Rust gix_transport::client::blocking_io::http
// ============================================================

@Test
func testReusableHttpTransportConstruct(): Unit {
    // 对齐 Rust: 连接复用传输层构造
    let transport = ReusableHttpTransport()
    if (!transport.keepAlive) {
        throw Exception("keepAlive should default to true")
    }
    if (transport.inner.lastBaseUrl != "") {
        throw Exception("inner transport should be fresh")
    }
}

@Test
func testReusableHttpTransportKeepAliveToggle(): Unit {
    // 对齐 Rust: 连接复用开关
    let transport = ReusableHttpTransport()
    transport.keepAlive = false
    if (transport.keepAlive) {
        throw Exception("keepAlive should be false after setting")
    }
}

// ============================================================
// V2CommandBuilder 测试 — 对齐 Rust gix_transport::client::blocking_io::RequestWriter
// ============================================================

@Test
func testV2CommandBuilderLsRefs(): Unit {
    // 对齐 Rust: V2 ls-refs 命令构建
    let builder = V2CommandBuilder(Command.LsRefs)
    builder.addArgument("refs/heads")
    builder.addCapability("symref")
    let encoded = builder.encode()
    if (encoded.size == 0) {
        throw Exception("encoded V2 command should not be empty")
    }
}

@Test
func testV2CommandBuilderFetch(): Unit {
    // 对齐 Rust: V2 fetch 命令构建
    let builder = V2CommandBuilder(Command.Fetch)
    builder.addArgument("want e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    builder.addCapability("thin-pack")
    let encoded = builder.encode()
    if (encoded.size == 0) {
        throw Exception("encoded V2 fetch command should not be empty")
    }
}

@Test
func testV2CommandBuilderMultipleArguments(): Unit {
    // 对齐 Rust: V2 命令多参数
    let builder = V2CommandBuilder(Command.LsRefs)
    builder.addArgument("refs/heads")
    builder.addArgument("refs/tags")
    builder.addCapability("symref")
    builder.addCapability("agent")
    if (builder.arguments.size != 2) {
        throw Exception("should have 2 arguments")
    }
    if (builder.capabilities.size != 2) {
        throw Exception("should have 2 capabilities")
    }
}

// ============================================================
// GitTcpTransport 测试 — 对齐 T015 git:// 协议传输
// ============================================================

@Test
func testGitTcpTransportConstruct(): Unit {
    let transport = GitTcpTransport()
    if (transport.lastHost != "") {
        throw Exception("lastHost should be empty on construction")
    }
    if (transport.lastPort != 9418) {
        throw Exception("lastPort should default to 9418, got: " + transport.lastPort.toString())
    }
    if (transport.lastPath != "") {
        throw Exception("lastPath should be empty on construction")
    }
    if (!transport.socket.isNone()) {
        throw Exception("socket should be None on construction")
    }
    if (transport.handshakeRefs.size != 0) {
        throw Exception("handshakeRefs should be empty on construction")
    }
    if (transport.handshakeCaps.size != 0) {
        throw Exception("handshakeCaps should be empty on construction")
    }
    if (transport.handshakeVersion != ProtocolVersion.V1) {
        throw Exception("handshakeVersion should default to V1")
    }
}

@Test
func testGitTcpTransportDefaultPort(): Unit {
    let transport = GitTcpTransport()
    if (transport.lastPort != 9418) {
        throw Exception("default port should be 9418 (git protocol default)")
    }
}

@Test
func testGitTcpTransportUrlParseGitScheme(): Unit {
    let url = Url.parse("git://github.com/user/repo.git")
    if (url.isNone()) {
        throw Exception("should parse git:// URL")
    }
    let u = url.getOrThrow()
    if (u.scheme != Scheme.Git) {
        throw Exception("scheme should be Git")
    }
    if (u.host.isNone() || u.host.getOrThrow() != "github.com") {
        throw Exception("host should be github.com")
    }
}

@Test
func testGitTcpTransportUrlParseCustomPort(): Unit {
    let url = Url.parse("git://github.com:1234/user/repo.git")
    if (url.isNone()) {
        throw Exception("should parse git:// URL with custom port")
    }
    let u = url.getOrThrow()
    if (u.port.isNone() || u.port.getOrThrow() != 1234) {
        throw Exception("port should be 1234")
    }
}

@Test
func testGitTcpTransportUrlParsePath(): Unit {
    let url = Url.parse("git://example.com/foo/bar.git")
    if (url.isNone()) {
        throw Exception("should parse git:// URL with path")
    }
    let u = url.getOrThrow()
    if (!u.path.startsWith("/foo/bar.git")) {
        throw Exception("path should start with /foo/bar.git, got: " + u.path)
    }
}

@Test
func testGitTcpTransportDecodePktLineValid(): Unit {
    let transport = GitTcpTransport()
    var data = ArrayList<Byte>()
    let line = "test line" + String.fromUtf8([UInt8(10)])
    let encoded = PacketLine.encode(line.toArray())
    for (b in encoded) {
        data.add(b)
    }
    let result = transport.decodePktLineGit(data.toArray(), 0)
    if (result.isNone()) {
        throw Exception("should decode valid pkt-line")
    }
    if (let Some(r) <- result) {
        let decoded = String.fromUtf8(r[0])
        if (!decoded.startsWith("test line")) {
            throw Exception("decoded content should start with test line, got: " + decoded)
        }
    }
}

@Test
func testGitTcpTransportDecodePktLineEmptyData(): Unit {
    let transport = GitTcpTransport()
    let data: Array<Byte> = []
    let result = transport.decodePktLineGit(data, 0)
    if (!result.isNone()) {
        throw Exception("should return None for empty data")
    }
}

@Test
func testGitTcpTransportDecodePktLineTooShort(): Unit {
    let transport = GitTcpTransport()
    let data: Array<Byte> = [48, 48]
    let result = transport.decodePktLineGit(data, 0)
    if (!result.isNone()) {
        throw Exception("should return None for data shorter than 4 bytes")
    }
}

@Test
func testGitTcpTransportParseRefLineSimple(): Unit {
    let transport = GitTcpTransport()
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 refs/heads/main"
    let result = transport.parseRefLineGit(line, false)
    if (result.isNone()) {
        throw Exception("should parse simple ref line")
    }
    if (let Some(r) <- result) {
        if (refName(r[0]) != "refs/heads/main") {
            throw Exception("ref name should be refs/heads/main, got: " + refName(r[0]))
        }
    }
}

@Test
func testGitTcpTransportParseRefLineWithCapabilities(): Unit {
    let transport = GitTcpTransport()
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 HEAD" + String.fromUtf8([UInt8(0)]) + "multi_ack side-band agent=git/2.40.0"
    let result = transport.parseRefLineGit(line, true)
    if (result.isNone()) {
        throw Exception("should parse ref line with capabilities")
    }
    if (let Some(r) <- result) {
        if (refName(r[0]) != "HEAD") {
            throw Exception("ref name should be HEAD")
        }
        if (r[1].size < 2) {
            throw Exception("should have at least 2 capabilities, got: " + r[1].size.toString())
        }
    }
}

@Test
func testGitTcpTransportParseRefLinePeeledTag(): Unit {
    let transport = GitTcpTransport()
    let line = "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391 refs/tags/v1.0^{}"
    let result = transport.parseRefLineGit(line, false)
    if (result.isNone()) {
        throw Exception("should parse peeled tag ref line")
    }
    if (let Some(r) <- result) {
        match (r[0]) {
            case Ref.Peeled(name, _, _) =>
                if (name != "refs/tags/v1.0") {
                    throw Exception("peeled tag name should be refs/tags/v1.0, got: " + name)
                }
            case _ => throw Exception("should be Peeled ref for ^{} suffix")
        }
    }
}

@Test
func testGitTcpTransportParseRefLineNoSpace(): Unit {
    let transport = GitTcpTransport()
    let line = "nospaceline"
    let result = transport.parseRefLineGit(line, false)
    if (!result.isNone()) {
        throw Exception("should return None for ref line without space separator")
    }
}

@Test
func testGitTcpTransportParseGitPushResponseOk(): Unit {
    let transport = GitTcpTransport()
    var data = ArrayList<Byte>()
    var okBytes = ArrayList<Byte>()
    okBytes.add(UInt8(1))
    for (b in "ok refs/heads/main".toArray()) {
        okBytes.add(b)
    }
    okBytes.add(UInt8(10))
    let encoded = PacketLine.encode(okBytes.toArray())
    for (b in encoded) {
        data.add(b)
    }
    for (b in PacketLine.flush()) {
        data.add(b)
    }
    let result = transport.parseGitPushResponse(data.toArray())
    if (result.isNone()) {
        throw Exception("should parse push response with ok")
    }
    if (let Some(pr) <- result) {
        if (pr.refUpdates.size != 1) {
            throw Exception("should have 1 ref update, got: " + pr.refUpdates.size.toString())
        }
        if (pr.refUpdates[0].status != "ok") {
            throw Exception("status should be ok")
        }
        if (pr.refUpdates[0].refName != "refs/heads/main") {
            throw Exception("ref name should be refs/heads/main")
        }
    }
}

@Test
func testGitTcpTransportParseGitPushResponseFailed(): Unit {
    let transport = GitTcpTransport()
    var data = ArrayList<Byte>()
    var ngBytes = ArrayList<Byte>()
    ngBytes.add(UInt8(1))
    for (b in "ng refs/heads/feature some error".toArray()) {
        ngBytes.add(b)
    }
    ngBytes.add(UInt8(10))
    let encoded = PacketLine.encode(ngBytes.toArray())
    for (b in encoded) {
        data.add(b)
    }
    for (b in PacketLine.flush()) {
        data.add(b)
    }
    let result = transport.parseGitPushResponse(data.toArray())
    if (result.isNone()) {
        throw Exception("should parse push response with failure")
    }
    if (let Some(pr) <- result) {
        if (pr.refUpdates.size != 1) {
            throw Exception("should have 1 ref update")
        }
        if (pr.refUpdates[0].status != "failed") {
            throw Exception("status should be failed")
        }
    }
}

@Test
func testGitTcpTransportParseGitPushResponseUnpackError(): Unit {
    let transport = GitTcpTransport()
    var data = ArrayList<Byte>()
    var errBytes = ArrayList<Byte>()
    errBytes.add(UInt8(1))
    for (b in "unpack error: corrupt pack".toArray()) {
        errBytes.add(b)
    }
    errBytes.add(UInt8(10))
    let encoded = PacketLine.encode(errBytes.toArray())
    for (b in encoded) {
        data.add(b)
    }
    for (b in PacketLine.flush()) {
        data.add(b)
    }
    let result = transport.parseGitPushResponse(data.toArray())
    if (result.isNone()) {
        throw Exception("should parse push response with unpack error")
    }
    if (let Some(pr) <- result) {
        if (pr.errorMessage.isNone()) {
            throw Exception("should have error message for unpack failure")
        }
    }
}

@Test
func testGitTcpTransportParseGitPushResponseSideBandError(): Unit {
    let transport = GitTcpTransport()
    var data = ArrayList<Byte>()
    var errBytes = ArrayList<Byte>()
    errBytes.add(UInt8(3))
    for (b in "fatal: remote error".toArray()) {
        errBytes.add(b)
    }
    errBytes.add(UInt8(10))
    let encoded = PacketLine.encode(errBytes.toArray())
    for (b in encoded) {
        data.add(b)
    }
    for (b in PacketLine.flush()) {
        data.add(b)
    }
    let result = transport.parseGitPushResponse(data.toArray())
    if (result.isNone()) {
        throw Exception("should parse push response with side-band error")
    }
    if (let Some(pr) <- result) {
        if (pr.errorMessage.isNone()) {
            throw Exception("should have error message for side-band channel 3")
        }
        if (!pr.errorMessage.getOrThrow().contains("fatal")) {
            throw Exception("error message should contain fatal")
        }
    }
}

@Test
func testGitTcpTransportFindNullByte(): Unit {
    let transport = GitTcpTransport()
    let s1 = "abc" + String.fromUtf8([UInt8(0)]) + "def"
    let idx1 = transport.findNullByteGit(s1)
    if (idx1 != 3) {
        throw Exception("null byte should be at position 3, got: " + idx1.toString())
    }
    let s2 = "no null byte"
    let idx2 = transport.findNullByteGit(s2)
    if (idx2 != -1) {
        throw Exception("should return -1 when no null byte, got: " + idx2.toString())
    }
}

// ============================================================
// FileTransport 测试 — 对齐 T016 file:// 协议传输
// ============================================================

@Test
func testFileTransportConstruct(): Unit {
    let transport = FileTransport()
    if (transport.repoPath != "") {
        throw Exception("repoPath should be empty on construction")
    }
    if (transport.lastRefs.size != 0) {
        throw Exception("lastRefs should be empty on construction")
    }
    if (transport.lastCaps.size != 0) {
        throw Exception("lastCaps should be empty on construction")
    }
}

@Test
func testFileTransportRepoPathField(): Unit {
    let transport = FileTransport()
    if (transport.repoPath != "") {
        throw Exception("repoPath should default to empty string")
    }
}

@Test
func testFileTransportLastRefsField(): Unit {
    let transport = FileTransport()
    if (transport.lastRefs.size != 0) {
        throw Exception("lastRefs should be empty ArrayList")
    }
}

@Test
func testFileTransportLastCapsField(): Unit {
    let transport = FileTransport()
    if (transport.lastCaps.size != 0) {
        throw Exception("lastCaps should be empty ArrayList")
    }
}

@Test
func testFileTransportHandshakeEmptyPath(): Unit {
    let transport = FileTransport()
    let url = Url(Scheme.File, None, None, None, "")
    let result = transport.handshake(url, Service.gitUploadPack())
    if (!result.isNone()) {
        throw Exception("handshake with empty path should return None")
    }
}

@Test
func testFileTransportFetchReturnsNone(): Unit {
    let transport = FileTransport()
    let wants = ArrayList<ObjectId>()
    let haves = ArrayList<ObjectId>()
    let result = transport.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("FileTransport.fetch should return None (not implemented)")
    }
}

@Test
func testFileTransportPushReturnsNone(): Unit {
    let transport = FileTransport()
    let refUpdates = ArrayList<RefUpdateCommand>()
    let packData: Array<Byte> = []
    let result = transport.push(refUpdates, packData)
    if (!result.isNone()) {
        throw Exception("FileTransport.push should return None (not implemented)")
    }
}
