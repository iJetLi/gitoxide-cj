// 文件：object_id.cj
// 用途：定义带哈希算法类型的对象标识符（ObjectId），是 Git 对象哈希的核心表示
// 所属包：gix.gix_hash
// 关键类型：ObjectId

package gitoxide.gix_hash

import std.collection.*
import std.overflow.*

// 带有哈希算法类型的对象标识符
// 与轻量级 oid 不同，ObjectId 同时携带哈希字节和算法类型
// 是 Git 对象系统中最常用的标识符类型
public class ObjectId {
    // 哈希值的原始字节（不可变）
    public let bytes: Array<Byte>
    // 哈希算法类型
    public let kind: HashKind
    // 创建一个 ObjectId 实例
    // 参数 bytes：哈希值的原始字节
    // 参数 kind：哈希算法类型
    public init(bytes: Array<Byte>, kind: HashKind) {
        this.bytes = bytes
        this.kind = kind
    }

    // 从十六进制字符串解析创建 ObjectId
    // 根据字符串长度自动推断哈希算法类型：40 字符为 SHA-1，64 字符为 SHA-256
    // 对齐 Rust: ObjectId::from_hex(buffer) -> Result<ObjectId, Error>
    // 仓颉差异：返回 ?ObjectId，解析失败返回 None
    // 参数 hex：十六进制格式的哈希字符串
    // 返回值：解析成功返回 ObjectId，失败返回 None
    public static func fromHex(hex: String): ?ObjectId {
        if (hex.size != 40 && hex.size != 64) {
            return None
        }
        var result = ArrayList<Byte>()
        var i: Int64 = 0
        while (i + 1 < hex.size) {
            let high = hexDigitValue(hex[i])
            let low = hexDigitValue(hex[i + 1])
            if (high < 0 || low < 0) {
                return None
            }
            result.add(UInt8((high << 4) | low))
            i += 2
        }
        let kind = if (hex.size == 40) {
            HashKind.Sha1
        } else {
            HashKind.Sha256
        }
        ObjectId(result.toArray(), kind)
    }

    // 便捷方法：从十六进制字符串解析，失败时抛出异常
    // 用于已知 hex 字符串合法的测试场景
    public static func fromHexOrThrow(hex: String): ObjectId {
        fromHex(hex).getOrThrow()
    }

    // 检查哈希是否全为零字节
    // 对齐 Rust: ObjectId::is_null() -> bool
    // 返回值：全零返回 true
    public func isNull(): Bool {
        for (b in bytes) {
            if (b != UInt8(0)) {
                return false
            }
        }
        true
    }

    // 获取空 blob 对象的 ObjectId
    // 空 blob 是 Git 中的特殊对象，内容为空
    // 参数 kind：哈希算法类型
    // 返回值：空 blob 对应的 ObjectId
    public static func emptyBlob(kind: HashKind): ObjectId {
        match (kind) {
            case HashKind.Sha1 => ObjectId.fromHexOrThrow("e69de29bb2d1d6434b8b29ae775ad8c2e48c5391")
            case HashKind.Sha256 => ObjectId.fromHexOrThrow(
                "473a0f4c3be8a93681a267e3b1e9a7dcda1185436fe141f7749120a303721813")
        }
    }

    // 获取空 tree 对象的 ObjectId
    // 空 tree 是 Git 中的特殊对象，不包含任何条目
    // 参数 kind：哈希算法类型
    // 返回值：空 tree 对应的 ObjectId
    public static func emptyTree(kind: HashKind): ObjectId {
        match (kind) {
            case HashKind.Sha1 => ObjectId.fromHexOrThrow("4b825dc642cb6eb9a060e54bf8d69288fbee4904")
            case HashKind.Sha256 => ObjectId.fromHexOrThrow(
                "6ef19b41225c5369f1c104d45d8d85efa9b057b53b14b4b9b939dd74decc5321")
        }
    }

    // 获取全零 ObjectId（null hash）
    // 对齐 Rust: ObjectId::null
    // 参数 kind：哈希算法类型
    // 返回值：全零的 ObjectId
    public static func null(kind: HashKind): ObjectId {
        match (kind) {
            case HashKind.Sha1 => ObjectId.fromHexOrThrow("0000000000000000000000000000000000000000")
            case HashKind.Sha256 => ObjectId.fromHexOrThrow(
                "0000000000000000000000000000000000000000000000000000000000000000")
        }
    }

    // 将哈希值转换为十六进制字符串
    // 返回值：小写十六进制表示的哈希字符串
    public func toHexString(): String {
        var sb = StringBuilder()
        for (b in bytes) {
            let high = (Int64(b) >> 4) & 0x0F
            let low = Int64(b) & 0x0F
            sb.append(Rune(hexDigitChar(high)))
            sb.append(Rune(hexDigitChar(low)))
        }
        sb.toString()
    }

    // 判断两个 ObjectId 是否相等
    // 参数 other：待比较的另一个 ObjectId
    // 返回值：字节内容完全相同时返回 true
    public func equals(other: ObjectId): Bool {
        if (bytes.size != other.bytes.size) {
            return false
        }
        for (i in 0..bytes.size) {
            if (bytes[i] != other.bytes[i]) {
                return false
            }
        }
        true
    }
}

extend ObjectId <: Equatable<ObjectId> {
    public operator func ==(other: ObjectId): Bool {
        this.equals(other)
    }

    public operator func !=(other: ObjectId): Bool {
        !(this == other)
    }
}

extend ObjectId <: Hashable {
    public func hashCode(): Int64 {
        var h: Int64 = 0
        for (b in bytes) {
            let (overflow1, prod) = h.carryingMul(31)
            let (overflow2, sum) = prod.carryingAdd(Int64(b))
            if (overflow1 || overflow2) {
                h = sum % 2971215073
            } else {
                h = sum
            }
        }
        h
    }
}

// 将十六进制字符（0-9, A-F, a-f）转换为对应的数值
// 参数 c：十六进制字符的 ASCII 编码
// 返回值：0-15 的数值，非法字符返回 -1
func hexDigitValue(c: UInt8): Int64 {
    if (c >= UInt8(48) && c <= UInt8(57)) {
        Int64(c - UInt8(48))
    } else if (c >= UInt8(65) && c <= UInt8(70)) {
        Int64(c - UInt8(55))
    } else if (c >= UInt8(97) && c <= UInt8(102)) {
        Int64(c - UInt8(87))
    } else {
        -1
    }
}

// 将 0-15 的整数值转换为对应的十六进制字符编码
// 参数 v：0-15 的整数
// 返回值：对应的 ASCII 字符编码（0-9 或 a-f）
func hexDigitChar(v: Int64): UInt8 {
    if (v < 10) {
        UInt8(v + 48)
    } else {
        UInt8(v + 87)
    }
}
