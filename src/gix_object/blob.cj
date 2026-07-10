// 文件：blob.cj
// 所属包：gix.gix_object
// 用途：定义 Git Blob（文件）对象的引用类型和拥有类型
// 关键类型：BlobRef - Blob 引用类型，持有原始字节数据
//           Blob - Blob 拥有类型，表示完整的文件内容对象

package gitoxide.gix_object

// Blob 引用类型
// 表示对 Blob 对象的引用，直接持有文件内容的字节数据
public class BlobRef {
    // 文件内容的原始字节数据
    public var data: Array<Byte>

    // 构造函数
    // 参数 data：文件内容的字节数据
    public init(data: Array<Byte>) {
        this.data = data
    }

    // 从字节数组创建 BlobRef
    // 参数 data：文件内容的字节数据
    // 返回值：包含该数据的 BlobRef 实例
    public static func fromBytes(data: Array<Byte>): BlobRef {
        BlobRef(data)
    }

    // 将 BlobRef 转换为拥有类型的 Blob
    // 返回值：包含相同数据的 Blob 实例
    public func intoOwned(): Blob {
        Blob(data)
    }

    // 获取文件内容的大小
    // 返回值：字节数据的长度
    public func size(): Int64 {
        data.size
    }
}

// Blob 拥有类型
// 表示完整的 Git Blob 对象，持有文件内容的字节数据
public class Blob {
    // 文件内容的原始字节数据
    public var data: Array<Byte>

    // 构造函数
    // 参数 data：文件内容的字节数据
    public init(data: Array<Byte>) {
        this.data = data
    }

    // 将 Blob 转换为引用类型的 BlobRef
    // 返回值：包含相同数据的 BlobRef 实例
    public func toRef(): BlobRef {
        BlobRef(data)
    }

    // 获取文件内容的大小
    // 返回值：字节数据的长度
    public func size(): Int64 {
        data.size
    }

    // 将 Blob 数据序列化为字节数组
    // 返回值：文件内容的原始字节数据
    public func writeToArray(): Array<Byte> {
        data
    }
}
