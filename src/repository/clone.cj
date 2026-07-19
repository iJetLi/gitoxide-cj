// 文件：clone.cj
// 用途：克隆远程仓库到本地，提供克隆选项及克隆流程的各阶段表示
// 所属包：gix.repository
// 关键类型：CloneOptions, PrepareFetch, PrepareCheckout

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_protocol.*
import gitoxide.gix_refspec.*
import gitoxide.gix_ref.*
import gitoxide.gix_ref.store.*
import gitoxide.gix_pack.*
import gitoxide.gix_object.computeHash
import gitoxide.gix_object.ObjectKind
import gitoxide.gix_object.ObjectRef
import gitoxide.gix_object.TreeRef
import gitoxide.gix_config.*
import std.collection.*
import std.fs.*

// 克隆选项，控制克隆行为
public class CloneOptions {
    // 是否创建裸仓库（无工作区）
    public var bare: Bool
    // 克隆时使用的引用规格列表
    public var refSpecs: ArrayList<RefSpec>
    // 远程名称，默认为 "origin"
    public var remoteName: String
    // 指定克隆后检出的分支，None 表示检出默认分支
    public var branch: ?String

    // 初始化克隆选项为默认值
    public init() {
        this.bare = false
        this.refSpecs = ArrayList<RefSpec>()
        this.remoteName = "origin"
        this.branch = None
    }
}

// 准备抓取阶段，表示克隆过程中已解析 URL 即将开始抓取
public class PrepareFetch {
    // 远程仓库 URL
    public var url: Url
    // 克隆选项
    public var options: CloneOptions

    // 参数 url：远程仓库 URL
    // 参数 options：克隆选项
    public init(url: Url, options: CloneOptions) {
        this.url = url
        this.options = options
    }
}

// 准备检出阶段，表示抓取完成即将检出工作区
public class PrepareCheckout {
    // 已初始化的仓库实例
    public var repo: Repository

    // 参数 repo：已初始化的仓库
    public init(repo: Repository) {
        this.repo = repo
    }
}

// 克隆远程仓库到本地路径
// 参数 url：远程仓库 URL 字符串
// 参数 destPath：本地目标路径
// 参数 options：克隆选项
// 返回值：成功返回 Repository，失败返回 None
public func clone(url: String, destPath: String, options: CloneOptions): ?Repository {
    let parsedUrl = Url.parse(url)
    if (parsedUrl.isNone()) {
        println("[clone] Failed to parse URL: ${url}")
        return None
    }
    let u = parsedUrl.getOrThrow()
    let repo = Repository.`init`(destPath, options.bare)
    if (repo.isNone()) {
        println("[clone] Failed to init repo at: ${destPath}")
        return None
    }
    let r = repo.getOrThrow()
    r.addRemote(options.remoteName, url)

    let transportOpt = createCloneTransport(u, url)
    if (transportOpt.isNone()) {
        println("[clone] No transport for URL scheme")
        return None
    }
    let transport = transportOpt.getOrThrow()
    println("[clone] Handshaking...")
    let service = Service.gitUploadPack()
    let handshakeResult = transport.handshake(u, service)
    if (handshakeResult.isNone()) {
        println("[clone] Handshake failed")
        return None
    }
    let hsResult = handshakeResult.getOrThrow()
    println("[clone] Got ${hsResult.refs.size} refs, caps=${hsResult.capabilities.size}")
    for (cap in hsResult.capabilities) {
        println("[clone] cap: ${cap}")
    }

    let wants = ArrayList<ObjectId>()
    for (`ref` in hsResult.refs) {
        if (let Some(id) <- refObjectId(`ref`)) {
            wants.add(id)
        }
    }
    if (wants.size == 0) {
        println("[clone] No wants")
        return None
    }
    let haves = ArrayList<ObjectId>()
    println("[clone] Fetching ${wants.size} objects...")
    let fetchResult = transport.fetch(wants, haves)
    if (fetchResult.isNone()) {
        println("[clone] Fetch failed")
        return None
    }
    let fr = fetchResult.getOrThrow()
    println("[clone] Got pack data: ${fr.packData.size} bytes")

    if (fr.packData.size > 0) {
        let writeOk = writePackAndIndex(r, fr.packData)
        if (!writeOk) {
            println("[clone] Failed to write pack/index")
            return None
        }
        println("[clone] Pack and index written")
    }

    writeCloneRefs(r, hsResult.refs, options.remoteName)

    let headTarget = findDefaultBranch(hsResult.refs)
    if (let Some(target) <- headTarget) {
        updateHead(r, target)
    }

    if (!options.bare) {
        checkoutHead(r)
    }

    Some(r)
}

func createCloneTransport(url: Url, urlStr: String): ?ClientTransport {
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
    None
}

