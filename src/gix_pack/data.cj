// 文件：data.cj
// 用途：全量对齐 Rust gitoxide gix-pack data 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/data/{mod,header,delta,entry,file}.rs
// 关键类型：Version, EntryHeader, Entry, EntryLocation, DataFile
//           ResolvedBase, DecodeHeaderOutcome, DecodeEntryOutcome

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_zlib.*
import gitoxide.gix_utils.*
import crc32fast.*
import std.fs.*
import std.collection.*

// ============================================================
// data::Version — 对齐 gix-pack/src/data/mod.rs
// pack 数据文件支持的版本
// ============================================================

public enum Version {
    | V2
    | V3
}

extend Version <: Equatable<Version> {
    public operator func ==(other: Version): Bool {
        match (this) {
            case Version.V2 => match (other) {
                case Version.V2 => true
                case _ => false
            }
            case Version.V3 => match (other) {
                case Version.V3 => true
                case _ => false
            }
        }
    }

    public operator func !=(other: Version): Bool {
        !(this == other)
    }
}

// ============================================================
// data::entry::Header — 对齐 gix-pack/src/data/entry/header.rs
// pack 条目头部，标识存储对象的类型
// ============================================================

public enum EntryHeader {
    | Commit
    | Tree
    | Blob
    | Tag
    | OfsDelta(Int64)
    | RefDelta(ObjectId)
}

extend EntryHeader <: Equatable<EntryHeader> {
    public operator func ==(other: EntryHeader): Bool {
        match (this) {
            case EntryHeader.Commit => match (other) {
                case EntryHeader.Commit => true
                case _ => false
            }
            case EntryHeader.Tree => match (other) {
                case EntryHeader.Tree => true
                case _ => false
            }
            case EntryHeader.Blob => match (other) {
                case EntryHeader.Blob => true
                case _ => false
            }
            case EntryHeader.Tag => match (other) {
                case EntryHeader.Tag => true
                case _ => false
            }
            case EntryHeader.OfsDelta(d1) => match (other) {
                case EntryHeader.OfsDelta(d2) => d1 == d2
                case _ => false
            }
            case EntryHeader.RefDelta(id1) => match (other) {
                case EntryHeader.RefDelta(id2) => id1.equals(id2)
                case _ => false
            }
        }
    }

    public operator func !=(other: EntryHeader): Bool {
        !(this == other)
    }
}

extend EntryHeader {
    // 将头部类型转换为 ObjectKind（delta 类型返回 None）
    // 对齐 Rust: Header::as_kind()
    public func asKind(): ?ObjectKind {
        match (this) {
            case EntryHeader.Tree => Some(ObjectKind.Tree)
            case EntryHeader.Blob => Some(ObjectKind.Blob)
            case EntryHeader.Commit => Some(ObjectKind.Commit)
            case EntryHeader.Tag => Some(ObjectKind.Tag)
            case EntryHeader.OfsDelta(_) => None
            case EntryHeader.RefDelta(_) => None
        }
    }

    // 返回 pack 内部类型编码
    // 对齐 Rust: Header::as_type_id()
    public func asTypeId(): Int64 {
        match (this) {
            case EntryHeader.Commit => 1
            case EntryHeader.Tree => 2
            case EntryHeader.Blob => 3
            case EntryHeader.Tag => 4
            case EntryHeader.OfsDelta(_) => 6
            case EntryHeader.RefDelta(_) => 7
        }
    }

    // 是否为 delta 对象
    // 对齐 Rust: Header::is_delta()
    public func isDelta(): Bool {
        match (this) {
            case EntryHeader.OfsDelta(_) => true
            case EntryHeader.RefDelta(_) => true
            case _ => false
        }
    }

    // 是否为基础对象（非 delta）
    // 对齐 Rust: Header::is_base()
    public func isBase(): Bool {
        !isDelta()
    }

    // 计算头部在 pack 中的规范编码字节数
    // 对齐 Rust: Header::size(decompressed_size)
    public func headerSize(decompressedSize: Int64): Int64 {
        var size = decompressedSize
        var len: Int64 = 1
        var c: Int64 = (asTypeId() << 4) | (size & 0x0F)
        size = size >> 4
        while (size != 0) {
            len += 1
            size = size >> 7
        }
        match (this) {
            case EntryHeader.RefDelta(id) => len + id.bytes.size
            case EntryHeader.OfsDelta(_) => len + leb64EncodedLen(this.getOfsDeltaDistance())
            case _ => len
        }
    }

    // 获取 OfsDelta 的 base_distance，非 OfsDelta 返回 0
    public func getOfsDeltaDistance(): Int64 {
        match (this) {
            case EntryHeader.OfsDelta(d) => d
            case _ => 0
        }
    }

    public func getRefDeltaId(): ?ObjectId {
        match (this) {
            case EntryHeader.RefDelta(id) => Some(id)
            case _ => None
        }
    }

    // 安全计算基础对象的 pack 偏移量
    // 对齐 Rust: Header::verified_base_pack_offset()
    public static func verifiedBasePackOffset(packOffset: Int64, distance: Int64): ?Int64 {
        if (distance == 0) {
            return None
        }
        if (packOffset < distance) {
            return None
        }
        Some(packOffset - distance)
    }
}

// ============================================================
// data::Entry — 对齐 gix-pack/src/data/mod.rs Entry 结构
// pack 数据文件中的条目
// ============================================================

