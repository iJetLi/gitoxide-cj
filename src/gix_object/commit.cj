// 文件：commit.cj
// 所属包：gix.gix_object
// 用途：定义 Git Commit（提交）对象的引用类型、拥有类型，以及提交对象的解析与序列化逻辑
// 关键类型：CommitRef - Commit 引用类型，字段为字符串形式
//           Commit - Commit 拥有类型，字段为结构化类型（ObjectId、Signature 等）

package gitoxide.gix_object

import std.collection.*
import gitoxide.gix_hash.*
import gitoxide.gix_actor.*

// Commit 引用类型
// 表示对提交对象的引用，字段以字符串形式存储，便于从原始数据快速解析
public class CommitRef {
    // 根树对象的十六进制哈希值
    public var tree: String
    // 父提交的十六进制哈希值列表
    public var parents: ArrayList<String>
    // 作者签名字符串（名称、邮箱、时间戳）
    public var author: String
    // 提交者签名字符串（名称、邮箱、时间戳）
    public var committer: String
    // 提交消息的编码格式，可选
    public var encoding: ?String
    // 提交消息内容
    public var message: String
    // 额外的头部字段列表，每个元素为 (字段名, 字段值) 的元组
    public var extraHeaders: ArrayList<(String, String)>

    // 构造函数
    // 参数 tree：根树哈希
    // 参数 parents：父提交哈希列表
    // 参数 author：作者签名
    // 参数 committer：提交者签名
    // 参数 encoding：编码格式，可为 None
    // 参数 message：提交消息
    // 参数 extraHeaders：额外头部字段列表
    public init(tree: String, parents: ArrayList<String>, author: String, committer: String, encoding: ?String,
        message: String, extraHeaders: ArrayList<(String, String)>) {
        this.tree = tree
        this.parents = parents
        this.author = author
        this.committer = committer
        this.encoding = encoding
        this.message = message
        this.extraHeaders = extraHeaders
    }

    // 从字节数组解析 CommitRef
    // 参数 data：提交对象的原始字节数据
    // 参数 hashKind：哈希算法类型（SHA1 或 SHA256）
    // 返回值：解析成功返回 CommitRef，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?CommitRef {
        parseCommit(data, hashKind)
    }

    // 获取根树对象的 ObjectId
    // 返回值：由 tree 字段解析得到的 ObjectId
    public func treeId(): ObjectId {
        ObjectId.fromHexOrThrow(tree)
    }

    // 获取所有父提交的 ObjectId 列表
    // 返回值：由 parents 字段解析得到的 ObjectId 列表
    public func parentIds(): ArrayList<ObjectId> {
        var result = ArrayList<ObjectId>()
        for (p in parents) {
            result.add(ObjectId.fromHexOrThrow(p))
        }
        result
    }

    // 解析作者签名为 Signature 对象
    // 返回值：解析成功返回 Signature，失败返回 None
    public func authorSignature(): ?Signature {
        Signature.parse(author.toArray())
    }

    // 解析提交者签名为 Signature 对象
    // 返回值：解析成功返回 Signature，失败返回 None
    public func committerSignature(): ?Signature {
        Signature.parse(committer.toArray())
    }

    // 将 CommitRef 转换为拥有类型的 Commit
    // 内部将字符串字段解析为结构化类型
    // 返回值：解析成功返回 Commit，任一签名解析失败则返回 None
    public func intoOwned(): ?Commit {
        let treeId = ObjectId.fromHexOrThrow(tree)
        var parentIds = ArrayList<ObjectId>()
        for (p in parents) {
            parentIds.add(ObjectId.fromHexOrThrow(p))
        }
        let authorSig = Signature.parse(author.toArray())
        let committerSig = Signature.parse(committer.toArray())
        if (let Some(a) <- authorSig) {
            if (let Some(c) <- committerSig) {
                Some(Commit(treeId, parentIds, a, c, encoding, message, extraHeaders))
            } else {
                None
            }
        } else {
            None
        }
    }
}

