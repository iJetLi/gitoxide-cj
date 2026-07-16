// 文件：multi_index.cj
// 用途：全量对齐 Rust gitoxide gix-pack/src/multi_index/ 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/multi_index/{mod,access,chunk,init,verify,write}.rs
// 关键类型：MultiIndexFile, MultiIndexVersion, MultiIndexEntry, MultiIndexEntryIndex

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_error.*
import gitoxide.gix_utils.*
import std.collection.*
import std.fs.*

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/mod.rs
// 核心类型定义
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/mod.rs Version
// 已知的 multi-index 文件版本
public enum MultiIndexVersion {
    | V1
}

extend MultiIndexVersion <: Equatable<MultiIndexVersion> {
    public operator func ==(other: MultiIndexVersion): Bool {
        match (this) {
            case MultiIndexVersion.V1 => match (other) {
                case MultiIndexVersion.V1 => true
                case _ => false
            }
        }
    }

    public operator func !=(other: MultiIndexVersion): Bool {
        !(this == other)
    }
}

extend MultiIndexVersion <: ToString {
    public func toString(): String {
        match (this) {
            case MultiIndexVersion.V1 => "1"
        }
    }
}

// 对齐 Rust: gix-pack/src/multi_index/mod.rs PackIndex
// pack 索引类型
public type MultiIndexPackIndex = UInt32

// 对齐 Rust: gix-pack/src/multi_index/mod.rs EntryIndex
// 条目索引类型
public type MultiIndexEntryIndex = UInt32

// 对齐 Rust: gix-pack/src/multi_index/access.rs Entry
// multi-index 中的一个条目，映射 ObjectId 到 pack 数据文件及偏移
public class MultiIndexEntry {
    public var oid: ObjectId
    public var packOffset: Int64
    public var packIndex: UInt32

    public init(oid: ObjectId, packOffset: Int64, packIndex: UInt32) {
        this.oid = oid
        this.packOffset = packOffset
        this.packIndex = packIndex
    }
}