public class Entry {
    // 条目头部
    public var header: EntryHeader
    // 解压后的大小
    public var decompressedSize: Int64
    // 压缩数据在 pack 中的绝对偏移量（紧跟头部之后）
    public var dataOffset: Int64
    // 编码头部占用的实际字节数（0 表示未知，回退到规范长度）
    public var encodedHeaderSize: Int64

    public init(header: EntryHeader, decompressedSize: Int64, dataOffset: Int64, encodedHeaderSize: Int64) {
        this.header = header
        this.decompressedSize = decompressedSize
        this.dataOffset = dataOffset
        this.encodedHeaderSize = encodedHeaderSize
    }

    public static func packEntry(header: EntryHeader, decompressedSize: Int64, dataOffset: Int64,
        encodedHeaderSize: Int64): Entry {
        Entry(header, decompressedSize, dataOffset, encodedHeaderSize)
    }

    // 条目在 pack 中的起始偏移量
    // 对齐 Rust: Entry::pack_offset()
    public func packOffset(): Int64 {
        dataOffset - headerSize()
    }

    // 头部占用的字节数
    // 对齐 Rust: Entry::header_size()
    public func headerSize(): Int64 {
        if (encodedHeaderSize == 0) {
            header.headerSize(decompressedSize)
        } else {
            encodedHeaderSize
        }
    }

    // 安全计算基础对象的 pack 偏移量
    // 对齐 Rust: Entry::checked_base_pack_offset()
    public func checkedBasePackOffset(distance: Int64): ?Int64 {
        EntryHeader.verifiedBasePackOffset(packOffset(), distance)
    }

    // 计算基础对象的 pack 偏移量
    // 对齐 Rust: Entry::base_pack_offset()
    public func basePackOffset(distance: Int64): ?Int64 {
        checkedBasePackOffset(distance)
    }
}

// ============================================================
// data::entry::Location — 对齐 gix-pack/src/data/entry/mod.rs
// 唯一标识 pack bundle 中条目的位置
// ============================================================

public class EntryLocation {
    // 包含此对象的 pack 的 ID
    public var packId: Int64
    // 条目在磁盘上的字节大小
    public var entrySize: Int64
    // 条目在 pack 中的起始偏移量
    public var packOffset: Int64

    public init(packId: Int64, entrySize: Int64, packOffset: Int64) {
        this.packId = packId
        this.entrySize = entrySize
        this.packOffset = packOffset
    }

    // 计算条目范围
    public func entryRange(): (Int64, Int64) {
        (packOffset, packOffset + entrySize)
    }
}

// ============================================================
// data::header — 对齐 gix-pack/src/data/header.rs
// pack 文件头部编解码（12 字节：PACK + 版本 + 对象数）
// ============================================================

// 解码 pack 文件头部 12 字节
// 对齐 Rust: data::header::decode() -> Result<(Version, u32), header::decode::Error>
public func decodePackHeader(data: Array<Byte>): PackResult<(Version, Int64)> {
    if (data.size < 12) {
        return PackResult.PackErr(
            PackError(PackErrorKind.InvalidData("pack header too short: ${data.size} bytes, need 12")))
    }
    // 检查 PACK 签名
    if (data[0] != UInt8(0x50) || data[1] != UInt8(0x41) || data[2] != UInt8(0x43) || data[3] != UInt8(0x4B)) {
        return PackResult.PackErr(PackError(PackErrorKind.InvalidData("invalid PACK signature")))
    }
    let versionVal = (Int64(data[4]) << 24) | (Int64(data[5]) << 16) | (Int64(data[6]) << 8) | Int64(data[7])
    let version = match (versionVal) {
        case 2 => Version.V2
        case 3 => Version.V3
        case _ => return PackResult.PackErr(
            PackError(PackErrorKind.InvalidData("unsupported pack version: ${versionVal}")))
    }
    let numObjects = (Int64(data[8]) << 24) | (Int64(data[9]) << 16) | (Int64(data[10]) << 8) | Int64(data[11])
    PackResult.PackOk((version, numObjects))
}

// 编码 pack 文件头部 12 字节
// 对齐 Rust: data::header::encode()
public func encodePackHeader(version: Version, numObjects: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    // PACK 签名
    result.add(UInt8(0x50))
    result.add(UInt8(0x41))
    result.add(UInt8(0x43))
    result.add(UInt8(0x4B))
    // 版本号
    let v = match (version) {
        case Version.V2 => 2
        case Version.V3 => 3
    }
    result.add(UInt8(Int64((v >> 24)) & 0xFF))
    result.add(UInt8(Int64((v >> 16)) & 0xFF))
    result.add(UInt8(Int64((v >> 8)) & 0xFF))
    result.add(UInt8(Int64(v & 0xFF)))
    // 对象数量
    result.add(UInt8(Int64((numObjects >> 24)) & 0xFF))
    result.add(UInt8(Int64((numObjects >> 16)) & 0xFF))
    result.add(UInt8(Int64((numObjects >> 8)) & 0xFF))
    result.add(UInt8(Int64(numObjects & 0xFF)))
    result.toArray()
}

// ============================================================
// data::entry::decode — 对齐 gix-pack/src/data/entry/decode.rs
// 从字节数据解码 pack 条目
// ============================================================

