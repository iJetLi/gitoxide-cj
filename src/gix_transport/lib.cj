// 文件：lib.cj
// 用途：Git 传输层抽象，定义客户端传输接口与握手/抓取结果类型
// 所属包：gix.gix_transport
// 关键类型：ClientTransport, HandshakeResult, FetchResult, Service, Ref, ProtocolVersion
//           HttpTransport（基于仓颉 TcpSocket 的 HTTP 传输实现）
// 对齐 Rust: gix-transport/src/lib.rs, client/mod.rs, client/traits.rs, client/capabilities.rs,
//           client/blocking_io/http/mod.rs, client/non_io_types.rs
// 注意：待 stdx_net 包可用后迁移到 stdx.net.http

package gitoxide.gix_transport

import gitoxide.gix_hash.*
import gitoxide.gix_url.*
import gitoxide.gix_packetline.*
import gitoxide.gix_utils.*
import std.collection.*
import std.net.*

// Git 协议版本，对齐 Rust gix_transport::Protocol
public enum ProtocolVersion {
    | V0 // Git 协议 V0 版本（类似 V1 但无能力声明）
    | V1 // Git 协议 V1 版本，有状态
    | V2 // Git 协议 V2 版本，基于命令的无状态协议

    public operator func ==(that: ProtocolVersion): Bool {
        match (this) {
            case V0 => match (that) {
                case V0 => true;
                case _ => false
            }
            case V1 => match (that) {
                case V1 => true;
                case _ => false
            }
            case V2 => match (that) {
                case V2 => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: ProtocolVersion): Bool {
        !(this == that)
    }
}

// Git 服务类型，对齐 Rust gix_transport::Service
public class Service {
    // 服务名称，如 "git-upload-pack"
    public var name: String

    public init(name: String) {
        this.name = name
    }

    // 创建 git-upload-pack 服务实例（用于客户端拉取）
    public static func gitUploadPack(): Service {
        Service("git-upload-pack")
    }

    // 创建 git-receive-pack 服务实例（用于客户端推送）
    public static func gitReceivePack(): Service {
        Service("git-receive-pack")
    }
}

// 客户端传输接口，对齐 Rust gix_transport::client::blocking_io::Transport
public interface ClientTransport {
    // 与远程仓库握手，获取引用列表与能力声明
    func handshake(url: Url, service: Service): ?HandshakeResult

    // 执行抓取操作，发送 want/have 协商后获取包数据
    func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult
}

// 握手结果，对齐 Rust gix_transport::client::blocking_io::SetServiceResponse
public class HandshakeResult {
    // 远程仓库的引用列表
    public var refs: ArrayList<Ref>
    // 协商的协议版本
    public var protocolVersion: ProtocolVersion
    // 服务器声明的能力列表
    public var capabilities: ArrayList<String>

    public init(refs: ArrayList<Ref>, protocolVersion: ProtocolVersion, capabilities: ArrayList<String>) {
        this.refs = refs
        this.protocolVersion = protocolVersion
        this.capabilities = capabilities
    }
}

// Git 引用类型，对齐 Rust: gix_protocol::handshake::Ref
// Rust 的 Ref 枚举区分 Peeled（标签指向对象）、Direct（直接指向提交）、
// Symbolic（符号引用如 HEAD）、Unborn（未初始化仓库的引用）
public enum Ref {
    // Peeled: 标签引用，tag 指向标签对象，object 指向标签指向的实际对象
    // 对齐 Rust: Ref::Peeled { full_ref_name, tag, object }
    | Peeled(String, ObjectId, ObjectId)
    // Direct: 直接指向提交对象的引用（如分支、轻量标签）
    // 对齐 Rust: Ref::Direct { full_ref_name, object }
    | Direct(String, ObjectId)
    // Symbolic: 符号引用，指向另一个引用（如 HEAD -> refs/heads/main）
    // 对齐 Rust: Ref::Symbolic { full_ref_name, target, tag, object }
    | Symbolic(String, String, ?ObjectId, ObjectId)
    // Unborn: 未初始化仓库中的引用（如新仓库的 HEAD）
    // 对齐 Rust: Ref::Unborn { full_ref_name, target }
    | Unborn(String, String)
}

// Ref 的辅助方法，对齐 Rust: Ref::unpack() -> (&BStr, Option<&oid>, Option<&oid>)
// 返回 (name, target, peeled)
public func refUnpack(r: Ref): (String, ?ObjectId, ?ObjectId) {
    match (r) {
        case Ref.Direct(name, object) =>
            (name, Some(object), None)
        case Ref.Symbolic(name, _, tag, object) =>
            match (tag) {
                case Some(t) => (name, Some(t), Some(object))
                case None => (name, Some(object), None)
            }
        case Ref.Peeled(name, tag, peeled) =>
            (name, Some(tag), Some(peeled))
        case Ref.Unborn(name, _) =>
            (name, None, None)
    }
}

// 获取 Ref 的名称，对齐 Rust: Ref::full_ref_name 或 Ref::name
public func refName(r: Ref): String {
    match (r) {
        case Ref.Direct(name, _) => name
        case Ref.Peeled(name, _, _) => name
        case Ref.Symbolic(name, _, _, _) => name
        case Ref.Unborn(name, _) => name
    }
}

// 获取 Ref 的目标 ObjectId（Unborn 返回 None），对齐 Rust: Ref::object
public func refObjectId(r: Ref): ?ObjectId {
    match (r) {
        case Ref.Direct(_, obj) => Some(obj)
        case Ref.Peeled(_, _, obj) => Some(obj)
        case Ref.Symbolic(_, _, _, obj) => Some(obj)
        case Ref.Unborn(_, _) => None
    }
}

// 抓取结果，对齐 Rust gix_protocol::fetch::Response
public class FetchResult {
    // 收到的 pack 数据
    public var packData: Array<Byte>
    // 收到的远程引用列表
    public var receivedRefs: ArrayList<Ref>

    public init(packData: Array<Byte>, receivedRefs: ArrayList<Ref>) {
        this.packData = packData
        this.receivedRefs = receivedRefs
    }
}

// ACK 类型，对齐 Rust gix_protocol::fetch::response::Acknowledgement
public enum Acknowledgement {
    | Common(ObjectId) // 远程确认共有的对象
    | Ready           // 服务器准备接收更多行
    | Nak             // 服务器尚未准备好
}

// 浅克隆更新类型，对齐 Rust gix_shallow::Update
public enum ShallowUpdate {
    | Shallow(ObjectId)   // 浅克隆边界
    | Unshallow(ObjectId) // 取消浅克隆边界
}

// 抓取响应，对齐 Rust gix_protocol::fetch::Response
public class Response {
    // ACK 列表
    public var acks: ArrayList<Acknowledgement>
    // 浅克隆更新列表
    public var shallows: ArrayList<ShallowUpdate>
    // 是否包含 pack 数据
    public var hasPack: Bool

    public init() {
        acks = ArrayList<Acknowledgement>()
        shallows = ArrayList<ShallowUpdate>()
        hasPack = false
    }

    public init(acks: ArrayList<Acknowledgement>, shallows: ArrayList<ShallowUpdate>, hasPack: Bool) {
        this.acks = acks
        this.shallows = shallows
        this.hasPack = hasPack
    }
}

// 能力声明，对齐 Rust gix_transport::client::Capabilities
public class Capabilities {
    public var names: ArrayList<String>
    public var keyValuePairs: ArrayList<(String, String)>

    public init() {
        names = ArrayList<String>()
        keyValuePairs = ArrayList<(String, String)>()
    }

    // 从字符串解析能力声明，对齐 Rust Capabilities::from_bytes
    public static func fromBytes(capStr: String): Capabilities {
        var caps = Capabilities()
        var parts = capStr.split(" ")
        for (part in parts) {
            if (part.isEmpty()) {
                continue
            }
            var eqIdx = part.indexOf("=")
            if (let Some(ei) <- eqIdx) {
                caps.keyValuePairs.add((part[0..ei], part[ei + 1..]))
                caps.names.add(part[0..ei])
            } else {
                caps.names.add(part)
            }
        }
        caps
    }

    // 检查是否包含指定能力
    public func contains(name: String): Bool {
        for (n in names) {
            if (n == name) {
                return true
            }
        }
        false
    }

    // 获取指定能力的值
    public func getValue(name: String): ?String {
        for (kv in keyValuePairs) {
            if (kv[0] == name) {
                return kv[1]
            }
        }
        None
    }
}

// 从数组中提取4字节并转为 hex 字符串
func readHex4(data: Array<Byte>, pos: Int64): String {
    var b0 = if (pos < data.size) {
        data[pos]
    } else {
        UInt8(48)
    }
    var b1 = if (pos + 1 < data.size) {
        data[pos + 1]
    } else {
        UInt8(48)
    }
    var b2 = if (pos + 2 < data.size) {
        data[pos + 2]
    } else {
        UInt8(48)
    }
    var b3 = if (pos + 3 < data.size) {
        data[pos + 3]
    } else {
        UInt8(48)
    }
    String.fromUtf8([b0, b1, b2, b3])
}

// 从数组中提取子数组
func sliceBytes(data: Array<Byte>, start: Int64, len: Int64): Array<Byte> {
    Array<Byte>(len, {i => data[start + i]})
}

// 解析 ACK 行，对齐 Rust Acknowledgement::from_line
public func parseAcknowledgement(line: String): ?Acknowledgement {
    var trimmed = trimStr(line)
    if (trimmed.startsWith("ready")) {
        return Some(Acknowledgement.Ready)
    }
    if (trimmed == "NAK") {
        return Some(Acknowledgement.Nak)
    }
    if (trimmed.startsWith("ACK ")) {
        var rest = trimmed[4..]
        var spaceIdx = rest.indexOf(" ")
        var hexStr = if (let Some(si) <- spaceIdx) {
            rest[0..si]
        } else {
            rest
        }
        let oid = ObjectId.fromHexOrThrow(hexStr)
        // 对齐 Rust: ACK <hash> ready → Ready, ACK <hash> common → Common
        var suffix = if (let Some(si) <- spaceIdx) {
            rest[(si + 1)..]
        } else {
            ""
        }
        if (suffix == "ready") {
            Some(Acknowledgement.Ready)
        } else {
            Some(Acknowledgement.Common(oid))
        }
    } else {
        None
    }
}

// 解析浅克隆更新行，对齐 Rust shallow_update_from_line
public func parseShallowUpdate(line: String): ?ShallowUpdate {
    var trimmed = trimStr(line)
    if (trimmed.startsWith("shallow ")) {
        var hexStr = trimmed[8..]
        let oid = ObjectId.fromHexOrThrow(hexStr)
        Some(ShallowUpdate.Shallow(oid))
    } else if (trimmed.startsWith("unshallow ")) {
        var hexStr = trimmed[10..]
        let oid = ObjectId.fromHexOrThrow(hexStr)
        Some(ShallowUpdate.Unshallow(oid))
    } else {
        None
    }
}

// HTTP 传输实现，基于仓颉 TcpSocket
// 对齐 Rust: gix_transport::client::blocking_io::http
// 注意：待 stdx.net.http 可用后迁移
public class HttpTransport <: ClientTransport {
    public var connectTimeout: Int64
    public var readTimeout: Int64
    public var lastHost: String
    public var lastPort: Int64
    public var lastPath: String

    public init() {
        connectTimeout = 30000
        readTimeout = 30000
        lastHost = ""
        lastPort = 80
        lastPath = ""
    }

    public func handshake(url: Url, service: Service): ?HandshakeResult {
        var host = ""
        var port: Int64 = 80
        if (let Some(h) <- url.host) {
            host = h
        }
        if (let Some(p) <- url.port) {
            port = p
        }
        var path = url.path
        if (path.isEmpty()) {
            path = "/"
        }

        lastHost = host
        lastPort = port
        lastPath = path

        var refPath = path
        if (!refPath.endsWith("/")) {
            refPath = refPath + "/"
        }
        refPath = refPath + "info/refs?service=" + service.name

        var response = httpGet(host, port, refPath)
        if (let Some(resp) <- response) {
            return parseHandshakeResponse(resp, service)
        }
        None
    }

    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        if (lastHost.isEmpty()) {
            return None
        }
        var service = Service.gitUploadPack()
        var postPath = lastPath
        if (!postPath.endsWith("/")) {
            postPath = postPath + "/"
        }
        postPath = postPath + service.name

        var body = ArrayList<Byte>()
        for (want in wants) {
            var wantLine = "want " + want.toHexString() + ""
            var encoded = PacketLine.encode(wantLine.toArray())
            for (b in encoded) {
                body.add(b)
            }
        }
        for (have in haves) {
            var haveLine = "have " + have.toHexString() + ""
            var encoded = PacketLine.encode(haveLine.toArray())
            for (b in encoded) {
                body.add(b)
            }
        }
        var doneEncoded = PacketLine.encode("done".toArray())
        for (b in doneEncoded) {
            body.add(b)
        }
        for (b in PacketLine.flush()) {
            body.add(b)
        }

        var response = httpPost(lastHost, lastPort, postPath, body.toArray(), "application/x-git-upload-pack-request")
        if (let Some(resp) <- response) {
            return parseFetchResponse(resp)
        }
        None
    }

    // 发送 HTTP GET 请求
    func httpGet(host: String, port: Int64, path: String): ?Array<Byte> {
        try {
            var socket = TcpSocket(host, UInt16(port))
            socket.connect()
            // 对齐 HTTP/1.1 规范：请求头行必须以 \r\n 结尾
            var request = "GET " + path + " HTTP/1.1\r\n"
            request = request + "Host: " + host + "\r\n"
            request = request + "User-Agent: git/gix-cj/1.0\r\n"
            request = request + "Accept: */*\r\n"
            request = request + "Connection: close\r\n"
            request = request + "\r\n"
            socket.write(request.toArray())
            var result = readAllFromSocket(socket)
            socket.close()
            extractHttpBody(result)
        } catch (_: Exception) {
            None
        }
    }

    // 发送 HTTP POST 请求
    func httpPost(host: String, port: Int64, path: String, body: Array<Byte>, contentType: String): ?Array<Byte> {
        try {
            var socket = TcpSocket(host, UInt16(port))
            socket.connect()
            var request = "POST " + path + " HTTP/1.1\r\n"
            request = request + "Host: " + host + "\r\n"
            request = request + "User-Agent: git/gix-cj/1.0\r\n"
            request = request + "Accept: */*\r\n"
            request = request + "Content-Type: " + contentType + "\r\n"
            request = request + "Content-Length: " + body.size.toString() + "\r\n"
            request = request + "Connection: close\r\n"
            request = request + "\r\n"
            socket.write(request.toArray())
            socket.write(body)
            var result = readAllFromSocket(socket)
            socket.close()
            extractHttpBody(result)
        } catch (_: Exception) {
            None
        }
    }

    // 从 socket 读取所有数据
    func readAllFromSocket(socket: TcpSocket): ArrayList<Byte> {
        var result = ArrayList<Byte>()
        var buf = Array<Byte>(4096, repeat: 0)
        var done = false
        // 对齐 Rust: 读取超时保护，防止无限阻塞
        var totalRead: Int64 = 0
        let maxRead: Int64 = 10 * 1024 * 1024 // 10MB 上限
        while (!done) {
            var count = socket.read(buf)
            if (count <= 0) {
                done = true
            } else {
                var i: Int64 = 0
                while (i < count) {
                    result.add(buf[i])
                    i++
                }
                totalRead += count
                if (totalRead >= maxRead) {
                    done = true
                }
            }
        }
        result
    }

    // 提取 HTTP 响应体，使用 CHAR_CR/CHAR_LF 常量
    func extractHttpBody(data: ArrayList<Byte>): ?Array<Byte> {
        var bodyStart = findBodyStart(data)
        if (bodyStart < 0) {
            return None
        }
        var body = ArrayList<Byte>()
        var j = bodyStart
        while (j < data.size) {
            body.add(data[j])
            j++
        }
        Some(body.toArray())
    }

    // 查找 HTTP 响应体起始位置，使用 CHAR_CR/CHAR_LF 常量
    func findBodyStart(data: ArrayList<Byte>): Int64 {
        var i: Int64 = 0
        while (i < data.size - 3) {
            if (data[i] == CHAR_CR && data[i + 1] == CHAR_LF && data[i + 2] == CHAR_CR && data[i + 3] == CHAR_LF) {
                return i + 4
            }
            i++
        }
        -1
    }

    // 解析 Smart HTTP 握手响应
    func parseHandshakeResponse(body: Array<Byte>, service: Service): ?HandshakeResult {
        var pos: Int64 = 0
        var refs = ArrayList<Ref>()
        var capabilities = ArrayList<String>()
        var protocolVersion = ProtocolVersion.V1

        // 解析第一行
        var firstLine = decodePktLine(body, pos)
        if (firstLine.isNone()) {
            return None
        }
        if (let Some(fl) <- firstLine) {
            pos = fl[1]
            var lineStr = String.fromUtf8(fl[0])
            if (!lineStr.contains("service=")) {
                var parseResult = parseRefLine(lineStr, true)
                if (let Some(pr) <- parseResult) {
                    refs.add(pr[0])
                    for (cap in pr[1]) {
                        capabilities.add(cap)
                    }
                }
            }
        }

        // 读取后续行
        var isFirstRef = refs.size == 0
        while (pos < body.size) {
            // 检查 flush/delimiter
            if (pos + 4 <= body.size) {
                var hexStr = readHex4(body, pos)
                if (hexStr == "0000" || hexStr == "0001") {
                    pos += 4
                    continue
                }
            }

            var lineResult = decodePktLine(body, pos)
            if (lineResult.isNone()) {
                break
            }
            if (let Some(lr) <- lineResult) {
                pos = lr[1]
                var lineStr = String.fromUtf8(lr[0])
                if (lineStr.endsWith("")) {
                    lineStr = lineStr[0..lineStr.size - 1]
                }
                if (lineStr.isEmpty()) {
                    continue
                }

                var parseResult = parseRefLine(lineStr, isFirstRef)
                if (let Some(pr) <- parseResult) {
                    refs.add(pr[0])
                    if (isFirstRef) {
                        for (cap in pr[1]) {
                            capabilities.add(cap)
                        }
                        isFirstRef = false
                    }
                }
            } else {
                break
            }
        }

        // 检测协议版本
        for (cap in capabilities) {
            if (cap.startsWith("version=")) {
                protocolVersion = ProtocolVersion.V2
            }
        }

        Some(HandshakeResult(refs, protocolVersion, capabilities))
    }

    // 解析 pkt-line
    func decodePktLine(data: Array<Byte>, pos: Int64): ?(Array<Byte>, Int64) {
        if (pos + 4 > data.size) {
            return None
        }
        var hexStr = readHex4(data, pos)
        var lenOpt = parseHexInt64(hexStr)
        if (let Some(len) <- lenOpt) {
            if (len < 4) {
                return None
            }
            if (pos + len > data.size) {
                return None
            }
            Some((sliceBytes(data, pos + 4, len - 4), pos + len))
        } else {
            None
        }
    }

    // 解析引用行，对齐 Rust: gix-transport 中的 ref line 解析
    // 传输层只解析基本 hash+name 格式，返回 Ref.Direct
    // 完整的 Peeled/Symbolic/Unborn 解析在 gix_protocol 的 parseV1RefLine/parseV2RefLine 中
    func parseRefLine(line: String, withCapabilities: Bool): ?(Ref, ArrayList<String>) {
        var caps = ArrayList<String>()
        var capStr = ""
        var workingLine = line

        var nullIdx = findNullByte(workingLine)
        if (nullIdx >= 0 && withCapabilities) {
            capStr = workingLine[nullIdx + 1..]
            workingLine = workingLine[0..nullIdx]
        } else if (nullIdx >= 0) {
            workingLine = workingLine[0..nullIdx]
        }

        var spaceIdxOpt = workingLine.indexOf(" ")
        if (let Some(spaceIdx) <- spaceIdxOpt) {
            var hashStr = workingLine[0..spaceIdx]
            var refName = workingLine[spaceIdx + 1..]

            var tabIdxOpt = refName.indexOf("\t")
            if (let Some(tabIdx) <- tabIdxOpt) {
                refName = refName[0..tabIdx]
            }
            var spaceInRefOpt = refName.indexOf(" ")
            if (let Some(spaceInRef) <- spaceInRefOpt) {
                refName = refName[0..spaceInRef]
            }

            if (!capStr.isEmpty()) {
                var capParts = capStr.split(" ")
                for (part in capParts) {
                    if (!part.isEmpty()) {
                        caps.add(part)
                    }
                }
            }

            var oid = ObjectId.fromHexOrThrow(hashStr)
            // 检测 peeled 标记（^{} 后缀），对齐 Rust: gix-protocol 中 peeled 检测
            if (refName.endsWith("^{}")) {
                let actualName = refName[0..refName.size - 3]
                Some((Ref.Peeled(actualName, oid, oid), caps))
            } else {
                Some((Ref.Direct(refName, oid), caps))
            }
        } else {
            None
        }
    }

    // 查找 null 字节，使用 CHAR_NULL 常量
    func findNullByte(s: String): Int64 {
        var i: Int64 = 0
        while (i < s.size) {
            if (s[i] == CHAR_NULL) {
                return i
            }
            i++
        }
        -1
    }

    // 解析 fetch 响应
    func parseFetchResponse(body: Array<Byte>): ?FetchResult {
        var packStart = findPackSignature(body)
        if (packStart < 0) {
            return Some(FetchResult(Array<Byte>(), ArrayList<Ref>()))
        }
        var packData = sliceBytes(body, packStart, body.size - packStart)
        Some(FetchResult(packData, ArrayList<Ref>()))
    }

    // 查找 PACK 签名
    func findPackSignature(data: Array<Byte>): Int64 {
        if (data.size < 4) {
            return -1
        }
        // PACK = 80(P) 65(A) 67(C) 75(K)
        var i: Int64 = 0
        while (i < data.size - 3) {
            if (data[i] == UInt8(80) && data[i + 1] == UInt8(65) && data[i + 2] == UInt8(67) && data[i + 3] == UInt8(75)) {
                return i
            }
            i++
        }
        -1
    }
}

// 远程进度信息，对齐 Rust gix_protocol::RemoteProgress
public class RemoteProgress {
    // 操作名称，如 "Counting objects"
    public var action: String
    // 百分比，0-100
    public var percent: ?Int64
    // 已处理项数
    public var step: ?Int64
    // 最大预期项数
    public var max: ?Int64

