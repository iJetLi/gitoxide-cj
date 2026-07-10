// 文件：lib.cj
// 用途：Git 传输层抽象，定义客户端传输接口与握手/抓取结果类型
// 所属包：gix.gix_transport
// 关键类型：ClientTransport, HandshakeResult, FetchResult, Service, RemoteRef, ProtocolVersion
//           HttpTransport（基于仓颉 TcpSocket 的 HTTP 传输实现）

package gitoxide.gix_transport

import gitoxide.gix_hash.*
import gitoxide.gix_url.*
import gitoxide.gix_packetline.*
import gitoxide.gix_utils.*
import std.collection.*
import std.net.*

// Git 协议版本
public enum ProtocolVersion {
    | V1 // Git 协议 V1 版本
    | V2 // Git 协议 V2 版本

    public operator func ==(that: ProtocolVersion): Bool {
        match (this) {
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

// Git 服务类型（如 upload-pack、receive-pack）
public class Service {
    // 服务名称，如 "git-upload-pack"
    public var name: String

    // 参数 name: 服务名称
    public init(name: String) {
        this.name = name
    }

    // 创建 git-upload-pack 服务实例（用于客户端拉取）
    // 返回值: git-upload-pack 服务
    public static func gitUploadPack(): Service {
        Service("git-upload-pack")
    }

    // 创建 git-receive-pack 服务实例（用于客户端推送）
    // 返回值: git-receive-pack 服务
    public static func gitReceivePack(): Service {
        Service("git-receive-pack")
    }
}

// 客户端传输接口，定义握手与抓取操作
public interface ClientTransport {
    // 与远程仓库握手，获取引用列表与能力声明
    // 参数 url: 远程仓库 URL
    // 参数 service: 请求的服务类型
    // 返回值: 握手成功返回 HandshakeResult，失败返回 None
    func handshake(url: Url, service: Service): ?HandshakeResult

    // 执行抓取操作，发送 want/have 协商后获取包数据
    // 参数 wants: 需要的对象 ID 列表
    // 参数 haves: 已有的对象 ID 列表
    // 返回值: 抓取成功返回 FetchResult，失败返回 None
    func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult
}

// 握手结果，包含远程引用、协议版本与能力声明
public class HandshakeResult {
    // 远程仓库的引用列表
    public var refs: ArrayList<RemoteRef>
    // 协商的协议版本
    public var protocolVersion: ProtocolVersion
    // 服务器声明的能力列表
    public var capabilities: ArrayList<String>

    // 参数 refs: 远程引用列表
    // 参数 protocolVersion: 协议版本
    // 参数 capabilities: 能力声明列表
    public init(refs: ArrayList<RemoteRef>, protocolVersion: ProtocolVersion, capabilities: ArrayList<String>) {
        this.refs = refs
        this.protocolVersion = protocolVersion
        this.capabilities = capabilities
    }
}

// 远程引用，表示远程仓库中的一个引用（分支/标签等）
public class RemoteRef {
    // 引用指向的对象 ID
    public var id: ObjectId
    // 引用全名，如 "refs/heads/main"
    public var name: String

    // 参数 id: 对象 ID
    // 参数 name: 引用全名
    public init(id: ObjectId, name: String) {
        this.id = id
        this.name = name
    }
}

// 抓取结果，包含收到的包数据与引用信息
public class FetchResult {
    // 收到的 pack 数据
    public var packData: Array<Byte>
    // 收到的远程引用列表
    public var receivedRefs: ArrayList<RemoteRef>

    // 参数 packData: pack 数据
    // 参数 receivedRefs: 收到的远程引用列表
    public init(packData: Array<Byte>, receivedRefs: ArrayList<RemoteRef>) {
        this.packData = packData
        this.receivedRefs = receivedRefs
    }
}

// 能力声明
public class Capabilities {
    public var names: ArrayList<String>
    public var keyValuePairs: ArrayList<(String, String)>

    public init() {
        names = ArrayList<String>()
        keyValuePairs = ArrayList<(String, String)>()
    }

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

    public func contains(name: String): Bool {
        for (n in names) {
            if (n == name) {
                return true
            }
        }
        false
    }

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

// HTTP 传输实现，基于仓颉 TcpSocket
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
            var wantLine = "want " + want.toHexString() + "\n"
            var encoded = PacketLine.encode(wantLine.toArray())
            for (b in encoded) {
                body.add(b)
            }
        }
        for (have in haves) {
            var haveLine = "have " + have.toHexString() + "\n"
            var encoded = PacketLine.encode(haveLine.toArray())
            for (b in encoded) {
                body.add(b)
            }
        }
        var doneEncoded = PacketLine.encode("done\n".toArray())
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

    func httpGet(host: String, port: Int64, path: String): ?Array<Byte> {
        try {
            var socket = TcpSocket(host, UInt16(port))
            socket.connect()
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

    func readAllFromSocket(socket: TcpSocket): ArrayList<Byte> {
        var result = ArrayList<Byte>()
        var buf = Array<Byte>(4096, repeat: 0)
        var done = false
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
            }
        }
        result
    }

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

    func findBodyStart(data: ArrayList<Byte>): Int64 {
        var i: Int64 = 0
        while (i < data.size - 3) {
            if (data[i] == 13 && data[i + 1] == 10 && data[i + 2] == 13 && data[i + 3] == 10) {
                return i + 4
            }
            i++
        }
        -1
    }

    // 解析 Smart HTTP 握手响应
    func parseHandshakeResponse(body: Array<Byte>, service: Service): ?HandshakeResult {
        var pos: Int64 = 0
        var refs = ArrayList<RemoteRef>()
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
                if (lineStr.endsWith("\n")) {
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

    // 解析引用行
    func parseRefLine(line: String, withCapabilities: Bool): ?(RemoteRef, ArrayList<String>) {
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

            var oid = ObjectId.fromHex(hashStr)
            Some((RemoteRef(oid, refName), caps))
        } else {
            None
        }
    }

    // 查找 null 字节
    func findNullByte(s: String): Int64 {
        var i: Int64 = 0
        while (i < s.size) {
            if (s[i] == UInt8(0)) {
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
            return Some(FetchResult(Array<Byte>(), ArrayList<RemoteRef>()))
        }
        var packData = sliceBytes(body, packStart, body.size - packStart)
        Some(FetchResult(packData, ArrayList<RemoteRef>()))
    }

    // 查找 PACK 签名
    func findPackSignature(data: Array<Byte>): Int64 {
        if (data.size < 4) {
            return -1
        }
        var i: Int64 = 0
        while (i < data.size - 3) {
            if (data[i] == 80 && data[i + 1] == 65 && data[i + 2] == 67 && data[i + 3] == 75) {
                return i
            }
            i++
        }
        -1
    }
}