func writePackAndIndex(repo: Repository, packData: Array<Byte>): Bool {
    let headerResult = decodePackHeader(packData)
    if (headerResult.isErr()) {
        return false
    }
    let (_, numObjects) = headerResult.unwrap()
    if (numObjects == 0) {
        return true
    }

    let hashLen = if (repo.hashKind == HashKind.Sha1) {
        20
    } else {
        32
    }
    let packChecksumStart = packData.size - hashLen
    var checksumBytes = ArrayList<Byte>()
    for (i in packChecksumStart..packData.size) {
        checksumBytes.add(packData[i])
    }
    let packChecksum = ObjectId(checksumBytes.toArray(), repo.hashKind)
    let hex = packChecksum.toHexString()

    let packDir = repo.gitDir + "/objects/pack"
    let packPath = packDir + "/pack-" + hex + ".pack"
    let idxPath = packDir + "/pack-" + hex + ".idx"

    try {
        if (!exists(packDir)) {
            Directory.create(packDir)
        }
        let packFile = File(packPath, OpenMode.Write)
        packFile.write(packData)
        packFile.close()
    } catch (_: Exception) {
        return false
    }

    let dataFileResult = DataFile.fromData(packData, packPath, repo.hashKind)
    if (dataFileResult.isErr()) {
        return false
    }
    let dataFile = dataFileResult.unwrap()

    let entriesResult = dataFile.iter()
    if (entriesResult.isErr()) {
        return false
    }
    let entries = entriesResult.unwrap()

    var indexEntries = ArrayList<IndexEntry>()
    var offset: Int64 = 12
    let endOffset = packData.size - hashLen
    var shaToEntryMut = HashMap<String, Entry>()
    var offsetMap = HashMap<Int64, Entry>()
    var ei: Int64 = 0
    while (ei < entries.size && offset < endOffset) {
        let entry = entries[ei]
        let hdrSize = entry.headerSize()
        let decompressed = dataFile.decompressEntry(entry)
        let compSize = if (decompressed.isSome()) {
            decompressed.getOrThrow().compressedSize
        } else {
            Int64(0)
        }

        let entryLen = hdrSize + compSize
        let crcOffset = offset
        var crcBytes = Array<Byte>(entryLen, { i =>
            if (crcOffset + i < packData.size) {
                packData[crcOffset + i]
            } else {
                UInt8(0)
            }
        })
        let crc = crc32OfBytes(crcBytes)

        let kind = entry.header.asKind()
        if (kind.isSome()) {
            let objData = dataFile.decompressEntry(entry)
            if (objData.isSome()) {
                let id = computeHash(repo.hashKind, kind.getOrThrow(), objData.getOrThrow().data)
                indexEntries.add(IndexEntry(id, offset, Some(crc)))
                shaToEntryMut.add(id.toHexString(), entry)
            }
        }
        offsetMap.add(offset, entry)

        offset += entryLen
        ei += 1
    }

    var deltaIndexEntries = ArrayList<IndexEntry>()
    offset = 12
    ei = 0
    while (ei < entries.size && offset < endOffset) {
        let entry = entries[ei]
        let hdrSize = entry.headerSize()
        let decompressed = dataFile.decompressEntry(entry)
        let compSize = if (decompressed.isSome()) {
            decompressed.getOrThrow().compressedSize
        } else {
            Int64(0)
        }

        let entryLen = hdrSize + compSize
        let crcOffset = offset
        var crcBytes = Array<Byte>(entryLen, { i =>
            if (crcOffset + i < packData.size) {
                packData[crcOffset + i]
            } else {
                UInt8(0)
            }
        })
        let crc = crc32OfBytes(crcBytes)

        if (entry.header.isDelta()) {
            let shaToEntry = shaToEntryMut
            let decodedOpt = dataFile.decodeEntryData(entry, { id: ObjectId =>
                let key = id.toHexString()
                if (let Some(baseEntry) <- shaToEntry.get(key)) {
                    Some(ResolvedBase.InPack(baseEntry))
                } else {
                    Option<ResolvedBase>.None
                }
            })
            if (let Some(decoded) <- decodedOpt) {
                let id = computeHash(repo.hashKind, decoded[0], decoded[1])
                deltaIndexEntries.add(IndexEntry(id, offset, Some(crc)))
                shaToEntryMut.add(id.toHexString(), entry)
            }
        }

        offset += entryLen
        ei += 1
    }

    for (die in deltaIndexEntries) {
        indexEntries.add(die)
    }

    indexEntries.sortBy(comparator: {
        a: IndexEntry, b: IndexEntry => a.oid.toHexString().compare(b.oid.toHexString())
    })

    let writer = IndexWriter(repo.hashKind)
    writer.packChecksum = Some(packChecksum)
    writer.write(indexEntries, idxPath)

    true
}

func writeCloneRefs(repo: Repository, refs: ArrayList<Ref>, remoteName: String): Unit {
    let refspec = "+refs/heads/*:refs/remotes/" + remoteName + "/*"
    let fileStore = FileStore(repo.gitDir, repo.hashKind)

    for (`ref` in refs) {
        let name = refName(`ref`)
        if (name == "HEAD") {
            continue
        }
        let oidOpt = refObjectId(`ref`)
        if (oidOpt.isNone()) {
            continue
        }
        let oid = oidOpt.getOrThrow()

        if (name.startsWith("refs/heads/")) {
            let localName = "refs/remotes/" + remoteName + "/" + name[11..]
            let fn = FullName.tryFrom(localName)
            if (let Some(fullName) <- fn) {
                fileStore.write(Reference(fullName, Target.Object(oid), Option<ObjectId>.None))
            }
            let localFn = FullName.tryFrom(name)
            if (let Some(lfn) <- localFn) {
                fileStore.write(Reference(lfn, Target.Object(oid), Option<ObjectId>.None))
            }
        } else if (name.startsWith("refs/tags/")) {
            let fn = FullName.tryFrom(name)
            if (let Some(fullName) <- fn) {
                fileStore.write(Reference(fullName, Target.Object(oid), Option<ObjectId>.None))
            }
        }
    }
}

