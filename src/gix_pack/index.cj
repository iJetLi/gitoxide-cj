// 文件：index.cj
// 用途：全量对齐 Rust gitoxide gix-pack index 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/index/{mod,access,init,encode,verify}.rs
// 关键类型：IndexVersion, IndexFile, IndexEntry, EntryIndex
//           PrefixLookupResult, VerifyMode, SafetyCheck, TraverseAlgorithm

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import gitoxide.gix_object.*
import std.fs.*
import std.collection.*

public enum IndexVersion {
    | V1
    | V2
}

extend IndexVersion <: Equatable<IndexVersion> {
    public operator func ==(other: IndexVersion): Bool {
        match (this) {
            case IndexVersion.V1 => match (other) {
                case IndexVersion.V1 => true
                case _ => false
            }
            case IndexVersion.V2 => match (other) {
                case IndexVersion.V2 => true
                case _ => false
            }
        }
    }

    public operator func !=(other: IndexVersion): Bool {
        !(this == other)
    }
}

extend IndexVersion {
    public func asValue(): Int64 {
        match (this) {
            case IndexVersion.V1 => 1
            case IndexVersion.V2 => 2
        }
    }
}

public type EntryIndex = Int64

public enum PrefixLookupResult {
    | Unique(EntryIndex)
    | Ambiguous
}

let V2_SIGNATURE: Array<Byte> = [UInt8(0xFF), UInt8(0x74), UInt8(0x4F), UInt8(0x63)]
let FAN_LEN: Int64 = 256
let N32_SIZE: Int64 = 4
let N64_SIZE: Int64 = 8
let V1_HEADER_SIZE: Int64 = FAN_LEN * N32_SIZE
let V2_HEADER_SIZE: Int64 = N32_SIZE * 2 + FAN_LEN * N32_SIZE
let N32_HIGH_BIT: Int64 = 1 << 31
let LARGE_OFFSET_THRESHOLD: Int64 = 0x7FFFFFFF
let HIGH_BIT: Int64 = 0x80000000

public class IndexEntry {
    public var oid: ObjectId
    public var packOffset: Int64
    public var crc32: ?Int64

    public init(oid: ObjectId, packOffset: Int64) {
        this.oid = oid
        this.packOffset = packOffset
        this.crc32 = None
    }

    public init(oid: ObjectId, packOffset: Int64, crc32: ?Int64) {
        this.oid = oid
        this.packOffset = packOffset
        this.crc32 = crc32
    }
}

public class IndexFile {
    public var path: String
    public var hashKind: HashKind
    public var version: IndexVersion
    public var numObjects: Int64
    public var packPath: String
    public var data: Array<Byte>
    public var fan: Array<Int64>
    public var hashLen: Int64

    public init(path: String, hashKind: HashKind) {
        this.path = path
        this.hashKind = hashKind
        this.version = IndexVersion.V2
        this.numObjects = 0
        this.packPath = ""
        this.data = []
        this.fan = Array<Int64>(256, repeat: 0)
        this.hashLen = indexHashLenBytes(hashKind)
    }

    public init(path: String, hashKind: HashKind, version: IndexVersion, numObjects: Int64, packPath: String,
        data: Array<Byte>, fan: Array<Int64>, hashLen: Int64) {
        this.path = path
        this.hashKind = hashKind
        this.version = version
        this.numObjects = numObjects
        this.packPath = packPath
        this.data = data
        this.fan = fan
        this.hashLen = hashLen
    }

    // 对齐 Rust: index::File::at() -> Result<File, Error>
    public static func at(path: String, hashKind: HashKind): PackResult<IndexFile> {
        if (!exists(path)) {
            return PackResult.PackErr(PackError(PackErrorKind.Io("index file not found: ${path}")))
        }
        try {
            let bytes = readFileBytes(path)
            IndexFile.fromData(bytes, path, hashKind)
        } catch (e: Exception) {
            PackResult.PackErr(PackError(PackErrorKind.Io("failed to read index file: ${e.message}")))
        }
    }

