// 文件：write.cj
// 所属包：gix.gix_object
// 用途：定义 Git 对象写入相关的接口
// 关键类型：Write - 对象写入接口（将数据写入对象存储并返回 ID）
//           WriteTo - 对象序列化接口（将对象序列化为字节数组）

package gitoxide.gix_object

import gitoxide.gix_hash.*

// 对象写入接口
// 定义将对象数据写入底层存储的能力，返回新写入对象的 ObjectId
public interface Write {
    // 将指定类型的数据写入对象存储
    // 参数 kind：对象类型
    // 参数 from：对象体的字节数据
    // 返回值：写入成功后对象的 ObjectId
    func writeBuf(kind: ObjectKind, from: Array<Byte>): ObjectId
}

// 对象序列化接口
// 定义将对象序列化为字节数组的能力，用于写入前的数据准备
public interface WriteTo {
    // 将对象序列化为字节数组
    // 返回值：序列化后的字节数组
    func writeToArray(): Array<Byte>
    // 获取对象类型
    // 返回值：对象的 ObjectKind 枚举值
    func kind(): ObjectKind
    // 获取对象体数据的大小
    // 返回值：序列化后数据的字节长度
    func size(): Int64
}
