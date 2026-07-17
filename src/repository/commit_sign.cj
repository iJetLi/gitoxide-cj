// 文件：commit_sign.cj
// 用途：仓库层 commit sign 胶水模块，桥接 gix_command/GPG 到 Repository
// 所属包：gitoxide.repository
// 关键类型：CommitSignQuery
// 对齐原版：gitoxide-core/src/repository/commit.rs::sign()

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_command.*
import gitoxide.gix_ref.*
import std.collection.*
import std.fs.*
import std.io.*
import gitoxide.gix_command.arg
import gitoxide.gix_utils.*

// commit sign 查询类
// 对齐原版：gitoxide-core/src/repository/commit.rs::sign()
public class CommitSignQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 签名提交：调用 GPG 对提交数据签名，将签名写入新提交对象
    // 对齐原版：gitoxide-core/src/repository/commit.rs::sign()
    // 参数 revSpec：要签名的提交规格，默认 HEAD
    // 返回值：签名后的新提交 ObjectId，失败返回 None
    public func sign(revSpec: String): ?ObjectId {
        let query = RevisionQuery(repo)
        let idOpt = query.resolve(revSpec)
        if (let Some(id) <- idOpt) {
            let dataOpt = repo.readObject(id)
            if (let Some(data) <- dataOpt) {
                if (let Some(ObjectRef.Commit(c)) <- data.decode()) {
                    if (hasPgpSignature(c)) {
                        return Some(id)
                    }
                    let signatureOpt = gpgSignData(data.data)
                    if (let Some(sig) <- signatureOpt) {
                        let signedData = insertSignatureHeader(data.data, sig)
                        let signedId = repo.writeObject(ObjectKind.Commit, signedData)
                        return Some(signedId)
                    }
                    None
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    // 验证提交签名：检查提交是否有 PGP 签名
    // 对齐原版：gitoxide-core/src/repository/commit.rs::verify()
    // 参数 revSpec：要验证的提交规格，默认 HEAD
    // 返回值：签名验证结果字符串
    public func verify(revSpec: String): String {
        let query = RevisionQuery(repo)
        let idOpt = query.resolve(revSpec)
        if (let Some(id) <- idOpt) {
            let dataOpt = repo.readObject(id)
            if (let Some(data) <- dataOpt) {
                if (let Some(ObjectRef.Commit(c)) <- data.decode()) {
                    if (hasPgpSignature(c)) {
                        let sigOpt = extractPgpSignature(c)
                        if (let Some(sig) <- sigOpt) {
                            let unsignedData = stripSignatureHeader(data.data)
                            let verifyResult = gpgVerifySignature(unsignedData, sig)
                            if (verifyResult == "OK") {
                                return "Commit at ${revSpec} has a valid signature"
                            } else {
                                return "Commit at ${revSpec} has an invalid signature (GPG verification failed)"
                            }
                        } else {
                            return "Commit at ${revSpec} is signed (signature verification requires GPG)"
                        }
                    } else {
                        return "Error: Commit at ${revSpec} is not signed"
                    }
                } else {
                    return "Error: Object is not a commit"
                }
            } else {
                return "Error: Object not found"
            }
        } else {
            return "Error: Cannot resolve: ${revSpec}"
        }
    }

    // 检查 CommitRef 是否包含 PGP 签名头部
    // 对齐原版：gix::objs::commit::SignatureField::pgp_signature()
    func hasPgpSignature(c: CommitRef): Bool {
        for ((name, _) in c.extraHeaders) {
            if (name == "gpgsig" || name == "gpgsig-sha256") {
                return true
            }
        }
        false
    }

    // 从 CommitRef 中提取 PGP 签名数据
    // 对齐原版：commit_ref.extra_headers().pgp_signature()
    func extractPgpSignature(c: CommitRef): ?String {
        for ((name, value) in c.extraHeaders) {
            if (name == "gpgsig" || name == "gpgsig-sha256") {
                return Some(value)
            }
        }
        None
    }

    func insertSignatureHeader(raw: Array<Byte>, signature: String): Array<Byte> {
        var blankLinePos: Int64 = -1
        var i: Int64 = 0
        while (i < raw.size - 1) {
            if (raw[i] == UInt8(10) && raw[i + 1] == UInt8(10)) {
                blankLinePos = i + 1
                break
            }
            i += 1
        }
        if (blankLinePos < 0) {
            if (raw.size > 0 && raw[raw.size - 1] == UInt8(10)) {
                blankLinePos = raw.size
            } else {
                return raw
            }
        }
        var sigLines = signature.split("\n")
        var sigBlock = ArrayList<Byte>()
        for (b in "gpgsig ".toArray()) { sigBlock.add(b) }
        var first = true
        for (line in sigLines) {
            if (!first) {
                sigBlock.add(UInt8(10))
                sigBlock.add(UInt8(32))
            }
            for (b in line.toArray()) { sigBlock.add(b) }
            first = false
        }
        sigBlock.add(UInt8(10))
        var result = ArrayList<Byte>()
        for (k in 0..blankLinePos) { result.add(raw[k]) }
        for (b in sigBlock) { result.add(b) }
        for (k in blankLinePos..raw.size) { result.add(raw[k]) }
        result.toArray()
    }

    func stripSignatureHeader(raw: Array<Byte>): Array<Byte> {
        let gpgsig = "gpgsig ".toArray()
        let gpgsigSha256 = "gpgsig-sha256 ".toArray()
        var sigStart: Int64 = -1
        var sigEnd: Int64 = -1
        var i: Int64 = 0
        while (i < raw.size) {
            if (sigStart < 0) {
                if (i + gpgsig.size <= raw.size) {
                    var isMatch = true
                    for (j in 0..gpgsig.size) {
                        if (raw[i + j] != gpgsig[j]) {
                            isMatch = false
                            break
                        }
                    }
                    if (isMatch) {
                        sigStart = i
                        i += 1
                        continue
                    }
                }
                if (i + gpgsigSha256.size <= raw.size) {
                    var isMatch2 = true
                    for (j in 0..gpgsigSha256.size) {
                        if (raw[i + j] != gpgsigSha256[j]) {
                            isMatch2 = false
                            break
                        }
                    }
                    if (isMatch2) {
                        sigStart = i
                        i += 1
                        continue
                    }
                }
            } else {
                if (raw[i] != UInt8(32) && raw[i] != UInt8(9)) {
                    if (raw[i - 1] == UInt8(10)) {
                        sigEnd = i
                        break
                    }
                }
            }
            i += 1
        }
        if (sigStart >= 0 && sigEnd < 0) {
            sigEnd = raw.size
        }
        if (sigStart >= 0 && sigEnd > sigStart) {
            var result = ArrayList<Byte>()
            for (k in 0..sigStart) { result.add(raw[k]) }
            for (k in sigEnd..raw.size) { result.add(raw[k]) }
            return result.toArray()
        }
        raw
    }

    // 调用 GPG 对数据进行签名
    // 对齐原版：gitoxide-core/src/repository/commit.rs::sign() 中调用 gpg --detach-sign --sign --armor
    // 实现方式：将数据写入临时文件，调用 GPG 签名，读取签名输出
    func gpgSignData(data: Array<Byte>): ?String {
        try {
            // 创建临时文件存放待签名数据
            let tempDir = repo.gitDir + "/tmp"
            if (!exists(tempDir)) {
                Directory.create(tempDir)
            }
            let dataPath = tempDir + "/gix-sign-data.tmp"
            let dataFile = File(dataPath, OpenMode.Write)
            dataFile.write(data)
            dataFile.close()

            // 调用 GPG 签名
            // 对齐原版：gpg --keyid-format=long --status-fd=2 --detach-sign --sign --armor
            var p = Prepare("gpg")
            p = arg(p, "--keyid-format=long")
            p = arg(p, "--status-fd=2")
            p = arg(p, "--detach-sign")
            p = arg(p, "--armor")
            p = arg(p, "--sign")
            p = arg(p, dataPath)
            let result = runPrepare(p)

            try {
                let sigPath = dataPath + ".asc"
                if (exists(sigPath)) {
                    let sigData = readFileBytes(sigPath)
                    remove(sigPath)
                    if (exists(dataPath)) { remove(dataPath) }
                    return Some(String.fromUtf8(sigData))
                }
                let gpgPath = dataPath + ".gpg"
                if (exists(gpgPath)) {
                    let sigData = readFileBytes(gpgPath)
                    remove(gpgPath)
                    if (exists(dataPath)) { remove(dataPath) }
                    return Some(String.fromUtf8(sigData))
                }
                if (exists(dataPath)) { remove(dataPath) }
            } catch (_: Exception) {
            }

            if (let Some(r) <- result) {
                if (r.success() && !r.stdout.isEmpty()) {
                    return Some(r.stdout)
                }
            }
            None
        } catch (_: Exception) {
            None
        }
    }

    // 调用 GPG 验证签名
    // 对齐原版：gitoxide-core/src/repository/commit.rs::verify() 中调用 gpg --verify
    func gpgVerifySignature(signedData: Array<Byte>, signature: String): String {
        try {
            let tempDir = repo.gitDir + "/tmp"
            if (!exists(tempDir)) {
                Directory.create(tempDir)
            }
            let sigPath = tempDir + "/gix-verify-sig.tmp"
            let sigFile = File(sigPath, OpenMode.Write)
            sigFile.write(signature.toArray())
            sigFile.close()

            let dataPath = tempDir + "/gix-verify-data.tmp"
            let dataFile = File(dataPath, OpenMode.Write)
            dataFile.write(signedData)
            dataFile.close()

            var p2 = Prepare("gpg")
            p2 = arg(p2, "--keyid-format=long")
            p2 = arg(p2, "--status-fd=1")
            p2 = arg(p2, "--verify")
            p2 = arg(p2, sigPath)
            p2 = arg(p2, dataPath)
            let result = runPrepare(p2)

            try {
                if (exists(sigPath)) { remove(sigPath) }
                if (exists(dataPath)) { remove(dataPath) }
            } catch (_: Exception) {
            }

            if (let Some(r) <- result) {
                if (r.success()) {
                    return "OK"
                } else {
                    return "FAIL"
                }
            }
            "FAIL no_result"
        } catch (_: Exception) {
            "FAIL exception"
        }
    }

    // 序列化 CommitRef 为 Git 提交对象字节数组
    // 对齐原版：gix::objs::CommitRef::write_to()
    func serializeCommitRef(c: CommitRef): Array<Byte> {
        var result = ArrayList<Byte>()
        // tree <hash>\n
        for (b in "tree ".toArray()) { result.add(b) }
        for (b in c.tree.toArray()) { result.add(b) }
        result.add(UInt8(10))
        // parent <hash>\n
        for (p in c.parents) {
            for (b in "parent ".toArray()) { result.add(b) }
            for (b in p.toArray()) { result.add(b) }
            result.add(UInt8(10))
        }
        // author <sig>\n
        for (b in "author ".toArray()) { result.add(b) }
        for (b in c.author.toArray()) { result.add(b) }
        result.add(UInt8(10))
        // committer <sig>\n
        for (b in "committer ".toArray()) { result.add(b) }
        for (b in c.committer.toArray()) { result.add(b) }
        result.add(UInt8(10))
        // encoding <enc>\n
        if (let Some(enc) <- c.encoding) {
            for (b in "encoding ".toArray()) { result.add(b) }
            for (b in enc.toArray()) { result.add(b) }
            result.add(UInt8(10))
        }
        // extra headers
        for ((name, value) in c.extraHeaders) {
            for (b in name.toArray()) { result.add(b) }
            result.add(UInt8(32))
            // 多行头部值（如 gpgsig）需要空格前缀续行
            var isFirstLine = true
            var lines = value.split("\n")
            for (line in lines) {
                if (!isFirstLine) {
                    result.add(UInt8(10))
                    result.add(UInt8(32))
                }
                for (b in line.toArray()) { result.add(b) }
                isFirstLine = false
            }
            result.add(UInt8(10))
        }
        // 空行
        result.add(UInt8(10))
        // 消息
        for (b in c.message.toArray()) { result.add(b) }
        result.toArray()
    }

    // 读取文件全部字节
    func readFileBytes(path: String): Array<Byte> {
        try {
            let file = File(path, OpenMode.Read)
            var bytes = ArrayList<Byte>()
            var buf = Array<Byte>(4096, repeat: 0)
            var n = file.read(buf)
            while (n > 0) {
                for (i in 0..n) {
                    bytes.add(buf[i])
                }
                n = file.read(buf)
            }
            file.close()
            bytes.toArray()
        } catch (_: Exception) {
            Array<Byte>()
        }
    }
}
