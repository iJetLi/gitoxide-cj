// 文件：store/types.cj
// 用途：定义 ODB 动态存储的类型系统——PackId、SlotIndexMarker、SlotMapIndex
// 所属包：gix.gix_odb.store
// 对齐来源：gix-odb/src/store_impls/dynamic/types.rs
// 关键类型：PackId、SlotIndexMarker、SlotMapIndex

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_pack.*
import std.collection.*

// 对齐 Rust: gix-odb/src/store_impls/dynamic/types.rs PackId
// 唯一标识一个 pack，命名空间由索引机制（单索引 vs 多包索引）区分
public class PackId {
    // 索引在 slot map 中的位置
    public var index: Int64
    // 如果是多包索引，这是多包索引内的 pack 索引
    public var multipackIndex: ?Int64

    public init(index: Int64, multipackIndex: ?Int64) {
        this.index = index
        this.multipackIndex = multipackIndex
    }

    // 对齐 Rust: PackId::max_indices()
    public static func maxIndices(): Int64 {
        (1 << 15) - 1
    }

    // 对齐 Rust: PackId::max_packs_in_multi_index()
    public static func maxPacksInMultiIndex(): Int64 {
        (1 << 16) - 1
    }

    // 对齐 Rust: PackId::to_intrinsic_pack_id()
    // 将 PackId 压缩为单个 UInt32，bit15 标记是否为多包索引
    public func toIntrinsicPackId(): UInt32 {
        if (index >= (1 << 15)) {
            throw Exception("PackId.index exceeds max: ${index}")
        }
        if (let Some(midx) <- multipackIndex) {
            if (midx > PackId.maxPacksInMultiIndex()) {
                throw Exception("PackId.multipackIndex exceeds max: ${midx}")
            }
            UInt32(index) | UInt32(1 << 15) | (UInt32(midx) << 16)
        } else {
            UInt32(index)
        }
    }

    // 对齐 Rust: PackId::from_intrinsic_pack_id()
    public static func fromIntrinsicPackId(packId: UInt32): PackId {
        if ((packId & UInt32(1 << 15)) == UInt32(0)) {
            PackId(Int64(packId & UInt32(0x7FFF)), None)
        } else {
            PackId(Int64(packId & UInt32(0x7FFF)), Some(Int64(packId >> 16)))
        }
    }
}

extend PackId <: Equatable<PackId> {
    public operator func ==(other: PackId): Bool {
        index == other.index && multipackIndex == other.multipackIndex
    }

    public operator func !=(other: PackId): Bool {
        !(this == other)
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/types.rs SlotIndexMarker
// 标记当前索引状态，用于判断已加载的索引是否仍然有效
public class SlotIndexMarker {
    // generation：索引的代数，不同代数的 PackId 完全不兼容
    public var generation: Int64
    // stateId：状态标识，变化时值不同
    public var stateId: Int64

    public init(generation: Int64, stateId: Int64) {
        this.generation = generation
        this.stateId = stateId
    }

    public init() {
        this.generation = 0
        this.stateId = 0
    }
}

extend SlotIndexMarker <: Equatable<SlotIndexMarker> {
    public operator func ==(other: SlotIndexMarker): Bool {
        generation == other.generation && stateId == other.stateId
    }

    public operator func !=(other: SlotIndexMarker): Bool {
        !(this == other)
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/types.rs SlotMapIndex
// 槽位映射索引，跟踪哪些索引文件已加载
public class SlotMapIndex {
    // 槽位索引列表
    public var slotIndices: ArrayList<Int64>
    // 代数（generation），用于判断 PackId 是否仍然有效
    public var generation: Int64
    // 下一个待加载的索引位置
    public var nextIndexToLoad: Int64
    // 已加载的索引数量
    public var loadedIndices: Int64

    public init() {
        this.slotIndices = ArrayList<Int64>()
        this.generation = 0
        this.nextIndexToLoad = 0
        this.loadedIndices = 0
    }

    // 是否已初始化（至少有一个槽位）
    public func isInitialized(): Bool {
        slotIndices.size > 0
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/iter.rs Ordering
// 定义迭代返回对象的顺序
public enum IterOrdering {
    | PackLexicographicalThenLooseLexicographical
    | PackAscendingOffsetThenLooseLexicographical
}

extend IterOrdering <: Equatable<IterOrdering> {
    public operator func ==(other: IterOrdering): Bool {
        match (this) {
            case IterOrdering.PackLexicographicalThenLooseLexicographical => match (other) {
                case IterOrdering.PackLexicographicalThenLooseLexicographical => true
                case _ => false
            }
            case IterOrdering.PackAscendingOffsetThenLooseLexicographical => match (other) {
                case IterOrdering.PackAscendingOffsetThenLooseLexicographical => true
                case _ => false
            }
        }
    }

    public operator func !=(other: IterOrdering): Bool {
        !(this == other)
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/iter.rs AllObjects
// 遍历所有对象 ID 的迭代器（可能包含重复 ID）
// 先遍历所有 pack 中的对象，再遍历所有 loose 对象
public class AllObjectsIterator <: Iterator<ObjectId> {
    // 所有 pack bundle 列表
    private var bundles: ArrayList<Bundle>
    // 当前正在遍历的 bundle 索引
    private var bundleIndex: Int64
    // 当前 bundle 的索引条目列表
    private var currentEntries: ArrayList<IndexEntry>
    // 当前条目索引
    private var entryIndex: Int64
    // loose 对象迭代器
    private var looseIter: ?Iterator<ObjectId>
    // 排序模式
    private var ordering: IterOrdering

    public init(bundles: ArrayList<Bundle>, looseIds: ArrayList<ObjectId>, ordering: IterOrdering) {
        this.bundles = bundles
        this.bundleIndex = 0
        this.currentEntries = ArrayList<IndexEntry>()
        this.entryIndex = 0
        this.looseIter = if (looseIds.size > 0) {
            Some(looseIds.iterator())
        } else {
            None
        }
        this.ordering = ordering
        // 预加载第一个 bundle 的条目
        loadNextBundle()
    }

    // 加载下一个 bundle 的索引条目
    private func loadNextBundle(): Unit {
        while (bundleIndex < bundles.size) {
            let bundle = bundles[bundleIndex]
            currentEntries = bundle.iter()
            // 如果需要按偏移排序
            if (ordering == IterOrdering.PackAscendingOffsetThenLooseLexicographical && currentEntries.size > 1) {
                currentEntries.sortBy(comparator: {
                    a, b => a.packOffset.compare(b.packOffset)
                })
            }
            entryIndex = 0
            bundleIndex += 1
            if (currentEntries.size > 0) {
                return
            }
        }
        // 所有 bundle 都遍历完毕，清空
        currentEntries = ArrayList<IndexEntry>()
    }

    public func next(): ?ObjectId {
        // 先遍历 pack 条目
        if (entryIndex < currentEntries.size) {
            let entry = currentEntries[entryIndex]
            entryIndex += 1
            return Some(entry.oid)
        }
        // 当前 bundle 遍历完毕，尝试下一个 bundle
        if (bundleIndex < bundles.size) {
            loadNextBundle()
            return next()
        }
        // 所有 pack 遍历完毕，遍历 loose
        if (let Some(iter) <- looseIter) {
            return iter.next()
        }
        None
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/prefix.rs lookup::Outcome
// 前缀查找结果：唯一匹配 / 歧义匹配
public enum PrefixLookupOutcome {
    // 唯一匹配，返回完整 ObjectId
    | Unique(ObjectId)
    // 歧义匹配，多个对象匹配此前缀
    | Ambiguous
}
