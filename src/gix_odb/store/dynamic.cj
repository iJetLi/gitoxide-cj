// 文件：store/dynamic.cj
// 用途：动态存储，负责发现和管理 Git pack 文件，加载 Bundle 实例提供 pack 查找
// 所属包：gix.gix_odb
// 对齐来源：gix-odb/src/store_impls/dynamic/{mod,find,init,metrics,types}.rs
// 关键类型：DynamicStore、RefreshMode、OdbMetrics

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_pack.*
import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// 对齐 Rust: gix-odb/src/store_impls/dynamic/mod.rs RefreshMode
// 决定当所有索引加载完毕后是否刷新
public enum RefreshMode {
    // 检查是否有新增或变更的 pack 索引（默认）
    | AfterAllIndicesLoaded
    // 不再刷新，即使 pack 文件有变更也不检测
    | NeverRefresh
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/types.rs Metrics
// 资源使用快照
public class OdbMetrics {
    // 当前活跃的 handle 数量
    public var numHandles: Int64
    // 执行磁盘状态整合（刷新）的次数
    public var numRefreshes: Int64
    // 已打开且可达的索引数量
    public var openReachableIndices: Int64
    // 已知的可达索引数量（含未打开的）
    public var knownReachableIndices: Int64
    // 已打开且可达的 pack 数据文件数量
    public var openReachablePacks: Int64
    // 已知的 pack 数量（含未打开的）
    public var knownPacks: Int64
    // 空闲槽位数量
    public var unusedSlots: Int64
    // 不可达但仍在内存中的索引数量
    public var unreachableIndices: Int64
    // 不可达但仍在内存中的 pack 数量
    public var unreachablePacks: Int64
    // 松散对象数据库数量（含 alternates）
    public var looseDbs: Int64