// Commit 拥有类型
// 表示完整的 Git 提交对象，字段使用结构化类型存储
public class Commit {
    // 根树对象的 ObjectId
    public var tree: ObjectId
    // 父提交的 ObjectId 列表
    public var parents: ArrayList<ObjectId>
    // 作者签名
    public var author: Signature
    // 提交者签名
    public var committer: Signature
    // 提交消息的编码格式，可选
    public var encoding: ?String
    // 提交消息内容
    public var message: String
    // 额外的头部字段列表
    public var extraHeaders: ArrayList<(String, String)>

    // 构造函数
    // 参数 tree：根树 ObjectId
    // 参数 parents：父提交 ObjectId 列表
    // 参数 author：作者签名
    // 参数 committer：提交者签名
    // 参数 encoding：编码格式，可为 None
    // 参数 message：提交消息
    // 参数 extraHeaders：额外头部字段列表
    public init(tree: ObjectId, parents: ArrayList<ObjectId>, author: Signature, committer: Signature,
        encoding: ?String, message: String, extraHeaders: ArrayList<(String, String)>) {
        this.tree = tree
        this.parents = parents
        this.author = author
        this.committer = committer
        this.encoding = encoding
        this.message = message
        this.extraHeaders = extraHeaders
    }

    // 从字节数组解析 Commit
    // 参数 data：提交对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 Commit，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?Commit {
        let ref = CommitRef.fromBytes(data, hashKind)
        if (let Some(r) <- ref) {
            r.intoOwned()
        } else {
            None
        }
    }

    // 将 Commit 序列化为字节数组
    // 按照 Git 提交对象格式输出：tree、parent、author、committer、encoding、额外头部、空行、消息
    // 返回值：序列化后的字节数组
    public func writeToArray(): Array<Byte> {
        var result = ArrayList<Byte>()
        appendHeaderId(result, "tree", tree.toHexString())
        for (p in parents) {
            appendHeaderId(result, "parent", p.toHexString())
        }
        appendHeaderSignature(result, "author", author)
        appendHeaderSignature(result, "committer", committer)
        if (let Some(enc) <- encoding) {
            appendHeaderField(result, "encoding", enc)
        }
        for ((name, value) in extraHeaders) {
            appendHeaderField(result, name, value)
        }
        result.add(UInt8(10))
        for (b in message.toArray()) {
            result.add(b)
        }
        result.toArray()
    }
}

// 向输出缓冲区追加带哈希 ID 的头部行
// 格式："<name> <hexId>\n"
// 参数 out：输出缓冲区
// 参数 name：头部字段名
// 参数 hexId：十六进制哈希值
func appendHeaderId(out: ArrayList<Byte>, name: String, hexId: String): Unit {
    for (b in name.toArray()) {
        out.add(b)
    }
    out.add(UInt8(32))
    for (b in hexId.toArray()) {
        out.add(b)
    }
    out.add(UInt8(10))
}

// 向输出缓冲区追加带签名的头部行
// 格式："<name> <signature>\n"
// 参数 out：输出缓冲区
// 参数 name：头部字段名
// 参数 sig：签名对象
func appendHeaderSignature(out: ArrayList<Byte>, name: String, sig: Signature): Unit {
    for (b in name.toArray()) {
        out.add(b)
    }
    out.add(UInt8(32))
    for (b in sig.toBytes()) {
        out.add(b)
    }
    out.add(UInt8(10))
}

// 向输出缓冲区追加普通头部行
// 格式："<name> <value>\n"
// 参数 out：输出缓冲区
// 参数 name：头部字段名
// 参数 value：字段值
func appendHeaderField(out: ArrayList<Byte>, name: String, value: String): Unit {
    for (b in name.toArray()) {
        out.add(b)
    }
    out.add(UInt8(32))
    for (b in value.toArray()) {
        out.add(b)
    }
    out.add(UInt8(10))
}