func findDefaultBranch(refs: ArrayList<Ref>): ?String {
    for (`ref` in refs) {
        match (`ref`) {
            case Ref.Symbolic(name, target, _, _) =>
                if (name == "HEAD") {
                    return Some(target)
                }
            case _ => continue
        }
    }
    for (`ref` in refs) {
        let name = refName(`ref`)
        if (name == "refs/heads/main" || name == "refs/heads/master") {
            return Some(name)
        }
    }
    None
}

func updateHead(repo: Repository, target: String): Unit {
    let headPath = repo.gitDir + "/HEAD"
    try {
        let file = File(headPath, OpenMode.Write)
        let content = "ref: " + target + "\n"
        file.write(content.toArray())
        file.close()
    } catch (_: Exception) {}
}

func checkoutHead(repo: Repository): Unit {
    let headId = resolveHeadId(repo)
    if (headId.isNone()) {
        return
    }
    let id = headId.getOrThrow()
    let obj = repo.readObject(id)
    if (obj.isNone()) {
        return
    }
    let data = obj.getOrThrow()
    if (data.kind != ObjectKind.Commit) {
        return
    }
    let decoded = data.decode()
    if (decoded.isNone()) {
        return
    }
    let commitRef = match (decoded.getOrThrow()) {
        case ObjectRef.Commit(c) => c
        case _ => return
    }
    let treeIdOpt = ObjectId.fromHex(commitRef.tree)
    if (treeIdOpt.isNone()) {
        return
    }
    let treeObj = repo.readObject(treeIdOpt.getOrThrow())
    if (treeObj.isNone()) {
        return
    }
    let treeData = treeObj.getOrThrow()
    if (treeData.kind != ObjectKind.Tree) {
        return
    }
    let treeDecoded = treeData.decode()
    if (treeDecoded.isNone()) {
        return
    }
    let treeRef = match (treeDecoded.getOrThrow()) {
        case ObjectRef.Tree(t) => t
        case _ => return
    }
    let workDir = repo.workDir
    if (workDir.isNone()) {
        return
    }
    let wd = workDir.getOrThrow()
    checkoutTreeRefRecursive(repo, treeRef, wd, "")
}

func checkoutTreeRefRecursive(repo: Repository, tree: TreeRef, baseDir: String, prefix: String): Unit {
    for (entry in tree.entries) {
        let path = if (prefix.size > 0) {
            baseDir + "/" + prefix + "/" + entry.filename
        } else {
            baseDir + "/" + entry.filename
        }
        if (entry.mode.isTree()) {
            if (!exists(path)) {
                try {
                    Directory.create(path)
                } catch (_: Exception) {}
            }
            let subTreeData = repo.readObject(entry.oid)
            if (let Some(d) <- subTreeData) {
                if (d.kind == ObjectKind.Tree) {
                    let subDecoded = d.decode()
                    if (let Some(subObj) <- subDecoded) {
                        let subTreeRef = match (subObj) {
                            case ObjectRef.Tree(t) => t
                            case _ => continue
                        }
                        let newPrefix = if (prefix.size > 0) {
                            prefix + "/" + entry.filename
                        } else {
                            entry.filename
                        }
                        checkoutTreeRefRecursive(repo, subTreeRef, baseDir, newPrefix)
                    }
                }
            }
        } else {
            try {
                let parent = parentDirClone(path)
                if (!exists(parent)) {
                    Directory.create(parent)
                }
                let blobData = repo.readObject(entry.oid)
                if (let Some(d) <- blobData) {
                    let file = File(path, OpenMode.Write)
                    file.write(d.data)
                    file.close()
                }
            } catch (_: Exception) {}
        }
    }
}

func parentDirClone(path: String): String {
    let sep = "/"
    let lastSep = path.lastIndexOf(sep)
    if (let Some(idx) <- lastSep) {
        path[0..idx]
    } else {
        path
    }
}

func resolveHeadId(repo: Repository): ?ObjectId {
    let headRef = repo.head()
    if (headRef.isNone()) {
        return None
    }
    let ref = headRef.getOrThrow()
    var depth: Int64 = 0
    var current = ref
    while (depth < 10) {
        if (let Target.Object(id) <- current.target) {
            if (let Some(p) <- current.peeled) {
                return Some(p)
            }
            return Some(id)
        }
        if (let Target.Symbolic(name) <- current.target) {
            let resolved = repo.findReference(name.value)
            if (let Some(r) <- resolved) {
                current = r
                depth += 1
            } else {
                return None
            }
        } else {
            return None
        }
    }
    None
}