extend MultiIndexEntry <: Equatable<MultiIndexEntry> {
    public operator func ==(other: MultiIndexEntry): Bool {
        oid == other.oid && packOffset == other.packOffset && packIndex == other.packIndex
    }

    public operator func !=(other: MultiIndexEntry): Bool {
        !(this == other)
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/mod.rs File<T>
// 多包索引文件的核心表示
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/mod.rs File
public class MultiIndexFile {
    public var path: String
    public var data: Array<Byte>
    public var version: MultiIndexVersion
    public var hashLen: Int64
    public var objectHash: HashKind
    // 包含的 pack 文件数量
    public var numIndices: UInt32
    // 总对象数量
    public var numObjects: UInt32
    // 分配限制（字节）
    public var allocLimitBytes: ?Int64

    // fanout 表：256 个 UInt32
    public var fan: Array<UInt32>
    // 索引名称列表（pack 对应的 .idx 文件路径）
    public var indexNames: ArrayList<String>
    // OID 查找表在 data 中的偏移
    public var lookupOfs: Int64
    // 偏移表在 data 中的偏移
    public var offsetsOfs: Int64
    // 大偏移表在 data 中的偏移（可选）
    public var largeOffsetsOfs: ?Int64

    public init(path: String) {
        this.path = path
        this.data = []
        this.version = MultiIndexVersion.V1
        this.hashLen = 20
        this.objectHash = HashKind.Sha1
        this.numIndices = 0
        this.numObjects = 0
        this.allocLimitBytes = None
        this.fan = Array<UInt32>(256, repeat: UInt32(0))
        this.indexNames = ArrayList<String>()
        this.lookupOfs = 0
        this.offsetsOfs = 0
        this.largeOffsetsOfs = None
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/access.rs
// 访问方法
// ============================================================

extend MultiIndexFile {
    // 对齐 Rust: File::version()
    public func getVersion(): MultiIndexVersion {
        version
    }

    // 对齐 Rust: File::path()
    public func getPath(): String {
        path
    }

    // 对齐 Rust: File::num_indices()
    public func getNumIndices(): UInt32 {
        numIndices
    }

    // 对齐 Rust: File::num_objects()
    public func getNumObjects(): UInt32 {
        numObjects
    }

    // 对齐 Rust: File::index_names()
    public func getIndexNames(): ArrayList<String> {
        indexNames
    }

    // 对齐 Rust: File::object_hash()
    public func getObjectHash(): HashKind {
        objectHash
    }

    // 对齐 Rust: File::fan()
    public func getFan(): Array<UInt32> {
        fan
    }

    // 对齐 Rust: File::lookup()
    // 使用二分查找在 multi-index 中查找 ObjectId
    // 返回 EntryIndex，若未找到返回 None
    public func lookup(id: ObjectId): ?MultiIndexEntryIndex {
        if (numObjects == 0) {
            return None
        }
        let firstByte = Int64(id.bytes[0])
        let lo: Int64 = if (firstByte == 0) {
            0
        } else {
            Int64(fan[firstByte - 1])
        }
        let hi = Int64(fan[firstByte])

        if (lo >= hi) {
            return None
        }

        // 二分查找
        var low = lo
        var high = hi - 1
        while (low <= high) {
            let mid = (low + high) / 2
            let entryOid = oidAtEntry(mid)
            if (entryOid.isNone()) {
                return None
            }
            let cmp = compareOid(id, entryOid.getOrThrow())
            if (cmp == 0) {
                return Some(UInt32(mid))
            } else if (cmp < 0) {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }
        None
    }

    // 对齐 Rust: File::entry()
    // 根据 EntryIndex 获取条目
    public func entry(index: MultiIndexEntryIndex): ?MultiIndexEntry {
        let idx = Int64(index)
        if (idx < 0 || idx >= Int64(numObjects)) {
            return None
        }
        let oid = oidAtEntry(idx)
        if (oid.isNone()) {
            return None
        }
        let packAndOffset = packIndexAndOffsetAt(idx)
        if (packAndOffset.isNone()) {
            return None
        }
        let (pi, po) = packAndOffset.getOrThrow()
        Some(MultiIndexEntry(oid.getOrThrow(), po, pi))
    }

    // 对齐 Rust: File::iter()
    // 遍历所有条目
    public func iter(): ArrayList<MultiIndexEntry> {
        let result = ArrayList<MultiIndexEntry>()
        for (i in 0..Int64(numObjects)) {
            let e = entry(UInt32(i))
            if (e.isSome()) {
                result.add(e.getOrThrow())
            }
        }
        result
    }

    // 对齐 Rust: File::prefix_lookup()
    // 前缀查找
    public func lookupPrefix(prefix: Prefix): ?PrefixLookupResult {
        if (numObjects == 0) {
            return None
        }
        let firstByte = Int64(prefix.id.bytes[0])
        let lo: Int64 = if (firstByte == 0) {
            0
        } else {
            Int64(fan[firstByte - 1])
        }
        let hi = Int64(fan[firstByte])

        if (lo >= hi) {
            return None
        }

        var low = lo
        var high = hi - 1
        var foundIdx: ?Int64 = None

        // 二分查找前缀
        while (low <= high) {
            let mid = (low + high) / 2
            let entryOid = oidAtEntry(mid)
            if (entryOid.isNone()) {
                return None
            }
            let cmp = compareOidPrefix(prefix, entryOid.getOrThrow())
            if (cmp == 0) {
                foundIdx = Some(mid)
                break
            } else if (cmp < 0) {
                high = mid - 1
            } else {
                low = mid + 1
            }
        }

        if (foundIdx.isNone()) {
            return None
        }

        // 检查是否唯一
        let idx = foundIdx.getOrThrow()
        // 检查前一个
        if (idx > 0) {
            let prevOid = oidAtEntry(idx - 1)
            if (prevOid.isSome() && compareOidPrefix(prefix, prevOid.getOrThrow()) == 0) {
                return Some(PrefixLookupResult.Ambiguous)
            }
        }
        // 检查后一个
        if (idx < Int64(numObjects) - 1) {
            let nextOid = oidAtEntry(idx + 1)
            if (nextOid.isSome() && compareOidPrefix(prefix, nextOid.getOrThrow()) == 0) {
                return Some(PrefixLookupResult.Ambiguous)
            }
        }
        Some(PrefixLookupResult.Unique(idx))
    }

    // 获取指定条目索引的 ObjectId
    func oidAtEntry(index: Int64): ?ObjectId {
        if (data.size == 0) {
            return None
        }
        let oidOfs = lookupOfs + index * hashLen
        if (oidOfs + hashLen > data.size) {
            return None
        }
        let bytes = Array<Byte>(hashLen, repeat: UInt8(0))
        for (i in 0..hashLen) {
            bytes[i] = data[oidOfs + i]
        }
        Some(ObjectId(bytes, objectHash))
    }

    // 获取指定条目索引的 (pack_index, pack_offset)
    func packIndexAndOffsetAt(index: Int64): ?(UInt32, Int64) {
        if (data.size == 0) {
            return None
        }
        // 4 字节 pack index + 4 字节 offset（或 8 字节大偏移）
        let entryOfs = offsetsOfs + index * 4
        if (entryOfs + 4 > data.size) {
            return None
        }
        let offset32 = readUInt32BE(data, entryOfs)
        if ((offset32 & UInt32(0x80000000)) != UInt32(0)) {
            // 大偏移：高位置 1 表示需要查找 largeOffsets 表
            if (largeOffsetsOfs.isNone()) {
                return None
            }
            let largeIdx = Int64(offset32 & 0x7FFFFFFF)
            let largeOfsBase = largeOffsetsOfs.getOrThrow()
            let largeOfs = largeOfsBase + largeIdx * 8
            if (largeOfs + 8 > data.size) {
                return None
            }
            let packIdx = readUInt32BE(data, entryOfs)
            // 大偏移表中存储的是 8 字节偏移量
            // 但实际上 Rust 的格式是：4字节 pack_index + 4字节 offset（小偏移）
            // 大偏移时 offset 的高位为 1，index 存在 largeOffsets 中
            // 对齐 Rust: gix-pack::multi_index::chunk::offsets — 大偏移表处理
            let packOffset = readUInt64BE(data, largeOfs)
            Some((packIdx, packOffset))
        } else {
            // 需要读取 pack_index：在 OID lookup 之后是 pack_index + offset 对
            // 实际格式：4 字节 pack_index 然后是 4 字节 offset
            // 但在 multi-index 中，偏移表存储的是 4 字节的 pack_index + offset 对
            // 对齐 Rust: gix-pack::multi_index::chunk::offsets — pack_index + offset 对
            // 对齐 Rust: 实际格式是先 4 字节 pack_index 再 4 字节 offset
            let packIdxOfs = offsetsOfs + Int64(numObjects) * 4 + index * 4
            if (packIdxOfs + 4 > data.size) {
                return None
            }
            let packIdx = readUInt32BE(data, packIdxOfs)
            Some((packIdx, Int64(offset32)))
        }
    }

    // 比较两个 ObjectId
    func compareOid(a: ObjectId, b: ObjectId): Int64 {
        for (i in 0..a.bytes.size) {
            if (a.bytes[i] < b.bytes[i]) {
                return -1
            }
            if (a.bytes[i] > b.bytes[i]) {
                return 1
            }
        }
        0
    }

    // 比较前缀与 ObjectId
    func compareOidPrefix(prefix: Prefix, oid: ObjectId): Int64 {
        let cmpLen = if (prefix.hexLen < oid.bytes.size) {
            prefix.hexLen
        } else {
            oid.bytes.size
        }
        // hexLen 是十六进制字符数，转换为字节数
        let byteLen = (cmpLen + 1) / 2
        for (i in 0..byteLen) {
            if (prefix.id.bytes[i] < oid.bytes[i]) {
                return -1
            }
            if (prefix.id.bytes[i] > oid.bytes[i]) {
                return 1
            }
        }
        0
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/chunk.rs
// Chunk 解析
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/chunk.rs index_names
// 解析 PNAM chunk 中的 pack 名称
public func decodeIndexNames(chunk: Array<Byte>, numPacks: Int64): ?ArrayList<String> {
    let names = ArrayList<String>()
    var start: Int64 = 0
    var count: Int64 = 0

    while (count < numPacks && start < chunk.size) {
        // 查找 null 终止符
        var end = start
        while (end < chunk.size && chunk[end] != 0) {
            end += 1
        }
        if (end >= chunk.size) {
            // 缺少 null 终止符
            return None
        }
        // 提取路径字符串
        var pathStr = ""
        for (i in start..end) {
            pathStr += String(Rune(chunk[i]))
        }
        names.add(pathStr)
        start = end + 1
        count += 1
    }

    // 验证字母序
    for (i in 1..names.size) {
        if (names[i] < names[i - 1]) {
            return None
        }
    }
    Some(names)
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/init.rs
// 从文件加载
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/init.rs Error
public class MultiIndexInitError <: GixError {
    public var kind: MultiIndexInitErrorKind

    public init(kind: MultiIndexInitErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum MultiIndexInitErrorKind {
    | Io(String)
    | Corrupt(String)
    | UnsupportedVersion(UInt8)
    | UnsupportedObjectHash(UInt8)
    | MultiPackFanSize
    | PackNames(String)
    | InvalidChunkSize(String)
}

extend MultiIndexInitErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case MultiIndexInitErrorKind.Io(msg) => "IO error: ${msg}"
            case MultiIndexInitErrorKind.Corrupt(msg) => "Corrupt: ${msg}"
            case MultiIndexInitErrorKind.UnsupportedVersion(v) => "Unsupported multi-index version: ${v}"
            case MultiIndexInitErrorKind.UnsupportedObjectHash(k) => "Unsupported object hash kind: ${k}"
            case MultiIndexInitErrorKind.MultiPackFanSize => "The multi-pack fan doesn't have the correct size of 256 * 4 bytes"
            case MultiIndexInitErrorKind.PackNames(msg) => "Pack names error: ${msg}"
            case MultiIndexInitErrorKind.InvalidChunkSize(msg) => "Invalid chunk size: ${msg}"
        }
    }
}

extend MultiIndexFile {
    // 对齐 Rust: File::at() -> Result<File, Error>
    // 从文件加载 multi-pack-index
    public static func at(path: String): PackResult<MultiIndexFile> {
        MultiIndexFile.atWithLimit(path, None)
    }

    // 对齐 Rust: File::at() with alloc_limit_bytes
    public static func atWithLimit(path: String, allocLimitBytes: ?Int64): PackResult<MultiIndexFile> {
        if (!exists(path)) {
            return PackResult.PackErr(PackError(PackErrorKind.Io("multi-index file not found: ${path}")))
        }
        let bytes = readFileBytes(path)
        if (bytes.size == 0) {
            return PackResult.PackErr(PackError(PackErrorKind.Io("failed to read multi-index file: ${path}")))
        }
        MultiIndexFile.fromData(bytes, path, allocLimitBytes)
    }

    // 从字节数据解析
    public static func fromData(data: Array<Byte>, path: String, allocLimitBytes: ?Int64): PackResult<MultiIndexFile> {
        let file = MultiIndexFile(path)
        file.data = data
        file.allocLimitBytes = allocLimitBytes

        if (data.size < 12) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("multi-index data too short")))
        }

        // 解析 header: 4 字节 magic + 1 字节 version + 1 字节 object_hash + 2 字节 num_chunks + 4 字节 num_objects
        // Git multi-pack-index 格式:
        // magic: "MIDX" (4 bytes)
        // version: 1 byte
        // object_hash: 1 byte (1=SHA1, 2=SHA256)
        // num_chunks: 2 bytes (unused in our case)
        // num_objects: 4 bytes
        // num_indices: 从 fanout[255] 推导

        // 验证 magic "MIDX"
        if (data[0] != 77 || data[1] != 73 || data[2] != 68 || data[3] != 88) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("invalid multi-index magic")))
        }

        // 版本
        let ver = data[4]
        if (ver != 1) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("unsupported multi-index version: ${ver}")))
        }
        file.version = MultiIndexVersion.V1

        // 对象哈希类型
        let hashKindByte = data[5]
        if (hashKindByte == 1) {
            file.objectHash = HashKind.Sha1
            file.hashLen = 20
        } else if (hashKindByte == 2) {
            file.objectHash = HashKind.Sha256
            file.hashLen = 32
        } else {
            return PackResult.PackErr(
                PackError(PackErrorKind.InvalidData("unsupported object hash kind: ${hashKindByte}")))
        }

        // num_objects (4 bytes, big-endian, offset 8)
        file.numObjects = readUInt32BE(data, 8)

        // 读取 fanout 表 (256 * 4 bytes)
        // fanout 紧跟 header 之后，在 chunk 表之后
        // 对齐 Rust: gix-pack::multi_index::chunk — 使用 chunk 定位 OIDF
        // 实际 Git 格式：header(12) + chunk table + chunks
        // 我们需要找到 OIDF (OID Fanout) chunk
        let chunkTableStart: Int64 = 12
        // chunk table: 每个条目 12 字节 (4 字节 chunk ID + 8 字节 offset)
        // 最后一个条目是全零终止符
        var fanoutOfs: ?Int64 = None
        var oidLookupOfs: ?Int64 = None
        var offsetsOfs: ?Int64 = None
        var largeOffsetsOfs: ?Int64 = None
        var packNamesOfs: ?Int64 = None
        var packNamesLen: ?Int64 = None
        var numIndicesFound: UInt32 = 0

        var pos = chunkTableStart
        while (pos + 12 <= data.size) {
            let chunkId = Array<Byte>(4, repeat: UInt8(0))
            for (i in 0..4) {
                chunkId[i] = data[pos + i]
            }
            let chunkOffset = readUInt64BE(data, pos + 4)

            // 检查是否是终止符（全零 chunk ID）
            if (chunkId[0] == 0 && chunkId[1] == 0 && chunkId[2] == 0 && chunkId[3] == 0) {
                break
            }

            // 识别 chunk
            if (chunkId[0] == 79 && chunkId[1] == 73 && chunkId[2] == 68 && chunkId[3] == 70) {
                // "OIDF" - OID Fanout
                fanoutOfs = Some(Int64(chunkOffset))
            } else if (chunkId[0] == 79 && chunkId[1] == 73 && chunkId[2] == 68 && chunkId[3] == 76) {
                // "OIDL" - OID Lookup
                oidLookupOfs = Some(Int64(chunkOffset))
            } else if (chunkId[0] == 79 && chunkId[1] == 73 && chunkId[2] == 68 && chunkId[3] == 83) {
                // "OIDS" - OID Sorted
                oidLookupOfs = Some(Int64(chunkOffset))
            } else if (chunkId[0] == 79 && chunkId[1] == 70 && chunkId[2] == 70 && chunkId[3] == 70) {
                // "OFFP" - Object Offsets
                offsetsOfs = Some(Int64(chunkOffset))
            } else if (chunkId[0] == 76 && chunkId[1] == 79 && chunkId[2] == 70 && chunkId[3] == 70) {
                // "LOFP" - Large Object Offsets
                largeOffsetsOfs = Some(Int64(chunkOffset))
            } else if (chunkId[0] == 80 && chunkId[1] == 78 && chunkId[2] == 65 && chunkId[3] == 77) {
                // "PNAM" - Pack Names
                packNamesOfs = Some(Int64(chunkOffset))
            }

            pos += 12
        }

        // 读取 fanout
        if (fanoutOfs.isSome()) {
            let fo = fanoutOfs.getOrThrow()
            for (i in 0..256) {
                file.fan[i] = readUInt32BE(data, fo + i * 4)
            }
            numIndicesFound = file.fan[255]
            file.numIndices = numIndicesFound
        }

        // 读取 pack 名称
        if (packNamesOfs.isSome()) {
            // 需要知道 PNAM chunk 的长度
            // 对齐 Rust: gix-pack::multi_index::chunk::index_names — 从 PNAM chunk 解析
            let names = decodeIndexNamesFromData(data, packNamesOfs.getOrThrow(), Int64(file.numIndices))
            if (names.isSome()) {
                file.indexNames = names.getOrThrow()
            }
        }

        // 设置偏移
        if (oidLookupOfs.isSome()) {
            file.lookupOfs = oidLookupOfs.getOrThrow()
        }
        if (offsetsOfs.isSome()) {
            file.offsetsOfs = offsetsOfs.getOrThrow()
        }
        if (largeOffsetsOfs.isSome()) {
            file.largeOffsetsOfs = largeOffsetsOfs
        }

        PackResult.PackOk(file)
    }
}