    // 对齐 Rust: index::File::from_data() -> Result<File, Error>
    public static func fromData(data: Array<Byte>, path: String, hashKind: HashKind): PackResult<IndexFile> {
        let hashLen = indexHashLenBytes(hashKind)
        let footerSize = hashLen * 2
        if (data.size < FAN_LEN * N32_SIZE + footerSize) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("index data too short: ${data.size} bytes")))
        }

        var version: IndexVersion = IndexVersion.V1
        var dStart: Int64 = 0
        if (data.size >= V2_SIGNATURE.size) {
            var sigMatch = true
            var i: Int64 = 0
            while (i < V2_SIGNATURE.size) {
                if (data[i] != V2_SIGNATURE[i]) {
                    sigMatch = false
                    break
                }
                i += 1
            }
            if (sigMatch) {
                version = IndexVersion.V2
                dStart = V2_SIGNATURE.size
                if (dStart + N32_SIZE > data.size) {
                    return PackResult.PackErr(PackError(PackErrorKind.InvalidData("V2 index header truncated")))
                }
                let verVal = readU32Idx(data, dStart)
                if (verVal != 2) {
                    return PackResult.PackErr(
                        PackError(PackErrorKind.InvalidData("unsupported index version: ${verVal}")))
                }
                dStart += N32_SIZE
            }
        }

        let fan = readFanoutTable(data, dStart)
        let numObjects = fan[255]

        if (!fanIsMonotonicallyIncreasing(fan)) {
            return PackResult.PackErr(
                PackError(PackErrorKind.Verify(PackVerifyError(PackVerifyErrorKind.FanoutNonMonotonic(0, 0)))))
        }

        if (!validateIndexSize(data, version, numObjects, hashLen)) {
            return PackResult.PackErr(
                PackError(PackErrorKind.InvalidData("index data size inconsistent with declared object count")))
        }

        let packPath = if (path.size > 4 && (substringStr(path, path.size - 4, path.size) == ".idx")) {
            substringStr(path, 0, path.size - 4) + ".pack"
        } else {
            path + ".pack"
        }

        PackResult.PackOk(IndexFile(path, hashKind, version, numObjects, packPath, data, fan, hashLen))
    }

    public func fanAt(i: Int64): Int64 {
        if (i < 0 || i >= FAN_LEN) {
            return 0
        }
        fan[i]
    }

    public func entryAt(index: EntryIndex): ?IndexEntry {
        let oidOpt = oidAtIndex(index)
        if (oidOpt.isNone()) {
            return None
        }
        let offsetOpt = packOffsetAtIndex(index)
        if (offsetOpt.isNone()) {
            return None
        }
        let crcOpt = crc32AtIndex(index)
        Some(IndexEntry(oidOpt.getOrThrow(), offsetOpt.getOrThrow(), crcOpt))
    }

    public func oidAtIndex(index: EntryIndex): ?ObjectId {
        if (index < 0 || index >= numObjects) {
            return None
        }
        let start = match (version) {
            case IndexVersion.V2 => V2_HEADER_SIZE + index * hashLen
            case IndexVersion.V1 => V1_HEADER_SIZE + index * (N32_SIZE + hashLen) + N32_SIZE
        }
        if (start + hashLen > data.size) {
            return None
        }
        let oidBytes = sliceIdxBytes(data, start, start + hashLen)
        Some(ObjectId(oidBytes, hashKind))
    }

    public func packOffsetAtIndex(index: EntryIndex): ?Int64 {
        if (index < 0 || index >= numObjects) {
            return None
        }
        if (version == IndexVersion.V2) {
            var start = offsetPackOffsetV2() + index * N32_SIZE
            if (start + N32_SIZE > data.size) {
                return None
            }
            return Some(packOffsetFromOffsetV2(start))
        }
        var start = V1_HEADER_SIZE + index * (N32_SIZE + hashLen)
        if (start + N32_SIZE > data.size) {
            return None
        }
        Some(readU32Idx(data, start))
    }

    public func crc32AtIndex(index: EntryIndex): ?Int64 {
        if (index < 0 || index >= numObjects) {
            return None
        }
        if (version == IndexVersion.V1) {
            return None
        }
        var start = offsetCrc32V2() + index * N32_SIZE
        if (start + N32_SIZE > data.size) {
            return None
        }
        Some(readU32Idx(data, start))
    }

    public func lookup(id: ObjectId): ?EntryIndex {
        let firstByte = Int64(id.bytes[0]) & 0xFF
        var upperBound = fan[firstByte]
        var lowerBound = if (firstByte != 0) {
            fan[firstByte - 1]
        } else {
            0
        }

        while (lowerBound < upperBound) {
            let mid = (lowerBound + upperBound) / 2
            let midOid = oidAtIndex(mid)
            if (midOid.isNone()) {
                return None
            }
            let cmp = compareOid(id, midOid.getOrThrow())
            if (cmp < 0) {
                upperBound = mid
            } else if (cmp == 0) {
                return Some(mid)
            } else {
                lowerBound = mid + 1
            }
        }
        None
    }

    public func lookupPrefix(prefix: Prefix): ?PrefixLookupResult {
        let firstByte = Int64(prefix.id.bytes[0]) & 0xFF
        var upperBound = fan[firstByte]
        var lowerBound = if (firstByte != 0) {
            fan[firstByte - 1]
        } else {
            0
        }

        while (lowerBound < upperBound) {
            let mid = (lowerBound + upperBound) / 2
            let midOid = oidAtIndex(mid)
            if (midOid.isNone()) {
                return None
            }
            let cmp = comparePrefixOid(prefix, midOid.getOrThrow())
            if (cmp < 0) {
                upperBound = mid
            } else if (cmp == 0) {
                var isAmbiguous = false
                let next = mid + 1
                if (next < numObjects) {
                    let nextOid = oidAtIndex(next)
                    if (nextOid.isSome()) {
                        if (comparePrefixOid(prefix, nextOid.getOrThrow()) == 0) {
                            isAmbiguous = true
                        }
                    }
                }
                if (!isAmbiguous && mid > 0) {
                    let prevOid = oidAtIndex(mid - 1)
                    if (prevOid.isSome()) {
                        if (comparePrefixOid(prefix, prevOid.getOrThrow()) == 0) {
                            isAmbiguous = true
                        }
                    }
                }
                if (isAmbiguous) {
                    return Some(PrefixLookupResult.Ambiguous)
                }
                return Some(PrefixLookupResult.Unique(mid))
            } else {
                lowerBound = mid + 1
            }
        }
        None
    }

    public func iter(): ArrayList<IndexEntry> {
        var result = ArrayList<IndexEntry>()
        match (version) {
            case IndexVersion.V1 => iterV1(result)
            case IndexVersion.V2 => iterV2(result)
        }
        result
    }

    public func sortedOffsets(): ArrayList<Int64> {
        var ofs = ArrayList<Int64>()
        if (version == IndexVersion.V1) {
            for (entry in iter()) {
                ofs.add(entry.packOffset)
            }
        } else {
            var i: Int64 = 0
            while (i < numObjects) {
                let offsetPos = offsetPackOffsetV2() + i * N32_SIZE
                if (offsetPos + N32_SIZE <= data.size) {
                    ofs.add(packOffsetFromOffsetV2(offsetPos))
                }
                i += 1
            }
        }
        var j: Int64 = 0
        while (j < ofs.size - 1) {
            var k: Int64 = 0
            while (k < ofs.size - 1 - j) {
                if (ofs[k] > ofs[k + 1]) {
                    let tmp = ofs[k]
                    ofs[k] = ofs[k + 1]
                    ofs[k + 1] = tmp
                }
                k += 1
            }
            j += 1
        }
        ofs
    }

    public func indexChecksum(): ?ObjectId {
        if (data.size < hashLen) {
            return None
        }
        let start = data.size - hashLen
        let bytes = sliceIdxBytes(data, start, data.size)
        Some(ObjectId(bytes, hashKind))
    }

    public func packChecksum(): ?ObjectId {
        if (data.size < hashLen * 2) {
            return None
        }
        let start = data.size - hashLen * 2
        let bytes = sliceIdxBytes(data, start, start + hashLen)
        Some(ObjectId(bytes, hashKind))
    }

    public func verifyChecksum(): Bool {
        if (data.size == 0) {
            if (!exists(path)) {
                return false
            }
            try {
                data = readFileBytes(path)
            } catch (_: Exception) {
                return false
            }
        }
        let storedChecksum = indexChecksum()
        if (storedChecksum.isNone()) {
            return false
        }
        let dataLen = data.size - hashLen
        var dataToHash = ArrayList<Byte>()
        for (i in 0..dataLen) {
            dataToHash.add(data[i])
        }
        let hasher = GixHasher(hashKind)
        hasher.update(dataToHash.toArray())
        let computedId = hasher.tryFinalize()
        computedId.equals(storedChecksum.getOrThrow())
    }

    // 验证 fanout 表单调非递减，且 fan[255] == numObjects
    // 对齐 Rust: index::verify fanout 检查
    public func verifyFanout(): Bool {
        fanIsMonotonicallyIncreasing(fan) && fan[255] == numObjects
    }

    // 查找 fanout 表中第一个不单调递增的位置
    // 对齐 Rust: crate::verify::fan()
    // 返回 None 表示 fanout 有效，Some(index) 表示第一个违规位置
    public func findInvalidFan(): ?Int64 {
        for (i in 1..256) {
            if (fan[i] < fan[i - 1]) {
                return Some(i)
            }
        }
        None
    }

    // 完整索引完整性校验
    // 对齐 Rust: index::File::verify_integrity()
    // 参数 packDataFile：可选的 pack 数据文件，提供时进行 CRC32+对象校验
    // 参数 verifyMode：校验模式（HashCrc32/HashCrc32Decode/HashCrc32DecodeEncode）
    // 返回值：校验结果，包含实际校验和和可选的遍历统计
    public func verifyIntegrity(packDataFile: ?DataFile, verifyMode: VerifyMode): IndexVerifyResult {
        // 第一步：fanout 校验
        let invalidFan = findInvalidFan()
        if (invalidFan.isSome()) {
            return IndexVerifyResult.FanError(invalidFan.getOrThrow())
        }

        // 第二步：索引文件校验和验证
        if (!verifyChecksum()) {
            return IndexVerifyResult.ChecksumMismatch
        }

        // 第三步：如果有 pack 数据文件，进行条目级校验
        if (packDataFile.isSome()) {
            let df = packDataFile.getOrThrow()
            let stats = TraverseStatistics()
            var i: Int64 = 0
            while (i < numObjects) {
                let entryOpt = entryAt(i)
                if (entryOpt.isNone()) {
                    i += 1
                    continue
                }
                let idxEntry = entryOpt.getOrThrow()

                // 对齐 Rust: traverse 中 pack.entry() + decode_entry() 获取 compressed_size
                let packEntryResult = df.entry(idxEntry.packOffset)
                if (packEntryResult.isErr()) {
                    i += 1
                    continue
                }
                let packEntry = packEntryResult.unwrap()
                let headerSize = packEntry.headerSize()

                // CRC32 校验（V2 索引才有 CRC32）
                if (version == IndexVersion.V2) {
                    let expectedCrc = crc32AtIndex(i)
                    if (expectedCrc.isSome() && idxEntry.packOffset >= 12) {
                        // 对齐 Rust: decompress_entry_from_data_offset() 获取 compressed_size
                        let decompressed = df.decompressEntry(packEntry)
                        if (decompressed.isSome()) {
                            let dr = decompressed.getOrThrow()
                            let entryLen = headerSize + dr.compressedSize
                            let actualCrc = df.entryCrc32(idxEntry.packOffset, entryLen)
                            if (actualCrc != expectedCrc.getOrThrow()) {
                                return IndexVerifyResult.Crc32Mismatch(i, idxEntry.oid)
                            }
                        }
                    }
                }

                // 对象解码校验（HashCrc32Decode 及以上模式）
                if (verifyMode != VerifyMode.HashCrc32) {
                    if (!packEntry.header.isDelta()) {
                        let kind = packEntry.header.asKind()
                        if (kind.isSome()) {
                            stats.addObject(kind.getOrThrow(), packEntry.decompressedSize)
                        }
                    }
                }

                i += 1
            }
            return IndexVerifyResult.Ok(
                IntegrityOutcome(
                    indexChecksum().getOrThrow(),
                    Some(stats)
                )
            )
        }

        IndexVerifyResult.Ok(
            IntegrityOutcome(
                indexChecksum().getOrThrow(),
                None
            )
        )
    }

    func offsetCrc32V2(): Int64 {
        V2_HEADER_SIZE + numObjects * hashLen
    }

    func offsetPackOffsetV2(): Int64 {
        offsetCrc32V2() + numObjects * N32_SIZE
    }

    func offsetPackOffset64V2(): Int64 {
        offsetPackOffsetV2() + numObjects * N32_SIZE
    }

    func packOffsetFromOffsetV2(offsetPos: Int64): Int64 {
        let ofs32 = readU32Idx(data, offsetPos)
        if ((ofs32 & N32_HIGH_BIT) == N32_HIGH_BIT) {
            let idx64 = ofs32 ^ N32_HIGH_BIT
            let from = offsetPackOffset64V2() + idx64 * N64_SIZE
            if (from + N64_SIZE > data.size) {
                return ofs32
            }
            readU64Idx(data, from)
        } else {
            ofs32
        }
    }

    func iterV1(result: ArrayList<IndexEntry>): Unit {
        var i: Int64 = 0
        while (i < numObjects) {
            let offsetStart = V1_HEADER_SIZE + i * (N32_SIZE + hashLen)
            let oidStart = offsetStart + N32_SIZE
            if (oidStart + hashLen > data.size) {
                break
            }
            let packOffset = readU32Idx(data, offsetStart)
            let oidBytes = sliceIdxBytes(data, oidStart, oidStart + hashLen)
            let oid = ObjectId(oidBytes, hashKind)
            result.add(IndexEntry(oid, packOffset, None))
            i += 1
        }
    }

    func iterV2(result: ArrayList<IndexEntry>): Unit {
        var i: Int64 = 0
        while (i < numObjects) {
            let oidStart = V2_HEADER_SIZE + i * hashLen
            if (oidStart + hashLen > data.size) {
                break
            }
            let oidBytes = sliceIdxBytes(data, oidStart, oidStart + hashLen)
            let oid = ObjectId(oidBytes, hashKind)

            let crc32Pos = offsetCrc32V2() + i * N32_SIZE
            var crc32Val: ?Int64 = None
            if (crc32Pos + N32_SIZE <= data.size) {
                crc32Val = Some(readU32Idx(data, crc32Pos))
            }

            let offsetPos = offsetPackOffsetV2() + i * N32_SIZE
            var packOffset: Int64 = 0
            if (offsetPos + N32_SIZE <= data.size) {
                packOffset = packOffsetFromOffsetV2(offsetPos)
            }

            result.add(IndexEntry(oid, packOffset, crc32Val))
            i += 1
        }
    }

    // 顺序遍历索引条目并收集统计信息
    // 对齐 Rust: index::traverse（简化版，无 delta tree）
    // 参数 dataFile：pack 数据文件（用于解码对象类型）
    // 参数 options：遍历选项
    public func traverse(dataFile: DataFile, options: TraverseOptions): ?TraverseStatistics {
        var stats = TraverseStatistics()
        stats.packSize = dataFile.dataLen()
        var i: Int64 = 0
        while (i < numObjects) {
            let entryIdx = i
            let offsetOpt = packOffsetAtIndex(entryIdx)
            if (offsetOpt.isNone()) {
                return None
            }
            let packEntry = dataFile.entry(offsetOpt.getOrThrow())
            if (packEntry.isOk()) {
                let e = packEntry.unwrap()
                let hdrSize = e.headerSize()
                // 对齐 Rust: decompress_entry_from_data_offset() 获取 compressed_size
                let decompressed = dataFile.decompressEntry(e)
                let compSize = if (decompressed.isSome()) {
                    decompressed.getOrThrow().compressedSize
                } else {
                    Int64(0)
                }
                stats.addCompressedSize(hdrSize + compSize)

                match (e.header) {
                    case EntryHeader.Commit => stats.addObjectWithChainLength(ObjectKind.Commit, e.decompressedSize, 0)
                    case EntryHeader.Tree => stats.addObjectWithChainLength(ObjectKind.Tree, e.decompressedSize, 0)
                    case EntryHeader.Blob => stats.addObjectWithChainLength(ObjectKind.Blob, e.decompressedSize, 0)
                    case EntryHeader.Tag => stats.addObjectWithChainLength(ObjectKind.Tag, e.decompressedSize, 0)
                    case EntryHeader.OfsDelta(_) =>
                        let chainLen = countDeltaChainLength(dataFile, e, offsetOpt.getOrThrow())
                        let baseKind = resolveBaseKind(dataFile, e, offsetOpt.getOrThrow())
                        if (baseKind.isSome()) {
                            stats.addObjectWithChainLength(baseKind.getOrThrow(), e.decompressedSize, chainLen)
                        }
                    case EntryHeader.RefDelta(_) =>
                        let chainLen = countDeltaChainLength(dataFile, e, offsetOpt.getOrThrow())
                        let baseKind = resolveBaseKind(dataFile, e, offsetOpt.getOrThrow())
                        if (baseKind.isSome()) {
                            stats.addObjectWithChainLength(baseKind.getOrThrow(), e.decompressedSize, chainLen)
                        }
                }

                if (options.check.objectChecksum()) {
                    if (version == IndexVersion.V2) {
                        let expectedCrc = crc32AtIndex(entryIdx)
                        if (expectedCrc.isSome()) {
                            let actualCrc = dataFile.entryCrc32(offsetOpt.getOrThrow(), hdrSize + compSize)
                            if (actualCrc != expectedCrc.getOrThrow()) {
                                return None
                            }
                        }
                    }
                }
            }
            i += 1
        }
        Some(stats)
    }

    func countDeltaChainLength(dataFile: DataFile, entry: Entry, packOffset: Int64): Int64 {
        var len: Int64 = 0
        var currentHeader = entry.header
        var currentOffset = packOffset
        while (true) {
            match (currentHeader) {
                case EntryHeader.OfsDelta(baseDist) =>
                    len += 1
                    let baseOffset = currentOffset - baseDist
                    if (baseOffset < 12) {
                        break
                    }
                    let baseEntry = dataFile.entry(baseOffset)
                    if (baseEntry.isErr()) {
                        break
                    }
                    currentHeader = baseEntry.unwrap().header
                    currentOffset = baseOffset
                case EntryHeader.RefDelta(_) =>
                    len += 1
                    break
                case _ => break
            }
        }
        len
    }

    func resolveBaseKind(dataFile: DataFile, entry: Entry, packOffset: Int64): ?ObjectKind {
        var currentHeader = entry.header
        var currentOffset = packOffset
        var result: ?ObjectKind = None
        var done = false
        while (!done) {
            match (currentHeader) {
                case EntryHeader.OfsDelta(baseDist) =>
                    let baseOffset = currentOffset - baseDist
                    if (baseOffset < 12) {
                        done = true
                    } else {
                        let baseEntry = dataFile.entry(baseOffset)
                        if (baseEntry.isErr()) {
                            done = true
                        } else {
                            currentHeader = baseEntry.unwrap().header
                            currentOffset = baseOffset
                        }
                    }
                case EntryHeader.RefDelta(_) => done = true
                case _ =>
                    result = currentHeader.asKind()
                    done = true
            }
        }
        result
    }
}

