// 文件：lib.cj
// 用途：Git 协议层实现，封装传输层提供抓取连接与 ls-remote 操作
// 所属包：gix.gix_protocol
// 关键类型：FetchConnection, LsRemoteResult, FetchArguments, lsRemote, handshake
// 对齐 Rust: gix-protocol/src/lib.rs, handshake/mod.rs, fetch/mod.rs, fetch/arguments/mod.rs,
//           fetch/negotiate.rs, fetch/response/mod.rs, command.rs, ls_refs.rs, remote_progress.rs, util.rs

package gitoxide.gix_protocol

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_negotiate.*
import gitoxide.gix_utils.*
import std.collection.*

// Ref 枚举已移至 gix_transport 包，此处通过 import gitoxide.gix_transport.* 使用
// refUnpack、refName、refObjectId 辅助函数同样来自 gix_transport

// 从 V1 协议行解析 Ref
// 对齐 Rust: gix_protocol::handshake::refs::from_v1_refs_received_as_part_of_handshake_and_capabilities
// V1 行格式: "<hex-hash> <ref-name>\n" 或 "<hex-hash> <ref-name> peeled:<peeled-hash>\n"
// 带 symref 能力: "<hex-hash> <ref-name> symref-target:<target>\n"
public func parseV1RefLine(line: String, capabilities: ArrayList<String>): ?Ref {
    var trimmed = line
    while (trimmed.size > 0 && trimmed[trimmed.size - 1] == UInt8(10)) {
        trimmed = substringStr(trimmed, 0, trimmed.size - 1)
    }
    if (trimmed.size == 0) {
        return None
    }
    let spaceIdx = trimmed.indexOf(" ")
    if (spaceIdx.isNone()) {
        return None
    }
    let si = spaceIdx.getOrThrow()
    if (si <= 0 || si >= trimmed.size - 1) {
        return None
    }
    let hashStr = substringStr(trimmed, 0, si)
    let rest = substringFromStr(trimmed, si + 1)
    let id = ObjectId.fromHexOrThrow(hashStr)
    let parts = rest.split(" ")
    if (parts.size == 0) {
        return None
    }
    let refName = parts[0]
    var peeledId: ?ObjectId = None
    var symrefTarget: ?String = None
    for (i in 1..parts.size) {
        if (parts[i].startsWith("peeled:")) {
            let peeledStr = substringFromStr(parts[i], 7)
            let pId = ObjectId.fromHexOrThrow(peeledStr)
            peeledId = pId
        }
        if (parts[i].startsWith("symref-target:")) {
            symrefTarget = substringFromStr(parts[i], 14)
        }
    }
    if (let Some(target) <- symrefTarget) {
        if (id.isNull()) {
            Some(Ref.Unborn(refName, target))
        } else {
            Some(Ref.Symbolic(refName, target, peeledId, id))
        }
    } else if (let Some(peeled) <- peeledId) {
        Some(Ref.Peeled(refName, id, peeled))
    } else {
        Some(Ref.Direct(refName, id))
    }
}

// 从 V2 协议行解析 Ref
// 对齐 Rust: gix_protocol::handshake::refs::from_v2_refs
// V2 行格式: "<hex-hash> <ref-name>[ peeled:<peeled-hash>][ symref-target:<target>]"
public func parseV2RefLine(line: String): ?Ref {
    var trimmed = line
    while (trimmed.size > 0 && trimmed[trimmed.size - 1] == UInt8(10)) {
        trimmed = substringStr(trimmed, 0, trimmed.size - 1)
    }
    if (trimmed.size == 0) {
        return None
    }
    let spaceIdx = trimmed.indexOf(" ")
    if (spaceIdx.isNone()) {
        return None
    }
    let si = spaceIdx.getOrThrow()
    if (si <= 0 || si >= trimmed.size - 1) {
        return None
    }
    let hashStr = substringStr(trimmed, 0, si)
    let rest = substringFromStr(trimmed, si + 1)
    let id = ObjectId.fromHexOrThrow(hashStr)
    let parts = rest.split(" ")
    if (parts.size == 0) {
        return None
    }
    let refName = parts[0]
    var peeledId: ?ObjectId = None
    var symrefTarget: ?String = None
    for (i in 1..parts.size) {
        if (parts[i].startsWith("peeled:")) {
            let peeledStr = substringFromStr(parts[i], 7)
            let pId = ObjectId.fromHexOrThrow(peeledStr)
            peeledId = pId
        }
        if (parts[i].startsWith("symref-target:")) {
            symrefTarget = substringFromStr(parts[i], 14)
        }
    }
    if (let Some(target) <- symrefTarget) {
        if (id.isNull()) {
            Some(Ref.Unborn(refName, target))
        } else {
            Some(Ref.Symbolic(refName, target, peeledId, id))
        }
    } else if (let Some(peeled) <- peeledId) {
        Some(Ref.Peeled(refName, id, peeled))
    } else {
        Some(Ref.Direct(refName, id))
    }
}

