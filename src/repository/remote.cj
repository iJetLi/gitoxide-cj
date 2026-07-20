// 文件：remote.cj
// 用途：仓库层 remote 胶水模块，桥接 gix_transport/gix_config 到 Repository
// 所属包：gitoxide.repository
// 关键类型：RemoteQuery
// 对齐原版：gitoxide-core/src/repository/remote.rs

package gitoxide.repository

import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_hash.*
import gitoxide.gix_config.*
import gitoxide.gix_ref.*
import std.collection.*
import std.process.*

// remote 查询类
// 对齐原版：gitoxide-core/src/repository/remote.rs
public class RemoteQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 获取远程仓库的 URL
    // 对齐原版：gix -r <repo> remote url
    // 参数 remoteName：远程仓库名称，默认 "origin"
    // 参数 push：是否获取 push URL
    // 参数 all：是否获取所有 URL
    // 返回值：URL 列表
    public func url(remoteName: String, push: Bool, all: Bool): ArrayList<String> {
        var result = ArrayList<String>()
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            if (push) {
                // 对齐原版：remote.<name>.pushUrl
                let pushUrlKey = "remote." + remoteName + ".pushurl"
                let pushUrl = cfg.find(pushUrlKey)
                if (let Some(u) <- pushUrl) {
                    result.add(u)
                } else {
                    // fallback to fetch url
                    let fetchUrlKey = "remote." + remoteName + ".url"
                    let fetchUrl = cfg.find(fetchUrlKey)
                    if (let Some(u) <- fetchUrl) {
                        result.add(u)
                    }
                }
            } else {
                // 对齐原版：remote.<name>.url
                let fetchUrlKey = "remote." + remoteName + ".url"
                let fetchUrl = cfg.find(fetchUrlKey)
                if (let Some(u) <- fetchUrl) {
                    result.add(u)
                }
                if (all) {
                    // 对齐原版：--all 输出所有有效 URL（包括 pushUrl）
                    let pushUrlKey = "remote." + remoteName + ".pushurl"
                    let pushUrl = cfg.find(pushUrlKey)
                    if (let Some(u) <- pushUrl) {
                        if (!result.contains(u)) {
                            result.add(u)
                        }
                    }
                }
            }
        }
        result
    }

    // 获取远程仓库的引用列表
    // 对齐原版：gix -r <repo> remote refs
    // 参数 remoteName：远程仓库名称或 URL，默认 "origin"
    // 参数 handshakeInfo：是否显示握手信息
    // 返回值：HandshakeResult，包含引用列表
    public func refs(remoteName: String, handshakeInfo: Bool): ?RemoteRefsResult {
        let urlStr = resolveRemoteUrl(remoteName)
        if (let Some(u) <- urlStr) {
            let url = Url.parse(u)
            if (let Some(parsedUrl) <- url) {
                let transportOpt = createTransport(parsedUrl, u)
                if (let Some(transport) <- transportOpt) {
                    let service = Service.gitUploadPack()
                    let handshakeResult = transport.handshake(parsedUrl, service)
                    if (let Some(result) <- handshakeResult) {
                        var showHandshake = handshakeInfo
                        return Some(
                            RemoteRefsResult(result.refs, result.protocolVersion, result.capabilities, showHandshake))
                    }
                } else {
                    return refsViaGitCommand(u)
                }
            }
        }
        None
    }

    // 获取远程仓库的引用映射（经过 refspec 过滤）
    // 对齐原版：gix -r <repo> remote ref-map
    // 参数 remoteName：远程仓库名称或 URL，默认 "origin"
    // 参数 showUnmapped：是否显示未映射的远程引用
    // 返回值：RefMapResult，包含映射后的引用列表
    public func refMap(remoteName: String, showUnmapped: Bool): ?RefMapResult {
        let urlStr = resolveRemoteUrl(remoteName)
        if (let Some(u) <- urlStr) {
            let url = Url.parse(u)
            if (let Some(parsedUrl) <- url) {
                let transportOpt = createTransport(parsedUrl, u)
                if (let Some(transport) <- transportOpt) {
                    let service = Service.gitUploadPack()
                    let handshakeResult = transport.handshake(parsedUrl, service)
                    if (let Some(result) <- handshakeResult) {
                        let refspecs = getFetchRefspecs(remoteName)
                        var mappings = ArrayList<RefMapping>()
                        var unmapped = ArrayList<Ref>()
                        for (`ref` in result.refs) {
                            let mapped = applyRefspecs(`ref`, refspecs, remoteName)
                            if (let Some(m) <- mapped) {
                                mappings.add(m)
                            } else {
                                unmapped.add(`ref`)
                            }
                        }
                        return Some(RefMapResult(mappings, unmapped, refspecs, showUnmapped))
                    }
                } else {
                    let refsResult = refsViaGitCommand(u)
                    if (let Some(rr) <- refsResult) {
                        let refspecs = getFetchRefspecs(remoteName)
                        var mappings = ArrayList<RefMapping>()
                        var unmapped = ArrayList<Ref>()
                        for (`ref` in rr.refs) {
                            let mapped = applyRefspecs(`ref`, refspecs, remoteName)
                            if (let Some(m) <- mapped) {
                                mappings.add(m)
                            } else {
                                unmapped.add(`ref`)
                            }
                        }
                        return Some(RefMapResult(mappings, unmapped, refspecs, showUnmapped))
                    }
                }
            }
        }
        None
    }

    // 解析远程仓库名称或 URL
    // 对齐原版：gitoxide-core/src/repository/remote.rs::by_name_or_url()
    func resolveRemoteUrl(nameOrUrl: String): ?String {
        if (nameOrUrl.startsWith("http://") || nameOrUrl.startsWith("https://") || nameOrUrl.startsWith("git://") ||
            nameOrUrl.startsWith("ssh://") || nameOrUrl.startsWith("file://") || nameOrUrl.startsWith("git@")) {
            return Some(nameOrUrl)
        }
        if (nameOrUrl.contains(":") && nameOrUrl.contains("/")) {
            return Some(nameOrUrl)
        }
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            let key = "remote." + nameOrUrl + ".url"
            cfg.find(key)
        } else {
            None
        }
    }

    func createTransport(url: Url, urlStr: String): ?ClientTransport {
        let authOpt = loadCredentialsForUrl(urlStr)
        if (url.scheme == Scheme.Http) {
            let t = HttpTransport()
            if (let Some(auth) <- authOpt) {
                t.authHeader = Some("Basic " + auth)
            }
            return Some(t)
        }
        if (url.scheme == Scheme.Https) {
            let t = TlsHttpTransport()
            if (let Some(auth) <- authOpt) {
                t.authHeader = Some("Basic " + auth)
            }
            return Some(t)
        }
        if (url.scheme == Scheme.Git) {
            return Some(GitTcpTransport())
        }
        if (url.scheme == Scheme.File) {
            return Some(FileTransport())
        }
        None
    }

    func refsViaGitCommand(urlStr: String): ?RemoteRefsResult {
        try {
            let (exitCode, stdout, stderr) = executeWithOutput("git", ["ls-remote", "--symref", urlStr])
            if (exitCode != 0) {
                return None
            }
            var refs = ArrayList<Ref>()
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
            Some(RemoteRefsResult(refs, ProtocolVersion.V2, ArrayList<String>(), false))
        } catch (_: Exception) {
            None
        }
    }
    // 对齐原版：gix::remote::refspecs()
    func getFetchRefspecs(remoteName: String): ArrayList<String> {
        var result = ArrayList<String>()
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            // 默认 refspec
            let key = "remote." + remoteName + ".fetch"
            let fetchSpec = cfg.find(key)
            if (let Some(spec) <- fetchSpec) {
                result.add(spec)
            }
        }
        // 如果没有配置 refspec，使用默认
        if (result.size == 0) {
            result.add("+refs/heads/*:refs/remotes/" + remoteName + "/*")
        }
        result
    }

    // 应用 refspec 将远程引用映射到本地引用
    // 对齐原版：gix::refspec::match_group::Mapping
    func applyRefspecs(`ref`: Ref, refspecs: ArrayList<String>, remoteName: String): ?RefMapping {
        let refName = refName(`ref`)
        for (spec in refspecs) {
            // 解析 refspec 格式：[+]<src>:<dst>
            var src = spec
            var dst = ""
            var forced = false
            if (src.startsWith("+")) {
                forced = true
                src = src[1..]
            }
            let colonIdx = src.indexOf(":")
            if (let Some(ci) <- colonIdx) {
                dst = src[ci + 1..]
                src = src[0..ci]
            }
            // 通配符匹配
            if (src.endsWith("/*")) {
                let prefix = src[0..src.size - 2]
                if (refName.startsWith(prefix)) {
                    let suffix = refName[prefix.size..]
                    let localName = dst[0..dst.size - 2] + suffix
                    // 检查本地引用状态
                    let status = checkLocalRefStatus(localName, `ref`)
                    let oid = refObjectId(`ref`)
                    return Some(RefMapping(refName, localName, status, forced, oid))
                }
            } else {
                // 精确匹配
                if (refName == src) {
                    let status = checkLocalRefStatus(dst, `ref`)
                    let oid = refObjectId(`ref`)
                    return Some(RefMapping(refName, dst, status, forced, oid))
                }
            }
        }
        None
    }

    // 检查本地引用状态
    // 对齐原版：gitoxide-core/src/repository/remote/refs.rs 中 [up-to-date]/[changed]/[new] 判断
    func checkLocalRefStatus(localName: String, remoteRef: Ref): String {
        let remoteId = refObjectId(remoteRef)
        let localRef = repo.findReference(localName)
        if (let Some(lr) <- localRef) {
            let localId = lr.tryId()
            if (let Some(lid) <- localId) {
                if (let Some(rid) <- remoteId) {
                    if (lid == rid) {
                        return "[up-to-date]"
                    } else {
                        return "[changed]"
                    }
                } else {
                    return "[skipped]"
                }
            } else {
                return "[skipped]"
            }
        }
        "[new]"
    }
}

