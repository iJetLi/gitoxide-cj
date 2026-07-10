// 文件：tag.cj
// 所属包：gix.gix_object
// 用途：定义 Git Tag（标签）对象的引用类型、拥有类型，以及标签对象的解析与序列化逻辑
// 关键类型：TagRef - Tag 引用类型，字段为字符串形式
//           Tag - Tag 拥有类型，字段为结构化类型（ObjectId、Signature 等）

package gitoxide.gix_object

import std.collection.*
import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import gitoxide.gix_actor.*

// Tag 引用类型
// 表示对标签对象的引用，字段以字符串形式存储，便于从原始数据快速解析
public class TagRef {
    // 目标对象的十六进制哈希值
    public var target: String
    // 目标对象的类型
    public var targetKind: ObjectKind
    // 标签名称
    public var name: String
    // 标签者签名字符串，可选（轻量标签无此字段）
    public var tagger: ?String
    // 标签消息内容
    public var message: String
    // PGP 签名，可选
    public var pgpSignature: ?String

    // 构造函数
    // 参数 target：目标对象哈希
    // 参数 targetKind：目标对象类型
    // 参数 name：标签名称
    // 参数 tagger：标签者签名，可为 None
    // 参数 message：标签消息
    // 参数 pgpSignature：PGP 签名，可为 None
    public init(target: String, targetKind: ObjectKind, name: String, tagger: ?String, message: String,
        pgpSignature: ?String) {
        this.target = target
        this.targetKind = targetKind
        this.name = name
        this.tagger = tagger
        this.message = message
        this.pgpSignature = pgpSignature
    }

    // 从字节数组解析 TagRef
    // 参数 data：标签对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 TagRef，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?TagRef {
        parseTag(data, hashKind)
    }

    // 获取目标对象的 ObjectId
    // 返回值：由 target 字段解析得到的 ObjectId
    public func targetId(): ObjectId {
        ObjectId.fromHex(target)
    }

    // 解析标签者签名为 Signature 对象
    // 返回值：解析成功返回 Signature，无标签者或解析失败返回 None
    public func taggerSignature(): ?Signature {
        if (let Some(raw) <- tagger) {
            Signature.parse(raw.toArray())
        } else {
            None
        }
    }

    // 将 TagRef 转换为拥有类型的 Tag
    // 内部将字符串字段解析为结构化类型
    // 返回值：Tag 实例（注意：tagger 解析失败时仍返回 Tag，tagger 字段为 None）
    public func intoOwned(): ?Tag {
        let targetId = ObjectId.fromHex(target)
        var taggerSig: ?Signature = None
        if (let Some(raw) <- tagger) {
            taggerSig = Signature.parse(raw.toArray())
        }
        Some(Tag(targetId, targetKind, name, taggerSig, message, pgpSignature))
    }
}

// Tag 拥有类型
// 表示完整的 Git 标签对象，字段使用结构化类型存储
public class Tag {
    // 目标对象的 ObjectId
    public var target: ObjectId
    // 目标对象的类型
    public var targetKind: ObjectKind
    // 标签名称
    public var name: String
    // 标签者签名，可选
    public var tagger: ?Signature
    // 标签消息内容
    public var message: String
    // PGP 签名，可选
    public var pgpSignature: ?String

    // 构造函数
    // 参数 target：目标对象 ObjectId
    // 参数 targetKind：目标对象类型
    // 参数 name：标签名称
    // 参数 tagger：标签者签名，可为 None
    // 参数 message：标签消息
    // 参数 pgpSignature：PGP 签名，可为 None
    public init(target: ObjectId, targetKind: ObjectKind, name: String, tagger: ?Signature, message: String,
        pgpSignature: ?String) {
        this.target = target
        this.targetKind = targetKind
        this.name = name
        this.tagger = tagger
        this.message = message
        this.pgpSignature = pgpSignature
    }