// 抓取连接，封装传输层与远程 URL，提供高层抓取操作
// 对齐 Rust: gix_protocol::fetch 模块的高层抽象
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
// 对齐 Rust: gix_protocol::handshake::Handshake
public class LsRemoteResult {
    // 远程仓库的引用列表
    public var refs: ArrayList<Ref>
    // 服务器声明的能力列表
    public var capabilities: ArrayList<String>

    // 参数 refs: 远程引用列表
    // 参数 capabilities: 能力声明列表
    public init(refs: ArrayList<Ref>, capabilities: ArrayList<String>) {
        this.refs = refs
        this.capabilities = capabilities
    }
}

// 列出远程仓库的引用（ls-remote 操作）
// 对齐 Rust: gix_protocol::handshake::function::handshake
public func lsRemote(url: Url, transport: ClientTransport): ?LsRemoteResult {
    let handshake = transport.handshake(url, Service.gitUploadPack())
    if (let Some(h) <- handshake) {
        Some(LsRemoteResult(h.refs, h.capabilities))
    } else {
        None
    }
}

// 抓取参数，对齐 Rust gix_protocol::fetch::Arguments
// 管理 want/have/shallow 等协议参数
// 检查参数列表中是否包含 want 行
func hasWantArg(args: ArrayList<String>): Bool {
    for (a in args) {
        if (a.startsWith("want ")) {
            return true
        }
    }
    false
}

public class FetchArguments {
    // 参数列表
    public var args: ArrayList<String>
    // have 列表
    public var haves: ArrayList<String>
    // 是否支持 filter
    public var filter: Bool
    // 是否支持 shallow
    public var shallow: Bool
    // 是否支持 deepen-since
    public var deepenSince: Bool
    // 是否支持 deepen-not
    public var deepenNot: Bool
    // 是否支持 deepen-relative
    public var deepenRelative: Bool
    // 是否支持 ref-in-want
    public var refInWant: Bool
    // 是否支持 include-tag
    public var supportsIncludeTag: Bool
    // 协议版本
    public var version: ProtocolVersion
    // 第一个 want 前的能力声明
    public var featuresForFirstWant: ?ArrayList<String>

    public init(version: ProtocolVersion, features: ArrayList<String>) {
        args = ArrayList<String>()
        haves = ArrayList<String>()
        filter = false
        shallow = false
        deepenSince = false
        deepenNot = false
        deepenRelative = false
        refInWant = false
        supportsIncludeTag = false
        this.version = version
        featuresForFirstWant = Some(features)
        // 根据能力设置标志
        for (f in features) {
            if (f == "filter") {
                filter = true
            }
            if (f == "shallow") {
                shallow = true
                deepenSince = true
                deepenNot = true
                deepenRelative = true
            }
            if (f == "deepen-since") {
                deepenSince = true
            }
            if (f == "deepen-not") {
                deepenNot = true
            }
            if (f == "deepen-relative") {
                deepenRelative = true
            }
            if (f == "ref-in-want") {
                refInWant = true
            }
            if (f == "include-tag") {
                supportsIncludeTag = true
            }
        }
    }

    // 是否为空参数
    // 对齐 Rust: Arguments::is_empty
    public func isEmpty(): Bool {
        if (let Some(f) <- featuresForFirstWant) {
            if (!f.isEmpty()) {
                return false
            }
        }
        haves.isEmpty() && !hasWantArg(args)
    }

    // 是否支持 filter
    public func canUseFilter(): Bool {
        filter
    }

    // 是否支持 shallow
    public func canUseShallow(): Bool {
        shallow
    }

    // 是否无状态模式
    // 对齐 Rust: Arguments::is_stateless
    public func isStateless(transportIsStateless: Bool): Bool {
        transportIsStateless || version == ProtocolVersion.V2
    }

    // 添加 want 行
    // 对齐 Rust: Arguments::want
    public func want(id: ObjectId): Unit {
        if (let Some(features) <- featuresForFirstWant) {
            featuresForFirstWant = None
            var line = "want " + id.toHexString()
            for (f in features) {
                line = line + " " + f
            }
            args.add(line)
        } else {
            args.add("want " + id.toHexString())
        }
    }

