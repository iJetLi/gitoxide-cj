// 文件：protocol_test.cj
// 用途：gix_protocol 包的单元测试，对齐 Rust gitoxide gix-protocol 测试
// 所属包：gix.gix_protocol
// 对齐来源：gix-protocol/tests/protocol/*.rs, gix-protocol/tests/blocking-protocol.rs

package gitoxide.gix_protocol

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import std.collection.*
import std.unittest.*

// ============================================================
// FetchConnection 构造测试 — 对齐 gix-protocol/tests/protocol/fetch_connection.rs
// ============================================================

@Test
func testFetchConnectionConstruct(): Unit {
    // 对齐 Rust: FetchConnection::new(transport, url)
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    if (conn.remoteUrl.scheme != Scheme.Https) {
        throw Exception("scheme should be Https")
    }
}

@Test
func testFetchConnectionFetchReturnsNone(): Unit {
    // 对齐 Rust: FetchConnection::fetch — DummyClientTransport 返回 None
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/user/repo.git")
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
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/user/repo.git")
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
    let url = Url(Scheme.Ssh, Some("git"), Some("github.com"), None, "/user/repo.git")
    let conn = FetchConnection(transport, url)
    if (conn.remoteUrl.scheme != Scheme.Ssh) {
        throw Exception("scheme should be Ssh")
    }
}

@Test
func testFetchConnectionWithFileUrl(): Unit {
    // 对齐 Rust: FetchConnection 使用本地文件 URL
    let transport = DummyClientTransport()
    let url = Url(Scheme.File, None, None, None, "/path/to/repo.git")
    let conn = FetchConnection(transport, url)
    if (conn.remoteUrl.scheme != Scheme.File) {
        throw Exception("scheme should be File")
    }
}

@Test
func testFetchConnectionFetchEmptyWantsAndHaves(): Unit {
    // 对齐 Rust: fetch 空的 wants 和 haves 列表
    let transport = DummyClientTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/repo.git")
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
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/repo.git")
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
    let refs = ArrayList<RemoteRef>()
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
    let refs = ArrayList<RemoteRef>()
    refs.add(RemoteRef(id, "refs/heads/main"))
    let caps = ArrayList<String>()
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 1) {
        throw Exception("refs should have 1 entry")
    }
    if (result.refs[0].name != "refs/heads/main") {
        throw Exception("ref name should be 'refs/heads/main'")
    }
}

@Test
func testLsRemoteResultWithMultipleRefs(): Unit {
    // 对齐 Rust: LsRemoteResult 包含多个远程引用
    let id = ObjectId.null(HashKind.Sha1)
    let refs = ArrayList<RemoteRef>()
    refs.add(RemoteRef(id, "refs/heads/main"))
    refs.add(RemoteRef(id, "refs/heads/develop"))
    refs.add(RemoteRef(id, "refs/tags/v1.0"))
    let caps = ArrayList<String>()
    let result = LsRemoteResult(refs, caps)
    if (result.refs.size != 3) {
        throw Exception("should have 3 refs")
    }
    if (result.refs[0].name != "refs/heads/main") {
        throw Exception("first ref mismatch")
    }
    if (result.refs[1].name != "refs/heads/develop") {
        throw Exception("second ref mismatch")
    }
    if (result.refs[2].name != "refs/tags/v1.0") {
        throw Exception("third ref mismatch")
    }
}

@Test
func testLsRemoteResultWithCapabilities(): Unit {
    // 对齐 Rust: LsRemoteResult 包含能力声明
    let refs = ArrayList<RemoteRef>()
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
    let refs = ArrayList<RemoteRef>()
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
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/user/repo.git")
    let result = lsRemote(url, transport)
    if (!result.isNone()) {
        throw Exception("dummy lsRemote should return None")
    }
}

@Test
func testLsRemoteWithReturningTransport(): Unit {
    // 对齐 Rust: ls_remote 使用返回数据的 transport
    let transport = ReturningClientTransport()
    let url = Url(Scheme.Https, None, Some("github.com"), None, "/user/repo.git")
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
// blocking-protocol / async-protocol 集成测试
// ============================================================
// 【部分可对齐】仓颉 stdx.net.http 提供 HTTP 客户端，blocking-protocol 测试可部分实现。
// async-protocol 测试仍无法对齐（仓颉网络编程是阻塞式的，无异步 I/O API）。
// 完整协议交互流程测试需本地 Git 服务器夹具支持。

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
}

// 返回数据的 transport 实现，用于测试 lsRemote
class ReturningClientTransport <: ClientTransport {
    public func handshake(url: Url, service: Service): ?HandshakeResult {
        let refs = ArrayList<RemoteRef>()
        refs.add(RemoteRef(ObjectId.null(HashKind.Sha1), "refs/heads/main"))
        let caps = ArrayList<String>()
        caps.add("multi_ack")
        Some(HandshakeResult(refs, ProtocolVersion.V2, caps))
    }
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        None
    }
}
