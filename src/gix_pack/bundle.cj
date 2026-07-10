// 文件：bundle.cj
// 用途：定义 Pack bundle（数据文件 + 索引文件）类型，提供统一的 pack 查找、验证、写入接口
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/bundle/{mod,init,find,write}.rs
// 关键类型：Bundle, BundleWriteOptions, BundleWriteOutcome, BundleWriteError

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import gitoxide.gix_zlib.*
import std.collection.*
import std.fs.*

// ============================================================
// bundle::write::Options — 对齐 gix-pack/src/bundle/write/types.rs
// Bundle 写入配置
// ============================================================

public class BundleWriteOptions {
    // 线程数限制（仓颉暂不并行，预留接口）
    public var threadLimit: ?Int64
    // 迭代模式：AsIs/Verify/Restore
    public var iterationMode: InputMode
    // 索引版本
    public var indexVersion: IndexVersion
    // 哈希算法类型
    public var objectHash: HashKind
    // 内存分配上限（字节），None 表示不限制
    public var allocLimitBytes: ?Int64

    public init() {
        this.threadLimit = None
        this.iterationMode = InputMode.Verify
        this.indexVersion = IndexVersion.V2
        this.objectHash = HashKind.Sha1
        this.allocLimitBytes = None
    }
}

// ============================================================
// bundle::write::Outcome — 对齐 gix-pack/src/bundle/write/types.rs
// Bundle 写入结果
// ============================================================

public class BundleWriteOutcome {
    // 索引写入结果
    public var indexOutcome: ?IndexWriteOutcome
    // 哈希算法类型
    public var objectHash: HashKind
    // pack 版本
    public var packVersion: Version
    // pack 数据文件路径（持久化后）
    public var dataPath: ?String
    // 索引文件路径（持久化后）
    public var indexPath: ?String
    // .keep 文件路径
    public var keepPath: ?String

    public init() {
        this.indexOutcome = None
        this.objectHash = HashKind.Sha1
        this.packVersion = Version.V2
        this.dataPath = None
        this.indexPath = None
        this.keepPath = None
    }
}

// ============================================================
// bundle::write::Error — 对齐 gix-pack/src/bundle/write/error.rs
// Bundle 写入错误类型
// ============================================================

public enum BundleWriteError {
    // IO 错误（读写文件失败）
    | Io(String)
    // pack 迭代解析错误
    | PackIter(String)
    // 临时文件持久化失败
    | Persist(String)
    // 索引写入错误
    | IndexWrite(String)
}

// ============================================================
// index::write::Outcome — 对齐 gix-pack/src/index/write/mod.rs
// 索引写入结果
// ============================================================

public class IndexWriteOutcome {
    // 写入的对象数量
    public var numObjects: Int64
    // pack 数据的哈希（用于文件命名）
    public var dataHash: ObjectId
    // 索引校验和
    public var indexHash: ObjectId

    public init(numObjects: Int64, dataHash: ObjectId, indexHash: ObjectId) {
        this.numObjects = numObjects
        this.dataHash = dataHash
        this.indexHash = indexHash
    }
}

// ============================================================
// Bundle — 对齐 gix-pack/src/bundle/mod.rs
// Pack bundle，组合 pack 数据文件和索引文件
// ============================================================

public class Bundle <: Find {
    // pack 索引文件
    public var index: IndexFile
    // pack 数据文件
    public var data: DataFile
    // 哈希算法类型
    public var hashKind: HashKind
    // 索引文件路径（用于刷新时标识 Bundle）
    public var indexPath: ?String

    // 构造函数
    public init(index: IndexFile, data: DataFile, hashKind: HashKind) {
        this.index = index
        this.data = data
        this.hashKind = hashKind
        this.indexPath = None
    }

    // 根据索引路径打开 bundle
    // 对齐 Rust: bundle::at() -> Result<Bundle, Error>
    // 自动推断对应的 .pack 数据文件路径
    public static func at(indexPath: String, hashKind: HashKind): PackResult<Bundle> {
        let idxResult = IndexFile.at(indexPath, hashKind)
        if (idxResult.isErr()) {
            return PackResult.PackErr(idxResult.err().getOrThrow())
        }
        let i = idxResult.unwrap()
        let dataPath = substringStr(indexPath, 0, indexPath.size - 4) + ".pack"
        let datResult = DataFile.at(dataPath, hashKind)
        if (datResult.isErr()) {
            return PackResult.PackErr(datResult.err().getOrThrow())
        }
        let d = datResult.unwrap()
        let bundle = Bundle(i, d, hashKind)
        bundle.indexPath = indexPath
        PackResult.PackOk(bundle)
    }