// 从数据中解析 pack 名称
func decodeIndexNamesFromData(data: Array<Byte>, startOfs: Int64, numPacks: Int64): ?ArrayList<String> {
    let names = ArrayList<String>()
    var pos = startOfs
    var count: Int64 = 0

    while (count < numPacks && pos < data.size) {
        var end = pos
        while (end < data.size && data[end] != 0) {
            end += 1
        }
        if (end >= data.size) {
            return None
        }
        var pathStr = ""
        for (i in pos..end) {
            pathStr += String(Rune(data[i]))
        }
        names.add(pathStr)
        pos = end + 1
        count += 1
    }
    Some(names)
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/verify.rs
// 校验
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/verify/integrity.rs Error
public class MultiIndexIntegrityError <: GixError {
    public var kind: MultiIndexIntegrityErrorKind

    public init(kind: MultiIndexIntegrityErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum MultiIndexIntegrityErrorKind {
    | PackOffsetMismatch(ObjectId, Int64, Int64)
    | ChecksumMismatch(String)
    | UnexpectedObjectCount(Int64, Int64)
    | OidNotFound(ObjectId)
    | OutOfOrder(Int64)
    | Fan(Int64)
    | NoIndices
}

extend MultiIndexIntegrityErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case MultiIndexIntegrityErrorKind.PackOffsetMismatch(id, expected, actual) => "Object ${id.toHexString()} should be at pack-offset ${expected} but was found at ${actual}"
            case MultiIndexIntegrityErrorKind.ChecksumMismatch(msg) => "Checksum mismatch: ${msg}"
            case MultiIndexIntegrityErrorKind.UnexpectedObjectCount(actual, expected) => "Counted ${actual} objects, but expected ${expected}"
            case MultiIndexIntegrityErrorKind.OidNotFound(id) => "${id.toHexString()} wasn't found in the index"
            case MultiIndexIntegrityErrorKind.OutOfOrder(index) => "The object id at multi-index entry ${index} wasn't in order"
            case MultiIndexIntegrityErrorKind.Fan(index) => "The fan at index ${index} is out of order"
            case MultiIndexIntegrityErrorKind.NoIndices => "The multi-index claims to have no objects"
        }
    }
}

