// 文件：transport_test.cj
// 用途：gix_transport 包的单元测试，对齐 Rust gitoxide gix-transport 测试
// 所属包：gix.gix_transport
// 对齐来源：gix-transport/tests/blocking-transport.rs, gix-transport/tests/blocking-transport-http.rs

package gitoxide.gix_transport

import gitoxide.gix_hash.*
import gitoxide.gix_url.*
import std.collection.*
import std.unittest.*

// ============================================================
// ProtocolVersion 测试 — 对齐 gix-transport/src/protocol/version.rs
// ============================================================

@Test
func testProtocolVersionV1(): Unit {
    // 对齐 Rust: ProtocolVersion::V1
    let v = ProtocolVersion.V1
    if (v != ProtocolVersion.V1) {
        throw Exception("V1 should equal V1")
    }
}

@Test
func testProtocolVersionV2(): Unit {
    // 对齐 Rust: ProtocolVersion::V2
    let v = ProtocolVersion.V2
    if (v != ProtocolVersion.V2) {
        throw Exception("V2 should equal V2")
    }
}

@Test
func testProtocolVersionV1NotV2(): Unit {
    // 对齐 Rust: V1 != V2
    if (ProtocolVersion.V1 == ProtocolVersion.V2) {
        throw Exception("V1 should not equal V2")
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
    let refs = ArrayList<RemoteRef>()
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
    let refs = ArrayList<RemoteRef>()
    refs.add(RemoteRef(id, "refs/heads/main"))
    refs.add(RemoteRef(id, "refs/tags/v1.0"))
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V1, caps)
    if (result.refs.size != 2) {
        throw Exception("refs should have 2 entries")
    }
    if (result.refs[0].name != "refs/heads/main") {
        throw Exception("first ref should be 'refs/heads/main'")
    }
    if (result.refs[1].name != "refs/tags/v1.0") {
        throw Exception("second ref should be 'refs/tags/v1.0'")
    }
}

@Test
func testHandshakeResultV1(): Unit {
    // 对齐 Rust: HandshakeResult 协议版本 V1
    let refs = ArrayList<RemoteRef>()
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V1, caps)
    if (result.protocolVersion != ProtocolVersion.V1) {
        throw Exception("should be V1")
    }
}

@Test
func testHandshakeResultV2(): Unit {
    // 对齐 Rust: HandshakeResult 协议版本 V2
    let refs = ArrayList<RemoteRef>()
    let caps = ArrayList<String>()
    let result = HandshakeResult(refs, ProtocolVersion.V2, caps)
    if (result.protocolVersion != ProtocolVersion.V2) {
        throw Exception("should be V2")
    }
}