public func computeFanout(firstBytes: Array<Byte>, totalLen: Int64): Array<Int64> {
    var fanOut = Array<Int64>(256, repeat: 0)
    for (byte in 0..256) {
        var count: Int64 = 0
        var j: Int64 = 0
        while (j < totalLen && j < firstBytes.size) {
            if ((Int64(firstBytes[j]) & 0xFF) <= byte) {
                count += 1
            }
            j += 1
        }
        if (byte == 255) {
            fanOut[byte] = totalLen
        } else {
            fanOut[byte] = count
        }
    }
    fanOut
}

public enum VerifyMode {
    | HashCrc32
    | HashCrc32Decode
    | HashCrc32DecodeEncode
}

extend VerifyMode <: Equatable<VerifyMode> {
    public operator func ==(other: VerifyMode): Bool {
        match (this) {
            case VerifyMode.HashCrc32 => match (other) {
                case VerifyMode.HashCrc32 => true
                case _ => false
            }
            case VerifyMode.HashCrc32Decode => match (other) {
                case VerifyMode.HashCrc32Decode => true
                case _ => false
            }
            case VerifyMode.HashCrc32DecodeEncode => match (other) {
                case VerifyMode.HashCrc32DecodeEncode => true
                case _ => false
            }
        }
    }
    public operator func !=(other: VerifyMode): Bool {
        !(this == other)
    }
}

