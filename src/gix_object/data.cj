// 文件：data.cj
// 所属包：gix.gix_object
// 用途：定义 Git 对象的数据容器类型和头部信息类型
// 关键类型：Data - 封装对象类型、哈希算法和原始字节数据的容器
//           Header - 封装对象头部信息（类型和大小）

package gitoxide.gix_object

import gitoxide.gix_hash.*

// 对象数据容器
// 封装 Git 对象的类型、哈希算法和原始字节数据，提供解码和类型转换功能
public class Data {
    // 对象类型
    public var kind: ObjectKind
    // 对象使用的哈希算法
    public var objectHash: HashKind
    // 对象体的原始字节数据
    public var data: Array<Byte>

    // 构造函数
    // 参数 kind：对象类型
    // 参数 objectHash：哈希算法类型
    // 参数 data：对象体的原始字节数据
    public init(kind: ObjectKind, objectHash: HashKind, data: Array<Byte>) {
        this.kind = kind
        this.objectHash = objectHash
        this.data = data
    }

    // 将数据解码为 ObjectRef
    // 根据对象类型和哈希算法解析原始字节数据
    // 返回值：解析成功返回 ObjectRef，失败返回 None
    public func decode(): ?ObjectRef {
        objectRefFromBytes(data, kind, objectHash)
    }

    // 尝试将数据转换为树条目迭代器
    // 仅当对象类型为 Tree 时返回迭代器，用于惰性遍历树条目
    // 返回值：对象类型为 Tree 时返回 TreeRefIter，否则返回 None
    public func tryIntoTreeIter(): ?TreeRefIter {
        match (kind) {
            case ObjectKind.Tree => Some(TreeRefIter(data, objectHash))
            case _ => None
        }
    }
}

// 对象头部信息
// 封装从松散对象头部解析出的类型和大小信息
public class Header {
    // 对象类型
    public var kind: ObjectKind
    // 对象体数据的字节大小
    public var size: Int64

    // 构造函数
    // 参数 kind：对象类型
    // 参数 size：对象体数据的字节大小
    public init(kind: ObjectKind, size: Int64) {
        this.kind = kind
        this.size = size
    }
}