    // 从字节数组解析 Tag
    // 参数 data：标签对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 Tag，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?Tag {
        let ref = TagRef.fromBytes(data, hashKind)
        if (let Some(r) <- ref) {
            r.intoOwned()
        } else {
            None
        }
    }

    // 将 Tag 序列化为字节数组
    // 按照 Git 标签对象格式输出：object、type、tag、tagger、空行、消息
    // 返回值：序列化后的字节数组
    public func writeToArray(): Array<Byte> {
        var result = ArrayList<Byte>()
        appendHeaderId2(result, "object", target.toHexString())
        appendHeaderField2(result, "type", kindToString(targetKind))
        appendHeaderField2(result, "tag", name)
        if (let Some(t) <- tagger) {
            appendHeaderSignature2(result, "tagger", t)
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
func appendHeaderId2(out: ArrayList<Byte>, name: String, hexId: String): Unit {
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
func appendHeaderSignature2(out: ArrayList<Byte>, name: String, sig: Signature): Unit {
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
func appendHeaderField2(out: ArrayList<Byte>, name: String, value: String): Unit {
    for (b in name.toArray()) {
        out.add(b)
    }
    out.add(UInt8(32))
    for (b in value.toArray()) {
        out.add(b)
    }
    out.add(UInt8(10))
}

// 解析标签对象的字节数据为 TagRef
// 按照 Git 标签对象格式依次解析 object、type、tag、tagger 和消息
// 参数 data：标签对象的原始字节数据
// 参数 hashKind：哈希算法类型，用于验证目标哈希长度
// 返回值：解析成功返回 TagRef，格式不匹配则返回 None
func parseTag(data: Array<Byte>, hashKind: HashKind): ?TagRef {
    var pos: Int64 = 0
    let targetField = parseHeaderField2(data, pos, "object")
    if (let Some(v) <- targetField) {
        pos = v[1]
        let targetHex = v[0]
        let hashLen = hashKindLenInHex3(hashKind)
        if (targetHex.size != hashLen) {
            return None
        }
        let kindField = parseHeaderField2(data, pos, "type")
        if (let Some(v2) <- kindField) {
            pos = v2[1]
            let targetKindOpt = kindFromBytes(v2[0].toArray())
            if (let Some(tk) <- targetKindOpt) {
                let nameField = parseHeaderField2(data, pos, "tag")
                if (let Some(v3) <- nameField) {
                    pos = v3[1]
                    let tagName = v3[0]
                    var taggerRaw: ?String = None
                    let taggerField = parseHeaderField2(data, pos, "tagger")
                    if (let Some(v4) <- taggerField) {
                        taggerRaw = Some(v4[0])
                        pos = v4[1]
                    }
                    if (pos < data.size && data[pos] == UInt8(10)) {
                        pos += 1
                        let message = bytesToString3(data, pos, data.size)
                        let (msg, sig) = extractPgpSignature(message)
                        return Some(TagRef(targetHex, tk, tagName, taggerRaw, msg, sig))
                    }
                }
            }
        }
    }
    None
}
// 解析指定名称的头部字段
// 在数据中查找 "<name> <value>\n" 格式的头部行
// 参数 data：原始字节数据
// 参数 start：起始解析位置
// 参数 name：期望的头部字段名
// 返回值：解析成功返回 (字段值, 解析结束位置)，失败返回 None
func parseHeaderField2(data: Array<Byte>, start: Int64, name: String): ?(String, Int64) {
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
    let value = bytesToString3(data, valueStart, pos)
    pos += 1
    Some((value, pos))
}

// 根据哈希算法类型获取十六进制哈希值的字符长度
// 参数 kind：哈希算法类型
// 返回值：SHA1 返回 40，SHA256 返回 64
func hashKindLenInHex3(kind: HashKind): Int64 {
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
func bytesToString3(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}

// 从标签消息中提取 PGP 签名
// 查找 "-----BEGIN PGP SIGNATURE-----" 标记，将消息分为正文和签名两部分
// 参数 message：可能包含 PGP 签名的标签消息
// 返回值：(消息正文, 可选的 PGP 签名) 元组
func extractPgpSignature(message: String): (String, ?String) {
    let marker = "-----BEGIN PGP SIGNATURE-----"
    let idx = message.indexOf(marker)
    if (let Some(pos) <- idx) {
        // PGP 标记必须在行首：pos==0 或前面是换行符
        let atLineStart = (pos == 0) || (message[pos - 1] == UInt8(10))
        if (atLineStart) {
            // 去除签名前的换行符
            let msgEnd = if (pos > 0 && message[pos - 1] == UInt8(10)) {
                pos - 1
            } else {
                pos
            }
            let msg = substringStr(message, 0, Int64(msgEnd))
            let sig = substringFromStr(message, Int64(pos))
            (msg, Some(sig))
        } else {
            // PGP 标记不在行首，视为消息内容
            (message, None)
        }
    } else {
        (message, None)
    }
}
