// 文件：find.cj
// 用途：定义对象数据库的查找、头部查询、存在性检查和写入接口
// 所属包：gix.gix_odb
// 关键类型：OdbFind、OdbFindHeader、OdbExists、OdbWrite

package gitoxide.gix_odb

import gitoxide.gix_hash.*
import gitoxide.gix_object.*

// 对象查找接口，按 ObjectId 尝试查找完整的对象数据
public interface OdbFind {
    // 尝试根据对象 ID 查找对象数据
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    func tryFind(id: ObjectId): ?Data
}

// 对象头部查询接口，按 ObjectId 获取对象的类型和大小信息
public interface OdbFindHeader {
    // 尝试根据对象 ID 获取对象头部信息（类型和大小）
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 Header，未找到返回 None
    func tryHeader(id: ObjectId): ?Header
}

// 对象存在性检查接口
public interface OdbExists {
    // 检查指定 ID 的对象是否存在于对象数据库中
    // 参数 id：要检查的对象 ID
    // 返回值：存在返回 true，否则返回 false
    func exists(id: ObjectId): Bool
}

// 对象写入接口，将对象数据写入对象数据库
public interface OdbWrite {
    // 将对象写入对象数据库
    // 参数 kind：对象类型（如 Blob、Tree、Commit 等）
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    func write(kind: ObjectKind, data: Array<Byte>): ObjectId
}
