// git:// protocol transport, based on TCP direct connection (port 9418)
// Aligned Rust: gix_transport::client::blocking_io::git::connect

package gitoxide.gix_transport

import gitoxide.gix_hash.*
import gitoxide.gix_url.*
import gitoxide.gix_packetline.*
import gitoxide.gix_utils.*
import std.collection.*
import std.net.*
import std.process.*

public class GitTcpTransport <: ClientTransport {
    public var lastHost: String
    public var lastPort: Int64
    public var lastPath: String
    public var socket: ?TcpSocket
    public var handshakeRefs: ArrayList<Ref>
    public var handshakeCaps: ArrayList<String>
    public var handshakeVersion: ProtocolVersion

    public init() {
        lastHost = ""
        lastPort = 9418
        lastPath = ""
        socket = None
        handshakeRefs = ArrayList<Ref>()
        handshakeCaps = ArrayList<String>()
        handshakeVersion = ProtocolVersion.V1
    }

    public func handshake(url: Url, service: Service): ?HandshakeResult {
        var host = ""
        var port: Int64 = 9418
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

        try {
            let sock = TcpSocket(host, UInt16(port))
            sock.connect()
            socket = Some(sock)

            var requestLine = service.name + " " + path + "\0host=" + host + "\0"
            var encoded = PacketLine.encode(requestLine.toArray())
            sock.write(encoded)

            for (b in PacketLine.flush()) {
            }

            var allData = readAllFromSocket(sock)

            parseGitHandshake(allData, service)
        } catch (e: Exception) {
            println("[git-tcp-handshake] Exception: " + e.message)
            closeSocket()
            None
        }
    }

