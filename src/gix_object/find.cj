// 文件：find.cj
// 所属包：gix.gix_object
// 用途：定义 Git 对象查找相关的接口和空实现
// 关键类型：Find - 对象查找接口
//           FindExt - 扩展查找接口（含头部查询）
//           Exists - 对象存在性检查接口
//           NeverFind - 所有查找接口的空实现（始终返回空/不存在）

package gitoxide.gix_object

import gitoxide.gix_hash.*

// 对象查找接口
// 定义根据 ObjectId 查找对象数据的基本能力
public interface Find {
    // 尝试查找指定 ID 的对象数据
    // 参数 id：待查找的对象 ID
    // 参数 buffer：用于存储数据的缓冲区
    // 返回值：查找成功返回 Data，未找到返回 None
    func tryFind(id: ObjectId, buffer: Array<Byte>): ?Data
}

// 扩展查找接口
// 在 Find 基础上增加头部信息查询能力
public interface FindExt <: Find {
    // 尝试获取指定 ID 的对象头部信息
    // 参数 id：待查询的对象 ID
    // 返回值：查询成功返回 Header，未找到返回 None
    func tryHeader(id: ObjectId): ?Header
}

// 对象存在性检查接口
// 定义判断对象是否存在的快速检查能力
public interface Exists {
    // 检查指定 ID 的对象是否存在
    // 参数 id：待检查的对象 ID
    // 返回值：存在返回 true，不存在返回 false
    func exists(id: ObjectId): Bool
}

// 空查找实现
// 实现 Find、FindExt 和 Exists 接口，所有操作均返回空/不存在
// 用于不需要实际查找功能的场景（如只写仓库）
public class NeverFind <: Find & FindExt & Exists {
    // 构造函数
    public init() {}
    // 查找对象，始终返回 None
    public func tryFind(id: ObjectId, buffer: Array<Byte>): ?Data {
        None
    }
    // 查询头部信息，始终返回 None
    public func tryHeader(id: ObjectId): ?Header {
        None
    }
    // 检查存在性，始终返回 false
    public func exists(id: ObjectId): Bool {
        false
    }
}
