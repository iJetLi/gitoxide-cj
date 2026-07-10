// 文件：kind.cj
// 所属包：gix.gix_object
// 用途：定义 Git 对象类型枚举及其与字节/字符串之间的转换函数
// 关键类型：ObjectKind - 表示 Git 对象的四种类型（Tree、Blob、Commit、Tag）

package gitoxide.gix_object

// Git 对象类型枚举
// 表示 Git 仓库中四种基础对象类型
public enum ObjectKind {
    | Tree // 树对象，表示目录结构
    | Blob // 文件对象，表示文件内容
    | Commit // 提交对象，表示提交记录
    | Tag
}

extend ObjectKind <: Equatable<ObjectKind> {
    public operator func ==(other: ObjectKind): Bool {
        match (this) {
            case ObjectKind.Tree => match (other) {
                case ObjectKind.Tree => true
                case _ => false
            }
            case ObjectKind.Blob => match (other) {
                case ObjectKind.Blob => true
                case _ => false
            }
            case ObjectKind.Commit => match (other) {
                case ObjectKind.Commit => true
                case _ => false
            }
            case ObjectKind.Tag => match (other) {
                case ObjectKind.Tag => true
                case _ => false
            }
        }
    }

    public operator func !=(other: ObjectKind): Bool {
        !(this == other)
    }

    public func toString(): String {
        kindToString(this)
    }
}

// 从字节数组解析对象类型
// 参数 s：包含类型名称的字节数组，如 "tree"、"blob" 等
// 返回值：匹配到的 ObjectKind，若无法识别则返回 None
public func kindFromBytes(s: Array<Byte>): ?ObjectKind {
    if (equalsBytes(s, "tree")) {
        return Some(ObjectKind.Tree)
    }
    if (equalsBytes(s, "blob")) {
        return Some(ObjectKind.Blob)
    }
    if (equalsBytes(s, "commit")) {
        return Some(ObjectKind.Commit)
    }
    if (equalsBytes(s, "tag")) {
        return Some(ObjectKind.Tag)
    }
    None
}

// 将对象类型转换为字节数组
// 参数 kind：对象类型枚举值
// 返回值：对应类型名称的字节数组
public func kindAsBytes(kind: ObjectKind): Array<Byte> {
    match (kind) {
        case ObjectKind.Tree => "tree".toArray()
        case ObjectKind.Blob => "blob".toArray()
        case ObjectKind.Commit => "commit".toArray()
        case ObjectKind.Tag => "tag".toArray()
    }
}

// 将对象类型转换为字符串
// 参数 kind：对象类型枚举值
// 返回值：对应类型名称的字符串
public func kindToString(kind: ObjectKind): String {
    match (kind) {
        case ObjectKind.Tree => "tree"
        case ObjectKind.Blob => "blob"
        case ObjectKind.Commit => "commit"
        case ObjectKind.Tag => "tag"
    }
}

// 比较字节数组与字符串是否相等
// 参数 a：待比较的字节数组
// 参数 b：待比较的字符串
// 返回值：若内容完全相同则返回 true，否则返回 false
func equalsBytes(a: Array<Byte>, b: String): Bool {
    if (a.size != b.size) {
        return false
    }
    var i: Int64 = 0
    while (i < a.size) {
        if (a[i] != b[i]) {
            return false
        }
        i += 1
    }
    true
}
