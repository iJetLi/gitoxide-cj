// 文件：sink.cj
// 用途：空存储实现（Sink），所有读取操作返回空值，写入操作仅计算哈希但不持久化
// 所属包：gix.gix_odb
// 关键类型：SinkStore

package gitoxide.gix_odb

import gitoxide.gix_hash.*
import gitoxide.gix_object.*

// 空存储，用于仅需要计算对象哈希而不需要实际存储的场景
// 实现了 OdbFind、OdbFindHeader、OdbExists、OdbWrite 四个接口
public class SinkStore <: OdbFind & OdbFindHeader & OdbExists & OdbWrite {
    // 构造函数，无状态
    public init() {}

    // 尝试查找对象数据，始终返回 None（空存储中无数据）
    // 参数 id：要查找的对象 ID（忽略）
    // 返回值：始终为 None
    public func tryFind(id: ObjectId): ?Data {
        None
    }

    // 尝试获取对象头部信息，始终返回 None（空存储中无数据）
    // 参数 id：要查询的对象 ID（忽略）
    // 返回值：始终为 None
    public func tryHeader(id: ObjectId): ?Header {
        None
    }

    // 检查对象是否存在，始终返回 false（空存储中无数据）
    // 参数 id：要检查的对象 ID（忽略）
    // 返回值：始终为 false
    public func exists(id: ObjectId): Bool {
        false
    }

    // 写入对象，仅计算哈希值但不持久化数据
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：根据对象内容计算出的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        computeHash(HashKind.Sha1, kind, data)
    }
}
