// 文件：writer.cj
// 用途：实现 pack 文件的写入功能，生成 v2 格式的 pack 文件
// 所属包：gix.gix_pack
// 关键类型：PackWriter, PackObject, OutputCount, OutputEntry, PackLocation, OutputEntryKind
// 对齐来源：gix-pack/src/data/output/{mod,count,entry,bytes}.rs

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import gitoxide.gix_zlib.*
import std.collection.*
import std.fs.*

// pack 文件写入器，将对象集合写入 v2 格式的 pack 文件
public class PackWriter {
    // 哈希算法类型
    public var hashKind: HashKind
    // 待写入的对象列表
    public var objects: ArrayList<PackObject>
    // 进度回调，参数为 (已写入对象数, 总对象数)
    // 对齐 Rust: gix-pack/src/data/output/bytes.rs progress
    public var progressCallback: ?((Int64, Int64) -> Unit)

    // 构造函数
    // 参数 hashKind：哈希算法类型
    public init(hashKind: HashKind) {
        this.hashKind = hashKind
        this.objects = ArrayList<PackObject>()
        this.progressCallback = None
    }

    // 添加对象到写入队列
    public func addObject(kind: ObjectKind, data: Array<Byte>): ObjectId {
        let id = computeHash(hashKind, kind, data)
        objects.add(PackObject(id, kind, data, OutputEntryKind.Base(kind), []))
        id
    }

    // 对齐 Rust: gix-pack/src/data/output/entry/mod.rs Kind::DeltaRef
    // 添加 OfsDelta 对象到写入队列
    // 参数 baseIndex：基础对象在 objects 列表中的索引
    // 参数 deltaData：delta 编码后的数据（由 Delta.encode() 生成）
    public func addOfsDeltaObject(baseIndex: Int64, deltaData: Array<Byte>): ObjectId {
        let baseObj = objects[baseIndex]
        let id = baseObj.id
        objects.add(PackObject(id, ObjectKind.Blob, deltaData, OutputEntryKind.DeltaRef(baseIndex), deltaData))
        id
    }

    // 对齐 Rust: gix-pack/src/data/output/entry/mod.rs Kind::DeltaOid
    // 添加 RefDelta 对象到写入队列（用于 thin pack）
    // 参数 baseId：基础对象的 ObjectId
    // 参数 deltaData：delta 编码后的数据
    public func addRefDeltaObject(baseId: ObjectId, deltaData: Array<Byte>): ObjectId {
        let hasher = GixHasher(hashKind)
        hasher.update(deltaData)
        let id = hasher.tryFinalize()
        objects.add(PackObject(id, ObjectKind.Blob, deltaData, OutputEntryKind.DeltaOid(baseId), deltaData))
        id
    }