    public init() {
        this.numHandles = 0
        this.numRefreshes = 0
        this.openReachableIndices = 0
        this.knownReachableIndices = 0
        this.openReachablePacks = 0
        this.knownPacks = 0
        this.unusedSlots = 0
        this.unreachableIndices = 0
        this.unreachablePacks = 0
        this.looseDbs = 0
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/verify.rs integrity::IndexStatistics
// 单个索引的校验统计
public class IndexVerifyStats {
    // 索引文件路径
    public var indexPath: String
    // 校验结果
    public var outcome: IntegrityOutcome

    public init(indexPath: String, outcome: IntegrityOutcome) {
        this.indexPath = indexPath
        this.outcome = outcome
    }
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/verify.rs integrity::Error
// 动态存储校验错误
public enum DynamicVerifyError {
    | IndexError(String)
    | PackChecksumError(String)
}

// 对齐 Rust: gix-odb/src/store_impls/dynamic/verify.rs integrity::Outcome
// 动态存储校验结果
public class DynamicVerifyResult {
    // 各索引的校验统计
    public var indexStatistics: ArrayList<IndexVerifyStats>
    // loose 对象校验结果（如果提供了 looseStore）
    public var looseObjectResult: ?VerifyIntegrityResult
    // 错误列表
    public var errors: ArrayList<DynamicVerifyError>

    public init(
        indexStatistics: ArrayList<IndexVerifyStats>,
        looseObjectResult: ?VerifyIntegrityResult,
        errors: ArrayList<DynamicVerifyError>
    ) {
        this.indexStatistics = indexStatistics
        this.looseObjectResult = looseObjectResult
        this.errors = errors
    }
}

// 动态存储，在初始化时扫描 pack 目录，加载所有可用的 Bundle 实例
// 对齐 Rust: gix-odb/src/store_impls/dynamic/mod.rs Store + Handle
public class DynamicStore {
    // Git 对象目录路径（如 .git/objects）
    public var objectsDir: String
    // 哈希算法类型（SHA-1 或 SHA-256）
    public var hashKind: HashKind
    // 已加载的 Bundle 实例列表
    // 对齐 Rust: snapshot.indices + snapshot.packs
    public var bundles: ArrayList<Bundle>
    // 刷新模式
    public var refreshMode: RefreshMode
    // 最大 delta 递归深度
    // 对齐 Rust: Handle.max_recursion_depth
    public var maxRecursionDepth: Int64
    // 对齐 Rust: Handle.ignore_replacements
    // 如果为 true，即使有替换规则也不应用
    public var ignoreReplacements: Bool
    // 对齐 Rust: Store.replacements
    // 替换规则列表：(原始 ObjectId, 替换 ObjectId)，按原始 ID 排序
    public var replacements: ArrayList<(ObjectId, ObjectId)>
    // 已加载的 idx 文件路径集合，用于增量刷新时避免重复加载
    var loadedIdxPaths: HashSet<String>
    // 刷新次数计数器
    public var refreshCount: Int64

    // 构造函数，初始化时自动扫描 pack 目录并加载 Bundle
    // 参数 objectsDir：Git 对象目录路径
    // 参数 hashKind：哈希算法类型
    public init(objectsDir: String, hashKind: HashKind) {
        this.objectsDir = objectsDir
        this.hashKind = hashKind
        this.bundles = ArrayList<Bundle>()
        this.refreshMode = RefreshMode.AfterAllIndicesLoaded
        this.maxRecursionDepth = 256
        this.ignoreReplacements = false
        this.replacements = ArrayList<(ObjectId, ObjectId)>()
        this.loadedIdxPaths = HashSet<String>()
        this.refreshCount = 0
        discoverAndLoadPacks()
    }

    // 带替换规则的构造函数
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/init.rs at_opts
    // 参数 objectsDir：Git 对象目录路径
    // 参数 hashKind：哈希算法类型
    // 参数 replacements：替换规则迭代器
    public init(objectsDir: String, hashKind: HashKind, replacements: ArrayList<(ObjectId, ObjectId)>) {
        this.objectsDir = objectsDir
        this.hashKind = hashKind
        this.bundles = ArrayList<Bundle>()
        this.refreshMode = RefreshMode.AfterAllIndicesLoaded
        this.maxRecursionDepth = 256
        this.ignoreReplacements = false
        this.replacements = ArrayList<(ObjectId, ObjectId)>()
        for (r in replacements) {
            this.replacements.add(r)
        }
        // 按原始 ID 排序，支持二分查找
        this.replacements.sortBy(comparator: {
            a: (ObjectId, ObjectId), b: (ObjectId, ObjectId) => a[0].toHexString().compare(b[0].toHexString())
        })
        this.loadedIdxPaths = HashSet<String>()
        this.refreshCount = 0
        discoverAndLoadPacks()
    }

    // 扫描 pack 目录，发现所有配对的 .idx/.pack 文件并加载为 Bundle
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/init.rs
    func discoverAndLoadPacks(): Unit {
        let packDir = objectsDir + "/pack"
        if (!exists(packDir)) {
            return
        }
        try {
            let entries = listDirectory(packDir)
            for (entry in entries) {
                if (entry.endsWith(".idx")) {
                    let idxPath = packDir + "/" + entry
                    if (loadedIdxPaths.contains(idxPath)) {
                        continue
                    }
                    let basePath = substringStr(entry, 0, entry.size - 4)
                    let packPath = packDir + "/" + basePath + ".pack"
                    if (exists(packPath)) {
                        let result = Bundle.at(idxPath, hashKind)
                        if (result.isOk()) {
                            bundles.add(result.unwrap())
                            loadedIdxPaths.add(idxPath)
                        }
                    }
                }
            }
        } catch (_: Exception) {}
    }

    // 对齐 Rust: gix-odb/src/store_impls/dynamic/load_index.rs consolidate_with_disk_state
    // 刷新 pack 目录，检测新增或删除的 pack 文件
    // 当 RefreshMode 为 AfterAllIndicesLoaded 时，在查找未命中时调用
    public func refresh(): Unit {
        refreshCount += 1
        // 重新扫描 pack 目录，发现新增的 pack
        let packDir = objectsDir + "/pack"
        if (!exists(packDir)) {
            return
        }
        try {
            let entries = listDirectory(packDir)
            var currentIdxPaths = HashSet<String>()
            for (entry in entries) {
                if (entry.endsWith(".idx")) {
                    let idxPath = packDir + "/" + entry
                    currentIdxPaths.add(idxPath)
                }
            }
            // 加载新增的 pack
            for (idxPath in currentIdxPaths) {
                if (!loadedIdxPaths.contains(idxPath)) {
                    let basePath = substringStr(idxPath, 0, idxPath.size - 4)
                    let packPath = basePath + ".pack"
                    if (exists(packPath)) {
                        let result = Bundle.at(idxPath, hashKind)
                        if (result.isOk()) {
                            bundles.add(result.unwrap())
                            loadedIdxPaths.add(idxPath)
                        }
                    }
                }
            }
            // 移除磁盘上已不存在的 pack
            var i = 0
            while (i < bundles.size) {
                let bundle = bundles[i]
                let idxPath = bundle.indexPath
                if (idxPath.isSome()) {
                    let path = idxPath.getOrThrow()
                    if (!currentIdxPaths.contains(path)) {
                        bundles.remove(at: i)
                        loadedIdxPaths.remove(path)
                    } else {
                        i += 1
                    }
                } else {
                    i += 1
                }
            }
        } catch (_: Exception) {}
    }

    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs — 替换规则应用
    // 如果 ignoreReplacements 为 false 且有匹配的替换规则，返回替换后的 ObjectId
    public func applyReplacements(id: ObjectId): ObjectId {
        if (ignoreReplacements || replacements.size == 0) {
            return id
        }
        let hex = id.toHexString()
        // 二分查找
        var lo = 0
        var hi = replacements.size - 1
        while (lo <= hi) {
            let mid = lo + (hi - lo) / 2
            let (srcId, dstId) = replacements[mid]
            let cmp = srcId.toHexString().compare(hex)
            if (cmp == Ordering.LT) {
                lo = mid + 1
            } else if (cmp == Ordering.GT) {
                hi = mid - 1
            } else {
                return dstId
            }
        }
        id
    }

    // 在所有已加载的 Bundle 中查找对象
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs try_find_cached_inner
    // 先查 pack（快），再查 loose（慢）— 这里只查 pack
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        let resolvedId = applyReplacements(id)
        for (bundle in bundles) {
            let result = bundle.tryFindData(resolvedId)
            if (result.isOk()) {
                let data = result.unwrap()
                if (data.isSome()) {
                    return data
                }
            }
        }
        // 对齐 Rust: RefreshMode::AfterAllIndicesLoaded — 未命中时刷新再试
        if (let RefreshMode.AfterAllIndicesLoaded <- refreshMode) {
            refresh()
            for (bundle in bundles) {
                let result = bundle.tryFindData(resolvedId)
                if (result.isOk()) {
                    let data = result.unwrap()
                    if (data.isSome()) {
                        return data
                    }
                }
            }
        }
        None
    }

    // 在所有已加载的 Bundle 中查找对象，返回带位置信息的查找结果
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs try_find_cached_inner
    // 参数 id：要查找的对象 ID
    // 参数 buffer：解码缓冲区
    // 返回值：找到则返回 FindResult，未找到返回 None
    public func tryFindWithLocation(id: ObjectId, buffer: ArrayList<Byte>): PackResult<?FindResult> {
        let resolvedId = applyReplacements(id)
        for (bundle in bundles) {
            let result = bundle.tryFind(resolvedId, buffer)
            if (result.isOk()) {
                let data = result.unwrap()
                if (data.isSome()) {
                    return result
                }
            }
        }
        // 对齐 Rust: RefreshMode::AfterAllIndicesLoaded — 未命中时刷新再试
        if (let RefreshMode.AfterAllIndicesLoaded <- refreshMode) {
            refresh()
            for (bundle in bundles) {
                let result = bundle.tryFind(resolvedId, buffer)
                if (result.isOk()) {
                    let data = result.unwrap()
                    if (data.isSome()) {
                        return result
                    }
                }
            }
        }
        PackResult.PackOk(None)
    }

    // 检查对象是否存在于任何已加载的 Bundle 中
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs Find::contains
    public func contains(id: ObjectId): Bool {
        let resolvedId = applyReplacements(id)
        for (bundle in bundles) {
            if (bundle.contains(resolvedId)) {
                return true
            }
        }
        false
    }

    // 获取已加载的 Bundle 数量
    public func packCount(): Int64 {
        bundles.size
    }

    // 对齐 Rust: gix-odb/src/store_impls/dynamic/metrics.rs
    // 返回当前存储的资源使用统计
    public func metrics(): OdbMetrics {
        let m = OdbMetrics()
        m.numRefreshes = refreshCount
        m.knownPacks = bundles.size
        m.knownReachableIndices = bundles.size
        m.openReachablePacks = bundles.size
        m.openReachableIndices = bundles.size
        m.looseDbs = 1
        m
    }

    // 对齐 Rust: gix-odb/src/store_impls/dynamic/access.rs replacements()
    // 返回替换规则的迭代器
    public func replacementsIter(): Iterator<(ObjectId, ObjectId)> {
        replacements.iterator()
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/iter.rs
    // ============================================================

    // 遍历所有 pack 中的对象 ID（可能包含重复）
    // 对齐 Rust: dynamic::Store::iter() -> AllObjects
    // 参数 ordering：排序模式
    // 返回值：对象 ID 迭代器
    public func iter(ordering: IterOrdering): AllObjectsIterator {
        AllObjectsIterator(bundles, ArrayList<ObjectId>(), ordering)
    }

    // 遍历所有 pack 中的对象 ID，然后遍历 loose 对象
    // 对齐 Rust: dynamic::Store::iter() -> AllObjects
    // 参数 looseIds：松散对象 ID 列表
    // 参数 ordering：排序模式
    public func iterWithLoose(looseIds: ArrayList<ObjectId>, ordering: IterOrdering): AllObjectsIterator {
        AllObjectsIterator(bundles, looseIds, ordering)
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/prefix.rs
    // ============================================================

    // 前缀查找：在所有 pack 索引中查找匹配前缀的对象
    // 对齐 Rust: Handle::lookup_prefix() -> Option<Outcome>
    // 参数 prefix：对象 ID 前缀
    // 返回值：None=未找到, Unique=唯一匹配, Ambiguous=歧义匹配
    public func lookupPrefix(prefix: Prefix): ?PrefixLookupOutcome {
        var candidate: ?ObjectId = None
        for (bundle in bundles) {
            let result = bundle.index.lookupPrefix(prefix)
            if (result.isNone()) {
                continue
            }
            match (result.getOrThrow()) {
                case PrefixLookupResult.Ambiguous => return Some(PrefixLookupOutcome.Ambiguous)
                case PrefixLookupResult.Unique(idx) =>
                    let oid = bundle.index.oidAtIndex(idx)
                    if (oid.isNone()) {
                        continue
                    }
                    let foundOid = oid.getOrThrow()
                    if (let Some(existing) <- candidate) {
                        if (existing != foundOid) {
                            return Some(PrefixLookupOutcome.Ambiguous)
                        }
                    } else {
                        candidate = Some(foundOid)
                    }
            }
        }
        // 刷新后重试
        if (let RefreshMode.AfterAllIndicesLoaded <- refreshMode) {
            refresh()
            for (bundle in bundles) {
                let result = bundle.index.lookupPrefix(prefix)
                if (result.isNone()) {
                    continue
                }
                match (result.getOrThrow()) {
                    case PrefixLookupResult.Ambiguous => return Some(PrefixLookupOutcome.Ambiguous)
                    case PrefixLookupResult.Unique(idx) =>
                        let oid = bundle.index.oidAtIndex(idx)
                        if (oid.isNone()) {
                            continue
                        }
                        let foundOid = oid.getOrThrow()
                        if (let Some(existing) <- candidate) {
                            if (existing != foundOid) {
                                return Some(PrefixLookupOutcome.Ambiguous)
                            }
                        } else {
                            candidate = Some(foundOid)
                        }
                }
            }
        }
        if (let Some(oid) <- candidate) {
            Some(PrefixLookupOutcome.Unique(oid))
        } else {
            None
        }
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/prefix.rs packed_object_count
    // ============================================================

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/verify.rs
    // ============================================================

    // 校验所有 pack 和 loose 对象的完整性
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/verify.rs Store::verify_integrity()
    // 遍历所有 Bundle，调用 bundle.verifyIntegrity()，汇总统计
    // 参数 verifyMode：校验模式（HashCrc32 / HashCrc32Decode / HashCrc32DecodeEncode）
    // 参数 looseStore：可选的 LooseStore，用于同时校验 loose 对象
    // 返回值：校验结果
    public func verifyIntegrity(verifyMode: VerifyMode, looseStore: ?LooseStore): DynamicVerifyResult {
        let indexStats = ArrayList<IndexVerifyStats>()
        var indexErrors = ArrayList<DynamicVerifyError>()

        // 对齐 Rust: verify.rs — 遍历所有 bundle，逐个校验
        for (bundle in bundles) {
            let result = bundle.verifyIntegrity(verifyMode)
            match (result) {
                case IndexVerifyResult.Ok(outcome) => indexStats.add(
                    IndexVerifyStats(
                        if (bundle.indexPath.isSome()) {
                            bundle.indexPath.getOrThrow()
                        } else {
                            ""
                        },
                        outcome
                    )
                )
                case IndexVerifyResult.FanError(idx) => indexErrors.add(
                    DynamicVerifyError.IndexError("fan table error at index ${idx}"))
                case IndexVerifyResult.ChecksumMismatch => indexErrors.add(
                    DynamicVerifyError.IndexError("index checksum mismatch"))
                case IndexVerifyResult.Crc32Mismatch(idx, id) => indexErrors.add(
                    DynamicVerifyError.IndexError("CRC32 mismatch at index ${idx} for object ${id.toHexString()}"))
                case IndexVerifyResult.ObjectDecodeError(idx, id, msg) => indexErrors.add(
                    DynamicVerifyError.IndexError("object decode error at index ${idx} for ${id.toHexString()}: ${msg}"))
            }

            // 对齐 Rust: verify.rs — 同时校验 pack 数据文件校验和
            if (!bundle.verifyChecksum()) {
                indexErrors.add(
                    DynamicVerifyError.PackChecksumError(
                        "pack data checksum mismatch for bundle at ${if (bundle.indexPath.isSome()) { bundle.indexPath.getOrThrow() } else { "" }}"))
            }
        }

        // 对齐 Rust: verify.rs — 校验 loose 对象数据库
        var looseResult: ?VerifyIntegrityResult = None
        if (let Some(loose) <- looseStore) {
            looseResult = Some(loose.verifyIntegrity())
        }

        DynamicVerifyResult(indexStats, looseResult, indexErrors)
    }

    // 返回所有 pack 中的对象总数
    // 对齐 Rust: Handle::packed_object_count() -> u64
    public func packedObjectCount(): Int64 {
        var count: Int64 = 0
        for (bundle in bundles) {
            count += bundle.index.numObjects
        }
        count
    }
}
