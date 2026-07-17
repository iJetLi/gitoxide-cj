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
                    // 检查是否已有签名，对齐原版：commit_ref.extra_headers().pgp_signature().is_some()
                    if (hasPgpSignature(c)) {
                        // 对齐原版：已签名则直接返回原 ID
                        return Some(id)
                    }
                    // 调用 GPG 签名
                    let signatureOpt = gpgSignData(data.data)
                    if (let Some(sig) <- signatureOpt) {
                        // 将签名添加到 extraHeaders
                        let newHeaders = ArrayList<(String, String)>()
                        for ((name, value) in c.extraHeaders) {
                            newHeaders.add((name, value))
                        }
                        newHeaders.add(("gpgsig", sig))
                        // 构造新的 CommitRef 并序列化
                        let newCommit = CommitRef(c.tree, c.parents, c.author, c.committer, c.encoding, c.message, newHeaders)
                        let newCommitData = serializeCommitRef(newCommit)
                        let signedId = repo.writeObject(ObjectKind.Commit, newCommitData)
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
                        // 尝试提取签名数据并调用 GPG 验证
                        let sigOpt = extractPgpSignature(c)
                        if (let Some(sig) <- sigOpt) {
                            let verifyResult = gpgVerifySignature(data.data, sig)
                            if (verifyResult) {
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
            p = arg(p, "--detach-sign")
            p = arg(p, "--armor")
            p = arg(p, "--sign")
            p = arg(p, dataPath)
            let result = runPrepare(p)

            // 清理临时文件
            try {
                if (exists(dataPath)) {
                    remove(dataPath)
                }
                // GPG 可能生成 .gpg 签名文件
                let sigPath = dataPath + ".asc"
                if (exists(sigPath)) {
                    // 读取签名文件
                    let sigData = readFileBytes(sigPath)
                    remove(sigPath)
                    return Some(String.fromUtf8(sigData))
                }
                let gpgPath = dataPath + ".gpg"
                if (exists(gpgPath)) {
                    remove(gpgPath)
                }
            } catch (_: Exception) {
            }

            // 如果 GPG 成功但没有找到签名文件，检查 stdout
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
    func gpgVerifySignature(signedData: Array<Byte>, signature: String): Bool {
        try {
            let tempDir = repo.gitDir + "/tmp"
            if (!exists(tempDir)) {
                Directory.create(tempDir)
            }
            // 写入签名文件
            let sigPath = tempDir + "/gix-verify-sig.tmp"
            let sigFile = File(sigPath, OpenMode.Write)
            sigFile.write(signature.toArray())
            sigFile.close()

            // 写入已签名数据
            let dataPath = tempDir + "/gix-verify-data.tmp"
            let dataFile = File(dataPath, OpenMode.Write)
            dataFile.write(signedData)
            dataFile.close()

            // 调用 GPG 验证
            var p2 = Prepare("gpg")
            p2 = arg(p2, "--keyid-format=long")
            p2 = arg(p2, "--status-fd=1")
            p2 = arg(p2, "--verify")
            p2 = arg(p2, sigPath)
            p2 = arg(p2, dataPath)
            let result = runPrepare(p2)

            // 清理临时文件
            try {
                if (exists(sigPath)) { remove(sigPath) }
                if (exists(dataPath)) { remove(dataPath) }
            } catch (_: Exception) {
            }

            if (let Some(r) <- result) {
                return r.success()
            }
            false
        } catch (_: Exception) {
            false
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