    // 将所有对象编码为 pack 字节数组（不写入文件）
    // 对齐 Rust: data::output::bytes::FromEntriesIter 的内存版本
    // 支持 Base/DeltaRef/DeltaOid 三种条目类型
    public func encode(): Array<Byte> {
        var result = ArrayList<Byte>()
        let headerBytes = encodePackHeader(Version.V2, objects.size)
        for (b in headerBytes) {
            result.add(b)
        }
        // 记录每个对象的 pack 偏移量，用于 OfsDelta 距离计算
        var packOffsets = ArrayList<Int64>()
        for (obj in objects) {
            packOffsets.add(Int64(result.size))
            match (obj.entryKind) {
                case OutputEntryKind.Base(_) =>
                    let header = encodePackEntryHeader(obj.kind, obj.data.size)
                    for (b in header) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.data)
                    for (b in compressed.data) {
                        result.add(b)
                    }
                case OutputEntryKind.DeltaRef(baseIndex) =>
                    let baseOffset = packOffsets[baseIndex]
                    let currentOffset = Int64(result.size)
                    let distance = currentOffset - baseOffset
                    let entryHeader = EntryHeader.OfsDelta(distance)
                    let headerBytes2 = encodeEntryHeader(entryHeader, Int64(obj.deltaData.size))
                    for (b in headerBytes2) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.deltaData)
                    for (b in compressed.data) {
                        result.add(b)
                    }
                case OutputEntryKind.DeltaOid(baseId) =>
                    let entryHeader = EntryHeader.RefDelta(baseId)
                    let headerBytes2 = encodeEntryHeader(entryHeader, Int64(obj.deltaData.size))
                    for (b in headerBytes2) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.deltaData)
                    for (b in compressed.data) {
                        result.add(b)
                    }
            }
        }
        let hasher = GixHasher(hashKind)
        hasher.update(result.toArray())
        let checksum = hasher.tryFinalize()
        for (b in checksum.bytes) {
            result.add(b)
        }
        result.toArray()
    }

    // 将所有对象写入 pack 文件
    // 对齐 Rust: data::output::bytes::FromEntriesIter
    public func write(path: String): Unit {
        let data = encode()
        try {
            let file = File(path, OpenMode.Write)
            file.write(data)
            file.close()
        } catch (_: Exception) {}
    }

    // 对齐 Rust: gix-pack/src/data/output/bytes.rs — 带进度回调的写入
    // 参数 path：输出文件路径
    // 参数 progress：进度回调函数 (已写入对象数, 总对象数)
    public func writeWithProgress(path: String, progress: (Int64, Int64) -> Unit): Unit {
        var result = ArrayList<Byte>()
        let headerBytes = encodePackHeader(Version.V2, objects.size)
        for (b in headerBytes) {
            result.add(b)
        }
        var packOffsets = ArrayList<Int64>()
        let total = Int64(objects.size)
        var count = 0
        for (obj in objects) {
            packOffsets.add(Int64(result.size))
            match (obj.entryKind) {
                case OutputEntryKind.Base(_) =>
                    let header = encodePackEntryHeader(obj.kind, obj.data.size)
                    for (b in header) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.data)
                    for (b in compressed.data) {
                        result.add(b)
                    }
                case OutputEntryKind.DeltaRef(baseIndex) =>
                    let baseOffset = packOffsets[baseIndex]
                    let currentOffset = Int64(result.size)
                    let distance = currentOffset - baseOffset
                    let entryHeader = EntryHeader.OfsDelta(distance)
                    let headerBytes2 = encodeEntryHeader(entryHeader, Int64(obj.deltaData.size))
                    for (b in headerBytes2) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.deltaData)
                    for (b in compressed.data) {
                        result.add(b)
                    }
                case OutputEntryKind.DeltaOid(baseId) =>
                    let entryHeader = EntryHeader.RefDelta(baseId)
                    let headerBytes2 = encodeEntryHeader(entryHeader, Int64(obj.deltaData.size))
                    for (b in headerBytes2) {
                        result.add(b)
                    }
                    let compressed = deflate(obj.deltaData)
                    for (b in compressed.data) {
                        result.add(b)
                    }
            }
            count += 1
            progress(count, total)
        }
        let hasher = GixHasher(hashKind)
        hasher.update(result.toArray())
        let checksum = hasher.tryFinalize()
        for (b in checksum.bytes) {
            result.add(b)
        }
        try {
            let file = File(path, OpenMode.Write)
            file.write(result.toArray())
            file.close()
        } catch (_: Exception) {}
    }
}

// 待写入的 pack 对象
public class PackObject {
    // 对象 ID
    public var id: ObjectId
    // 对象类型
    public var kind: ObjectKind
    // 对象数据
    public var data: Array<Byte>
    // 条目类型（Base/DeltaRef/DeltaOid）
    // 对齐 Rust: gix-pack/src/data/output/entry/mod.rs Kind
    public var entryKind: OutputEntryKind
    // delta 编码数据（仅 delta 对象使用）
    public var deltaData: Array<Byte>