    // 添加 want-ref 行
    // 对齐 Rust: Arguments::want_ref
    public func wantRef(refPath: String): Unit {
        args.add("want-ref " + refPath)
    }

    // 添加 have 行
    // 对齐 Rust: Arguments::have
    public func have(id: ObjectId): Unit {
        haves.add("have " + id.toHexString())
    }

    // 添加 shallow 行
    public func addShallow(id: ObjectId): Unit {
        if (shallow) {
            args.add("shallow " + id.toHexString())
        }
    }

    // 添加 deepen 行
    public func deepen(depth: Int64): Unit {
        if (shallow) {
            args.add("deepen " + depth.toString())
        }
    }

    // 添加 deepen-since 行
    public func addDeepenSince(seconds: Int64): Unit {
        if (deepenSince) {
            args.add("deepen-since " + seconds.toString())
        }
    }

    // 添加 deepen-relative 行
    public func addDeepenRelative(): Unit {
        if (deepenRelative) {
            args.add("deepen-relative")
        }
    }

    // 添加 deepen-not 行
    public func addDeepenNot(refPath: String): Unit {
        if (deepenNot) {
            args.add("deepen-not " + refPath)
        }
    }

    // 添加 filter 行
    public func addFilterSpec(spec: String): Unit {
        if (filter) {
            args.add("filter " + spec)
        }
    }

    // 添加 include-tag 能力
    public func useIncludeTag(): Unit {
        if (supportsIncludeTag) {
            args.add("include-tag")
        }
    }

    // 获取所有参数（包含 args 和 haves）
    public func allArgs(): ArrayList<String> {
        var result = ArrayList<String>()
        for (a in args) {
            result.add(a)
        }
        for (h in haves) {
            result.add(h)
        }
        result
    }
}

// 协商动作类型，对齐 Rust gix_protocol::fetch::negotiate::Action
public enum NegotiateAction {
    | NoChange // 无变化，无需抓取
    | SkipToRefUpdate // 跳过协商，直接更新引用
    | MustNegotiate // 需要协商
}

// 执行一轮协商，对齐 Rust gix_protocol::fetch::negotiate::one_round
// 参数 negotiator: 协商器实现
// 参数 graph: 协商图
// 参数 state: 协商状态
// 参数 arguments: 抓取参数
// 参数 previousResponse: 上一轮响应（可能为 None）
// 返回值: (轮次信息, 是否完成)

// 从 ACK 中提取共有对象 ID
func parseAcknowledgementCommon(ack: Acknowledgement): ?ObjectId {
    match (ack) {
        case Acknowledgement.Common(id) => Some(id)
        case _ => None
    }
}

public func oneRound(
    negotiator: Negotiator,
    graph: Graph,
    state: NegotiateState,
    arguments: FetchArguments,
    previousResponse: ?Response
): (Round, Bool) {
    var seenAck = false
    if (let Some(response) <- previousResponse) {
        for (ack in response.acks) {
            if (let Some(id) <- parseAcknowledgementCommon(ack)) {
                seenAck = true
                negotiator.inCommonWithRemote(id, graph)
                if (let Some(common) <- state.commonCommits) {
                    common.add(id)
                }
            }
        }
    }

    // 无状态连接时重发共有提交
    if (let Some(common) <- state.commonCommits) {
        for (haveId in common) {
            arguments.have(haveId)
        }
    }

    var havesAdded: Int64 = 0
    var i: Int64 = 0
    while (i < state.havesToSend) {
        let haveOpt = negotiator.nextHave(graph)
        if (haveOpt.isNone()) {
            break
        }
        if (let Some(haveId) <- haveOpt) {
            arguments.have(haveId)
            havesAdded += 1
        }
        i += 1
    }

    if (seenAck) {
        state.inVain = 0
    }
    state.seenAck = state.seenAck || seenAck
    state.inVain += havesAdded

    let round = Round(
        havesAdded,
        state.inVain,
        state.havesToSend,
        seenAck
    )
    let isDone = havesAdded != state.havesToSend || (state.seenAck && state.inVain >= 256)
    state.adjustWindowSize()

    (round, isDone)
}

// 抓取引用映射，对齐 Rust gix_protocol::fetch::RefMap
public class RefMap {
    // 远程引用到本地跟踪分支的映射
    public var mappings: ArrayList<Mapping>
    // 远程引用列表
    public var remoteRefs: ArrayList<Ref>
    // 对象哈希类型
    public var objectHash: HashKind

    public init() {
        mappings = ArrayList<Mapping>()
        remoteRefs = ArrayList<Ref>()
        objectHash = HashKind.Sha1
    }
}

