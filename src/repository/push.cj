// 文件：push.cj
// 用途：仓库层 push 胶水模块，桥接 gix_transport/gix_pack/gix_refspec 到 Repository
// 所属包：gitoxide.repository
// 关键类型：PushQuery, PushOptions
// 对齐原版：gitoxide-core/src/repository/push.rs (原版 Rust gix 尚未实现 push，此处为自主实现)

package gitoxide.repository

import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_hash.*
import gitoxide.gix_config.*
import gitoxide.gix_ref.*
import gitoxide.gix_refspec.*
import gitoxide.gix_pack.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import gitoxide.gix_path.*
import std.collection.*
import std.fs.*
import std.process.*

// 推送选项，控制推送行为
public class PushOptions {
    // 是否强制推送（相当于 --force）
    public var force: Bool
    // 推送时使用的引用规格列表
    public var refSpecs: ArrayList<RefSpec>
    // 远程名称，默认为 "origin"
    public var remoteName: String
    // 是否推送所有本地分支
    public var pushAll: Bool
    // 是否删除远程引用（newId 为全零时）
    public var delete: Bool
    // 是否干运行（不实际推送）
    public var dryRun: Bool

    public init() {
        this.force = false
        this.refSpecs = ArrayList<RefSpec>()
        this.remoteName = "origin"
        this.pushAll = false
        this.delete = false
        this.dryRun = false
    }
}