    public init(action: String, percent: ?Int64, step: ?Int64, max: ?Int64) {
        this.action = action
        this.percent = percent
        this.step = step
        this.max = max
    }

    // 从字节解析远程进度，对齐 Rust RemoteProgress::from_bytes
    public static func fromBytes(line: Array<Byte>): ?RemoteProgress {
        var colonPos: Int64 = -1
        var i: Int64 = 0
        while (i < line.size) {
            if (line[i] == CHAR_COLON) {
                colonPos = i
                break
            }
            i += 1
        }
        if (colonPos <= 0) {
            return None
        }
        var action = String.fromUtf8(sliceBytes(line, 0, colonPos))
        var rest = String.fromUtf8(sliceBytes(line, colonPos + 1, line.size - colonPos - 1))
        var percent: ?Int64 = None
        var step: ?Int64 = None
        var max: ?Int64 = None
        // 解析百分比
        var pctIdx = rest.indexOf("%")
        if (let Some(pi) <- pctIdx) {
            var beforePct = rest[0..pi]
            var numStr = extractTrailingNumber(beforePct)
            if (let Some(ns) <- numStr) {
                if (let Some(v) <- parseInt(ns)) {
                    percent = Some(v)
                }
            }
            rest = rest[pi + 1..]
        }
        // 解析 step/max
        // 对齐 Rust: 先尝试括号格式 "step/max"，再尝试逗号前数字
        var parenIdx = rest.indexOf("(")
        if (let Some(poi) <- parenIdx) {
            var afterParen = rest[poi + 1..]
            var slashIdx = afterParen.indexOf("/")
            if (let Some(si) <- slashIdx) {
                var stepStr = afterParen[0..si]
                var afterSlash = afterParen[si + 1..]
                var closeIdx = afterSlash.indexOf(")")
                var maxStr = if (let Some(ci) <- closeIdx) {
                    afterSlash[0..ci]
                } else {
                    afterSlash
                }
                if (let Some(sv) <- parseInt(stepStr)) {
                    step = Some(sv)
                }
                if (let Some(mv) <- parseInt(maxStr)) {
                    max = Some(mv)
                }
            }
        } else {
            // 对齐 Rust: 无括号格式，如 " 10, done." → step=10
            var trimmedRest = rest.trimAscii()
            if (!trimmedRest.isEmpty()) {
                var numPart = trimmedRest
                if (let Some(ci) <- trimmedRest.indexOf(",")) {
                    numPart = trimmedRest[0..ci]
                }
                var trimmedNum = numPart.trimAscii()
                if (let Some(v) <- parseInt(trimmedNum)) {
                    step = Some(v)
                }
            }
        }
        if (percent.isNone() && step.isNone() && max.isNone()) {
            return None
        }
        Some(RemoteProgress(action, percent, step, max))
    }
}

// 提取字符串末尾的数字
func extractTrailingNumber(s: String): ?String {
    var end = s.size
    while (end > 0) {
        var c = s[end - 1]
        if (c >= UInt8(48) && c <= UInt8(57)) {
            end -= 1
        } else {
            break
        }
    }
    if (end < s.size) {
        Some(s[end..])
    } else {
        None
    }
}

// 命令类型，对齐 Rust gix_protocol::Command
public enum Command {
    | LsRefs // 列出引用
    | Fetch  // 抓取包
}

// 写入模式，对齐 Rust gix_transport::client::WriteMode
public enum WriteMode {
    | Binary                     // 二进制模式，每次写入为原始字节
    | OneLfTerminatedLinePerWriteCall // 文本模式，每次写入为一行 pkt-line
}

// 消息类型，对齐 Rust gix_transport::client::MessageKind
public enum MessageKind {
    | Flush       // flush 包
    | Delimiter   // V2 分隔符
    | ResponseEnd // 响应结束
    | Text(String) // 文本内容
}

// 生成 agent 字符串，对齐 Rust gix_protocol::util::agent
public func agent(name: String): String {
    if (name.startsWith("git/")) {
        name
    } else {
        "git/" + name
    }
}

// 连接复用传输层，对齐 Rust: gix_transport::client::blocking_io::http::buf_read::WithLineEnding
// 在同一 TCP 连接上执行多次请求（HTTP keep-alive）
public class ReusableHttpTransport <: ClientTransport {
    public var inner: HttpTransport
    // 是否保持连接复用，对齐 Rust: gix_transport::client::Connect
    public var keepAlive: Bool

