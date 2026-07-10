// 文件：cache.cj
// 用途：全量对齐 Rust gitoxide gix-pack/src/cache/ 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/cache/{mod,lru,object,delta/traverse}.rs
// 关键类型：DecodeEntry, ObjectCache, NeverDecodeEntry, NeverObjectCache,
//           LruEntry, LruLinkedList, MemoryCappedDecodeEntry, MemoryCappedObjectCache

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*
import std.sync.*

// ============================================================
// 对齐 Rust: gix-pack/src/cache/mod.rs DecodeEntry trait
// 按 (pack_id, offset) 键缓存已解码的 pack 条目
// ============================================================

// 对齐 Rust: gix-pack/src/cache/mod.rs DecodeEntry::put() 的缓存条目
public class DecodeEntryValue {
    public var data: Array<Byte>
    public var kind: ObjectKind
    public var compressedSize: Int64

    public init(data: Array<Byte>, kind: ObjectKind, compressedSize: Int64) {
        this.data = data
        this.kind = kind
        this.compressedSize = compressedSize
    }
}

// 对齐 Rust: gix-pack/src/cache/mod.rs DecodeEntry trait
// 按 (pack_id, offset) 键存储和检索已解码的 pack 条目
public interface DecodeEntry {
    // 将已解码对象存入缓存
    func put(packId: UInt32, offset: Int64, data: Array<Byte>, kind: ObjectKind, compressedSize: Int64): Unit
    // 从缓存中获取已解码对象，返回 (kind, compressedSize)，数据写入 out
    func get(packId: UInt32, offset: Int64, out: ArrayList<Byte>): ?DecodeEntryValue
}

// 对齐 Rust: gix-pack/src/cache/mod.rs Never
// 空缓存实现，不存储也不检索
public class NeverDecodeEntry <: DecodeEntry {
    public init() {}

    public func put(packId: UInt32, offset: Int64, data: Array<Byte>, kind: ObjectKind, compressedSize: Int64): Unit {}