// 从字节数据解码 Entry
// 对齐 Rust: Entry::from_bytes() -> Result<Entry, entry::decode::Error>
public func entryFromBytes(data: Array<Byte>, packOffset: Int64, hashKind: HashKind): PackResult<Entry> {
    if (data.size == 0) {
        return PackResult.PackErr(PackError(PackErrorKind.EntryDecode(EntryDecodeError("empty data"))))
    }
    let headerResult = parsePackEntryHeader(data)
    if (headerResult.isNone()) {
        return PackResult.PackErr(
            PackError(PackErrorKind.EntryDecode(EntryDecodeError("failed to parse pack entry header"))))
    }
    let (typeId, size, consumed) = headerResult.getOrThrow()
    let hashLen = hashKindLenBytes(hashKind)

    var header: ?EntryHeader = None
    var extraConsumed: Int64 = 0

    match (typeId) {
        case 6 =>
            let lebResult = parseLeb64(data, consumed)
            if (lebResult.isNone()) {
                return PackResult.PackErr(
                    PackError(PackErrorKind.EntryDecode(EntryDecodeError("failed to parse OfsDelta distance"))))
            }
            let (distance, lebBytes) = lebResult.getOrThrow()
            header = Some(EntryHeader.OfsDelta(distance))
            extraConsumed = lebBytes
        case 7 =>
            if (consumed + hashLen > data.size) {
                return PackResult.PackErr(
                    PackError(PackErrorKind.EntryDecode(EntryDecodeError("RefDelta data truncated"))))
            }
            let oidBytes = sliceBytesPackData(data, consumed, consumed + hashLen)
            header = Some(EntryHeader.RefDelta(ObjectId(oidBytes, hashKind)))
            extraConsumed = hashLen
        case 1 =>
            header = Some(EntryHeader.Commit)
            extraConsumed = 0
        case 2 =>
            header = Some(EntryHeader.Tree)
            extraConsumed = 0
        case 3 =>
            header = Some(EntryHeader.Blob)
            extraConsumed = 0
        case 4 =>
            header = Some(EntryHeader.Tag)
            extraConsumed = 0
        case _ => return PackResult.PackErr(
            PackError(PackErrorKind.EntryDecode(EntryDecodeError("unsupported object type: ${typeId}"))))
    }

    if (header.isNone()) {
        return PackResult.PackErr(
            PackError(PackErrorKind.EntryDecode(EntryDecodeError("header is None after parsing"))))
    }

    let totalConsumed = consumed + extraConsumed
    PackResult.PackOk(Entry(header.getOrThrow(), size, packOffset + totalConsumed, totalConsumed))
}

// 解析 pack 条目头部变长编码
// 对齐 Rust: parse_header_info()
func parsePackEntryHeader(data: Array<Byte>): ?(Int64, Int64, Int64) {
    if (data.size == 0) {
        return None
    }
    var c = Int64(data[0])
    var i: Int64 = 1
    let typeId = (c >> 4) & 0x07
    var size = c & 0x0F
    var shift: Int64 = 4
    while ((c & 0x80) != 0) {
        if (i >= data.size) {
            return None
        }
        c = Int64(data[i])
        i += 1
        size = size | ((c & 0x7F) << shift)
        shift += 7
    }
    Some((typeId, size, i))
}

// 解析 OFS_DELTA 使用的 LEB128 编码的距离值
// 对齐 Rust: parse_leb64()
func parseLeb64(data: Array<Byte>, start: Int64): ?(Int64, Int64) {
    if (start >= data.size) {
        return None
    }
    var i = start
    var c = Int64(data[i])
    i += 1
    var value = c & 0x7F
    while ((c & 0x80) != 0) {
        if (i >= data.size) {
            return None
        }
        c = Int64(data[i])
        i += 1
        value = (value + 1) << 7
        value = value + (c & 0x7F)
    }
    Some((value, i - start))
}

// 计算 leb64 编码后的字节数
func leb64EncodedLen(n: Int64): Int64 {
    if (n == 0) {
        return 1
    }
    var len: Int64 = 0
    var v = n
    v = v >> 7
    len += 1
    while (v != 0) {
        v = v - 1
        v = v >> 7
        len += 1
    }
    len
}

// 编码 leb64（OfsDelta base_distance）
// 对齐 Rust: leb64_encode()
public func leb64Encode(n: Int64): Array<Byte> {
    if (n == 0) {
        return [UInt8(0)]
    }
    var buf = Array<Int64>(10, repeat: 0)
    var bytesWritten: Int64 = 1
    buf[9] = n & 0x7F
    var v = n
    var idx = 8
    while (idx >= 0) {
        v = v >> 7
        if (v == 0) {
            break
        }
        v = v - 1
        buf[idx] = 0x80 | (v & 0x7F)
        bytesWritten += 1
        idx -= 1
    }
    let start = 10 - bytesWritten
    var result = ArrayList<Byte>()
    var j = start
    while (j < 10) {
        result.add(UInt8(buf[j]))
        j += 1
    }
    result.toArray()
}

// ============================================================
// data::delta — 对齐 gix-pack/src/data/delta.rs
// delta 头部大小解码
// ============================================================

// 解码 delta 头部中的大小值（变长编码）
// 对齐 Rust: delta::decode_header_size()
public func decodeDeltaHeaderSize(data: Array<Byte>): ?(Int64, Int64) {
    var shift: Int64 = 0
    var size: Int64 = 0
    var consumed: Int64 = 0
    for (cmd in data) {
        consumed += 1
        size = size | ((Int64(cmd) & 0x7F) << shift)
        shift += 7
        if ((Int64(cmd) & 0x80) == 0) {
            return Some((size, consumed))
        }
    }
    None
}

