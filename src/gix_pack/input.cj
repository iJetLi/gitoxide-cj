// 文件：input.cj
// 用途：全量对齐 Rust gitoxide gix-pack data::input 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/data/input/{mod,types,entry,bytes_to_entries,entries_to_bytes,lookup_ref_delta_objects}.rs
// 关键类型：InputEntry, InputMode, EntryDataMode, InputError, BytesToEntriesIter, EntriesToBytesIter

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_zlib.*
import gitoxide.gix_utils.*
import gitoxide.gix_error.GixError
import crc32fast.*
import std.collection.*
import std.fs.*

// ============================================================
// data::input::Mode — 对齐 gix-pack/src/data/input/types.rs
// 迭代模式
// ============================================================

public enum InputMode {
    | AsIs
    | Verify
    | Restore
}

extend InputMode <: Equatable<InputMode> {
    public operator func ==(other: InputMode): Bool {
        match (this) {
            case InputMode.AsIs => match (other) {
                case InputMode.AsIs => true
                case _ => false
            }
            case InputMode.Verify => match (other) {
                case InputMode.Verify => true
                case _ => false
            }
            case InputMode.Restore => match (other) {
                case InputMode.Restore => true
                case _ => false
            }
        }
    }

    public operator func !=(other: InputMode): Bool {
        !(this == other)
    }
}

// ============================================================
// data::input::EntryDataMode — 对齐 gix-pack/src/data/input/types.rs
// 条目压缩数据处理模式
// ============================================================

public enum EntryDataMode {
    | Ignore
    | Crc32
    | Keep
    | KeepAndCrc32
}

extend EntryDataMode {
    // 是否计算 CRC32
    public func shouldCrc32(): Bool {
        match (this) {
            case EntryDataMode.KeepAndCrc32 => true
            case EntryDataMode.Crc32 => true
            case EntryDataMode.Keep => false
            case EntryDataMode.Ignore => false
        }
    }

    // 是否保留压缩数据
    public func shouldKeep(): Bool {
        match (this) {
            case EntryDataMode.Keep => true
            case EntryDataMode.KeepAndCrc32 => true
            case EntryDataMode.Ignore => false
            case EntryDataMode.Crc32 => false
        }
    }
}

// ============================================================
// data::input::Error — 对齐 gix-pack/src/data/input/types.rs
// ============================================================

public enum InputErrorKind {
    | Io(String)
    | PackParse(String)
    | Verify(String)
    | IncompletePack(Int64, Int64)
    | NotFound(ObjectId)
}

public class InputError <: GixError {
    public var kind: InputErrorKind

    public init(kind: InputErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

extend InputErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case InputErrorKind.Io(msg) => "IO error: ${msg}"
            case InputErrorKind.PackParse(msg) => "Pack parse error: ${msg}"
            case InputErrorKind.Verify(msg) => "Verify error: ${msg}"
            case InputErrorKind.IncompletePack(actual, expected) => "Pack is incomplete: decompressed into ${actual} bytes but ${expected} bytes were expected"
            case InputErrorKind.NotFound(id) => "Object not found: ${id.toHexString()}"
        }
    }
}

// ============================================================
// data::input::Entry — 对齐 gix-pack/src/data/input/mod.rs
// 流式输入迭代产生的条目
// ============================================================

public class InputEntry {
    // 条目头部
    public var header: EntryHeader
    // 头部编码占用的字节数
    public var headerSize: Int64
    // 条目在 pack 中的起始偏移量
    public var packOffset: Int64
    // 压缩数据（取决于 EntryDataMode）
    public var compressed: ?Array<Byte>
    // 压缩数据占用的字节数
    public var compressedSize: Int64
    // 条目的 CRC32（取决于 EntryDataMode）
    public var crc32: ?Int64
    // 解压后的大小
    public var decompressedSize: Int64
    // 最后一个条目时提供 pack 尾部校验和
    public var trailer: ?ObjectId

    public init(header: EntryHeader, headerSize: Int64, packOffset: Int64, compressed: ?Array<Byte>,
        compressedSize: Int64, crc32: ?Int64, decompressedSize: Int64, trailer: ?ObjectId) {
        this.header = header
        this.headerSize = headerSize
        this.packOffset = packOffset
        this.compressed = compressed
        this.compressedSize = compressedSize
        this.crc32 = crc32
        this.decompressedSize = decompressedSize
        this.trailer = trailer
    }

    // 从 Git 对象数据创建输入条目
    // 对齐 Rust: input::Entry::from_data_obj()
    public static func fromDataObj(kind: ObjectKind, data: Array<Byte>, hashKind: HashKind, packOffset: Int64): ?InputEntry {
        let header = kindToEntryHeader(kind)
        let compressedResult = deflate(data)
        let compressedData = compressedResult.data
        let compressedSize = Int64(compressedData.size)
        let hdrSize = header.headerSize(Int64(data.size))
        let entry = InputEntry(
            header,
            hdrSize,
            packOffset,
            Some(compressedData),
            compressedSize,
            None,
            Int64(data.size),
            None
        )
        entry.crc32 = Some(entry.computeCrc32())
        entry
    }