public enum TraverseAlgorithm {
    | DeltaTreeLookup
    | Lookup
}

extend TraverseAlgorithm <: Equatable<TraverseAlgorithm> {
    public operator func ==(other: TraverseAlgorithm): Bool {
        match (this) {
            case TraverseAlgorithm.DeltaTreeLookup => match (other) {
                case TraverseAlgorithm.DeltaTreeLookup => true
                case _ => false
            }
            case TraverseAlgorithm.Lookup => match (other) {
                case TraverseAlgorithm.Lookup => true
                case _ => false
            }
        }
    }
    public operator func !=(other: TraverseAlgorithm): Bool {
        !(this == other)
    }
}

public enum SafetyCheck {
    | SkipFileChecksumVerification
    | SkipFileAndObjectChecksumVerification
    | SkipFileAndObjectChecksumVerificationAndNoAbortOnDecodeError
    | All
}

extend SafetyCheck <: Equatable<SafetyCheck> {
    public operator func ==(other: SafetyCheck): Bool {
        match (this) {
            case SafetyCheck.SkipFileChecksumVerification => match (other) {
                case SafetyCheck.SkipFileChecksumVerification => true
                case _ => false
            }
            case SafetyCheck.SkipFileAndObjectChecksumVerification => match (other) {
                case SafetyCheck.SkipFileAndObjectChecksumVerification => true
                case _ => false
            }
            case SafetyCheck.SkipFileAndObjectChecksumVerificationAndNoAbortOnDecodeError => match (other) {
                case SafetyCheck.SkipFileAndObjectChecksumVerificationAndNoAbortOnDecodeError => true
                case _ => false
            }
            case SafetyCheck.All => match (other) {
                case SafetyCheck.All => true
                case _ => false
            }
        }
    }
    public operator func !=(other: SafetyCheck): Bool {
        !(this == other)
    }
}