    // 构造函数
    // 参数 id：对象 ID
    // 参数 kind：对象类型
    // 参数 data：对象数据
    public init(id: ObjectId, kind: ObjectKind, data: Array<Byte>, entryKind: OutputEntryKind, deltaData: Array<Byte>) {
        this.id = id
        this.kind = kind
        this.data = data
        this.entryKind = entryKind
        this.deltaData = deltaData
    }
}

// 编码 pack 条目的变长头部
// 对齐 Rust: Header::write_to()
func encodePackEntryHeader(kind: ObjectKind, size: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    let typeBits = kindToPackType(kind)
    var value = Int64(typeBits) << 4 | (size & 0x0F)
    var remaining = size >> 4
    if (remaining > 0) {
        value = value | 0x80
    }
    result.add(UInt8(Int64(value)))
    while (remaining > 0) {
        value = remaining & 0x7F
        remaining = remaining >> 7
        if (remaining > 0) {
            value = value | 0x80
        }
        result.add(UInt8(Int64(value)))
    }
    result.toArray()
}

// 编码带 EntryHeader 的 pack 条目头部（支持 delta 类型）
// 对齐 Rust: Header::write_to()
public func encodeEntryHeader(header: EntryHeader, decompressedSize: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var size = decompressedSize
    var c: Int64 = (header.asTypeId() << 4) | (size & 0x0F)
    size = size >> 4
    while (size != 0) {
        result.add(UInt8(c | 0x80))
        c = size & 0x7F
        size = size >> 7
    }
    result.add(UInt8(c))

    match (header) {
        case EntryHeader.RefDelta(id) => for (b in id.bytes) {
            result.add(b)
        }
        case EntryHeader.OfsDelta(_) => for (b in leb64Encode(header.getOfsDeltaDistance())) {
            result.add(b)
        }
        case _ => ()
    }
    result.toArray()
}

// 将 ObjectKind 转换为 pack 类型编码
// 参数 kind：对象类型
// 返回值：pack 类型编码（1=Commit, 2=Tree, 3=Blob, 4=Tag）
func kindToPackType(kind: ObjectKind): Int64 {
    match (kind) {
        case ObjectKind.Commit => 1
        case ObjectKind.Tree => 2
        case ObjectKind.Blob => 3
        case ObjectKind.Tag => 4
    }
}

// 将整数转换为大端序 4 字节数组
// 参数 v：整数值
// 返回值：4 字节的大端序数组
func intToBytes(v: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    result.add(UInt8(Int64((v >> 24)) & 0xFF))
    result.add(UInt8(Int64((v >> 16)) & 0xFF))
    result.add(UInt8(Int64((v >> 8)) & 0xFF))
    result.add(UInt8(Int64(v & 0xFF)))
    result.toArray()
}

// 计算 Git 对象的哈希 ID
// 参数 hashKind：哈希算法类型
// 参数 kind：对象类型
// 参数 data：对象数据
// 返回值：ObjectId
func computeHash(hashKind: HashKind, kind: ObjectKind, data: Array<Byte>): ObjectId {
    let header = looseHeader(kind, data.size)
    let fullData = concatArraysPack(header, data)
    let hasher = GixHasher(hashKind)
    hasher.update(fullData)
    hasher.tryFinalize()
}

// 编码松散对象头部
// 参数 kind：对象类型
// 参数 size：对象数据大小
// 返回值：编码后的头部字节数组
func looseHeader(kind: ObjectKind, size: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    let kindBytes = kindAsBytesPack(kind)
    for (b in kindBytes) {
        result.add(b)
    }
    result.add(UInt8(32))
    let sizeStr = size.toString()
    for (b in sizeStr.toArray()) {
        result.add(b)
    }
    result.add(UInt8(0))
    result.toArray()
}

// 将 ObjectKind 转换为类型名称字节数组
// 参数 kind：对象类型
// 返回值：类型名称的字节数组
func kindAsBytesPack(kind: ObjectKind): Array<Byte> {
    match (kind) {
        case ObjectKind.Tree => "tree".toArray()
        case ObjectKind.Blob => "blob".toArray()
        case ObjectKind.Commit => "commit".toArray()
        case ObjectKind.Tag => "tag".toArray()
    }
}