// 推送查询类，提供从仓库推送本地提交到远程的功能
public class PushQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 推送本地提交到远程仓库
    // 对齐 git push 命令的核心流程：
    //   1. 解析远程 URL
    //   2. 与远程握手（git-receive-pack）
    //   3. 根据 refspec 确定要推送的引用
    //   4. 收集需要推送的对象并生成 pack
    //   5. 发送引用更新和 pack 数据
    //   6. 解析服务器响应
    public func push(remoteName: String, refSpecs: ArrayList<String>): ?PushResult {
        let remoteUrl = resolveRemoteUrl(remoteName)
        if (let Some(urlStr) <- remoteUrl) {
            if (urlStr.startsWith("ssh://") || urlStr.startsWith("git@")) {
                return pushViaGitCommand(remoteName, refSpecs, repo.gitDir)
            }
            let url = Url.parse(urlStr)
            if (let Some(parsedUrl) <- url) {
                let service = Service.gitReceivePack()
                let authOpt = loadCredentialsForUrl(urlStr)

                if (urlStr.startsWith("https://")) {
                    var tlsTransport = TlsHttpTransport()
                    if (let Some(auth) <- authOpt) {
                        tlsTransport.authHeader = Some("Basic " + auth)
                    }

                    var handshakeResult: ?HandshakeResult = None
                    try {
                        handshakeResult = tlsTransport.handshake(parsedUrl, service)
                    } catch (_: Exception) {
                        return None
                    }

                    if (let Some(hsResult) <- handshakeResult) {
                        let pushCommands = resolvePushRefs(refSpecs, hsResult.refs, remoteName)
                        if (pushCommands.size == 0) {
                            return None
                        }

                        let objectsToSend = collectObjectsToSend(pushCommands, hsResult.refs)
                        var packData: Array<Byte> = []
                        if (objectsToSend.size > 0) {
                            let writer = PackWriter(repo.hashKind)
                            for (objId in objectsToSend) {
                                let objData = repo.readObject(objId)
                                if (let Some(data) <- objData) {
                                    writer.addObject(data.kind, data.data)
                                }
                            }
                            packData = writer.encode()
                        }

                        if (packData.size == 0 && !hasDeletes(pushCommands)) {
                            return None
                        }

                        tlsTransport.push(pushCommands, packData)
                    } else {
                        None
                    }
                } else {
                    var transport = HttpTransport()
                    if (let Some(auth) <- authOpt) {
                        transport.authHeader = Some("Basic " + auth)
                    }

                    var handshakeResult: ?HandshakeResult = None
                    try {
                        handshakeResult = transport.handshake(parsedUrl, service)
                    } catch (_: Exception) {
                        return None
                    }

                    if (let Some(hsResult) <- handshakeResult) {
                        let pushCommands = resolvePushRefs(refSpecs, hsResult.refs, remoteName)
                        if (pushCommands.size == 0) {
                            return None
                        }

                        let objectsToSend = collectObjectsToSend(pushCommands, hsResult.refs)
                        var packData: Array<Byte> = []
                        if (objectsToSend.size > 0) {
                            let writer = PackWriter(repo.hashKind)
                            for (objId in objectsToSend) {
                                let objData = repo.readObject(objId)
                                if (let Some(data) <- objData) {
                                    writer.addObject(data.kind, data.data)
                                }
                            }
                            packData = writer.encode()
                        }

                        if (packData.size == 0 && !hasDeletes(pushCommands)) {
                            return None
                        }

                        transport.push(pushCommands, packData)
                    } else {
                        None
                    }
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    // 使用 PushOptions 推送
    public func pushWithOptions(options: PushOptions): ?PushResult {
        var refSpecs = ArrayList<String>()

        if (options.refSpecs.size > 0) {
            for (spec in options.refSpecs) {
                var s = ""
                if (spec.force) {
                    s = "+"
                }
                if (let Some(src) <- spec.src) {
                    s = s + src
                }
                if (let Some(dst) <- spec.dst) {
                    s = s + ":" + dst
                }
                if (s.size > 0) {
                    refSpecs.add(s)
                }
            }
        } else {
            // 默认使用 push refspec
            let pushSpecs = getPushRefspecs(options.remoteName)
            if (pushSpecs.size > 0) {
                for (spec in pushSpecs) {
                    refSpecs.add(spec)
                }
            } else {
                // 默认推送当前分支
                refSpecs.add("HEAD")
            }
        }

        push(options.remoteName, refSpecs)
    }

    // 解析远程仓库名称或 URL
    func resolveRemoteUrl(nameOrUrl: String): ?String {
        if (nameOrUrl.startsWith("http://") || nameOrUrl.startsWith("https://") ||
            nameOrUrl.startsWith("git://") || nameOrUrl.startsWith("ssh://") ||
            nameOrUrl.startsWith("file://")) {
            return Some(nameOrUrl)
        }
        // 优先使用 pushUrl，回退到 url
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            let pushUrlKey = "remote." + nameOrUrl + ".pushurl"
            let pushUrl = cfg.find(pushUrlKey)
            if (let Some(u) <- pushUrl) {
                return Some(u)
            }
            let key = "remote." + nameOrUrl + ".url"
            cfg.find(key)
        } else {
            None
        }
    }

    // 获取 push refspec 列表
    func getPushRefspecs(remoteName: String): ArrayList<String> {
        var result = ArrayList<String>()
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            let key = "remote." + remoteName + ".push"
            let pushSpec = cfg.find(key)
            if (let Some(spec) <- pushSpec) {
                result.add(spec)
            }
        }
        result
    }

    // 根据用户指定的 refspec 解析要推送的引用
    // 对齐 git push 中 refspec 匹配逻辑
    func resolvePushRefs(
        refSpecs: ArrayList<String>,
        remoteRefs: ArrayList<Ref>,
        _remoteName: String
    ): ArrayList<RefUpdateCommand> {
        var commands = ArrayList<RefUpdateCommand>()
        var nullId = ObjectId.null(repo.hashKind)

        for (spec in refSpecs) {
            // 解析 refspec
            // 格式: [+]<src>[:<dst>]
            var force = false
            var remaining = spec
            if (remaining.startsWith("+")) {
                force = true
                remaining = remaining[1..]
            }

            var srcRef: ?String = None
            var dstRef: ?String = None
            let colonIdx = remaining.indexOf(":")
            if (let Some(ci) <- colonIdx) {
                srcRef = remaining[0..ci]
                dstRef = remaining[ci + 1..]
            } else {
                srcRef = remaining
            }

            // 解析源引用
            if (let Some(src) <- srcRef) {
                // 特殊处理 HEAD
                var resolvedSrc = src
                if (src == "HEAD") {
                    let head = repo.head()
                    if (let Some(h) <- head) {
                        if (let Target.Symbolic(name) <- h.target) {
                            resolvedSrc = name.value
                        } else if (let Target.Object(id) <- h.target) {
                            resolvedSrc = "HEAD"
                        }
                    }
                } else if (!src.startsWith("refs/")) {
                    resolvedSrc = "refs/heads/" + src
                }

                let localRef = repo.findReference(resolvedSrc)
                if (let Some(lr) <- localRef) {
                    let newId = lr.tryId()
                    if (let Some(nid) <- newId) {
                        // 确定目标引用名
                        var remoteRefName: String
                        if (let Some(dst) <- dstRef) {
                            remoteRefName = dst
                        } else {
                            // 默认：本地分支推送到同名远程分支
                            if (resolvedSrc.startsWith("refs/heads/")) {
                                remoteRefName = resolvedSrc
                            } else if (resolvedSrc.startsWith("refs/tags/")) {
                                remoteRefName = resolvedSrc
                            } else {
                                remoteRefName = resolvedSrc
                            }
                        }

                        // 查找远程引用的旧 ID
                        var oldId = ObjectId.null(repo.hashKind)
                        for (rr in remoteRefs) {
                            let rrName = refName(rr)
                            if (rrName == remoteRefName) {
                                if (let Some(rid) <- refObjectId(rr)) {
                                    oldId = rid
                                }
                            }
                        }

                        // 检查是否需要推送（fast-forward 检查）
                        if (!force && !oldId.equals(nullId) && !oldId.equals(nid)) {
                            // 非强制推送时检查 fast-forward
                            // 简化实现：如果新旧不同且非 null，允许推送
                            // 完整实现需要检查祖先关系
                        }

                        commands.add(RefUpdateCommand(remoteRefName, oldId, nid))
                    }
                } else if (dstRef.isSome()) {
                    // 删除远程引用：src 为空，dst 有值
                    if (let Some(dst) <- dstRef) {
                        var oldId = ObjectId.null(repo.hashKind)
                        for (rr in remoteRefs) {
                            let rrName = refName(rr)
                            if (rrName == dst) {
                                if (let Some(rid) <- refObjectId(rr)) {
                                    oldId = rid
                                }
                            }
                        }
                        if (!oldId.equals(ObjectId.null(repo.hashKind))) {
                            commands.add(RefUpdateCommand(dst, oldId, ObjectId.null(repo.hashKind)))
                        }
                    }
                }
            }
        }

        commands
    }

    // 收集需要推送的对象 ID
    // 对齐 git push 中对象收集逻辑：找出本地有但远程没有的对象
    func collectObjectsToSend(
        pushCommands: ArrayList<RefUpdateCommand>,
        remoteRefs: ArrayList<Ref>
    ): ArrayList<ObjectId> {
        var result = ArrayList<ObjectId>()
        var seen = HashSet<ObjectId>()

        // 收集远程已有的对象 ID
        var remoteIds = HashSet<ObjectId>()
        for (rr in remoteRefs) {
            if (let Some(rid) <- refObjectId(rr)) {
                remoteIds.add(rid)
            }
        }

        // 对每个推送命令，遍历新对象可达的提交
        for (cmd in pushCommands) {
            if (cmd.newId.equals(ObjectId.null(repo.hashKind))) {
                continue
            }
            if (remoteIds.contains(cmd.newId)) {
                continue
            }
            collectReachableObjects(cmd.newId, remoteIds, seen, result)
        }

        result
    }

    // 递归收集从给定对象可达的所有对象
    func collectReachableObjects(
        startId: ObjectId,
        remoteIds: HashSet<ObjectId>,
        seen: HashSet<ObjectId>,
        result: ArrayList<ObjectId>
    ): Unit {
        if (seen.contains(startId)) {
            return
        }
        seen.add(startId)

        if (remoteIds.contains(startId)) {
            return
        }

        result.add(startId)

        // 如果是 commit 对象，递归遍历 tree 和 parent
        let objData = repo.readObject(startId)
        if (let Some(data) <- objData) {
            if (data.kind == ObjectKind.Commit) {
                let commitStr = String.fromUtf8(data.data)
                // 解析 tree 行
                let lines = commitStr.split("\n")
                for (line in lines) {
                    if (line.startsWith("tree ")) {
                        let treeIdStr = line[5..]
                        let treeId = ObjectId.fromHexOrThrow(treeIdStr)
                        collectReachableObjects(treeId, remoteIds, seen, result)
                    } else if (line.startsWith("parent ")) {
                        let parentIdStr = line[7..]
                        let parentId = ObjectId.fromHexOrThrow(parentIdStr)
                        collectReachableObjects(parentId, remoteIds, seen, result)
                    } else if (line.isEmpty()) {
                        break
                    }
                }
            } else if (data.kind == ObjectKind.Tree) {
                // 解析 tree 条目
                let entries = parseTreeEntries(data.data)
                for (entryId in entries) {
                    collectReachableObjects(entryId, remoteIds, seen, result)
                }
            }
        }
    }

    // 解析 tree 对象中的条目，返回所有对象 ID
    func parseTreeEntries(data: Array<Byte>): ArrayList<ObjectId> {
        var result = ArrayList<ObjectId>()
        var pos: Int64 = 0
        while (pos < data.size) {
            // 格式: <mode> <name>\0<20-byte-sha1>
            // 跳过 mode
            while (pos < data.size && data[pos] != UInt8(32)) {
                pos += 1
            }
            pos += 1
            // 跳过 name
            while (pos < data.size && data[pos] != UInt8(0)) {
                pos += 1
            }
            pos += 1
            // 读取 20 字节 SHA-1
            if (pos + 20 <= data.size) {
                var hashBytes = ArrayList<Byte>()
                var j: Int64 = 0
                while (j < 20) {
                    hashBytes.add(data[pos + j])
                    j += 1
                }
                let oid = ObjectId(hashBytes.toArray(), repo.hashKind)
                result.add(oid)
                pos += 20
            } else {
                break
            }
        }
        result
    }

    // 检查推送命令中是否有删除操作
    func hasDeletes(commands: ArrayList<RefUpdateCommand>): Bool {
        let nullId = ObjectId.null(repo.hashKind)
        for (cmd in commands) {
            if (cmd.newId.equals(nullId)) {
                return true
            }
        }
        false
    }
}

// 从 ~/.git-credentials 读取匹配 URL 的凭证
// 对齐 git credential-store 格式: https://user:pass@host/path
func loadCredentialsForUrl(urlStr: String): ?String {
    let homeOpt = homeDir()
    if (homeOpt.isNone()) {
        return None
    }
    var credPath = homeOpt.getOrThrow()
    if (!credPath.endsWith("/") && !credPath.endsWith("\\")) {
        credPath = credPath + "/"
    }
    credPath = credPath + ".git-credentials"
    if (!exists(credPath)) {
        return None
    }
    try {
        let credBytes = readFileBytes(credPath)
        var content = String.fromUtf8(credBytes)
        let lines = content.split("\n")
        for (line in lines) {
            var trimmed = line
            while (trimmed.size > 0 && (trimmed[trimmed.size - 1] == UInt8(13) || trimmed[trimmed.size - 1] == UInt8(10))) {
                trimmed = substringStr(trimmed, 0, trimmed.size - 1)
            }
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            // 格式: http://user:pass@host:port/path
            let schemeEnd = trimmed.indexOf("://")
            if (schemeEnd.isNone()) {
                continue
            }
            let si = schemeEnd.getOrThrow()
            let scheme = toLowerStr(substringStr(trimmed, 0, si))
            let rest = substringFromStr(trimmed, si + 3)
            // 检查 URL 是否匹配
            // 简化匹配：检查 host 和 scheme
            let urlSchemeEnd = urlStr.indexOf("://")
            if (urlSchemeEnd.isNone()) {
                continue
            }
            let urlSi = urlSchemeEnd.getOrThrow()
            let urlScheme = toLowerStr(substringStr(urlStr, 0, urlSi))
            if (scheme != urlScheme) {
                continue
            }
            // 提取 user:pass
            let atIdx = rest.lastIndexOf("@")
            if (atIdx.isNone()) {
                continue
            }
            let ati = atIdx.getOrThrow()
            let userPass = substringStr(rest, 0, ati)
            let hostPart = urlDecode(substringFromStr(rest, ati + 1))
            let urlRest = substringFromStr(urlStr, urlSi + 3)
            // urlRest 可能是 host:port/path 或 host/path
            if (!urlRest.startsWith(hostPart) && !hostPart.startsWith(urlRest)) {
                var credHost = hostPart
                let credHostEnd = hostPart.indexOf("/")
                if (let Some(e) <- credHostEnd) {
                    credHost = substringStr(hostPart, 0, e)
                }
                var urlHost = urlRest
                let urlHostEnd = urlRest.indexOf("/")
                if (let Some(e) <- urlHostEnd) {
                    urlHost = substringStr(urlRest, 0, e)
                }
                var credHostNoPort = credHost
                let credColonIdx = credHost.indexOf(":")
                if (let Some(ci) <- credColonIdx) {
                    credHostNoPort = substringStr(credHost, 0, ci)
                }
                var urlHostNoPort = urlHost
                let urlColonIdx = urlHost.indexOf(":")
                if (let Some(ci) <- urlColonIdx) {
                    urlHostNoPort = substringStr(urlHost, 0, ci)
                }
                if (credHostNoPort != urlHostNoPort) {
                    continue
                }
            }
            // URL decode user:pass
            let decodedUserPass = urlDecode(userPass)
            let encoded = base64Encode(decodedUserPass)
            return Some(encoded)
        }
    } catch (_: Exception) {
        Option<String>.None
    }
    Option<String>.None
}

// URL 解码（处理 %XX 编码）
func urlDecode(s: String): String {
    var result = StringBuilder()
    var i: Int64 = 0
    while (i < s.size) {
        if (s[i] == UInt8(37) && i + 2 < s.size) {
            // %XX
            var hex = substringStr(s, i + 1, i + 3)
            var byteVal = hexToInt(hex)
            result.append(Rune(byteVal))
            i += 3
        } else {
            result.append(Rune(s[i]))
            i += 1
        }
    }
    result.toString()
}

// 十六进制字符串转整数
func hexToInt(hex: String): Int64 {
    var result: Int64 = 0
    for (i in 0..hex.size) {
        var c = hex[i]
        result = result * 16
        if (c >= UInt8(48) && c <= UInt8(57)) {
            result = result + Int64(c) - 48
        } else if (c >= UInt8(65) && c <= UInt8(70)) {
            result = result + Int64(c) - 55
        } else if (c >= UInt8(97) && c <= UInt8(102)) {
            result = result + Int64(c) - 87
        }
    }
    result
}

// Base64 编码
func base64Encode(s: String): String {
    let table = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
    let bytes = s.toArray()
    var chars = ArrayList<Byte>()
    var i: Int64 = 0
    while (i < bytes.size) {
        var b0 = Int64(bytes[i])
        var b1: Int64 = 0
        var b2: Int64 = 0
        var count: Int64 = 1
        if (i + 1 < bytes.size) {
            b1 = Int64(bytes[i + 1])
            count = 2
        }
        if (i + 2 < bytes.size) {
            b2 = Int64(bytes[i + 2])
            count = 3
        }
        var n = (b0 << 16) | (b1 << 8) | b2
        var idx0 = (n >> 18) & 0x3F
        var idx1 = (n >> 12) & 0x3F
        var idx2 = (n >> 6) & 0x3F
        var idx3 = n & 0x3F
        chars.add(table[idx0])
        chars.add(table[idx1])
        if (count >= 2) {
            chars.add(table[idx2])
        } else {
            chars.add(UInt8(61))
        }
        if (count >= 3) {
            chars.add(table[idx3])
        } else {
            chars.add(UInt8(61))
        }
        i += 3
    }
    String.fromUtf8(chars.toArray())
}

// 通过系统 git push 命令推送（用于 HTTPS/SSH 等需要 TLS/SSH 的协议）
func pushViaGitCommand(remoteName: String, refSpecs: ArrayList<String>, gitDir: String): ?PushResult {
    try {
        var args = ArrayList<String>()
        args.add("-C")
        var workDir = gitDir
        if (workDir.endsWith("/.git") || workDir.endsWith("\\.git")) {
            workDir = workDir[0..workDir.size - 4]
        } else if (workDir.endsWith(".git")) {
            workDir = workDir[0..workDir.size - 4]
        }
        args.add(workDir)
        args.add("push")
        args.add(remoteName)
        for (spec in refSpecs) {
            args.add(spec)
        }
        let (exitCode, stdout, stderr) = executeWithOutput("git", args.toArray())
        var stdoutStr = String.fromUtf8(stdout)
        var stderrStr = String.fromUtf8(stderr)
        if (!stdoutStr.isEmpty()) {
            println(stdoutStr)
        }
        if (!stderrStr.isEmpty()) {
            println(stderrStr)
        }
        var errMsg: ?String = None
        if (exitCode != 0) {
            errMsg = Some("git push failed with exit code ${exitCode}")
        }
        var pushResult = PushResult(ArrayList<PushRefUpdateStatus>(), errMsg)
        Some(pushResult)
    } catch (e: Exception) {
        var pushResult = PushResult(ArrayList<PushRefUpdateStatus>(), Some("failed to run git push: ${e.message}"))
        Some(pushResult)
    }
}
