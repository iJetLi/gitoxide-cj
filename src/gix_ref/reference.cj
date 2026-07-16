// 文件：reference.cj
// 用途：定义 Git 引用类型，支持直接引用和符号引用的解析与序列化
// 所属包：gix.gix_ref
// 关键类型：Reference

package gitoxide.gix_ref

import gitoxide.gix_hash.*
import std.collection.*

// Git 引用，包含引用名、目标和已解析的 ObjectId
// 支持两种目标类型：直接指向对象（Object）和指向另一个引用（Symbolic）
public class Reference {
    // 引用的完整名称
    public var name: FullName
    // 引用目标（对象 ID 或符号引用名）
    public var target: Target
    // 已解析的 ObjectId（标签引用 peel 后的对象 ID），可选
    public var peeled: ?ObjectId

    // 构造函数
    // 参数 name：引用名
    // 参数 target：引用目标
    // 参数 peeled：已解析的 ObjectId
    public init(name: FullName, target: Target, peeled: ?ObjectId) {
        this.name = name
        this.target = target
        this.peeled = peeled
    }

    // 从字节数组解析 Reference
    // 参数 data：引用文件的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 Reference，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?Reference {
        parseReference(data, hashKind)
    }

    // 获取引用的类型（对象引用或符号引用）
    // 返回值：引用类型枚举值
    public func kind(): RefKind {
        targetKind(target)
    }

    // 尝试获取引用指向的 ObjectId
    // 仅对直接引用有效，符号引用返回 None
    // 返回值：对象 ID
    public func tryId(): ?ObjectId {
        targetTryId(target)
    }

    // 尝试获取符号引用指向的引用名
    // 仅对符号引用有效，直接引用返回 None
    // 返回值：引用名
    public func tryName(): ?FullName {
        targetTryName(target)
    }

    // 将引用序列化为字节数组
    // 符号引用格式："ref: <name>\n"，直接引用格式："<hex-id>\n"
    // 返回值：序列化后的字节数组
    public func toBytes(): Array<Byte> {
        if (let Target.Symbolic(n) <- target) {
            var result = ArrayList<Byte>()
            let prefix = "ref: "
            for (b in prefix.toArray()) {
                result.add(b)
            }
            for (b in n.value.toArray()) {
                result.add(b)
            }
            result.add(UInt8(10))
            result.toArray()
        } else if (let Target.Object(id) <- target) {
            var result = ArrayList<Byte>()
            let hex = id.toHexString()
            for (b in hex.toArray()) {
                result.add(b)
            }
            result.add(UInt8(10))
            result.toArray()
        } else {
            Array<Byte>()
        }
    }

    // 解引用符号引用，返回指向的引用
    // 对齐 Rust: Reference::follow
    // 参数 finder：引用查找器
    // 返回值：找到返回引用，未找到或非符号引用返回 None
    public func follow(finder: FindObject): ?Reference {
        if (let Target.Symbolic(n) <- target) {
            finder.findRef(n)
        } else {
            None
        }
    }
}

// 解析引用文件的字节数据
// 区分符号引用（以 "ref: " 开头）和直接引用（十六进制哈希值）
// 参数 data：引用文件的原始字节数据
// 参数 hashKind：哈希算法类型
// 返回值：解析成功返回 Reference，失败返回 None
func parseReference(data: Array<Byte>, hashKind: HashKind): ?Reference {
    if (data.size == 0) {
        return None
    }
    if (data.size > 5) {
        var isSym = true
        let prefix = "ref: "
        var i: Int64 = 0
        while (i < 5) {
            if (data[i] != prefix.toArray()[i]) {
                isSym = false
                break
            }
            i += 1
        }
        if (isSym) {
            let nameStart: Int64 = 5
            var nameEnd = data.size
            if (data[data.size - 1] == UInt8(10)) {
                nameEnd = nameEnd - 1
            }
            let refName = bytesToStringRef(data, nameStart, nameEnd)
            let fullName = FullName.tryFrom(refName)
            if (let Some(fn) <- fullName) {
                return Some(Reference(fn, Target.Symbolic(fn), None))
            }
            return None
        }
    }
    parseObjectIdRef(data, hashKind)
}

// 解析直接引用（十六进制哈希值）
// 参数 data：引用文件的原始字节数据
// 参数 hashKind：哈希算法类型
// 返回值：解析成功返回 Reference
func parseObjectIdRef(data: Array<Byte>, hashKind: HashKind): ?Reference {
    var end = data.size
    if (end > 0 && data[end - 1] == UInt8(10)) {
        end -= 1
    }
    let hexStr = bytesToStringRef(data, 0, end)
    let idOpt = ObjectId.fromHex(hexStr)
    if (idOpt.isNone()) {
        return None
    }
    let id = idOpt.getOrThrow()
    let name = FullName("HEAD")
    Some(Reference(name, Target.Object(id), None))
}

// 将字节数组的指定范围转换为字符串
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：转换得到的字符串
func bytesToStringRef(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
