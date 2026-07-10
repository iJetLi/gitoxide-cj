// 文件：kind.cj
// 用途：定义哈希算法类型枚举，用于标识 Git 对象使用的哈希算法
// 所属包：gix.gix_hash
// 关键类型：HashKind

package gitoxide.gix_hash

public enum HashKind {
    | Sha1
    | Sha256
}

extend HashKind <: Equatable<HashKind> {
    public operator func ==(other: HashKind): Bool {
        match (this) {
            case HashKind.Sha1 => match (other) {
                case HashKind.Sha1 => true
                case _ => false
            }
            case HashKind.Sha256 => match (other) {
                case HashKind.Sha256 => true
                case _ => false
            }
        }
    }

    public operator func !=(other: HashKind): Bool {
        !(this == other)
    }
}

public func matchHashKind(a: HashKind, b: HashKind): Bool {
    a == b
}