    // 条目在 pack 中的总字节数
    // 对齐 Rust: input::Entry::bytes_in_pack()
    public func bytesInPack(): Int64 {
        headerSize + compressedSize
    }

    // 计算条目的 CRC32（从头部编码 + 压缩数据）
    // 对齐 Rust: input::Entry::compute_crc32()
    public func computeCrc32(): Int64 {
        let headerBytes = encodeEntryHeader(header, decompressedSize)
        let state = crc32OfBytes(headerBytes)
        if (compressed.isSome()) {
            let c = compressed.getOrThrow()
            let combined = concatInputArrays(headerBytes, c)
            crc32OfBytes(combined)
        } else {
            state
        }
    }
}

// 将 ObjectKind 转换为 EntryHeader
func kindToEntryHeader(kind: ObjectKind): EntryHeader {
    match (kind) {
        case ObjectKind.Tree => EntryHeader.Tree
        case ObjectKind.Blob => EntryHeader.Blob
        case ObjectKind.Commit => EntryHeader.Commit
        case ObjectKind.Tag => EntryHeader.Tag
    }
}

// 拼接两个字节数组
func concatInputArrays(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    for (x in a) {
        result.add(x)
    }
    for (x in b) {
        result.add(x)
    }
    result.toArray()
}

// ============================================================
// data::input::BytesToEntriesIter — 对齐 gix-pack/src/data/input/bytes_to_entries.rs
// 从 pack 字节流迭代解析条目
// ============================================================

public class BytesToEntriesIter {
    // pack 数据
    public var data: Array<Byte>
    // 当前偏移量
    public var offset: Int64
    // 是否发生过错误
    public var hadError: Bool
    // pack 版本
    public var version: Version
    // 剩余对象数
    public var objectsLeft: Int64
    // 哈希计算器（Verify/Restore 模式）
    public var hasher: ?GixHasher
    // 迭代模式
    public var mode: InputMode
    // 压缩数据处理模式
    public var compressedMode: EntryDataMode
    // 哈希算法类型
    public var hashKind: HashKind

    public init(data: Array<Byte>, version: Version, numObjects: Int64, mode: InputMode, compressedMode: EntryDataMode,
        hashKind: HashKind) {
        this.data = data
        this.offset = 12
        this.hadError = false
        this.version = version
        this.objectsLeft = numObjects
        this.mode = mode
        this.compressedMode = compressedMode
        this.hashKind = hashKind
        if (mode != InputMode.AsIs) {
            let h = GixHasher(hashKind)
            h.update(sliceBytesPackData(data, 0, 12))
            this.hasher = Some(h)
        } else {
            this.hasher = None
        }
    }