// ============================================================
// data::file — 对齐 gix-pack/src/data/file/
// pack 数据文件
// ============================================================

// 解码头部时的解析结果
// 对齐 gix-pack/src/data/file/decode/header.rs ResolvedBase
public enum ResolvedBase {
    | InPack(Entry)
    | OutOfPack(ObjectKind, ?Int64)
}

extend ResolvedBase {
    public func isInPack(): Bool {
        match (this) {
            case ResolvedBase.InPack(_) => true
            case _ => false
        }
    }

    public func getInPackEntry(): Entry {
        match (this) {
            case ResolvedBase.InPack(e) => e
            case _ => Entry(EntryHeader.Commit, 0, 0, 0)
        }
    }

    public func getOutOfPackKind(): ObjectKind {
        match (this) {
            case ResolvedBase.OutOfPack(k, _) => k
            case _ => ObjectKind.Blob
        }
    }

    public func getOutOfPackNumDeltas(): Int64 {
        match (this) {
            case ResolvedBase.OutOfPack(_, Some(d)) => d
            case _ => 0
        }
    }
}

// 解码头部的统计信息
// 对齐 gix-pack/src/data/file/decode/header.rs Outcome
public class DecodeHeaderOutcome {
    // 解析后的对象类型
    public var kind: ObjectKind
    // 解压后的大小
    public var objectSize: Int64
    // delta 链中的 delta 数量
    public var numDeltas: Int64

    public init(kind: ObjectKind, objectSize: Int64, numDeltas: Int64) {
        this.kind = kind
        this.objectSize = objectSize
        this.numDeltas = numDeltas
    }
}

// 解压条目的结果
// 对齐 Rust: decompress_entry_from_data_offset() 返回的 (consumed_in, data)
public class DecompressResult {
    public var data: Array<Byte>
    public var compressedSize: Int64

    public init(data: Array<Byte>, compressedSize: Int64) {
        this.data = data
        this.compressedSize = compressedSize
    }
}

// 解码条目的统计信息
// 对齐 gix-pack/src/data/file/decode/entry.rs Outcome
public class DecodeEntryOutcome {
    // 解析后的对象类型
    public var kind: ObjectKind
    // delta 链中的 delta 数量
    public var numDeltas: Int64
    // delta 链中所有条目的总解压大小
    public var decompressedSize: Int64
    // delta 链中所有条目的总压缩大小
    public var compressedSize: Int64
    // 解码后的对象大小
    public var objectSize: Int64

    public init(kind: ObjectKind, numDeltas: Int64, decompressedSize: Int64, compressedSize: Int64, objectSize: Int64) {
        this.kind = kind
        this.numDeltas = numDeltas
        this.decompressedSize = decompressedSize
        this.compressedSize = compressedSize
        this.objectSize = objectSize
    }
}

// pack 数据文件
// 对齐 Rust: data::File<T>
public class DataFile {
    // 文件路径
    public var path: String
    // 哈希算法类型
    public var hashKind: HashKind
    // pack 版本
    public var version: Version
    // 文件中的对象数量
    public var numObjects: Int64
    // 唯一标识此 pack 的 ID（由对象存储分配）
    public var id: Int64
    // 文件数据缓存
    public var data: Array<Byte>
    // 最大单次分配限制（0 表示无限制）
    public var allocLimitBytes: Int64

    // 构造函数
    public init(path: String, hashKind: HashKind) {
        this.path = path
        this.hashKind = hashKind
        this.version = Version.V2
        this.numObjects = 0
        this.id = 0
        this.data = []
        this.allocLimitBytes = 0
    }

    // 完整构造函数
    public init(path: String, hashKind: HashKind, version: Version, numObjects: Int64, id: Int64, data: Array<Byte>,
        allocLimitBytes: Int64) {
        this.path = path
        this.hashKind = hashKind
        this.version = version
        this.numObjects = numObjects
        this.id = id
        this.data = data
        this.allocLimitBytes = allocLimitBytes
    }

    // 打开指定路径的 pack 数据文件
    // 对齐 Rust: File::at() -> Result<File, Error>
    public static func at(path: String, hashKind: HashKind): PackResult<DataFile> {
        if (!exists(path)) {
            return PackResult.PackErr(PackError(PackErrorKind.Io("file not found: ${path}")))
        }
        try {
            let bytes = readFileBytes(path)
            DataFile.fromData(bytes, path, hashKind)
        } catch (e: Exception) {
            PackResult.PackErr(PackError(PackErrorKind.Io("failed to read pack file: ${e.message}")))
        }
    }

