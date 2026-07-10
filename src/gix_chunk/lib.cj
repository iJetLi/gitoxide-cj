// 文件：lib.cj
// 用途：提供 chunk 文件格式解析功能，用于 commit-graph 等文件的分块读写
// 所属包：gix.gix_chunk
// 关键类型：ChunkFile, Chunk, ChunkIndex
// 对齐来源：gix-chunk/src/lib.rs, gix-chunk/src/file/

package gitoxide.gix_chunk

import std.collection.*

// 对齐 Rust: gix_chunk::Id
// chunk 类型标识，4 字节
public type ChunkId = UInt32

// 对齐 Rust: gix_chunk::SENTINEL
// chunk 表末尾哨兵值
public let SENTINEL: ChunkId = 0

// 对齐 Rust: gix_chunk::file::Offset
// chunk 文件中的偏移量
public type Offset = Int64

// 对齐 Rust: gix_chunk::file::index::Entry
// chunk 索引条目，包含类型和偏移范围
public class ChunkIndexEntry {
    // 对齐 Rust: index::Entry::kind
    public var kind: ChunkId
    // 对齐 Rust: index::Entry::offset (Range<Offset>)
    public var startOffset: Offset
    public var endOffset: Offset

    public init(kind: ChunkId, startOffset: Offset, endOffset: Offset) {
        this.kind = kind
        this.startOffset = startOffset
        this.endOffset = endOffset
    }
}

// 对齐 Rust: gix_chunk::file::Index
// chunk 文件索引，解析后的 chunk 元数据
public class ChunkIndex {
    // 对齐 Rust: file::Index::chunks
    public var entries: ArrayList<ChunkIndexEntry>

    public init() {
        this.entries = ArrayList<ChunkIndexEntry>()
    }

    // 对齐 Rust: file::Index::ENTRY_SIZE
    // 每个索引条目的大小：4 字节 kind + 8 字节 offset = 12 字节
    public static let ENTRY_SIZE: Int64 = 12

    // 对齐 Rust: file::Index::offset_by_id()
    // 根据 chunk ID 查找偏移范围
    public func offsetById(kind: ChunkId): ?ChunkIndexEntry {
        for (entry in entries) {
            if (entry.kind == kind) {
                return Some(entry)
            }
        }
        None
    }

    // 对齐 Rust: file::Index::data_by_id()
    // 根据 chunk ID 查找数据
    public func dataById(data: Array<Byte>, kind: ChunkId): ?Array<Byte> {
        let entry = offsetById(kind)
        if (let Some(e) <- entry) {
            if (e.startOffset >= 0 && e.endOffset <= data.size && e.startOffset <= e.endOffset) {
                let len = e.endOffset - e.startOffset
                var result = Array<Byte>(len, repeat: 0)
                var i: Int64 = 0
                while (i < len) {
                    result[i] = data[e.startOffset + i]
                    i += 1
                }
                return Some(result)
            }
        }
        None
    }

    // 对齐 Rust: file::Index::size_for_entries()
    // 计算指定条目数的索引大小
    public static func sizeForEntries(numEntries: Int64): Int64 {
        ENTRY_SIZE * (numEntries + 1)
    }
}

// chunk 文件，包含多个数据块
// 对齐 Rust: gix_chunk::file::Index (读取端) + file::write (写入端)
public class ChunkFile {
    // 文件中的数据块列表
    public var chunks: ArrayList<Chunk>
    // 解析后的索引
    public var index: ChunkIndex
    // 原始数据（用于数据访问）
    public var rawData: Array<Byte>

    public init() {
        this.chunks = ArrayList<Chunk>()
        this.index = ChunkIndex()
        this.rawData = []
    }

    // 对齐 Rust: gix_chunk::file::Index::from_bytes()
    // 从字节数组解析 chunk 文件
    // 参数 data：chunk 文件的原始字节数据
    // 参数 tocOffset：table of contents 在 data 中的偏移
    // 参数 numChunks：chunk 数量
    // 返回值：解析成功返回 ChunkFile，数据不足或格式错误返回 None
    public static func parse(data: Array<Byte>, tocOffset: Int64, numChunks: Int64): ?ChunkFile {
        if (numChunks == 0) {
            return None
        }
        let cf = ChunkFile()
        cf.rawData = data
        let expectedMinSize = ChunkIndex.sizeForEntries(numChunks)
        if (data.size - tocOffset < expectedMinSize) {
            return None
        }
        var pos = tocOffset
        var i: Int64 = 0
        while (i < numChunks) {
            if (pos + 12 > data.size) {
                return None
            }
            let kind = readChunkId(data, pos)
            pos += 4
            let offset = readOffset(data, pos)
            pos += 8
            if (kind == SENTINEL) {
                return None
            }
            var duplicate = false
            for (existing in cf.index.entries) {
                if (existing.kind == kind) {
                    duplicate = true
                    break
                }
            }
            if (duplicate) {
                return None
            }
            let entry = ChunkIndexEntry(kind, offset, 0)
            cf.index.entries.add(entry)
            i += 1
        }
        if (pos + 12 > data.size) {
            return None
        }
        let sentinelKind = readChunkId(data, pos)
        pos += 4
        let sentinelOffset = readOffset(data, pos)
        pos += 8
        if (sentinelKind != SENTINEL) {
            return None
        }
        for (j in 0..cf.index.entries.size) {
            let current = cf.index.entries[j]
            if (j + 1 < cf.index.entries.size) {
                current.endOffset = cf.index.entries[j + 1].startOffset
            } else {
                current.endOffset = sentinelOffset
            }
            let chunk = Chunk(current.kind, current.startOffset, current.endOffset - current.startOffset)
            cf.chunks.add(chunk)
        }
        Some(cf)
    }