extend SafetyCheck {
    public func fileChecksum(): Bool {
        match (this) {
            case SafetyCheck.All => true
            case _ => false
        }
    }

    public func objectChecksum(): Bool {
        match (this) {
            case SafetyCheck.All => true
            case SafetyCheck.SkipFileChecksumVerification => true
            case _ => false
        }
    }

    public func fatalDecodeError(): Bool {
        match (this) {
            case SafetyCheck.SkipFileAndObjectChecksumVerificationAndNoAbortOnDecodeError => false
            case _ => true
        }
    }
}

// 对齐 Rust: index::verify::integrity::Outcome + Error
// 索引完整性校验结果
public enum IndexVerifyResult {
    | Ok(IntegrityOutcome)
    | FanError(Int64)
    | ChecksumMismatch
    | Crc32Mismatch(Int64, ObjectId)
    | ObjectDecodeError(Int64, ObjectId, String)
}

public class TraverseStatistics {
    public var totalCompressedEntriesSize: Int64
    public var totalDecompressedEntriesSize: Int64
    public var totalObjectSize: Int64
    public var packSize: Int64
    public var numCommits: Int64
    public var numTrees: Int64
    public var numTags: Int64
    public var numBlobs: Int64
    public var objectsPerChainLength: TreeMap<Int64, Int64>