// 拼接两个字节数组
// 参数 a：第一个字节数组
// 参数 b：第二个字节数组
// 返回值：拼接后的新字节数组
func concatArraysPack(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
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
// data::output::count::PackLocation — 对齐 gix-pack/src/data/output/count/mod.rs
// pack 位置的查找状态
// ============================================================

public enum PackLocation {
    | NotLookedUp
    | LookedUp(?EntryLocation)
}

extend PackLocation {
    // 是否为已查找但无位置
    // 对齐 Rust: PackLocation::is_none()
    public func isNoneLocation(): Bool {
        match (this) {
            case PackLocation.LookedUp(opt) => opt.isNone()
            case PackLocation.NotLookedUp => false
        }
    }

    // 获取引用
    // 对齐 Rust: PackLocation::as_ref()
    public func asRef(): ?EntryLocation {
        match (this) {
            case PackLocation.LookedUp(opt) => opt
            case PackLocation.NotLookedUp => None
        }
    }
}

// ============================================================
// data::output::Count — 对齐 gix-pack/src/data/output/mod.rs
// 计数阶段的对象条目，表示即将写入 pack 的对象
// ============================================================

public class OutputCount {
    // 对象哈希 ID
    public var id: ObjectId
    // 对象在 pack 中的位置信息
    public var entryPackLocation: PackLocation

    public init(id: ObjectId, entryPackLocation: PackLocation) {
        this.id = id
        this.entryPackLocation = entryPackLocation
    }

    // 从对象 ID 和位置创建
    // 对齐 Rust: Count::from_data()
    public static func fromData(oid: ObjectId, location: ?EntryLocation): OutputCount {
        OutputCount(oid, PackLocation.LookedUp(location))
    }
}

// ============================================================
// data::output::entry::Kind — 对齐 gix-pack/src/data/output/entry/mod.rs
// pack 输出条目的类型
// ============================================================

public enum OutputEntryKind {
    // 完整基础对象
    | Base(ObjectKind)
    // 基于索引的 delta 引用
    | DeltaRef(Int64)
    // 基于 ObjectId 的 delta 引用（thin pack）
    | DeltaOid(ObjectId)
}

extend OutputEntryKind <: Equatable<OutputEntryKind> {
    public operator func ==(other: OutputEntryKind): Bool {
        match (this) {
            case OutputEntryKind.Base(k1) => match (other) {
                case OutputEntryKind.Base(k2) => k1 == k2
                case _ => false
            }
            case OutputEntryKind.DeltaRef(i1) => match (other) {
                case OutputEntryKind.DeltaRef(i2) => i1 == i2
                case _ => false
            }
            case OutputEntryKind.DeltaOid(id1) => match (other) {
                case OutputEntryKind.DeltaOid(id2) => id1.equals(id2)
                case _ => false
            }
        }
    }

    public operator func !=(other: OutputEntryKind): Bool {
        !(this == other)
    }
}

// ============================================================
// data::output::Entry — 对齐 gix-pack/src/data/output/mod.rs
// 待写入 pack 的条目
// ============================================================

public class OutputEntry {
    // 对象哈希 ID
    public var id: ObjectId
    // 条目类型
    public var kind: OutputEntryKind
    // 解压后的大小
    public var decompressedSize: Int64
    // 压缩后的数据
    public var compressedData: Array<Byte>

    public init(id: ObjectId, kind: OutputEntryKind, decompressedSize: Int64, compressedData: Array<Byte>) {
        this.id = id
        this.kind = kind
        this.decompressedSize = decompressedSize
        this.compressedData = compressedData
    }

    // 创建无效条目标记
    // 对齐 Rust: output::Entry::invalid()
    public static func invalid(): OutputEntry {
        OutputEntry(
            ObjectId.null(HashKind.Sha1),
            OutputEntryKind.Base(ObjectKind.Blob),
            0,
            []
        )
    }

    // 是否为无效条目（全零 ObjectId）
    // 对齐 Rust: output::Entry::is_invalid()
    public func isInvalid(): Bool {
        id.equals(ObjectId.null(id.kind))
    }

    // 从计数对象和 Git 对象数据创建
    // 对齐 Rust: output::Entry::from_data()
    public static func fromData(count: OutputCount, kind: ObjectKind, data: Array<Byte>): OutputEntry {
        let compressedResult = deflate(data)
        OutputEntry(
            count.id,
            OutputEntryKind.Base(kind),
            Int64(data.size),
            compressedResult.data
        )
    }

    // 转换为 pack 条目头部
    // 对齐 Rust: output::Entry::to_entry_header()
    public func toEntryHeader(indexToBaseDistance: (Int64) -> Int64): EntryHeader {
        match (kind) {
            case OutputEntryKind.Base(k) => kindToEntryHeader(k)
            case OutputEntryKind.DeltaOid(id) => EntryHeader.RefDelta(id)
            case OutputEntryKind.DeltaRef(objectIndex) => EntryHeader.OfsDelta(indexToBaseDistance(objectIndex))
        }
    }
}

// ============================================================
// data::output::bytes::FromEntriesIter — 对齐 gix-pack/src/data/output/bytes.rs
// 将 OutputEntry 列表写入 pack 字节流
// ============================================================

public class FromEntriesIter {
    // 输出缓冲区
    public var output: ArrayList<Byte>
    // pack 版本
    public var entryVersion: Version
    // 哈希算法类型
    public var hashKind: HashKind
    // 已写入的字节数
    public var written: Int64
    // 各对象的 pack 偏移量和有效性
    public var packOffsetsAndValidity: ArrayList<(Int64, Bool)>
    // 尾部校验和
    public var trailer: ?ObjectId
    // 是否完成
    public var isDone: Bool

    public init(version: Version, hashKind: HashKind) {
        this.output = ArrayList<Byte>()
        this.entryVersion = version
        this.hashKind = hashKind
        this.written = 0
        this.packOffsetsAndValidity = ArrayList<(Int64, Bool)>()
        this.trailer = None
        this.isDone = false
    }

    // 将一批条目写入 pack 字节流
    // 对齐 Rust: FromEntriesIter::next_inner()
    public func writeEntries(entries: ArrayList<OutputEntry>, numEntries: Int64): Int64 {
        let previousWritten = written

        // 写入头部（首次）
        if (written == 0) {
            let headerBytes = encodePackHeader(entryVersion, numEntries)
            for (b in headerBytes) {
                output.add(b)
            }
            written += Int64(headerBytes.size)
        }

        // 写入每个条目
        for (entry in entries) {
            if (entry.isInvalid()) {
                packOffsetsAndValidity.add((0, false))
                continue
            }
            packOffsetsAndValidity.add((written, true))
            let header = entry.toEntryHeader(
                {
                    index: Int64 =>
                        let (baseOffset, isValid) = packOffsetsAndValidity[index]
                        if (!isValid) {
                            0
                        } else {
                            written - baseOffset
                        }
                }
            )
            let headerBytes = encodeEntryHeader(header, entry.decompressedSize)
            for (b in headerBytes) {
                output.add(b)
            }
            written += Int64(headerBytes.size)
            for (b in entry.compressedData) {
                output.add(b)
            }
            written += Int64(entry.compressedData.size)
        }

        written - previousWritten
    }

    // 完成写入，追加尾部校验和
    // 对齐 Rust: FromEntriesIter — 迭代结束时计算 digest
    public func finish(): Array<Byte> {
        if (isDone) {
            return output.toArray()
        }

        let hasher = GixHasher(hashKind)
        hasher.update(output.toArray())
        let digest = hasher.tryFinalize()
        for (b in digest.bytes) {
            output.add(b)
        }
        written += Int64(digest.bytes.size)
        trailer = Some(digest)
        isDone = true
        output.toArray()
    }

    // 获取尾部校验和
    public func digest(): ?ObjectId {
        trailer
    }
}
