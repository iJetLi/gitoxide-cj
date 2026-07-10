// 文件：oid.cj
// 用途：定义轻量级对象标识符（oid），用于表示 Git 对象的哈希值
// 所属包：gix.gix_hash
// 关键类型：oid

package gitoxide.gix_hash

// 轻量级对象标识符，存储 Git 对象的原始哈希字节
// 与 ObjectId 不同，oid 不携带哈希算法类型信息
public class oid {
    // 哈希值的原始字节数组
    public var bytes: Array<Byte>

    // 创建一个 oid 实例
    // 参数 bytes：哈希值的原始字节
    public init(bytes: Array<Byte>) {
        this.bytes = bytes
    }

    // 返回哈希值的字节切片（副本）
    // 返回值：与内部字节相同的数组
    public func asSlice(): Array<Byte> {
        bytes
    }

    // 将哈希值转换为十六进制字符串
    // 返回值：小写十六进制表示的哈希字符串
    public func toHexString(): String {
        var sb = StringBuilder()
        for (b in bytes) {
            let high = (Int64(b) >> 4) & 0x0F
            let low = Int64(b) & 0x0F
            sb.append(Rune(hexChar(high)))
            sb.append(Rune(hexChar(low)))
        }
        sb.toString()
    }

    // 判断两个 oid 是否相等
    // 参数 other：待比较的另一个 oid
    // 返回值：字节内容完全相同时返回 true
    public func equals(other: oid): Bool {
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

// 将 0-15 的整数值转换为对应的十六进制字符编码
// 参数 v：0-15 的整数
// 返回值：对应的 ASCII 字符编码（0-9 或 a-f）
func hexChar(v: Int64): UInt8 {
    if (v < 10) {
        UInt8(v + 48)
    } else {
        UInt8(v + 87)
    }
}