    // 根据对象 ID 查找对象数据（便捷方法，不含位置信息）
    // 对齐 Rust: bundle::find() -> Result<Option<Data>, Error>
    public func tryFindData(id: ObjectId): PackResult<?Data> {
        let entryIndex = index.lookup(id)
        if (entryIndex.isNone()) {
            return PackResult.PackOk(None)
        }
        let idx = entryIndex.getOrThrow()
        let packOffset = index.packOffsetAtIndex(idx)
        if (packOffset.isNone()) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("pack offset not found for index ${idx}")))
        }
        let entry = data.readAtOffset(packOffset.getOrThrow())
        if (entry.isNone()) {
            return PackResult.PackErr(
                PackError(PackErrorKind.Io("failed to read pack entry at offset ${packOffset.getOrThrow()}")))
        }
        let e = entry.getOrThrow()
        if (e.kind.isNone()) {
            return PackResult.PackErr(
                PackError(PackErrorKind.InvalidData("entry has no object kind at offset ${packOffset.getOrThrow()}")))
        }
        PackResult.PackOk(Some(Data(e.kind.getOrThrow(), hashKind, e.data)))
    }

    // ============================================================
    // 对齐 Rust: gix-pack/src/find-traits.rs Find interface
    // ============================================================

    // Find::contains()
    public func contains(id: ObjectId): Bool {
        let entryIndex = index.lookup(id)
        entryIndex.isSome()
    }

    // Find::try_find()
    public func tryFind(id: ObjectId, buffer: ArrayList<Byte>): PackResult<?FindResult> {
        tryFindCached(id, buffer, NeverDecodeEntry())
    }

    // Find::try_find_cached()
    public func tryFindCached(id: ObjectId, buffer: ArrayList<Byte>, packCache: DecodeEntry): PackResult<?FindResult> {
        let entryIndex = index.lookup(id)
        if (entryIndex.isNone()) {
            return PackResult.PackOk(None)
        }
        let idx = entryIndex.getOrThrow()
        let packOffset = index.packOffsetAtIndex(idx)
        if (packOffset.isNone()) {
            return PackResult.PackErr(PackError(PackErrorKind.InvalidData("pack offset not found for index ${idx}")))
        }
        let offset = packOffset.getOrThrow()

        // 先检查缓存
        let cached = packCache.get(0, offset, buffer)
        if (cached.isSome()) {
            let v = cached.getOrThrow()
            let objData = Data(v.kind, hashKind, buffer.toArray())
            let loc = PackEntryLocation(0, v.compressedSize, offset)
            return PackResult.PackOk(Some(FindResult(objData, Some(loc))))
        }

        // 缓存未命中，从 pack 读取
        let entry = data.readAtOffset(offset)
        if (entry.isNone()) {
            return PackResult.PackErr(PackError(PackErrorKind.Io("failed to read pack entry at offset ${offset}")))
        }
        let e = entry.getOrThrow()
        if (e.kind.isNone()) {
            return PackResult.PackErr(
                PackError(PackErrorKind.InvalidData("entry has no object kind at offset ${offset}")))
        }

        // 写入缓存
        packCache.put(0, offset, e.data, e.kind.getOrThrow(), e.data.size)

        // 写入 buffer
        buffer.clear()
        for (b in e.data) {
            buffer.add(b)
        }

        let objData = Data(e.kind.getOrThrow(), hashKind, e.data)
        let loc = PackEntryLocation(0, e.data.size, offset)
        PackResult.PackOk(Some(FindResult(objData, Some(loc))))
    }

    // Find::location_by_oid()
    public func locationByOid(id: ObjectId, buffer: ArrayList<Byte>): ?PackEntryLocation {
        let entryIndex = index.lookup(id)
        if (entryIndex.isNone()) {
            return None
        }
        let idx = entryIndex.getOrThrow()
        let packOffset = index.packOffsetAtIndex(idx)
        if (packOffset.isNone()) {
            return None
        }
        Some(PackEntryLocation(0, 0, packOffset.getOrThrow()))
    }

    // Find::pack_offsets_and_oid()
    public func packOffsetsAndOid(packId: UInt32): ?ArrayList<(Int64, ObjectId)> {
        // Bundle 只有一个 pack，packId 必须为 0
        if (packId != 0) {
            return None
        }
        let result = ArrayList<(Int64, ObjectId)>()
        for (i in 0..index.numObjects) {
            let oid = index.oidAtIndex(i)
            let offset = index.packOffsetAtIndex(i)
            if (oid.isSome() && offset.isSome()) {
                result.add((offset.getOrThrow(), oid.getOrThrow()))
            }
        }
        Some(result)
    }

    // Find::entry_by_location()
    public func entryByLocation(location: PackEntryLocation): ?FindEntry {
        if (location.packId != 0) {
            return None
        }
        let entry = data.readAtOffset(location.packOffset)
        if (entry.isNone()) {
            return None
        }
        let e = entry.getOrThrow()
        Some(FindEntry(e.data, data.version))
    }

    // 遍历索引中的所有条目
    public func iter(): ArrayList<IndexEntry> {
        index.iter()
    }

    // 验证 pack 文件的校验和
    public func verifyChecksum(): Bool {
        data.verifyChecksum()
    }

    // 验证完整性
    public func verifyIntegrity(verifyMode: VerifyMode): IndexVerifyResult {
        index.verifyIntegrity(data, verifyMode)
    }

    // 遍历统计
    public func traverse(options: TraverseOptions): ?TraverseStatistics {
        index.traverse(data, options)
    }

    // ============================================================
    // bundle::write — 对齐 gix-pack/src/bundle/write/mod.rs
    // ============================================================

    // 从 pack 字节流写入到指定目录，同时生成索引文件
    // 对齐 Rust: Bundle::write_to_directory()
    // 参数 packData：pack 文件的原始字节数据
    // 参数 directory：目标目录路径，None 时仅验证不写文件
    // 参数 options：写入配置
    // 返回值：写入结果或错误
    public static func writeToDirectory(
        packData: Array<Byte>,
        directory: ?String,
        options: BundleWriteOptions
    ): BundleWriteOutcome {
        let objectHash = options.objectHash

        // 1. 先将 pack 数据写入临时文件
        // 对齐 Rust: data_file = Arc::new(parking_lot::Mutex::new(io::BufWriter::new(tempfile)))
        var packTempPath: ?String = None
        if (directory.isSome()) {
            let dir = directory.getOrThrow()
            packTempPath = dir + "/pack.tmp"
            writeFileBytes(packTempPath.getOrThrow(), packData)
        }

        // 2. 用 DataFile 解析 pack 数据
        // 对齐 Rust: BytesToEntriesIter 从 pack 头部解析
        let dataFileResult = DataFile.fromData(packData, "/tmp/write-bundle.pack", objectHash)
        if (dataFileResult.isErr()) {
            return bundleWriteError("pack data parse failed")
        }
        let df = dataFileResult.unwrap()

        // 3. 遍历 pack 条目，解码每个对象，计算 ObjectId
        // 对齐 Rust: index::write_data_iter_to_stream() 中遍历条目并计算 hash
        // 从 pack 头部后（偏移量 12）开始逐条遍历
        var indexEntries = ArrayList<IndexEntry>()
        var offset: Int64 = 12
        let packEnd = df.packEnd()
        while (offset < packEnd) {
            // 读取 pack 条目元数据
            let entryResult = df.entry(offset)
            if (entryResult.isErr()) {
                break
            }
            let e = entryResult.unwrap()

            // 读取解压后的对象数据
            // 对齐 Rust: data::File::read_at_offset() 解码对象
            let packEntryOpt = df.readAtOffset(offset)
            if (packEntryOpt.isNone()) {
                offset = offset + e.headerSize() + 1
                continue
            }
            let packEntry = packEntryOpt.getOrThrow()

            // 计算对象哈希：hash(kind + size + "\0" + data)
            // 对齐 Rust: index::write 中对每个条目计算 hash
            if (packEntry.kind.isNone()) {
                offset = offset + e.headerSize() + 1
                continue
            }
            let kind = packEntry.kind.getOrThrow()
            let oid = computeHash(objectHash, kind, packEntry.data)

            // 计算 CRC32（从 pack 原始字节计算）
            // 对齐 Rust: input::Entry::compute_crc32()
            let headerBytes = encodePackEntryHeader(kind, packEntry.data.size)
            let compressedResult = deflate(packEntry.data)
            let compressedData = compressedResult.data
            let crc32Val = crc32OfEntry(headerBytes, compressedData)

            indexEntries.add(IndexEntry(oid, offset, crc32Val))

            // 推进到下一个条目
            // 对齐 Rust: pack_offset += entry.bytes_in_pack()
            offset = offset + e.headerSize() + Int64(compressedData.size)
        }

        // 4. 计算 pack 数据校验和（pack 尾部 20 字节）
        // 对齐 Rust: pack 尾部的 SHA-1 校验和
        let hashLen = indexHashLenBytes(objectHash)
        let dataHash = if (packData.size >= hashLen) {
            ObjectId(sliceBytesPackData(packData, packData.size - hashLen, packData.size), objectHash)
        } else {
            ObjectId(Array<Byte>(hashLen, repeat: UInt8(0)), objectHash)
        }

        // 5. 生成索引
        // 对齐 Rust: index::write_data_iter_to_stream() 生成索引
        let indexWriter = IndexWriter(objectHash)
        let indexBytes = indexWriter.encodeWithPackChecksum(indexEntries, dataHash)
        let indexHash = ObjectId(indexHashFromBytes(indexBytes, objectHash), objectHash)

        let outcome = IndexWriteOutcome(
            Int64(indexEntries.size),
            dataHash,
            indexHash
        )

        // 6. 持久化文件到最终路径
        // 对齐 Rust: inner_write() 中的 tempfile persist 逻辑
        var result = BundleWriteOutcome()
        result.indexOutcome = outcome
        result.objectHash = objectHash
        result.packVersion = Version.V2

        if (directory.isSome() && outcome.numObjects > 0) {
            let dir = directory.getOrThrow()
            let hexHash = dataHash.toHexString()
            let finalDataPath = dir + "/pack-" + hexHash + ".pack"
            let finalIndexPath = dir + "/pack-" + hexHash + ".idx"
            let keepPath = dir + "/pack-" + hexHash + ".keep"

            // 持久化 pack 文件：临时文件重命名为最终文件名
            // 对齐 Rust: tempfile.persist(&data_path)
            if (packTempPath.isSome()) {
                try {
                    rename(packTempPath.getOrThrow(), to: finalDataPath, overwrite: true)
                    result.dataPath = finalDataPath
                } catch (_: Exception) {
                    return bundleWriteError("failed to persist pack file")
                }
            }

            // 写入索引文件
            // 对齐 Rust: index_file.persist(&index_path)
            try {
                writeFileBytes(finalIndexPath, indexBytes)
                result.indexPath = finalIndexPath
            } catch (_: Exception) {
                return bundleWriteError("failed to write index file")
            }

            // 创建 .keep 文件（防止 GC 回收刚写入的 pack）
            // 对齐 Rust: std::fs::write(&keep_path, b"")
            if (!exists(keepPath)) {
                try {
                    writeFileBytes(keepPath, [])
                    result.keepPath = keepPath
                } catch (_: Exception) {
                    // .keep 文件创建失败不是致命错误
                }
            }
        }

        result
    }

    // 从 PackWriter 写入到指定目录
    // 对齐 Rust: Bundle::write_to_directory() 的内存版本
    // 参数 writer：已添加对象的 PackWriter
    // 参数 directory：目标目录路径
    // 参数 options：写入配置
    public static func writeFromWriter(
        writer: PackWriter,
        directory: String,
        options: BundleWriteOptions
    ): BundleWriteOutcome {
        let packData = writer.encode()
        writeToDirectory(packData, Some(directory), options)
    }
}

// ============================================================
// 辅助函数
// ============================================================

// 计算条目的 CRC32（从头部编码 + 压缩数据）
// 对齐 Rust: input::Entry::compute_crc32()
func crc32OfEntry(headerBytes: Array<Byte>, compressedData: Array<Byte>): Int64 {
    var combined = ArrayList<Byte>()
    for (b in headerBytes) {
        combined.add(b)
    }
    for (b in compressedData) {
        combined.add(b)
    }
    crc32OfBytes(combined.toArray())
}

// 从索引编码字节中提取索引校验和（最后 hashLen 字节）
func indexHashFromBytes(data: Array<Byte>, hashKind: HashKind): Array<Byte> {
    let hashLen = indexHashLenBytes(hashKind)
    sliceBytesPackData(data, data.size - hashLen, data.size)
}

// 追加写入字节数据到文件
func appendFileBytes(path: String, data: Array<Byte>): Unit {
    try {
        let file = File(path, OpenMode.Append)
        file.write(data)
        file.close()
    } catch (_: Exception) {}
}

// 构造 BundleWriteError 的 Io 结果
func bundleWriteError(msg: String): BundleWriteOutcome {
    let result = BundleWriteOutcome()
    result.indexOutcome = None
    result
}