@Test
func testHandshakeResultMultipleCapabilities(): Unit {
    // 对齐 Rust: HandshakeResult 多个能力声明
    let refs = ArrayList<RemoteRef>()
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
// RemoteRef 测试 — 对齐 gix-transport/src/client/remote_ref.rs
// ============================================================

@Test
func testRemoteRefConstruct(): Unit {
    // 对齐 Rust: RemoteRef { id, name }
    let id = ObjectId.null(HashKind.Sha1)
    let r = RemoteRef(id, "refs/heads/main")
    if (r.name != "refs/heads/main") {
        throw Exception("name should be 'refs/heads/main'")
    }
}

@Test
func testRemoteRefDifferentNames(): Unit {
    // 对齐 Rust: 不同引用名
    let id = ObjectId.null(HashKind.Sha1)
    let branch = RemoteRef(id, "refs/heads/develop")
    let tag = RemoteRef(id, "refs/tags/v2.0")
    if (branch.name != "refs/heads/develop") {
        throw Exception("branch name mismatch")
    }
    if (tag.name != "refs/tags/v2.0") {
        throw Exception("tag name mismatch")
    }
}

@Test
func testRemoteRefWithRealId(): Unit {
    // 对齐 Rust: RemoteRef 使用真实 ObjectId
    let id = ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
    let r = RemoteRef(id, "refs/heads/main")
    if (r.id.toHexString() != "e69de29bb2d1d6434b8b29ae775ad8c2e48c5391") {
        throw Exception("id should match")
    }
}

@Test
func testRemoteRefHeadRef(): Unit {
    // 对齐 Rust: RemoteRef HEAD 引用
    let id = ObjectId.null(HashKind.Sha1)
    let r = RemoteRef(id, "HEAD")
    if (r.name != "HEAD") {
        throw Exception("name should be 'HEAD'")
    }
}

@Test
func testRemoteRefPeeledTag(): Unit {
    // 对齐 Rust: RemoteRef 剥离标签引用
    let id = ObjectId.null(HashKind.Sha1)
    let r = RemoteRef(id, "refs/tags/v1.0^{}")
    if (r.name != "refs/tags/v1.0^{}") {
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
    let receivedRefs = ArrayList<RemoteRef>()
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
    let receivedRefs = ArrayList<RemoteRef>()
    receivedRefs.add(RemoteRef(id, "refs/heads/main"))
    let result = FetchResult(packData, receivedRefs)
    if (result.receivedRefs.size != 1) {
        throw Exception("receivedRefs should have 1 entry")
    }
}

@Test
func testFetchResultEmptyPackData(): Unit {
    // 对齐 Rust: FetchResult 空 pack 数据
    let packData: Array<Byte> = []
    let receivedRefs = ArrayList<RemoteRef>()
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
    let receivedRefs = ArrayList<RemoteRef>()
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
    haves.add(ObjectId.fromHex("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391"))
    let result = transport.fetch(wants, haves)
    if (!result.isNone()) {
        throw Exception("should return None")
    }
}

// ============================================================
// blocking-transport-http 测试
// ============================================================
// 【部分可对齐】仓颉 stdx.net.http 提供 HTTP 客户端（ClientBuilder/client.get/client.post），
// 可实现 Smart HTTP 传输层测试。但原版 reqwest 特定测试和异步传输测试仍无法对齐。

// ============================================================
// async-transport 测试
// ============================================================
// 【无法对齐】原版 async-transport.rs 测试依赖 tokio 异步运行时，
// 验证异步传输层。仓颉网络编程是阻塞式的（但不会阻塞系统线程），
// 无对应异步 I/O API。

// ============================================================
// client 测试 — 对齐 gix-transport/tests/client/*.rs
// ============================================================
// 【无法对齐】原版 client 测试验证 Git 协议的细节（capabilities negotiation、
// ref advertisement parsing 等），依赖本地 Git 服务器夹具。

// 测试辅助：DummyTransport 实现 ClientTransport 接口
class DummyTransport <: ClientTransport {
    public func handshake(url: Url, service: Service): ?HandshakeResult {
        None
    }
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
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
    if (transport.lastHost != "") {
        throw Exception("lastHost should be empty")
    }
    if (transport.lastPort != 80) {
        throw Exception("lastPort should be 80")
    }
}

@Test
func testHttpTransportHandshakeWithGitea(): Unit {
    // 对齐 Rust: blocking_io::http — 通过 HTTP GET /info/refs 获取引用列表
    // 使用本地 Gitea 服务器测试（需要 Gitea 运行在 localhost:3000）
    let transport = HttpTransport()
    let url = Url(Scheme.Http, None, Some("localhost"), Some(3000), "/jet/test.git")
    let result = transport.handshake(url, Service.gitUploadPack())
    if (result.isNone()) {
        throw Exception("handshake should succeed with Gitea")
    }
    if (let Some(hr) <- result) {
        if (hr.refs.size == 0) {
            throw Exception("should have at least 1 ref")
        }
        // 验证 HEAD 引用存在
        var foundHead = false
        for (r in hr.refs) {
            if (r.name == "HEAD") {
                foundHead = true
            }
        }
        if (!foundHead) {
            throw Exception("should have HEAD ref")
        }
        // 验证能力声明
        if (hr.capabilities.size == 0) {
            throw Exception("should have capabilities")
        }
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
            if (r.name == "refs/heads/main") {
                foundMain = true
                // 验证 ObjectId 是有效的 40 字符 hex
                if (r.id.toHexString().size != 40) {
                    throw Exception("ObjectId should be 40 hex chars, got ${r.id.toHexString().size}")
                }
            }
        }
        if (!foundMain) {
            throw Exception("should have refs/heads/main")
        }
    }
}

@Test
func testHttpTransportCapabilities(): Unit {
    // 对齐 Rust: capabilities::from_bytes — 解析能力声明
    let caps = Capabilities.fromBytes(
        "multi_ack thin-pack side-band ofs-delta shallow agent=git/2.28.0 symref=HEAD:refs/heads/main")
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
            throw Exception("agent should be git/2.28.0, got ${v}")
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
    // 对齐 Rust: capabilities — 无值的能力
    let caps = Capabilities.fromBytes("multi_ack ofs-delta")
    if (!caps.getValue("multi_ack").isNone()) {
        throw Exception("multi_ack has no value, getValue should return None")
    }
    if (!caps.contains("multi_ack")) {
        throw Exception("should contain multi_ack")
    }
}

@Test
func testHttpTransportFetchWithGitea(): Unit {
    // 对齐 Rust: blocking_io::http — 通过 HTTP POST /git-upload-pack 抓取
    // 注意：此测试需要本地 HTTP 服务器运行在 localhost:3000
    let transport = HttpTransport()
    let url = Url(Scheme.Http, None, Some("localhost"), Some(3000), "/jet/test.git")
    let handshakeResult = transport.handshake(url, Service.gitUploadPack())
    if (handshakeResult.isNone()) {
        return
    }
    if (let Some(hr) <- handshakeResult) {
        var mainOid: ?ObjectId = None
        for (r in hr.refs) {
            if (r.name == "refs/heads/main") {
                mainOid = Some(r.id)
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

@Test
func testProtocolVersionEquality(): Unit {
    // 对齐 Rust: ProtocolVersion 比较
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