    // 便捷方法：从字节数组解析 chunk 文件，自动检测 TOC 偏移
    // 对齐 Rust: gix_chunk::file::Index::from_bytes() 简化版
    public static func parse(data: Array<Byte>): ?ChunkFile {
        if (data.size < 12) {
            return None
        }
        let signature = readChunkId(data, 0)
        let version = readU32(data, 4)
        let numChunks = readU32(data, 8)
        let tocOffset: Int64 = 12
        parse(data, tocOffset, numChunks)
    }

    // 对齐 Rust: gix_chunk::file::Index::offset_by_id()
    // 根据类型 ID 查找数据块
    public func findChunk(kind: ChunkId): ?Chunk {
        for (chunk in chunks) {
            if (chunk.kind == kind) {
                return Some(chunk)
            }
        }
        None
    }

    // 对齐 Rust: gix_chunk::file::Index::data_by_id()
    // 根据 chunk ID 获取数据
    public func chunkData(kind: ChunkId): ?Array<Byte> {
        index.dataById(rawData, kind)
    }
}

// 单个数据块，包含类型、偏移和大小
// 对齐 Rust: gix_chunk::file::index::Entry 简化
public class Chunk {
    // 数据块的类型标识
    public var kind: ChunkId
    // 数据块在文件中的偏移量
    public var offset: Offset
    // 数据块的字节大小
    public var size: Int64

    public init(kind: ChunkId, offset: Offset, size: Int64) {
        this.kind = kind
        this.offset = offset
        this.size = size
    }
}

// 对齐 Rust: gix_chunk::file::write::Index
// chunk 文件写入器
public class ChunkWriter {
    // 计划写入的 chunk 列表
    public var plannedChunks: ArrayList<PlannedChunk>
    // 文件头大小
    public var headerSize: Int64

    public init(headerSize: Int64) {
        this.plannedChunks = ArrayList<PlannedChunk>()
        this.headerSize = headerSize
    }

    // 对齐 Rust: gix_chunk::file::Index::plan_chunk()
    // 计划一个 chunk
    public func planChunk(kind: ChunkId, dataSize: Int64): Unit {
        plannedChunks.add(PlannedChunk(kind, dataSize))
    }

    // 对齐 Rust: gix_chunk::file::write::Index::into_write()
    // 将所有 chunk 写入字节流
    public func write(headerData: Array<Byte>): Array<Byte> {
        var result = ArrayList<Byte>()
        for (b in headerData) {
            result.add(b)
        }
        let numChunks = plannedChunks.size
        let tocSize = ChunkIndex.sizeForEntries(numChunks)
        while (result.size < headerSize + tocSize) {
            result.add(UInt8(0))
        }
        var dataOffset: Int64 = headerSize + tocSize
        var idx: Int64 = 0
        while (idx < plannedChunks.size) {
            let pc = plannedChunks[idx]
            writeChunkId(result, pc.kind, headerSize + idx * 12)
            writeOffset(result, dataOffset, headerSize + idx * 12 + 4)
            dataOffset += pc.dataSize
            idx += 1
        }
        writeChunkId(result, SENTINEL, headerSize + numChunks * 12)
        writeOffset(result, dataOffset, headerSize + numChunks * 12 + 4)
        result.toArray()
    }
}

public class PlannedChunk {
    public var kind: ChunkId
    public var dataSize: Int64

    public init(kind: ChunkId, dataSize: Int64) {
        this.kind = kind
        this.dataSize = dataSize
    }
}

// ====== 辅助函数 ======

// 读取 4 字节 chunk ID（大端序）
func readChunkId(data: Array<Byte>, offset: Int64): ChunkId {
    if (offset + 4 > data.size) {
        return 0
    }
    ((UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16) |
        (UInt32(data[offset + 2]) << 8) | UInt32(data[offset + 3]))
}

// 读取 8 字节偏移量（大端序）
func readOffset(data: Array<Byte>, offset: Int64): Offset {
    if (offset + 8 > data.size) {
        return 0
    }
    var result: Int64 = 0
    var i: Int64 = 0
    while (i < 8) {
        result = (result << 8) | Int64(data[offset + i])
        i += 1
    }
    result
}

// 读取 4 字节无符号整数（大端序）
func readU32(data: Array<Byte>, offset: Int64): Int64 {
    if (offset + 4 > data.size) {
        return 0
    }
    ((Int64(data[offset]) << 24) | (Int64(data[offset + 1]) << 16) |
        (Int64(data[offset + 2]) << 8) | Int64(data[offset + 3]))
}

// 写入 4 字节 chunk ID（大端序）
func writeChunkId(result: ArrayList<Byte>, kind: ChunkId, offset: Int64): Unit {
    if (offset + 4 > result.size) {
        return
    }
    result[offset] = UInt8((kind >> 24) & 0xFF)
    result[offset + 1] = UInt8((kind >> 16) & 0xFF)
    result[offset + 2] = UInt8((kind >> 8) & 0xFF)
    result[offset + 3] = UInt8(kind & 0xFF)
}

// 写入 8 字节偏移量（大端序）
func writeOffset(result: ArrayList<Byte>, value: Offset, offset: Int64): Unit {
    if (offset + 8 > result.size) {
        return
    }
    var i: Int64 = 7
    while (i >= 0) {
        result[offset + i] = UInt8(value >> ((7 - i) * 8) & 0xFF)
        i -= 1
    }
}

// 从 4 个字节构造 chunk ID
public func makeChunkId(b0: Byte, b1: Byte, b2: Byte, b3: Byte): ChunkId {
    (UInt32(b0) << 24) | (UInt32(b1) << 16) | (UInt32(b2) << 8) | UInt32(b3)
}