    public func get(packId: UInt32, offset: Int64, out: ArrayList<Byte>): ?DecodeEntryValue {
        None
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/cache/object.rs Object trait
// 按 ObjectId 键缓存对象
// ============================================================

// 对齐 Rust: gix-pack/src/cache/object.rs Object trait
public interface ObjectCache {
    // 将对象存入缓存
    func put(id: ObjectId, kind: ObjectKind, data: Array<Byte>): Unit
    // 从缓存中获取对象，返回 kind
    func get(id: ObjectId, out: ArrayList<Byte>): ?ObjectKind
}

// 对齐 Rust: gix-pack/src/cache/object.rs Never
// 空对象缓存实现
public class NeverObjectCache <: ObjectCache {
    public init() {}

    public func put(id: ObjectId, kind: ObjectKind, data: Array<Byte>): Unit {}

    public func get(id: ObjectId, out: ArrayList<Byte>): ?ObjectKind {
        None
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/cache/lru.rs — LRU 缓存核心
// 使用 HashMap + 双向链表实现 O(1) LRU 淘汰
// ============================================================

// LRU 双向链表节点
class LruNode<K> where K <: Hashable & Equatable<K> {
    var key: K
    var prev: ?LruNode<K>
    var next: ?LruNode<K>

    init(key: K) {
        this.key = key
        this.prev = None
        this.next = None
    }
}

// 对齐 Rust: clru::CLruCache + uluru::LRUCache
// 基于内存容量限制的 LRU 缓存，使用 HashMap + 双向链表
// 键类型 K 必须满足 Hashable + Equatable
// 使用 ?LruNode<K> 头尾指针替代哨兵节点
public class LruLinkedList<K, V> where K <: Hashable & Equatable<K> {
    // HashMap 存储键到 (值, 链表节点) 的映射
    var map: HashMap<K, (V, LruNode<K>)>
    // 链表头节点（最近使用），None 表示空
    var head: ?LruNode<K>
    // 链表尾节点（最久未使用），None 表示空
    var tail: ?LruNode<K>
    // 当前内存使用量（字节）
    var memUsed: Int64
    // 内存上限（字节）
    var memLimit: Int64
    // 权重计算函数
    var weightFunc: (K, V) -> Int64

    public init(memLimit: Int64, weightFunc: (K, V) -> Int64) {
        this.map = HashMap<K, (V, LruNode<K>)>()
        this.head = None
        this.tail = None
        this.memUsed = 0
        this.memLimit = memLimit
        this.weightFunc = weightFunc
    }

    // 获取当前条目数
    public func len(): Int64 {
        map.size
    }

    // 是否为空
    public func isEmpty(): Bool {
        map.size == 0
    }

    // 将节点移到链表头部（最近使用）
    func moveToHead(node: LruNode<K>): Unit {
        // 先从原位置摘除
        detachNode(node)
        // 插入到头部
        insertAtHead(node)
    }

    // 摘除节点
    func detachNode(node: LruNode<K>): Unit {
        let prevNode = node.prev
        let nextNode = node.next
        if (prevNode.isSome()) {
            prevNode.getOrThrow().next = nextNode
        } else {
            // node 是头节点
            head = nextNode
        }
        if (nextNode.isSome()) {
            nextNode.getOrThrow().prev = prevNode
        } else {
            // node 是尾节点
            tail = prevNode
        }
        node.prev = None
        node.next = None
    }

    // 在头部插入节点
    func insertAtHead(node: LruNode<K>): Unit {
        node.next = head
        node.prev = None
        if (head.isSome()) {
            head.getOrThrow().prev = Some(node)
        } else {
            // 链表为空，node 也是尾节点
            tail = Some(node)
        }
        head = Some(node)
    }

    // 移除尾部节点（最久未使用），返回被移除的 (key, value)
    func removeTail(): ?(K, V) {
        if (tail.isNone()) {
            return None
        }
        let lastNode = tail.getOrThrow()
        detachNode(lastNode)
        let removed = map.remove(lastNode.key)
        if (let Some((value, _)) <- removed) {
            Some((lastNode.key, value))
        } else {
            None
        }
    }

    // 放入缓存，如果内存超限则淘汰最久未使用的条目
    // 返回被淘汰的旧值（如果有）
    public func put(key: K, value: V): ?V {
        let weight = weightFunc(key, value)
        // 先淘汰直到有足够空间
        while (memUsed + weight > memLimit && map.size > 0) {
            let evicted = removeTail()
            if (let Some((evictedKey, evictedValue)) <- evicted) {
                memUsed -= weightFunc(evictedKey, evictedValue)
            } else {
                break
            }
        }
        // 如果单个条目就超限，不存
        if (weight > memLimit) {
            return None
        }
        // 检查是否已存在
        let existing = map.get(key)
        if (let Some((oldValue, oldNode)) <- existing) {
            memUsed -= weightFunc(key, oldValue)
            map[key] = (value, oldNode)
            moveToHead(oldNode)
            memUsed += weight
            Some(oldValue)
        } else {
            let node = LruNode<K>(key)
            map[key] = (value, node)
            insertAtHead(node)
            memUsed += weight
            None
        }
    }

    // 获取缓存值，并移到头部（标记为最近使用）
    public func get(key: K): ?V {
        let entry = map.get(key)
        if (let Some((value, node)) <- entry) {
            moveToHead(node)
            Some(value)
        } else {
            None
        }
    }

    // 检查是否包含键（不移到头部）
    public func contains(key: K): Bool {
        map.contains(key)
    }

    // 移除指定键
    public func remove(key: K): ?V {
        let entry = map.get(key)
        if (let Some((value, node)) <- entry) {
            detachNode(node)
            map.remove(key)
            memUsed -= weightFunc(key, value)
            Some(value)
        } else {
            None
        }
    }

    // 清空缓存
    public func clear(): Unit {
        map.clear()
        head = None
        tail = None
        memUsed = 0
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/cache/lru.rs MemoryCappedHashmap (DecodeEntry)
// 基于内存容量限制的 LRU 缓存，实现 DecodeEntry 接口
// 键为 (pack_id, offset) 对
// ============================================================

// (pack_id, offset) 键类型
public class PackOffsetKey <: Hashable & Equatable<PackOffsetKey> {
    public var packId: UInt32
    public var offset: Int64

    public init(packId: UInt32, offset: Int64) {
        this.packId = packId
        this.offset = offset
    }

    public func hashCode(): Int64 {
        packId.hashCode() ^ offset.hashCode()
    }

    public operator func ==(other: PackOffsetKey): Bool {
        packId == other.packId && offset == other.offset
    }

    public operator func !=(other: PackOffsetKey): Bool {
        !(this == other)
    }
}

// 对齐 Rust: gix-pack/src/cache/lru.rs MemoryCappedHashmap
// 基于内存容量限制的 LRU 缓存，实现 DecodeEntry 接口
public class MemoryCappedDecodeEntry <: DecodeEntry {
    var lru: LruLinkedList<PackOffsetKey, DecodeEntryValue>
    // 空闲列表：复用 Array<Byte> 减少分配
    var freeList: ArrayList<Array<Byte>>

    public init(memoryCapBytes: Int64) {
        this.lru = LruLinkedList<PackOffsetKey, DecodeEntryValue>(
            memoryCapBytes,
            {_: PackOffsetKey, v: DecodeEntryValue => v.data.size}
        )
        this.freeList = ArrayList<Array<Byte>>()
    }

    public func put(packId: UInt32, offset: Int64, data: Array<Byte>, kind: ObjectKind, compressedSize: Int64): Unit {
        var buf: Array<Byte>
        if (!freeList.isEmpty()) {
            buf = freeList.remove(at: freeList.size - 1)
            if (buf.size != data.size) {
                buf = Array<Byte>(data.size, repeat: UInt8(0))
            }
        } else {
            buf = Array<Byte>(data.size, repeat: UInt8(0))
        }
        for (i in 0..data.size) {
            buf[i] = data[i]
        }
        let key = PackOffsetKey(packId, offset)
        let value = DecodeEntryValue(buf, kind, compressedSize)
        let old = lru.put(key, value)
        if (old.isSome()) {
            freeList.add(old.getOrThrow().data)
        }
    }

    public func get(packId: UInt32, offset: Int64, out: ArrayList<Byte>): ?DecodeEntryValue {
        let key = PackOffsetKey(packId, offset)
        let entry = lru.get(key)
        if (let Some(v) <- entry) {
            // 将数据写入 out
            out.clear()
            for (i in 0..v.data.size) {
                out.add(v.data[i])
            }
            Some(v)
        } else {
            None
        }
    }

    // 当前内存使用量
    public func memUsed(): Int64 {
        lru.memUsed
    }

    // 当前条目数
    public func len(): Int64 {
        lru.len()
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/cache/object.rs MemoryCappedHashmap (ObjectCache)
// 基于 ObjectId 键的内存容量限制 LRU 缓存
// ============================================================

// 对齐 Rust: gix-pack/src/cache/object.rs MemoryCappedHashmap
public class MemoryCappedObjectCache <: ObjectCache {
    var lru: LruLinkedList<ObjectId, ObjectCacheValue>
    var freeList: ArrayList<Array<Byte>>

    init(memoryCapBytes: Int64) {
        this.lru = LruLinkedList<ObjectId, ObjectCacheValue>(
            memoryCapBytes,
            {_: ObjectId, v: ObjectCacheValue => v.data.size + 20}
        )
        this.freeList = ArrayList<Array<Byte>>()
    }

    public func put(id: ObjectId, kind: ObjectKind, data: Array<Byte>): Unit {
        var buf: Array<Byte>
        if (!freeList.isEmpty()) {
            buf = freeList.remove(at: freeList.size - 1)
            if (buf.size != data.size) {
                buf = Array<Byte>(data.size, repeat: UInt8(0))
            }
        } else {
            buf = Array<Byte>(data.size, repeat: UInt8(0))
        }
        for (i in 0..data.size) {
            buf[i] = data[i]
        }
        let value = ObjectCacheValue(buf, kind)
        let old = lru.put(id, value)
        if (old.isSome()) {
            freeList.add(old.getOrThrow().data)
        }
    }

    public func get(id: ObjectId, out: ArrayList<Byte>): ?ObjectKind {
        let entry = lru.get(id)
        if (let Some(v) <- entry) {
            out.clear()
            for (i in 0..v.data.size) {
                out.add(v.data[i])
            }
            Some(v.kind)
        } else {
            None
        }
    }

    public func memUsed(): Int64 {
        lru.memUsed
    }

    public func len(): Int64 {
        lru.len()
    }
}

// 对象缓存条目值
class ObjectCacheValue {
    var data: Array<Byte>
    var kind: ObjectKind

    init(data: Array<Byte>, kind: ObjectKind) {
        this.data = data
        this.kind = kind
    }
}

// ============================================================
// 旧版 Cache 类保留为兼容层（标记为 deprecated）
// ============================================================

// 兼容旧接口，新代码应使用 DecodeEntry 或 ObjectCache
public class Cache {
    public var entries: HashMap<String, Array<Byte>>
    public var maxSize: Int64

    public init(maxSize: Int64) {
        this.entries = HashMap<String, Array<Byte>>()
        this.maxSize = maxSize
    }

    public func get(id: ObjectId): ?Array<Byte> {
        entries.get(id.toHexString())
    }

    public func put(id: ObjectId, data: Array<Byte>): Unit {
        if (entries.size < maxSize) {
            entries[id.toHexString()] = data
        }
    }

    public func clear(): Unit {
        entries.clear()
    }
}
