// 文件：lib.cj
// 用途：对象数据库（ODB）的门面句柄，将操作委托给内部的 CompoundStore
// 所属包：gix.gix_odb
// 关键类型：OdbHandle、OdbHandleArc

package gitoxide.gix_odb

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_odb.store.*

// 对象数据库句柄，持有复合存储的引用，提供对象的查找、头部查询、存在性检查和写入操作
public class OdbHandle {
    // 底层复合存储，包含松散存储和动态存储
    public var store: CompoundStore

    // 构造函数
    // 参数 store：复合存储实例
    public init(store: CompoundStore) {
        this.store = store
    }

    // 尝试根据对象 ID 查找完整的对象数据
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        store.tryFind(id)
    }

    // 尝试根据对象 ID 获取对象头部信息
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 Header，未找到返回 None
    public func tryHeader(id: ObjectId): ?Header {
        store.tryHeader(id)
    }

    // 检查指定 ID 的对象是否存在于对象数据库中
    // 参数 id：要检查的对象 ID
    // 返回值：存在返回 true，否则返回 false
    public func exists(id: ObjectId): Bool {
        store.exists(id)
    }

    // 将对象写入对象数据库
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        store.write(kind, data)
    }

    // 遍历所有对象 ID（先 pack 后 loose，可能包含重复）
    // 对齐 Rust: Handle::iter() -> AllObjects
    public func iter(ordering: IterOrdering): AllObjectsIterator {
        store.iter(ordering)
    }

    // 前缀查找：在所有 pack 索引和 loose 对象中查找匹配前缀的对象
    // 对齐 Rust: Handle::lookup_prefix()
    public func lookupPrefix(prefix: Prefix): ?PrefixLookupOutcome {
        store.lookupPrefix(prefix)
    }

    // 返回所有 pack 中的对象总数
    // 对齐 Rust: Handle::packed_object_count()
    public func packedObjectCount(): Int64 {
        store.packedObjectCount()
    }
}

// 对象数据库句柄的另一种变体，功能与 OdbHandle 相同，保留以备后续线程安全等扩展使用
public class OdbHandleArc {
    // 底层复合存储，包含松散存储和动态存储
    public var store: CompoundStore

    // 构造函数
    // 参数 store：复合存储实例
    public init(store: CompoundStore) {
        this.store = store
    }

    // 尝试根据对象 ID 查找完整的对象数据
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        store.tryFind(id)
    }

    // 尝试根据对象 ID 获取对象头部信息
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 Header，未找到返回 None
    public func tryHeader(id: ObjectId): ?Header {
        store.tryHeader(id)
    }

    // 检查指定 ID 的对象是否存在于对象数据库中
    // 参数 id：要检查的对象 ID
    // 返回值：存在返回 true，否则返回 false
    public func exists(id: ObjectId): Bool {
        store.exists(id)
    }

    // 将对象写入对象数据库
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        store.write(kind, data)
    }

    // 遍历所有对象 ID（先 pack 后 loose，可能包含重复）
    public func iter(ordering: IterOrdering): AllObjectsIterator {
        store.iter(ordering)
    }

    // 前缀查找
    public func lookupPrefix(prefix: Prefix): ?PrefixLookupOutcome {
        store.lookupPrefix(prefix)
    }

    // 返回所有 pack 中的对象总数
    public func packedObjectCount(): Int64 {
        store.packedObjectCount()
    }
}