// 解析提交对象的字节数据为 CommitRef
// 按照 Git 提交对象格式依次解析 tree、parent、author、committer、encoding、额外头部和消息
// 参数 data：提交对象的原始字节数据
// 参数 hashKind：哈希算法类型，用于验证 tree/parent 哈希长度
// 返回值：解析成功返回 CommitRef，格式不匹配则返回 None
func parseCommit(data: Array<Byte>, hashKind: HashKind): ?CommitRef {
    var pos: Int64 = 0
    var parents = ArrayList<String>()
    var encoding: ?String = None
    var extraHeaders = ArrayList<(String, String)>()

    let tree = parseHeaderField(data, pos, "tree")
    if (let Some(v) <- tree) {
        pos = v[1]
        let treeHex = v[0]
        let hashLen = hashKindLenInHex(hashKind)
        if (treeHex.size != hashLen) {
            return None
        }

        // 循环解析所有 parent 字段
        while (true) {
            let parent = parseHeaderField(data, pos, "parent")
            if (let Some(v) <- parent) {
                pos = v[1]
                parents.add(v[0])
            } else {
                break
            }
        }

        let author = parseHeaderField(data, pos, "author")
        if (let Some(v) <- author) {
            pos = v[1]
            let committer = parseHeaderField(data, pos, "committer")
            if (let Some(v2) <- committer) {
                pos = v2[1]

                // 尝试解析可选的 encoding 字段
                let enc = parseHeaderField(data, pos, "encoding")
                if (let Some(v3) <- enc) {
                    encoding = Some(v3[0])
                    pos = v3[1]
                }

                // 解析剩余的额外头部字段
                while (true) {
                    let extra = parseAnyHeaderField(data, pos)
                    if (let Some(v4) <- extra) {
                        pos = v4[1]
                        extraHeaders.add((v4[0], v4[0]))
                    } else {
                        break
                    }
                }

                // 空行之后为提交消息
                if (pos < data.size && data[pos] == UInt8(10)) {
                    pos += 1
                    let message = bytesToString(data, pos, data.size)
                    Some(CommitRef(treeHex, parents, v[0], v2[0], encoding, message, extraHeaders))
                } else {
                    None
                }
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

// 解析指定名称的头部字段
// 在数据中查找 "<name> <value>\n" 格式的头部行
// 参数 data：原始字节数据
// 参数 start：起始解析位置
// 参数 name：期望的头部字段名
// 返回值：解析成功返回 (字段值, 解析结束位置)，失败返回 None
func parseHeaderField(data: Array<Byte>, start: Int64, name: String): ?(String, Int64) {
    var pos = start
    let nameBytes = name.toArray()
    if (pos + nameBytes.size + 1 >= data.size) {
        return None
    }
    var i: Int64 = 0
    while (i < nameBytes.size) {
        if (data[pos + i] != nameBytes[i]) {
            return None
        }
        i += 1
    }
    pos += nameBytes.size
    if (data[pos] != UInt8(32)) {
        return None
    }
    pos += 1
    let valueStart = pos
    while (pos < data.size && data[pos] != UInt8(10)) {
        pos += 1
    }
    if (pos >= data.size) {
        return None
    }
    let value = bytesToString(data, valueStart, pos)
    pos += 1
    Some((value, pos))
}

// 解析任意名称的头部字段
// 在数据中查找 "<name> <value>\n" 格式的头部行，不限定字段名
// 参数 data：原始字节数据
// 参数 start：起始解析位置
// 返回值：解析成功返回 (字段名, 解析结束位置)，失败返回 None
func parseAnyHeaderField(data: Array<Byte>, start: Int64): ?(String, Int64) {
    var pos = start
    if (pos >= data.size) {
        return None
    }
    // 遇到空行则头部结束
    if (data[pos] == UInt8(10)) {
        return None
    }
    let nameStart = pos
    while (pos < data.size && data[pos] != UInt8(32) && data[pos] != UInt8(10)) {
        pos += 1
    }
    if (pos >= data.size || data[pos] != UInt8(32)) {
        return None
    }
    let name = bytesToString(data, nameStart, pos)
    pos += 1
    let valueStart = pos
    while (pos < data.size && data[pos] != UInt8(10)) {
        pos += 1
    }
    if (pos >= data.size) {
        return None
    }
    let value = bytesToString(data, valueStart, pos)
    pos += 1
    Some((name, pos))
}

// 根据哈希算法类型获取十六进制哈希值的字符长度
// 参数 kind：哈希算法类型
// 返回值：SHA1 返回 40，SHA256 返回 64
func hashKindLenInHex(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 40
        case HashKind.Sha256 => 64
    }
}

// 将字节数组的指定范围转换为字符串
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：由字节转换得到的字符串
func bytesToString(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
