// 文件：lib.cj
// 用途：Git 协议层实现，封装传输层提供抓取连接与 ls-remote 操作
// 所属包：gix.gix_protocol
// 关键类型：FetchConnection, LsRemoteResult, lsRemote

package gitoxide.gix_protocol

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import std.collection.*

// 抓取连接，封装传输层与远程 URL，提供高层抓取操作
public class FetchConnection {
    // 底层传输实现
    public var transport: ClientTransport
    // 远程仓库 URL
    public var remoteUrl: Url

    // 参数 transport: 传输层实现
    // 参数 remoteUrl: 远程仓库 URL
    public init(transport: ClientTransport, remoteUrl: Url) {
        this.transport = transport
        this.remoteUrl = remoteUrl
    }

    // 执行抓取操作，通过传输层发送 want/have 协商
    // 参数 wants: 需要的对象 ID 列表
    // 参数 haves: 已有的对象 ID 列表
    // 返回值: 抓取成功返回 FetchResult，失败返回 None
    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        transport.fetch(wants, haves)
    }
}

// ls-remote 操作结果，包含远程引用与能力声明
public class LsRemoteResult {
    // 远程仓库的引用列表
    public var refs: ArrayList<RemoteRef>
    // 服务器声明的能力列表
    public var capabilities: ArrayList<String>

    // 参数 refs: 远程引用列表
    // 参数 capabilities: 能力声明列表
    public init(refs: ArrayList<RemoteRef>, capabilities: ArrayList<String>) {
        this.refs = refs
        this.capabilities = capabilities
    }
}

// 列出远程仓库的引用（ls-remote 操作）
// 参数 url: 远程仓库 URL
// 参数 transport: 传输层实现
// 返回值: 成功返回 LsRemoteResult，握手失败返回 None
public func lsRemote(url: Url, transport: ClientTransport): ?LsRemoteResult {
    let handshake = transport.handshake(url, Service.gitUploadPack())
    if (let Some(h) <- handshake) {
        Some(LsRemoteResult(h.refs, h.capabilities))
    } else {
        None
    }
}