// 引用映射项，对齐 Rust gix_protocol::fetch::refmap::Mapping
public class Mapping {
    // 远程引用
    public var remote: Ref
    // 本地引用名（可能为 None）
    public var local: ?String

    public init(remote: Ref, local: ?String) {
        this.remote = remote
        this.local = local
    }
}

// 浅克隆类型，对齐 Rust gix_protocol::fetch::Shallow
public enum Shallow {
    | NoChange // 无变化
    | DepthAtRemote(Int64) // 深度
    | Deepen(Int64) // 扩展深度
    | Since(Int64) // 时间截止
    | Exclude(ArrayList<String>, ?Int64) // 排除引用
}

// 标签处理方式，对齐 Rust gix_protocol::fetch::Tags
public enum Tags {
    | All // 抓取所有标签
    | Included // 仅抓取被引用的标签
    | None // 不抓取标签
}

// 握手结果，对齐 Rust gix_protocol::handshake::hero::Handshake
public class Handshake {
    // 服务器协议版本
    public var serverProtocolVersion: ProtocolVersion
    // V1 引用列表（V2 为 None）
    public var refs: ?ArrayList<Ref>
    // V1 浅克隆更新
    public var v1ShallowUpdates: ?ArrayList<ShallowUpdate>
    // 服务器能力
    public var capabilities: Capabilities

    public init(serverProtocolVersion: ProtocolVersion, refs: ?ArrayList<Ref>,
        v1ShallowUpdates: ?ArrayList<ShallowUpdate>, capabilities: Capabilities) {
        this.serverProtocolVersion = serverProtocolVersion
        this.refs = refs
        this.v1ShallowUpdates = v1ShallowUpdates
        this.capabilities = capabilities
    }
}

// 执行握手，对齐 Rust gix_protocol::handshake::function::handshake
public func handshake(transport: ClientTransport, url: Url, service: Service): ?Handshake {
    let result = transport.handshake(url, service)
    if (let Some(h) <- result) {
        var caps = Capabilities()
        for (cap in h.capabilities) {
            var eqIdx = cap.indexOf("=")
            if (let Some(ei) <- eqIdx) {
                caps.names.add(cap[0..ei])
                caps.keyValuePairs.add((cap[0..ei], cap[ei + 1..]))
            } else {
                caps.names.add(cap)
            }
        }
        // V1 协议直接返回引用，V2 需要单独请求
        var refs: ?ArrayList<Ref> = None
        if (h.protocolVersion == ProtocolVersion.V1 || h.protocolVersion == ProtocolVersion.V0) {
            refs = Some(h.refs)
        }
        Some(Handshake(h.protocolVersion, refs, None, caps))
    } else {
        None
    }
}

// 发送结束交互消息，对齐 Rust gix_protocol::util::indicate_end_of_interaction
public func indicateEndOfInteraction(): Unit {
    // 仓颉实现中无实际 I/O，仅作为协议标记
}

// 命令转字符串，对齐 Rust gix_protocol::Command::as_str
public func commandAsStr(cmd: Command): String {
    match (cmd) {
        case Command.LsRefs => "ls-refs"
        case Command.Fetch => "fetch"
        case Command.Push => "push"
    }
}

// 推送连接，封装传输层与远程 URL，提供高层推送操作
// 对齐 Rust: gix-protocol push 模块的高层抽象
public class PushConnection {
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

    // 与远程仓库握手，获取远程引用列表
    // 对齐 Rust: git-receive-pack 握手
    public func handshake(): ?HandshakeResult {
        transport.handshake(remoteUrl, Service.gitReceivePack())
    }

    // 执行推送操作，发送引用更新和 pack 数据
    // 参数 refUpdates: 引用更新命令列表
    // 参数 packData: pack 文件数据
    // 返回值: 推送成功返回 PushResult，失败返回 None
    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        transport.push(refUpdates, packData)
    }
}

// 推送引用映射，对齐 Rust gix_protocol::push::RefMap
public class PushRefMap {
    // 本地引用到远程引用的映射
    public var mappings: ArrayList<PushMapping>
    // 远程引用列表
    public var remoteRefs: ArrayList<Ref>
    // 对象哈希类型
    public var objectHash: HashKind

    public init() {
        mappings = ArrayList<PushMapping>()
        remoteRefs = ArrayList<Ref>()
        objectHash = HashKind.Sha1
    }
}

// 推送映射项，对齐 Rust gix_protocol::push::Mapping
public class PushMapping {
    // 本地引用
    public var local: Ref
    // 远程引用名（可能为 None）
    public var remote: ?String

    public init(local: Ref, remote: ?String) {
        this.local = local
        this.remote = remote
    }
}