    func parseGitHandshake(data: Array<Byte>, service: Service): ?HandshakeResult {
        var refs = ArrayList<Ref>()
        var capabilities = ArrayList<String>()
        var protocolVersion = ProtocolVersion.V1
        var pos: Int64 = 0

        var firstLine = decodePktLineGit(data, pos)
        if (firstLine.isNone()) {
            return None
        }
        if (let Some(fl) <- firstLine) {
            pos = fl[1]
            var lineStr = String.fromUtf8(fl[0])
            while (lineStr.size > 0 && lineStr[lineStr.size - 1] == UInt8(10)) {
                lineStr = lineStr[0..lineStr.size - 1]
            }
            var parseResult = parseRefLineGit(lineStr, true)
            if (let Some(pr) <- parseResult) {
                refs.add(pr[0])
                for (cap in pr[1]) {
                    capabilities.add(cap)
                }
            }
        }

        var isFirstRef = refs.size == 0
        while (pos < data.size) {
            if (pos + 4 <= data.size) {
                var hexStr = readHex4(data, pos)
                if (hexStr == "0000") {
                    pos += 4
                    break
                }
                if (hexStr == "0001") {
                    pos += 4
                    continue
                }
            }

            var lineResult = decodePktLineGit(data, pos)
            if (lineResult.isNone()) {
                break
            }
            if (let Some(lr) <- lineResult) {
                pos = lr[1]
                var lineStr = String.fromUtf8(lr[0])
                while (lineStr.size > 0 && lineStr[lineStr.size - 1] == UInt8(10)) {
                    lineStr = lineStr[0..lineStr.size - 1]
                }
                if (lineStr.isEmpty()) {
                    continue
                }

                var parseResult = parseRefLineGit(lineStr, isFirstRef)
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

        for (cap in capabilities) {
            if (cap.startsWith("version=")) {
                protocolVersion = ProtocolVersion.V2
            }
        }

        var symrefTargets = HashMap<String, String>()
        for (cap in capabilities) {
            if (cap.startsWith("symref=")) {
                let rest = cap[7..]
                let colonIdx = rest.indexOf(":")
                if (let Some(ci) <- colonIdx) {
                    let refName = rest[0..ci]
                    let target = rest[ci + 1..]
                    symrefTargets.add(refName, target)
                }
            }
        }
        if (symrefTargets.size > 0) {
            var newRefs = ArrayList<Ref>()
            for (r in refs) {
                let converted = convertSymrefRef(r, symrefTargets)
                newRefs.add(converted)
            }
            refs = newRefs
        }

        handshakeRefs = refs
        handshakeCaps = capabilities
        handshakeVersion = protocolVersion
        Some(HandshakeResult(refs, protocolVersion, capabilities))
    }

    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        if (let Some(sock) <- socket) {
            try {
                var body = ArrayList<Byte>()

                var isFirst = true
                for (want in wants) {
                    if (isFirst) {
                        var wantLine = "want " + want.toHexString()
                        for (cap in handshakeCaps) {
                            wantLine = wantLine + " " + cap
                        }
                        wantLine = wantLine + "\n"
                        for (b in PacketLine.encode(wantLine.toArray())) {
                            body.add(b)
                        }
                        isFirst = false
                    } else {
                        var wantLine = "want " + want.toHexString() + "\n"
                        for (b in PacketLine.encode(wantLine.toArray())) {
                            body.add(b)
                        }
                    }
                }
                for (have in haves) {
                    var haveLine = "have " + have.toHexString() + "\n"
                    for (b in PacketLine.encode(haveLine.toArray())) {
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

                sock.write(body.toArray())

                var allData = readAllFromSocket(sock)
                parseGitFetchResponse(allData)
            } catch (e: Exception) {
                println("[git-tcp-fetch] Exception: " + e.message)
                closeSocket()
                None
            }
        } else {
            None
        }
    }

    func parseGitFetchResponse(data: Array<Byte>): ?FetchResult {
        var packData = ArrayList<Byte>()
        var pos: Int64 = 0

        while (pos < data.size) {
            if (pos + 4 <= data.size) {
                var hexStr = readHex4(data, pos)
                if (hexStr == "0000") {
                    pos += 4
                    continue
                }
                if (hexStr == "0001") {
                    pos += 4
                    continue
                }
            }

            var packStart = findPackSignatureGlobal(data)
            if (packStart >= 0 && packStart >= pos) {
                var slice = sliceBytes(data, packStart, data.size - packStart)
                return Some(FetchResult(slice, ArrayList<Ref>()))
            }

            var lineResult = decodePktLineGit(data, pos)
            if (lineResult.isNone()) {
                break
            }
            if (let Some(lr) <- lineResult) {
                pos = lr[1]
                var lineData = lr[0]
                if (lineData.size < 1) {
                    continue
                }
                var channel = Int64(lineData[0])
                if (channel == 1) {
                    for (i in 1..lineData.size) {
                        packData.add(lineData[i])
                    }
                }
            } else {
                break
            }
        }

        if (packData.size > 0) {
            Some(FetchResult(packData.toArray(), ArrayList<Ref>()))
        } else {
            None
        }
    }

    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        if (let Some(sock) <- socket) {
            try {
                var body = ArrayList<Byte>()

                var isFirst = true
                for (cmd in refUpdates) {
                    if (isFirst) {
                        var firstLine = cmd.oldId.toHexString() + " " + cmd.newId.toHexString() + " " + cmd.refName
                        var firstLineBytes = firstLine.toArray()
                        for (b in firstLineBytes) {
                            body.add(b)
                        }
                        body.add(UInt8(0))
                        var capsStr = "report-status side-band-6k agent=git/gix-cj/1.0"
                        for (b in capsStr.toArray()) {
                            body.add(b)
                        }
                        body.add(UInt8(10))
                        isFirst = false
                    } else {
                        for (b in cmd.encode()) {
                            body.add(b)
                        }
                    }
                }

                for (b in PacketLine.flush()) {
                    body.add(b)
                }

                for (b in packData) {
                    body.add(b)
                }

                sock.write(body.toArray())

                var allData = readAllFromSocket(sock)
                parseGitPushResponse(allData)
            } catch (e: Exception) {
                println("[git-tcp-push] Exception: " + e.message)
                closeSocket()
                None
            }
        } else {
            None
        }
    }

    func parseGitPushResponse(data: Array<Byte>): ?PushResult {
        var refUpdates = ArrayList<PushRefUpdateStatus>()
        var errorMessage: ?String = None
        var pos: Int64 = 0

        while (pos < data.size) {
            if (pos + 4 <= data.size) {
                var hexStr = readHex4(data, pos)
                if (hexStr == "0000") {
                    pos += 4
                    continue
                }
            }

            var lineResult = decodePktLineGit(data, pos)
            if (lineResult.isNone()) {
                break
            }
            if (let Some(lr) <- lineResult) {
                pos = lr[1]
                var lineStr = String.fromUtf8(lr[0])
                if (lineStr.size > 0 && lineStr[lineStr.size - 1] == UInt8(10)) {
                    lineStr = lineStr[0..lineStr.size - 1]
                }
                if (lineStr.isEmpty()) {
                    continue
                }

                if (lineStr.size > 1) {
                    var channel = Int64(lineStr[0])
                    var payload = lineStr[1..]
                    if (channel == 3) {
                        errorMessage = Some(payload)
                        continue
                    }
                    if (channel == 2) {
                        continue
                    }
                    if (channel == 1) {
                        lineStr = payload
                    }
                }

                if (lineStr.startsWith("ok ")) {
                    var refName = lineStr[3..]
                    refUpdates.add(PushRefUpdateStatus(refName, "ok", None))
                } else if (lineStr.startsWith("ng ")) {
                    var rest = lineStr[3..]
                    var spaceIdx = rest.indexOf(" ")
                    if (let Some(si) <- spaceIdx) {
                        var refName = rest[0..si]
                        var msg = rest[si + 1..]
                        refUpdates.add(PushRefUpdateStatus(refName, "failed", Some(msg)))
                    } else {
                        refUpdates.add(PushRefUpdateStatus(rest, "failed", None))
                    }
                } else if (lineStr.startsWith("unpack ok")) {
                } else if (lineStr.startsWith("unpack ")) {
                    errorMessage = Some(lineStr)
                }
            } else {
                break
            }
        }

        Some(PushResult(refUpdates, errorMessage))
    }

    func decodePktLineGit(data: Array<Byte>, pos: Int64): ?(Array<Byte>, Int64) {
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

    func parseRefLineGit(line: String, withCapabilities: Bool): ?(Ref, ArrayList<String>) {
        var caps = ArrayList<String>()
        var capStr = ""
        var workingLine = line

        var nullIdx = findNullByteGit(workingLine)
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

    func findNullByteGit(s: String): Int64 {
        var i: Int64 = 0
        while (i < s.size) {
            if (s[i] == CHAR_NULL) {
                return i
            }
            i++
        }
        -1
    }

    func readAllFromSocket(sock: TcpSocket): Array<Byte> {
        var result = ArrayList<Byte>()
        var buf = Array<Byte>(8192, repeat: 0)
        var totalRead: Int64 = 0
        let maxRead: Int64 = 50 * 1024 * 1024
        var done = false
        while (!done) {
            try {
                var count = sock.read(buf)
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
            } catch (_: Exception) {
                done = true
            }
        }
        result.toArray()
    }

    func closeSocket(): Unit {
        if (let Some(sock) <- socket) {
            try {
                sock.close()
            } catch (_: Exception) {
            }
            socket = None
        }
    }
}

// file:// protocol transport, via local git command execution
// Aligned Rust: gix_transport::client::blocking_io::local
public class FileTransport <: ClientTransport {
    public var repoPath: String
    public var lastRefs: ArrayList<Ref>
    public var lastCaps: ArrayList<String>

    public init() {
        repoPath = ""
        lastRefs = ArrayList<Ref>()
        lastCaps = ArrayList<String>()
    }

    public func handshake(url: Url, service: Service): ?HandshakeResult {
        var path = url.path
        if (path.isEmpty()) {
            return None
        }
        repoPath = path

        try {
            var args = ArrayList<String>()
            args.add("ls-remote")
            args.add("--symref")
            args.add(path)
            let (exitCode, stdout, stderr) = executeWithOutput("git", args.toArray())
            if (exitCode != 0) {
                return None
            }

            var refs = ArrayList<Ref>()
            var capabilities = ArrayList<String>()
            var headSymrefTarget: ?String = None
            var headOid: ?ObjectId = None
            let content = String.fromUtf8(stdout)
            let lines = content.split("\n")
            for (line in lines) {
                if (line.size == 0) {
                    continue
                }
                let tabIdx = line.indexOf("\t")
                if (tabIdx.isNone()) {
                    continue
                }
                let ti = tabIdx.getOrThrow()
                let first = line[0..ti]
                let refName = line[ti + 1..]
                if (refName == "HEAD" && first.startsWith("ref: ")) {
                    headSymrefTarget = Some(first[5..])
                } else {
                    let oidOpt = ObjectId.fromHex(first)
                    if (let Some(oid) <- oidOpt) {
                        if (refName == "HEAD") {
                            headOid = Some(oid)
                        } else if (refName.startsWith("refs/")) {
                            refs.add(Ref.Direct(refName, oid))
                        }
                    }
                }
            }
            if (let Some(oid) <- headOid) {
                let target = if (let Some(t) <- headSymrefTarget) {
                    t
                } else {
                    "refs/heads/master"
                }
                let headList = ArrayList<Ref>()
                headList.add(Ref.Symbolic("HEAD", target, Option<ObjectId>.None, oid))
                refs.add(all: headList, at: 0)
            }

            lastRefs = refs
            lastCaps = capabilities
            Some(HandshakeResult(refs, ProtocolVersion.V2, capabilities))
        } catch (e: Exception) {
            println("[file-handshake] Exception: " + e.message)
            None
        }
    }

    public func fetch(wants: ArrayList<ObjectId>, haves: ArrayList<ObjectId>): ?FetchResult {
        None
    }

    public func push(refUpdates: ArrayList<RefUpdateCommand>, packData: Array<Byte>): ?PushResult {
        None
    }
}