extend MultiIndexFile {
    // 对齐 Rust: File::verify_integrity()
    // 校验 multi-index 文件的完整性
    public func verifyIntegrity(): PackResult<Unit> {
        // 1. 检查 fanout 单调性
        for (i in 1..256) {
            if (fan[i] < fan[i - 1]) {
                return PackResult.PackErr(PackError(PackErrorKind.InvalidData("fan at index ${i} is out of order")))
            }
        }

        // 2. 检查 fan[255] == numObjects
        if (fan[255] != numObjects) {
            return PackResult.PackErr(
                PackError(PackErrorKind.InvalidData("fan[255] = ${fan[255]} != numObjects = ${numObjects}")))
        }

        // 3. 检查 OID 排序
        for (i in 1..Int64(numObjects)) {
            let prev = oidAtEntry(i - 1)
            let curr = oidAtEntry(i)
            if (prev.isSome() && curr.isSome()) {
                let cmp = compareOid(prev.getOrThrow(), curr.getOrThrow())
                if (cmp >= 0) {
                    return PackResult.PackErr(PackError(PackErrorKind.InvalidData("OID at entry ${i} not in order")))
                }
            }
        }

        // 4. 校验尾部校验和
        if (data.size >= hashLen) {
            let storedChecksumStart = data.size - hashLen
            let computed = computeChecksum(data, 0, storedChecksumStart)
            for (i in 0..hashLen) {
                if (data[storedChecksumStart + i] != computed[i]) {
                    return PackResult.PackErr(
                        PackError(
                            PackErrorKind.Verify(
                                PackVerifyError(PackVerifyErrorKind.ChecksumMismatch("multi-index checksum")))))
                }
            }
        }

        PackResult.PackOk(())
    }

    // 计算数据的校验和
    func computeChecksum(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
        let hasher = GixHasher(objectHash)
        var i = start
        while (i < end) {
            let chunkEnd = if (i + 4096 < end) {
                i + 4096
            } else {
                end
            }
            let chunkSize = chunkEnd - i
            let chunk = Array<Byte>(chunkSize, repeat: UInt8(0))
            for (j in 0..chunkSize) {
                chunk[j] = data[i + j]
            }
            hasher.update(chunk)
            i = chunkEnd
        }
        hasher.tryFinalize().bytes
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/multi_index/write.rs
// 写入
// ============================================================

// 对齐 Rust: gix-pack/src/multi_index/write.rs Options
public class MultiIndexWriteOptions {
    public var objectHash: HashKind

    public init(objectHash: HashKind) {
        this.objectHash = objectHash
    }
}

// 对齐 Rust: gix-pack/src/multi_index/write.rs Outcome
public class MultiIndexWriteOutcome {
    public var multiIndexChecksum: ObjectId

    public init(multiIndexChecksum: ObjectId) {
        this.multiIndexChecksum = multiIndexChecksum
    }
}

// 对齐 Rust: gix-pack/src/multi_index/write.rs write_from_index_paths()
// 从多个 pack index 文件路径生成 multi-pack-index
public func writeMultiIndexFromIndexPaths(
    indexPaths: ArrayList<String>,
    multiIndexPath: String,
    options: MultiIndexWriteOptions
): PackResult<MultiIndexWriteOutcome> {
    // 1. 收集所有 index 文件中的条目
    let allEntries = ArrayList<MultiIndexEntry>()
    for (pi in 0..indexPaths.size) {
        let idxPath = indexPaths[pi]
        let indexResult = IndexFile.at(idxPath, options.objectHash)
        if (indexResult.isErr()) {
            return PackResult.PackErr(indexResult.err().getOrThrow())
        }
        let indexFile = indexResult.unwrap()
        for (i in 0..indexFile.numObjects) {
            let oid = indexFile.oidAtIndex(i)
            if (oid.isSome()) {
                let offset = indexFile.packOffsetAtIndex(i)
                if (offset.isSome()) {
                    allEntries.add(MultiIndexEntry(oid.getOrThrow(), offset.getOrThrow(), UInt32(pi)))
                }
            }
        }
    }

    // 2. 按 ObjectId 排序
    allEntries.sortBy(
        comparator: {
            a: MultiIndexEntry, b: MultiIndexEntry =>
                let cmpA = a.oid.bytes
                let cmpB = b.oid.bytes
                var result: Ordering = Ordering.EQ
                for (i in 0..cmpA.size) {
                    if (cmpA[i] < cmpB[i]) {
                        result = Ordering.LT
                        break
                    }
                    if (cmpA[i] > cmpB[i]) {
                        result = Ordering.GT
                        break
                    }
                }
                result
        }
    )

    // 3. 构建 multi-pack-index 数据
    let numObjects = allEntries.size
    let hashLen = indexHashLenBytes(options.objectHash)

    // Header: "MIDX" + version(1) + hash_kind(1) + 0(2) + num_objects(4) = 12 bytes
    var buf = ArrayList<Byte>()
    // Magic
    buf.add(77) // M
    buf.add(73) // I
    buf.add(68) // D
    buf.add(88) // X

    // Version
    buf.add(1)
    // Object hash kind
    buf.add(if (options.objectHash == HashKind.Sha256) {
        UInt8(2)
    } else {
        UInt8(1)
    })
    // Padding
    buf.add(0)
    buf.add(0)
    // num_objects (4 bytes big-endian)
    writeUInt32BEToBuf(buf, UInt32(numObjects))

    // Chunk table 占位符 — 先写数据再回头填
    // 对齐 Rust: gix-pack::multi_index::write — 顺序写入各 chunk

    // PNAM chunk: pack 名称
    let pnamStart = buf.size
    for (pi in 0..indexPaths.size) {
        let name = indexPaths[pi]
        for (j in 0..name.size) {
            buf.add(UInt8(name[j]))
        }
        buf.add(0) // null 终止
    }
    // 对齐到 4 字节
    while (buf.size % 4 != 0) {
        buf.add(0)
    }

    // OIDF chunk: fanout 表 (256 * 4 bytes)
    let oidfStart = buf.size
    let fanout = computeMultiIndexFanout(allEntries, hashLen)
    for (i in 0..256) {
        writeUInt32BEToBuf(buf, fanout[i])
    }

    // OIDS chunk: 排序后的 OID 列表
    let oidsStart = buf.size
    for (i in 0..numObjects) {
        let oid = allEntries[i].oid
        for (j in 0..oid.bytes.size) {
            buf.add(oid.bytes[j])
        }
    }

    // OFFP chunk: 偏移表 (每个条目 4 字节 pack_index + 4 字节 offset)
    let offpStart = buf.size
    for (i in 0..numObjects) {
        writeUInt32BEToBuf(buf, allEntries[i].packIndex)
    }
    for (i in 0..numObjects) {
        writeUInt32BEToBuf(buf, UInt32(allEntries[i].packOffset))
    }

    // 校验和
    let dataArray = buf.toArray()
    let checksum = computeMultiIndexChecksum(dataArray, options.objectHash)
    for (i in 0..checksum.size) {
        buf.add(checksum[i])
    }

    // 写入文件
    let finalData = buf.toArray()
    try {
        let f = File(multiIndexPath, OpenMode.Write)
        let writeBuf = Array<UInt8>(finalData.size, repeat: UInt8(0))
        for (i in 0..finalData.size) {
            writeBuf[i] = finalData[i]
        }
        f.write(writeBuf)
        f.close()
    } catch (e: Exception) {
        return PackResult.PackErr(PackError(PackErrorKind.Io("failed to write multi-index: ${e.message}")))
    }

    PackResult.PackOk(MultiIndexWriteOutcome(ObjectId(checksum, options.objectHash)))
}

// 计算 multi-index 的 fanout 表
func computeMultiIndexFanout(entries: ArrayList<MultiIndexEntry>, hashLen: Int64): Array<UInt32> {
    let fan = Array<UInt32>(256, repeat: UInt32(0))
    for (i in 0..entries.size) {
        let firstByte = entries[i].oid.bytes[0]
        fan[Int64(firstByte)] += UInt32(1)
    }
    // 累加
    var acc: UInt32 = 0
    for (i in 0..256) {
        acc += fan[i]
        fan[i] = acc
    }
    fan
}

// 计算 multi-index 校验和
func computeMultiIndexChecksum(data: Array<Byte>, hashKind: HashKind): Array<Byte> {
    let hasher = GixHasher(hashKind)
    hasher.update(data)
    hasher.tryFinalize().bytes
}

// ============================================================
// 辅助函数
// ============================================================

// 大端序读取 UInt32
func readUInt32BE(data: Array<Byte>, offset: Int64): UInt32 {
    UInt32(data[offset]) << 24 | UInt32(data[offset + 1]) << 16 | UInt32(data[offset + 2]) << 8 | UInt32(data[offset + 3])
}

// 大端序读取 UInt64
func readUInt64BE(data: Array<Byte>, offset: Int64): Int64 {
    (Int64(data[offset]) << 56) | (Int64(data[offset + 1]) << 48) | (Int64(data[offset + 2]) << 40) | (Int64(data[offset +
            3]) << 32) | (Int64(data[offset + 4]) << 24) | (Int64(data[offset + 5]) << 16) | (Int64(data[offset + 6]) <<
        8) | Int64(data[offset + 7])
}

// 大端序写入 UInt32 到 buf
func writeUInt32BEToBuf(buf: ArrayList<Byte>, value: UInt32): Unit {
    buf.add(UInt8((value >> 24) & UInt32(0xFF)))
    buf.add(UInt8((value >> 16) & UInt32(0xFF)))
    buf.add(UInt8((value >> 8) & UInt32(0xFF)))
    buf.add(UInt8(value & UInt32(0xFF)))
}