    // 从 pack 文件头部创建迭代器
    // 对齐 Rust: BytesToEntriesIter::new_from_header()
    public static func newFromHeader(data: Array<Byte>, mode: InputMode, compressedMode: EntryDataMode,
        hashKind: HashKind): PackResult<BytesToEntriesIter> {
        let headerResult = decodePackHeader(data)
        if (headerResult.isErr()) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("invalid pack header")))
        }
        let (version, numObjects) = headerResult.unwrap()
        PackResult.PackOk(BytesToEntriesIter(data, version, numObjects, mode, compressedMode, hashKind))
    }

    // 获取下一个条目
    // 对齐 Rust: BytesToEntriesIter::next()
    public func nextEntry(): ?InputEntry {
        if (hadError || objectsLeft == 0) {
            return None
        }
        objectsLeft -= 1

        let entryResult = entryFromBytes(sliceBytesPackData(data, offset, data.size), offset, hashKind)
        if (entryResult.isErr()) {
            hadError = true
            return None
        }
        let e = entryResult.unwrap()

        // 解压以确定压缩数据大小
        let decompressed = inflateFromData(e)
        if (decompressed.isNone()) {
            hadError = true
            return None
        }
        let (decompressedData, compressedSize) = decompressed.getOrThrow()

        let packOffset = offset
        let headerSize = e.headerSize()
        offset = offset + headerSize + compressedSize

        // 获取压缩数据切片
        let compressedSlice = sliceBytesPackData(data, e.dataOffset, e.dataOffset + compressedSize)

        // 更新哈希 — 直接使用 pack 中的原始字节（头部 + 压缩数据）
        // 对齐 Rust: BytesToEntriesIter 直接从 read stream 读取字节喂给 hasher
        if (hasher.isSome()) {
            let entryRawBytes = sliceBytesPackData(data, packOffset, e.dataOffset + compressedSize)
            hasher.getOrThrow().update(entryRawBytes)
        }

        // CRC32 计算
        var crc32Value: ?Int64 = None
        if (compressedMode.shouldCrc32()) {
            let headerBytes = encodeEntryHeader(e.header, e.decompressedSize)
            let combined = concatInputArrays(headerBytes, compressedSlice)
            crc32Value = Some(crc32OfBytes(combined))
        }

        // 压缩数据保留
        var compressed: ?Array<Byte> = None
        if (compressedMode.shouldKeep()) {
            compressed = Some(compressedSlice)
        }

        // 尾部校验和
        var trailer: ?ObjectId = None
        if (objectsLeft == 0) {
            trailer = tryReadTrailer()
        } else if (mode == InputMode.Restore) {
            if (hasher.isSome()) {
                trailer = Some(hasher.getOrThrow().tryFinalize())
            }
        }

        InputEntry(
            e.header,
            headerSize,
            packOffset,
            compressed,
            compressedSize,
            crc32Value,
            Int64(decompressedData.size),
            trailer
        )
    }

    // 解压条目数据并返回 (解压数据, 压缩字节数)
    func inflateFromData(entry: Entry): ?(Array<Byte>, Int64) {
        if (entry.dataOffset >= data.size) {
            return None
        }
        try {
            let sliceData = sliceBytesPackData(data, entry.dataOffset, data.size)
            let inflated = inflate(sliceData)
            Some((inflated.data, inflated.consumed))
        } catch (_: Exception) {
            None
        }
    }

    // 尝试读取尾部校验和
    func tryReadTrailer(): ?ObjectId {
        let hashLen = hashKindLenBytes(hashKind)
        if (offset + hashLen > data.size) {
            if (mode == InputMode.Restore) {
                if (hasher.isSome()) {
                    return Some(hasher.getOrThrow().tryFinalize())
                }
            }
            return None
        }
        let checksumBytes = sliceBytesPackData(data, offset, offset + hashLen)
        let storedId = ObjectId(checksumBytes, hashKind)
        if (hasher.isSome()) {
            let computedId = hasher.getOrThrow().tryFinalize()
            if (mode == InputMode.Verify) {
                if (!computedId.equals(storedId)) {
                    return None
                }
            }
            if (mode == InputMode.Restore) {
                return Some(computedId)
            }
        }
        Some(storedId)
    }

    // 剩余条目数
    public func remaining(): Int64 {
        objectsLeft
    }
}

// ============================================================
// data::input::EntriesToBytesIter — 对齐 gix-pack/src/data/input/entries_to_bytes.rs
// 将 InputEntry 迭代写回 pack 字节流
// ============================================================

public class EntriesToBytesIter {
    // 输入条目列表
    public var entries: ArrayList<InputEntry>
    // 输出缓冲区
    public var output: ArrayList<Byte>
    // pack 版本
    public var dataVersion: Version
    // 哈希算法类型
    public var hashKind: HashKind
    // 已写入的条目数
    public var numEntries: Int64
    // 尾部校验和
    public var trailer: ?ObjectId
    // 是否完成
    public var isDone: Bool
    // 当前迭代索引
    public var currentIndex: Int64

    public init(entries: ArrayList<InputEntry>, version: Version, hashKind: HashKind) {
        this.entries = entries
        this.output = ArrayList<Byte>()
        this.dataVersion = version
        this.hashKind = hashKind
        this.numEntries = 0
        this.trailer = None
        this.isDone = false
        this.currentIndex = 0
    }

    // 将所有条目写入 pack 字节流
    // 对齐 Rust: EntriesToBytesIter 迭代器
    public func writeAll(): Array<Byte> {
        if (isDone) {
            return output.toArray()
        }

        // 写入 pack 头部（先写 0 个对象，最后修正）
        let headerBytes = encodePackHeader(dataVersion, 0)
        for (b in headerBytes) {
            output.add(b)
        }

        // 写入每个条目
        for (entry in entries) {
            numEntries += 1
            let hdrBytes = encodeEntryHeader(entry.header, entry.decompressedSize)
            for (b in hdrBytes) {
                output.add(b)
            }
            if (entry.compressed.isSome()) {
                for (b in entry.compressed.getOrThrow()) {
                    output.add(b)
                }
            }
        }

        // 修正头部中的对象数量
        let fixedHeader = encodePackHeader(dataVersion, numEntries)
        var i: Int64 = 0
        while (i < 12) {
            output[i] = fixedHeader[i]
            i += 1
        }

        // 计算并写入尾部校验和
        let hasher = GixHasher(hashKind)
        hasher.update(output.toArray())
        let digest = hasher.tryFinalize()
        for (b in digest.bytes) {
            output.add(b)
        }
        trailer = Some(digest)
        isDone = true
        output.toArray()
    }

    // 获取尾部校验和
    public func digest(): ?ObjectId {
        trailer
    }
}