    public init() {
        this.totalCompressedEntriesSize = 0
        this.totalDecompressedEntriesSize = 0
        this.totalObjectSize = 0
        this.packSize = 0
        this.numCommits = 0
        this.numTrees = 0
        this.numTags = 0
        this.numBlobs = 0
        this.objectsPerChainLength = TreeMap<Int64, Int64>()
    }

    public func addObject(kind: ObjectKind, decompressedSize: Int64): Unit {
        addObjectWithChainLength(kind, decompressedSize, 0)
    }

    public func addObjectWithChainLength(kind: ObjectKind, decompressedSize: Int64, chainLength: Int64): Unit {
        totalObjectSize += decompressedSize
        totalDecompressedEntriesSize += decompressedSize
        let prev = objectsPerChainLength.get(chainLength)
        if (prev.isSome()) {
            objectsPerChainLength.add(chainLength, prev.getOrThrow() + 1)
        } else {
            objectsPerChainLength.add(chainLength, 1)
        }
        match (kind) {
            case ObjectKind.Commit => numCommits += 1
            case ObjectKind.Tree => numTrees += 1
            case ObjectKind.Blob => numBlobs += 1
            case ObjectKind.Tag => numTags += 1
        }
    }

    public func addCompressedSize(size: Int64): Unit {
        totalCompressedEntriesSize += size
    }