    public init() {
        this.inner = HttpTransport()
        this.keepAlive = true
    }

    public func handshake(url: Url, service: Service): ?HandshakeResult {
        inner.handshake(url, service)
    }

    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        inner.fetch(wants, haves)
    }
}

// V2 命令请求构建器，对齐 Rust: gix_transport::client::blocking_io::RequestWriter
// 用于构建 V2 协议的 ls-refs 和 fetch 命令请求
public class V2CommandBuilder {
    public var command: Command
    public var arguments: ArrayList<String>
    public var capabilities: ArrayList<String>

    public init(command: Command) {
        this.command = command
        this.arguments = ArrayList<String>()
        this.capabilities = ArrayList<String>()
    }

    // 添加命令参数，对齐 Rust: gix_transport::client::blocking_io::RequestWriter::append_argument
    public func addArgument(arg: String): V2CommandBuilder {
        arguments.add(arg)
        this
    }

    // 添加能力声明
    public func addCapability(cap: String): V2CommandBuilder {
        capabilities.add(cap)
        this
    }

    // 编码为 V2 协议字节流，对齐 Rust: gix_transport::client::blocking_io::RequestWriter
    public func encode(): Array<Byte> {
        var result = ArrayList<Byte>()
        // 命令行
        let cmdName = commandAsStr(command)
        let cmdLine = "command=" + cmdName + "\n"
        for (b in PacketLine.encode(cmdLine.toArray())) {
            result.add(b)
        }
        // 能力声明
        for (cap in capabilities) {
            let capLine = cap + "\n"
            for (b in PacketLine.encode(capLine.toArray())) {
                result.add(b)
            }
        }
        // 分隔符
        for (b in PacketLine.delimiter()) {
            result.add(b)
        }
        // 参数
        for (arg in arguments) {
            let argLine = arg + "\n"
            for (b in PacketLine.encode(argLine.toArray())) {
                result.add(b)
            }
        }
        // flush
        for (b in PacketLine.flush()) {
            result.add(b)
        }
        result.toArray()
    }
}

// 命令名称转换，对齐 Rust: gix_protocol::Command::as_str
func commandAsStr(cmd: Command): String {
    match (cmd) {
        case Command.LsRefs => "ls-refs"
        case Command.Fetch => "fetch"
    }
}