    // 从字节数据构造 DataFile
    // 对齐 Rust: File::from_data() -> Result<File, Error>
    public static func fromData(data: Array<Byte>, path: String, hashKind: HashKind): PackResult<DataFile> {
        let hashLen = hashKindLenBytes(hashKind)
        if (data.size < 12 + hashLen) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("pack data too short: ${data.size} bytes")))
        }
        let headerResult = decodePackHeader(data)
        if (headerResult.isErr()) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("invalid pack header")))
        }
        let (version, numObjects) = headerResult.unwrap()
        let id = crc32OfPath(path)
        PackResult.PackOk(DataFile(path, hashKind, version, numObjects, id, data, 0))
    }

    // 数据长度
    public func dataLen(): Int64 {
        data.size
    }

    // 哈希算法类型
    public func objectHash(): HashKind {
        hashKind
    }

    // pack 数据结束位置（trailing hash 之前）
    // 对齐 Rust: File::pack_end()
    public func packEnd(): Int64 {
        data.size - hashKindLenBytes(hashKind)
    }

    // 获取指定范围的条目切片
    // 对齐 Rust: File::entry_slice()
    public func entrySlice(start: Int64, end: Int64): ?Array<Byte> {
        if (start < 0 || end < 0 || end > data.size || start > end) {
            return None
        }
        Some(sliceBytesPackData(data, start, end))
    }

    // 计算 CRC32
    // 对齐 Rust: File::entry_crc32()
    public func entryCrc32(packOffset: Int64, size: Int64): Int64 {
        if (packOffset < 0 || packOffset + size > data.size) {
            return 0
        }
        crc32OfBytes(sliceBytesPackData(data, packOffset, packOffset + size))
    }

    // 获取尾部校验和
    // 对齐 Rust: File::checksum()
    public func checksum(): ObjectId {
        let hashLen = hashKindLenBytes(hashKind)
        let start = data.size - hashLen
        var checksumBytes = ArrayList<Byte>()
        for (i in start..data.size) {
            checksumBytes.add(data[i])
        }
        ObjectId(checksumBytes.toArray(), hashKind)
    }

    // 验证 pack 文件的校验和
    // 对齐 Rust: File::verify_checksum()
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
        let hashLen = hashKindLenBytes(hashKind)
        if (data.size < hashLen) {
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
        let storedId = checksum()
        computedId.equals(storedId)
    }

    // 获取指定偏移量处的 Entry
    // 对齐 Rust: File::entry() -> Result<Entry, Error>
    public func entry(offset: Int64): PackResult<Entry> {
        if (offset < 0 || offset > data.size) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("pack offset out of range: ${offset}")))
        }
        entryFromBytes(sliceBytesPackData(data, offset, data.size), offset, hashKind)
    }

    // 从指定偏移量读取 pack 条目（兼容旧接口）
    public func readAtOffset(offset: Int64): ?PackEntry {
        let entryResult = entry(offset)
        if (entryResult.isErr()) {
            return None
        }
        let e = entryResult.unwrap()
        let kind = e.header.asKind()
        if (kind.isNone()) {
            try {
                let inflated = inflate(sliceBytesPackData(data, e.dataOffset, data.size))
                Some(PackEntry(None, inflated.data, offset))
            } catch (_: Exception) {
                None
            }
        } else {
            try {
                let inflated = inflate(sliceBytesPackData(data, e.dataOffset, data.size))
                Some(PackEntry(kind, inflated.data, offset))
            } catch (_: Exception) {
                None
            }
        }
    }

    // 解压指定条目
    // 对齐 Rust: File::decompress_entry() / decompress_entry_from_data_offset()
    // 返回解压数据及压缩数据的字节大小（zlib 流的 consumed 字节数）
    public func decompressEntry(entry: Entry): ?DecompressResult {
        if (entry.decompressedSize == 0) {
            // 对齐 Rust: 空 pack entry 直接返回空数据
            return Some(DecompressResult(Array<Byte>(), 0))
        }
        if (entry.dataOffset >= data.size) {
            return None
        }
        try {
            let inflated = inflate(sliceBytesPackData(data, entry.dataOffset, data.size))
            Some(DecompressResult(inflated.data, Int64(inflated.consumed)))
        } catch (_: Exception) {
            None
        }
    }

    // 解码条目头部信息（跟随 delta 链）
    // 对齐 Rust: File::decode_header()
    public func decodeHeader(startEntry: Entry, resolve: (ObjectId) -> ?ResolvedBase): ?DecodeHeaderOutcome {
        var currentEntry = startEntry
        var numDeltas: Int64 = 0
        var firstDeltaDecompressedSize: ?Int64 = None

        var loopCount: Int64 = 0
        while (loopCount < 100000) {
            loopCount += 1
            if (currentEntry.header.isDelta()) {
                numDeltas += 1
                if (firstDeltaDecompressedSize.isNone()) {
                    let deltaSize = decodeDeltaObjectSize(currentEntry)
                    if (deltaSize.isNone()) {
                        return None
                    }
                    firstDeltaDecompressedSize = Some(deltaSize.getOrThrow())
                }
                let isOfsDelta2 = match (currentEntry.header) {
                    case EntryHeader.OfsDelta(_) => true
                    case _ => false
                }
                if (isOfsDelta2) {
                    let baseDistance = currentEntry.header.getOfsDeltaDistance()
                    let baseOffset = EntryHeader.verifiedBasePackOffset(currentEntry.packOffset(), baseDistance)
                    if (baseOffset.isNone()) {
                        return None
                    }
                    let nextEntry = this.entry(baseOffset.getOrThrow())
                    if (nextEntry.isErr()) {
                        return None
                    }
                    currentEntry = nextEntry.unwrap()
                } else {
                    let baseId = currentEntry.header.getRefDeltaId()
                    if (baseId.isNone()) {
                        return None
                    }
                    let resolved = resolve(baseId.getOrThrow())
                    if (resolved.isNone()) {
                        return None
                    }
                    let rb = resolved.getOrThrow()
                    if (rb.isInPack()) {
                        currentEntry = rb.getInPackEntry()
                    } else {
                        let objSize = match (firstDeltaDecompressedSize) {
                            case Some(s) => s
                            case None => currentEntry.decompressedSize
                        }
                        let extraDeltas = rb.getOutOfPackNumDeltas()
                        return DecodeHeaderOutcome(rb.getOutOfPackKind(), objSize, extraDeltas + numDeltas)
                    }
                }
            } else {
                let objSize = match (firstDeltaDecompressedSize) {
                    case Some(s) => s
                    case None => currentEntry.decompressedSize
                }
                let kind = currentEntry.header.asKind()
                if (kind.isNone()) {
                    return None
                }
                return DecodeHeaderOutcome(kind.getOrThrow(), objSize, numDeltas)
            }
        }
        None
    }

    // 解码 delta 对象的结果大小
    func decodeDeltaObjectSize(entry: Entry): ?Int64 {
        try {
            let inflated = inflate(sliceBytesPackData(data, entry.dataOffset, data.size))
            let deltaData = inflated.data
            // 对齐 Rust: decode_delta_object_size — 验证解压大小与声明一致
            if (deltaData.size != entry.decompressedSize) {
                return None
            }
            let baseSizeResult = decodeDeltaHeaderSize(deltaData)
            if (baseSizeResult.isNone()) {
                return entry.decompressedSize
            }
            let (_, offset) = baseSizeResult.getOrThrow()
            let resultSizeResult = decodeDeltaHeaderSize(sliceBytesPackData(deltaData, offset, deltaData.size))
            if (resultSizeResult.isNone()) {
                return entry.decompressedSize
            }
            let (resultSize, _) = resultSizeResult.getOrThrow()
            resultSize
        } catch (_: Exception) {
            entry.decompressedSize
        }
    }

    // 解码条目（完整 delta 解析）
    // 对齐 Rust: File::decode_entry() → Outcome
    public func decodeEntry(entry: Entry, resolve: (ObjectId) -> ?ResolvedBase): ?DecodeEntryOutcome {
        if (entry.header.isDelta()) {
            return resolveDeltas(entry, resolve)
        }
        let decompressed = decompressEntry(entry)
        if (decompressed.isNone()) {
            return None
        }
        let dr = decompressed.getOrThrow()
        let kind = entry.header.asKind()
        if (kind.isNone()) {
            return None
        }
        // 对齐 Rust: pack entry decompressed size must match entry header
        if (dr.data.size != entry.decompressedSize) {
            return None
        }
        Some(DecodeEntryOutcome(kind.getOrThrow(), 0, entry.decompressedSize, dr.compressedSize, entry.decompressedSize))
    }

    public func decodeEntryData(entry: Entry, resolve: (ObjectId) -> ?ResolvedBase): ?(ObjectKind, Array<Byte>) {
        if (entry.header.isDelta()) {
            return resolveDeltasData(entry, resolve)
        }
        let decompressed = decompressEntry(entry)
        if (decompressed.isNone()) {
            return None
        }
        let dr = decompressed.getOrThrow()
        let kind = entry.header.asKind()
        if (kind.isNone()) {
            return None
        }
        if (dr.data.size != entry.decompressedSize) {
            return None
        }
        Some((kind.getOrThrow(), dr.data))
    }

    // 解析 delta 链
    // 对齐 Rust: resolve_deltas() → Outcome
    func resolveDeltas(entry: Entry, resolve: (ObjectId) -> ?ResolvedBase): ?DecodeEntryOutcome {
        var chain = ArrayList<Entry>()
        var cursor = entry
        var baseObjectKind: ?ObjectKind = None
        var consumedInput: Int64 = 0

        var loopCount: Int64 = 0
        while (loopCount < 100000) {
            loopCount += 1
            if (!cursor.header.isDelta()) {
                break
            }
            chain.add(cursor)
            let isOfsDelta = match (cursor.header) {
                case EntryHeader.OfsDelta(_) => true
                case _ => false
            }
            if (isOfsDelta) {
                let baseDistance = cursor.header.getOfsDeltaDistance()
                let baseOffset = EntryHeader.verifiedBasePackOffset(cursor.packOffset(), baseDistance)
                if (baseOffset.isNone()) {
                    return None
                }
                let nextEntry = this.entry(baseOffset.getOrThrow())
                if (nextEntry.isErr()) {
                    return None
                }
                cursor = nextEntry.unwrap()
            } else {
                let baseId = cursor.header.getRefDeltaId()
                if (baseId.isNone()) {
                    return None
                }
                let resolved = resolve(baseId.getOrThrow())
                if (resolved.isNone()) {
                    return None
                }
                let rb = resolved.getOrThrow()
                if (rb.isInPack()) {
                    cursor = rb.getInPackEntry()
                } else {
                    baseObjectKind = Some(rb.getOutOfPackKind())
                    break
                }
            }
        }

        var result: Array<Byte>
        var totalDecompressedSize: Int64 = 0
        if (baseObjectKind.isSome()) {
            return None
        } else {
            let kind = cursor.header.asKind()
            if (kind.isNone()) {
                return None
            }
            baseObjectKind = kind
            let baseDecompressed = decompressEntry(cursor)
            if (baseDecompressed.isNone()) {
                return None
            }
            let dr = baseDecompressed.getOrThrow()
            // 对齐 Rust: base decompressed size must match entry header
            if (dr.data.size != cursor.decompressedSize) {
                return None
            }
            result = dr.data
            totalDecompressedSize += cursor.decompressedSize
            consumedInput = dr.compressedSize
        }

        // 从最老到最新应用 delta
        var i = chain.size - 1
        while (i >= 0) {
            let deltaEntry = chain[i]
            let deltaDecompressed = decompressEntry(deltaEntry)
            if (deltaDecompressed.isNone()) {
                return None
            }
            let dr = deltaDecompressed.getOrThrow()
            let deltaData = dr.data
            // 对齐 Rust: 最后一个 delta（即输入 entry 自身）的 compressed_size 作为 consumed_input
            if (i == 0) {
                consumedInput = dr.compressedSize
            }
            totalDecompressedSize += deltaEntry.decompressedSize
            let delta = Delta.fromBytes(deltaData)
            if (delta.isNone()) {
                return None
            }
            let applied = delta.getOrThrow().apply(result)
            if (applied.isNone()) {
                return None
            }
            result = applied.getOrThrow()
            i -= 1
        }

        Some(
            DecodeEntryOutcome(baseObjectKind.getOrThrow(), Int64(chain.size), totalDecompressedSize, consumedInput,
                Int64(result.size)))
    }

    func resolveDeltasData(entry: Entry, resolve: (ObjectId) -> ?ResolvedBase): ?(ObjectKind, Array<Byte>) {
        var chain = ArrayList<Entry>()
        var cursor = entry
        var baseObjectKind: ?ObjectKind = None

        var loopCount: Int64 = 0
        while (loopCount < 100000) {
            loopCount += 1
            if (!cursor.header.isDelta()) {
                break
            }
            chain.add(cursor)
            let isOfsDelta = match (cursor.header) {
                case EntryHeader.OfsDelta(_) => true
                case _ => false
            }
            if (isOfsDelta) {
                let baseDistance = cursor.header.getOfsDeltaDistance()
                let baseOffset = EntryHeader.verifiedBasePackOffset(cursor.packOffset(), baseDistance)
                if (baseOffset.isNone()) {
                    return None
                }
                let nextEntry = this.entry(baseOffset.getOrThrow())
                if (nextEntry.isErr()) {
                    return None
                }
                cursor = nextEntry.unwrap()
            } else {
                let baseId = cursor.header.getRefDeltaId()
                if (baseId.isNone()) {
                    return None
                }
                let resolved = resolve(baseId.getOrThrow())
                if (resolved.isNone()) {
                    return None
                }
                let rb = resolved.getOrThrow()
                if (rb.isInPack()) {
                    cursor = rb.getInPackEntry()
                } else {
                    baseObjectKind = Some(rb.getOutOfPackKind())
                    break
                }
            }
        }

        var result: Array<Byte>
        if (baseObjectKind.isSome()) {
            return None
        } else {
            let kind = cursor.header.asKind()
            if (kind.isNone()) {
                return None
            }
            baseObjectKind = kind
            let baseDecompressed = decompressEntry(cursor)
            if (baseDecompressed.isNone()) {
                return None
            }
            let dr = baseDecompressed.getOrThrow()
            if (dr.data.size != cursor.decompressedSize) {
                return None
            }
            result = dr.data
        }

        var i = chain.size - 1
        while (i >= 0) {
            let deltaEntry = chain[i]
            let deltaDecompressed = decompressEntry(deltaEntry)
            if (deltaDecompressed.isNone()) {
                return None
            }
            let dr = deltaDecompressed.getOrThrow()
            let deltaData = dr.data
            let delta = Delta.fromBytes(deltaData)
            if (delta.isNone()) {
                return None
            }
            let applied = delta.getOrThrow().apply(result)
            if (applied.isNone()) {
                return None
            }
            result = applied.getOrThrow()
            i -= 1
        }

        Some((baseObjectKind.getOrThrow(), result))
    }

    // 设置分配限制
    // 对齐 Rust: File::with_alloc_limit_bytes()
    public func withAllocLimitBytes(limit: Int64): DataFile {
        allocLimitBytes = limit
        this
    }

    // 逐条目校验 pack 文件完整性
    // 遍历 pack 中所有条目
    // 对齐 Rust: gix-pack/src/index/access.rs sorted_offsets() + iter()
    // 从 pack 头部开始，逐条目解析，返回所有 Entry
    // 用于 gc/verify 等场景（无需索引文件）
    public func iter(): PackResult<ArrayList<Entry>> {
        var result = ArrayList<Entry>()
        let headerResult = decodePackHeader(data)
        if (headerResult.isErr()) {
            return PackResult.PackErr(headerResult.err().getOrThrow())
        }
        let (_, numObjects) = headerResult.unwrap()
        var offset: Int64 = 12
        let hashLen = hashKindLenBytes(hashKind)
        let endOffset = data.size - hashLen

        while (offset < endOffset) {
            let entryResult = entry(offset)
            if (entryResult.isErr()) {
                return PackResult.PackErr(entryResult.err().getOrThrow())
            }
            let e = entryResult.unwrap()
            result.add(e)
            // 对齐 Rust: decompress_entry_from_data_offset() 获取 compressed_size
            let hdrSize = e.headerSize()
            let decompressed = decompressEntry(e)
            let compSize = if (decompressed.isSome()) {
                decompressed.getOrThrow().compressedSize
            } else {
                Int64(0)
            }
            offset += hdrSize + compSize
            if (result.size >= numObjects) {
                break
            }
        }
        PackResult.PackOk(result)
    }

    // 遍历 pack 中所有条目的偏移量
    // 对齐 Rust: gix-pack/src/index/access.rs sorted_offsets()
    // 返回排序后的偏移量列表
    public func sortedOffsets(): ArrayList<Int64> {
        var offsets = ArrayList<Int64>()
        let headerResult = decodePackHeader(data)
        if (headerResult.isErr()) {
            return offsets
        }
        let (_, numObjects) = headerResult.unwrap()
        var offset: Int64 = 12
        let hashLen = hashKindLenBytes(hashKind)
        let endOffset = data.size - hashLen

        while (offset < endOffset) {
            let entryResult = entry(offset)
            if (entryResult.isErr()) {
                break
            }
            let e = entryResult.unwrap()
            offsets.add(offset)
            let hdrSize = e.headerSize()
            let decompressed = decompressEntry(e)
            let compSize = if (decompressed.isSome()) {
                decompressed.getOrThrow().compressedSize
            } else {
                Int64(0)
            }
            offset += hdrSize + compSize
            if (offsets.size >= numObjects) {
                break
            }
        }
        offsets
    }

    // 对齐 Rust: data::file::verify — 逐条目 CRC32 + 解压校验
    // 遍历所有条目，验证：(1) 条目头部可解析 (2) 压缩数据可解压 (3) CRC32 匹配索引（如提供）
    // 参数 indexCrc32s：索引文件中各条目的 CRC32 值列表，为 None 时跳过 CRC32 比对
    // 返回值：校验通过返回 None，失败返回 PackVerifyError
    public func verifyEntries(indexCrc32s: ?ArrayList<Int64>): ?PackVerifyError {
        var offset: Int64 = 12
        let hashLen = hashKindLenBytes(hashKind)
        let endOffset = data.size - hashLen
        var entryIndex: Int64 = 0

        while (offset < endOffset) {
            let entryResult = entry(offset)
            if (entryResult.isErr()) {
                return PackVerifyError(PackVerifyErrorKind.TruncatedData)
            }
            let e = entryResult.unwrap()

            // 校验解压并获取 compressedSize
            let decompressed = decompressEntry(e)
            if (decompressed.isNone()) {
                return PackVerifyError(PackVerifyErrorKind.Crc32Mismatch(entryIndex, 0, 0))
            }
            let dr = decompressed.getOrThrow()
            let headerSize = e.headerSize()
            let entrySize = headerSize + dr.compressedSize

            // CRC32 校验（如索引提供）
            if (indexCrc32s.isSome()) {
                let crcList = indexCrc32s.getOrThrow()
                if (entryIndex < crcList.size) {
                    let expectedCrc = crcList[entryIndex]
                    let actualCrc = entryCrc32(offset, entrySize)
                    if (actualCrc != expectedCrc) {
                        return PackVerifyError(PackVerifyErrorKind.Crc32Mismatch(entryIndex, expectedCrc, actualCrc))
                    }
                }
            }

            // 前进到下一个条目
            offset = offset + entrySize
            entryIndex += 1
        }

        if (entryIndex != numObjects) {
            return PackVerifyError(PackVerifyErrorKind.ObjectCountMismatch(numObjects, entryIndex))
        }
        None
    }
}