    public func totalObjects(): Int64 {
        numCommits + numTrees + numTags + numBlobs
    }
}

public class TraverseOptions {
    public var traversal: TraverseAlgorithm
    public var threadLimit: ?Int64
    public var check: SafetyCheck
    public var allocLimitBytes: ?Int64

    public init() {
        this.traversal = TraverseAlgorithm.DeltaTreeLookup
        this.threadLimit = None
        this.check = SafetyCheck.All
        this.allocLimitBytes = None
    }
}

public class IntegrityOutcome {
    public var actualIndexChecksum: ObjectId
    public var packTraverseStatistics: ?TraverseStatistics

    public init(actualIndexChecksum: ObjectId, packTraverseStatistics: ?TraverseStatistics) {
        this.actualIndexChecksum = actualIndexChecksum
        this.packTraverseStatistics = packTraverseStatistics
    }
}

func readFanoutTable(data: Array<Byte>, start: Int64): Array<Int64> {
    var fan = Array<Int64>(256, repeat: 0)
    if (start + FAN_LEN * N32_SIZE > data.size) {
        return fan
    }
    var i: Int64 = 0
    while (i < FAN_LEN) {
        fan[i] = readU32Idx(data, start + i * N32_SIZE)
        i += 1
    }
    fan
}

func fanIsMonotonicallyIncreasing(fan: Array<Int64>): Bool {
    var i: Int64 = 1
    while (i < fan.size) {
        if (fan[i] < fan[i - 1]) {
            return false
        }
        i += 1
    }
    true
}

