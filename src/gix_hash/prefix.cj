// 文件：prefix.cj
// 用途：定义对象 ID 前缀类型，用于 Git 的缩写哈希匹配场景
// 所属包：gix.gix_hash
// 关键类型：Prefix

package gitoxide.gix_hash

// 对象 ID 前缀，表示 ObjectId 的前若干个十六进制字符
// 常用于 Git 的缩写哈希引用（如 git log --abbrev-commit）
public class Prefix {
    // 完整的对象标识符
    public var id: ObjectId
    // 前缀的十六进制字符长度
    public var hexLen: Int64

    // 创建一个 Prefix 实例（不检查合法性）
    // 参数 id：完整的对象标识符
    // 参数 hexLen：前缀的十六进制字符长度
    public init(id: ObjectId, hexLen: Int64) {
        this.id = id
        this.hexLen = hexLen
    }

    // 安全地创建一个 Prefix 实例，会验证 hexLen 的合法性
    // 参数 id：完整的对象标识符
    // 参数 hexLen：前缀的十六进制字符长度，必须不小于 0 且不超过 id 的十六进制总长度
    // 返回值：合法时返回 Some(Prefix)，非法时返回 None
    public static func new(id: ObjectId, hexLen: Int64): ?Prefix {
        if (hexLen < 0 || hexLen > id.bytes.size * 2) {
            return None
        }
        Some(Prefix(id, hexLen))
    }

    // 判断此前缀是否匹配给定的完整 ObjectId
    // 比较前 hexLen 个十六进制字符对应的字节
    // 参数 other：待匹配的完整对象标识符
    // 返回值：前缀匹配时返回 true
    public func matches(other: ObjectId): Bool {
        let byteLen = (hexLen + 1) / 2
        if (byteLen > other.bytes.size) {
            return false
        }
        var i: Int64 = 0
        while (i < byteLen) {
            if (id.bytes[i] != other.bytes[i]) {
                return false
            }
            i += 1
        }
        true
    }
}