// 远程引用列表结果
// 对齐原版：gix -r <repo> remote refs 输出
public class RemoteRefsResult {
    public var refs: ArrayList<Ref>
    public var protocolVersion: ProtocolVersion
    public var capabilities: ArrayList<String>
    public var showHandshake: Bool

    public init(refs: ArrayList<Ref>, protocolVersion: ProtocolVersion, capabilities: ArrayList<String>,
        showHandshake: Bool) {
        this.refs = refs
        this.protocolVersion = protocolVersion
        this.capabilities = capabilities
        this.showHandshake = showHandshake
    }
}

// 引用映射结果
// 对齐原版：gix -r <repo> remote ref-map 输出
public class RefMapping {
    public var remoteRef: String
    public var localRef: String
    public var status: String
    public var forced: Bool
    public var objectId: ?ObjectId

    public init(remoteRef: String, localRef: String, status: String, forced: Bool, objectId: ?ObjectId) {
        this.remoteRef = remoteRef
        this.localRef = localRef
        this.status = status
        this.forced = forced
        this.objectId = objectId
    }
}

// ref-map 结果
// 对齐原版：gix::remote::fetch::RefMap
public class RefMapResult {
    public var mappings: ArrayList<RefMapping>
    public var unmapped: ArrayList<Ref>
    public var refspecs: ArrayList<String>
    public var showUnmapped: Bool

    public init(mappings: ArrayList<RefMapping>, unmapped: ArrayList<Ref>, refspecs: ArrayList<String>,
        showUnmapped: Bool) {
        this.mappings = mappings
        this.unmapped = unmapped
        this.refspecs = refspecs
        this.showUnmapped = showUnmapped
    }
}