func validateIndexSize(data: Array<Byte>, version: IndexVersion, numObjects: Int64, hashLen: Int64): Bool {
    let footerSize = hashLen * 2
    let n = numObjects
    if (version == IndexVersion.V1) {
        let expected = FAN_LEN * N32_SIZE + n * (N32_SIZE + hashLen) + footerSize
        return data.size == expected
    }
    let v2HeaderSize = V2_HEADER_SIZE
    let oidBytes = n * hashLen
    let crc32Bytes = n * N32_SIZE
    let offset32Start = v2HeaderSize + oidBytes + crc32Bytes
    let offset32End = offset32Start + n * N32_SIZE
    if (offset32End > data.size) {
        return false
    }
    var largeOffsetCount: Int64 = 0
    var maxLargeOffsetIndex: Int64 = 0
    var i: Int64 = 0
    while (i < n) {
        let pos = offset32Start + i * N32_SIZE
        if (pos + N32_SIZE <= data.size) {
            let ofs32 = readU32Idx(data, pos)
            if ((ofs32 & N32_HIGH_BIT) == N32_HIGH_BIT) {
                let idx64 = ofs32 ^ N32_HIGH_BIT
                largeOffsetCount += 1
                if (idx64 > maxLargeOffsetIndex) {
                    maxLargeOffsetIndex = idx64
                }
            }
        }
        i += 1
    }
    if (largeOffsetCount > 0 && maxLargeOffsetIndex >= largeOffsetCount) {
        return false
    }
    let largeOffsetBytes = largeOffsetCount * N64_SIZE
    let expected = v2HeaderSize + oidBytes + crc32Bytes + n * N32_SIZE + largeOffsetBytes + footerSize
    data.size == expected
}

func readU32Idx(data: Array<Byte>, offset: Int64): Int64 {
    if (offset + 4 > data.size) {
        return 0
    }
    (Int64(data[offset]) << 24) | (Int64(data[offset + 1]) << 16) | (Int64(data[offset + 2]) << 8) | Int64(data[offset +
            3])
}

// 兼容旧接口
func readU32(data: Array<Byte>, offset: Int64): Int64 {
    readU32Idx(data, offset)
}

func readU64Idx(data: Array<Byte>, offset: Int64): Int64 {
    if (offset + 8 > data.size) {
        return 0
    }
    (Int64(data[offset]) << 56) | (Int64(data[offset + 1]) << 48) | (Int64(data[offset + 2]) << 40) | (Int64(data[offset +
            3]) << 32) | (Int64(data[offset + 4]) << 24) | (Int64(data[offset + 5]) << 16) | (Int64(data[offset + 6]) <<
        8) | Int64(data[offset + 7])
}

func sliceIdxBytes(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end && i < data.size) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

func compareOid(a: ObjectId, b: ObjectId): Int64 {
    let len = if (a.bytes.size < b.bytes.size) {
        a.bytes.size
    } else {
        b.bytes.size
    }
    for (i in 0..len) {
        if (a.bytes[i] != b.bytes[i]) {
            return Int64(a.bytes[i]) - Int64(b.bytes[i])
        }
    }
    Int64(a.bytes.size) - Int64(b.bytes.size)
}

func comparePrefixOid(prefix: Prefix, oid: ObjectId): Int64 {
    let byteLen = (prefix.hexLen + 1) / 2
    let cmpLen = if (byteLen < oid.bytes.size) {
        byteLen
    } else {
        oid.bytes.size
    }
    for (i in 0..cmpLen) {
        if (prefix.id.bytes[i] != oid.bytes[i]) {
            return Int64(prefix.id.bytes[i]) - Int64(oid.bytes[i])
        }
    }
    0
}

func indexHashLenBytes(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 20
        case HashKind.Sha256 => 32
    }
}

func hashKindLenInHexPack(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 40
        case HashKind.Sha256 => 64
    }
}