// ============================================================
// 兼容旧接口：PackEntry
// ============================================================

// pack 条目，包含对象类型、数据和在 pack 文件中的偏移量
// 保留以兼容已有代码
public class PackEntry {
    // 对象类型，解析失败时为 None
    public var kind: ?ObjectKind
    // 解压后的对象数据
    public var data: Array<Byte>
    // 在 pack 文件中的偏移量
    public var packOffset: Int64

    public init(kind: ?ObjectKind, data: Array<Byte>, packOffset: Int64) {
        this.kind = kind
        this.data = data
        this.packOffset = packOffset
    }
}

// ============================================================
// 工具函数
// ============================================================

// 读取 pack 格式的变长整数（兼容旧接口）
func readVarIntPack(data: Array<Byte>, offset: Int64): (Int64, Int64) {
    var byte = Int64(data[offset])
    var value = byte & 0x7F
    var shift: Int64 = 4
    var pos = offset + 1
    while ((byte & 0x80) != 0 && pos < data.size) {
        byte = Int64(data[pos])
        value = value | ((byte & 0x7F) << shift)
        shift += 7
        pos += 1
    }
    (value, pos)
}

// 将 pack 类型编码转换为 ObjectKind
func packTypeToKind(t: Int64): ?ObjectKind {
    match (t) {
        case 1 => Some(ObjectKind.Commit)
        case 2 => Some(ObjectKind.Tree)
        case 3 => Some(ObjectKind.Blob)
        case 4 => Some(ObjectKind.Tag)
        case _ => None
    }
}

// 截取字节数组的指定范围
func sliceBytesPackData(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end && i < data.size) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 获取哈希算法的字节长度
func hashKindLenBytes(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 20
        case HashKind.Sha256 => 32
    }
}

// 计算路径的 CRC32
// 使用 crc32fast 库
func crc32OfPath(path: String): Int64 {
    Int64(hash(path.toArray()))
}

// 计算字节数组的 CRC32
// 对齐 Rust: gix_features::hash::crc32()
// 使用 crc32fast 库
public func crc32OfBytes(data: Array<Byte>): Int64 {
    Int64(hash(data))
}
