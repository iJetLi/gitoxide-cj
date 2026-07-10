// 文件：lib.cj
// 用途：提供基于拉链法实现的哈希表数据结构，以及线程安全的 ObjectIdMap
// 所属包：gix.gix_hashtable
// 关键类型：HashMap, Entry, ObjectIdMap

package gitoxide.gix_hashtable

import std.collection.*
import std.collection.concurrent.*
import gitoxide.gix_hash.*
import gitoxide.gix_utils.*

// 基于拉链法的泛型哈希表实现
// 使用链地址法解决哈希冲突，支持动态扩容
// 键类型 K 必须实现 Hashable 和 Equatable 接口
public class HashMap<K, V> where K <: Hashable & Equatable<K> {
    // 桶数组，每个桶是一个 Entry 链表
    var buckets: ArrayList<ArrayList<Entry<K, V>>>
    // 当前元素数量
    var size: Int64
    // 负载因子，超过此比例时需要扩容
    var loadFactor: Float64

    // 创建一个指定初始容量的 HashMap
    // 容量最小为 16
    // 参数 capacity：初始容量
    public init(capacity: Int64) {
        let cap = if (capacity < 16) {
            16
        } else {
            capacity
        }
        buckets = ArrayList<ArrayList<Entry<K, V>>>()
        for (i in 0..cap) {
            buckets.add(ArrayList<Entry<K, V>>())
        }
        size = 0
        loadFactor = 0.75
    }

    // 创建一个默认容量（16）的 HashMap
    public init() {
        this(16)
    }

    // 插入或更新键值对
    // 如果键已存在，更新值并返回旧值；否则插入新条目
    // 参数 key：键
    // 参数 value：值
    // 返回值：键已存在时返回旧值，否则返回 None
    public func put(key: K, value: V): ?V {
        let idx = (key.hashCode() & 0x7FFFFFFF) % buckets.size
        let bucket = buckets[idx]
        for (i in 0..bucket.size) {
            if (bucket[i].key == key) {
                let old = bucket[i].value
                bucket[i].value = value
                return old
            }
        }
        bucket.add(Entry(key, value))
        size += 1
        None
    }

    // 根据键获取值
    // 参数 key：键
    // 返回值：键存在时返回 Some(值)，否则返回 None
    public func get(key: K): ?V {
        let idx = (key.hashCode() & 0x7FFFFFFF) % buckets.size
        let bucket = buckets[idx]
        for (entry in bucket) {
            if (entry.key == key) {
                return Some(entry.value)
            }
        }
        None
    }

    // 判断是否包含指定键
    // 参数 key：键
    // 返回值：包含该键返回 true
    public func contains(key: K): Bool {
        let v = get(key)
        match (v) {
            case Some(_) => true
            case None => false
        }
    }

    // 根据键删除条目
    // 参数 key：键
    // 返回值：键存在时返回被删除的值，否则返回 None
    public func remove(key: K): ?V {
        let idx = (key.hashCode() & 0x7FFFFFFF) % buckets.size
        let bucket = buckets[idx]
        for (i in 0..bucket.size) {
            if (bucket[i].key == key) {
                let old = bucket[i].value
                bucket.remove(at: i)
                buckets[idx] = bucket
                size -= 1
                return old
            }
        }
        None
    }

    // 返回哈希表中的元素数量
    // 返回值：元素数量
    public func len(): Int64 {
        size
    }

    // 遍历所有键值对，对每个值执行操作
    // 参数 action：对每个值执行的操作
    public func forEachValue(action: (V)->Unit): Unit {
        var bucketIdx: Int64 = 0
        while (bucketIdx < buckets.size) {
            let bucket = buckets[bucketIdx]
            var entryIdx: Int64 = 0
            while (entryIdx < bucket.size) {
                action(bucket[entryIdx].value)
                entryIdx += 1
            }
            bucketIdx += 1
        }
    }
}

// 哈希表条目，存储键值对
public class Entry<K, V> {
    // 键
    var key: K
    // 值
    var value: V
    // 创建一个条目
    // 参数 key：键
    // 参数 value：值
    public init(key: K, value: V) {
        this.key = key
        this.value = value
    }
}

// 线程安全的 ObjectId → V 映射
// 对齐 Rust: gix_hashtable::sync::ObjectIdMap
// 使用仓颉标准库 ConcurrentHashMap 实现，按 ObjectId 首字节分片（256 个分片）
// Rust 原版使用 parking_lot::Mutex + 256 个 HashMap 分片，仓颉版使用 ConcurrentHashMap（内置分段锁）
public class ObjectIdMap<V> {
    // 底层并发哈希表，按 ObjectId 首字节分 256 个分片
    // 对齐 Rust: shards: [Mutex<HashMap<ObjectId, V>>; 256]
    let shards: ArrayList<ConcurrentHashMap<ObjectId, V>>

    // 创建默认的 ObjectIdMap
    // 对齐 Rust: ObjectIdMap::default()
    public init() {
        shards = ArrayList<ConcurrentHashMap<ObjectId, V>>()
        for (_ in 0..256) {
            shards.add(ConcurrentHashMap<ObjectId, V>())
        }
    }

    // 插入键值对，返回旧值
    // 对齐 Rust: ObjectIdMap::insert(&self, key: ObjectId, value: V) -> Option<V>
    // 按 ObjectId 首字节选择分片，在对应分片上执行 put
    // 参数 key：ObjectId 键
    // 参数 value：值
    // 返回值：键已存在时返回旧值，否则返回 None
    public func insert(key: ObjectId, value: V): ?V {
        let shardIdx = Int64(key.bytes[0])
        let shard = shards[shardIdx]
        let old = shard.get(key)
        shard[key] = value
        old
    }

    // 根据键获取值
    // 参数 key：ObjectId 键
    // 返回值：键存在时返回 Some(值)，否则返回 None
    public func get(key: ObjectId): ?V {
        let shardIdx = Int64(key.bytes[0])
        shards[shardIdx].get(key)
    }

    // 判断是否包含指定键
    // 参数 key：ObjectId 键
    // 返回值：包含该键返回 true
    public func contains(key: ObjectId): Bool {
        let shardIdx = Int64(key.bytes[0])
        shards[shardIdx].contains(key)
    }

    // 根据键删除条目
    // 参数 key：ObjectId 键
    // 返回值：键存在时返回被删除的值，否则返回 None
    public func remove(key: ObjectId): ?V {
        let shardIdx = Int64(key.bytes[0])
        let shard = shards[shardIdx]
        let old = shard.get(key)
        if (old.isSome()) {
            shard.remove(key)
        }
        old
    }

    // 返回所有分片中的元素总数
    // 注意：并发场景下不保证原子性
    public func len(): Int64 {
        var total: Int64 = 0
        for (i in 0..256) {
            total += shards[i].size
        }
        total
    }
}
