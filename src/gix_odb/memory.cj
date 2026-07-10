// 文件：memory.cj
// 用途：带内存缓存的对象数据库代理，在查找时优先访问 LRU 缓存以提升性能
// 所属包：gix.gix_odb
// 对齐来源：gix-odb/src/cache.rs — Cache<S> 包装 Handle，提供 pack 缓存 + object 缓存（LRU）
// 关键类型：MemoryProxy

package gitoxide.gix_odb

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_odb.store.*
import gitoxide.gix_pack.*
import std.collection.*

// 内存缓存代理，包装 CompoundStore 并在查找时使用 LRU 缓存已读取的对象数据
// 对齐 Rust: gix-odb/src/cache.rs Cache<S> — LRU pack 缓存 + object 缓存
// 当前实现：基于 gix_pack 层的 LruLinkedList，按内存容量淘汰
public class MemoryProxy {
    // 底层复合存储，负责实际的对象读写操作
    public var inner: CompoundStore
    // LRU 缓存，键为对象 ID 的十六进制字符串，值为对象数据
    // 对齐 Rust: Cache 内部的 object 缓存（LRU 淘汰策略）
    public var cache: LruLinkedList<String, Data>
    // 缓存的最大内存容量（字节）
    public var maxSize: Int64

    // 构造函数
    // 参数 inner：底层复合存储实例
    // 参数 maxSize：缓存的最大内存容量（字节），决定 LRU 淘汰阈值
    public init(inner: CompoundStore, maxSize: Int64) {
        this.inner = inner
        this.cache = LruLinkedList<String, Data>(maxSize, {
            _: String, v: Data => v.data.size
        })
        this.maxSize = maxSize
    }

    // 尝试根据对象 ID 查找对象数据，优先从 LRU 缓存读取
    // 对齐 Rust: Cache::try_find() — 缓存命中时直接返回，未命中时查找并缓存
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        let key = id.toHexString()
        let cached = cache.get(key)
        if (cached.isSome()) {
            return cached
        }
        let result = inner.tryFind(id)
        if (result.isSome()) {
            let d = result.getOrThrow()
            cache.put(key, d)
            Some(d)
        } else {
            None
        }
    }

    // 尝试根据对象 ID 获取对象头部信息（不经过缓存）
    // 对齐 Rust: Cache::try_find_header() — header 不缓存
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 Header，未找到返回 None
    public func tryHeader(id: ObjectId): ?Header {
        inner.tryHeader(id)
    }

    // 检查指定 ID 的对象是否存在于对象数据库中（不经过缓存）
    // 对齐 Rust: Cache::exists() — exists 不缓存
    // 参数 id：要检查的对象 ID
    // 返回值：存在返回 true，否则返回 false
    public func exists(id: ObjectId): Bool {
        inner.exists(id)
    }

    // 将对象写入底层存储，并使缓存中对应的旧数据失效
    // 对齐 Rust: Cache::write() — 写入后 invalidate 缓存
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        let id = inner.write(kind, data)
        cache.remove(id.toHexString())
        id
    }
}
