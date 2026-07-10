// 文件：index_writer.cj
// 用途：实现 pack index v2 文件的写入功能，对齐 Rust gix-pack/src/index/encode.rs
// 所属包：gix.gix_pack
// 关键类型：IndexWriter

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*
import std.fs.*

// pack index 写入器，生成 v2 格式的索引文件
public class IndexWriter {
    // 哈希算法类型
    public var hashKind: HashKind
    // pack 校验和（可选，由调用者提供）
    public var packChecksum: ?ObjectId

    // 构造函数
    // 参数 hashKind：哈希算法类型
    public init(hashKind: HashKind) {
        this.hashKind = hashKind
        this.packChecksum = None
    }

    // 将索引条目写入文件
    // 生成 v2 格式的 pack index：魔数、版本号、fanout 表、对象名、CRC32、偏移量
    // 参数 entries：索引条目列表
    // 参数 path：输出文件路径
    public func write(entries: ArrayList<IndexEntry>, path: String): Unit {
        let bytes = encode(entries)
        try {
            let file = File(path, OpenMode.Write)
            file.write(bytes)
            file.close()
        } catch (_: Exception) {}
    }

    public func encode(entries: ArrayList<IndexEntry>): Array<Byte> {
        var result = ArrayList<Byte>()
        let hashLen = indexHashLenBytes(hashKind)

        // V2 魔数 + 版本号
        result.add(UInt8(0xFF))
        result.add(UInt8(0x74))
        result.add(UInt8(0x4F))
        result.add(UInt8(0x63))
        result.add(UInt8(0))
        result.add(UInt8(0))
        result.add(UInt8(0))
        result.add(UInt8(2))

        // fanout 表
        var fanout = Array<Int64>(256, repeat: Int64(0))
        for (entry in entries) {
            if (entry.oid.bytes.size > 0) {
                let idx = Int64(entry.oid.bytes[0]) & 0xFF
                fanout[idx] += 1
            }
        }
        var cumulative: Int64 = 0
        for (i in 0..256) {
            cumulative += fanout[i]
            writeU32(result, cumulative)
        }

        // 对象名（按 OID 排序）
        for (entry in entries) {
            for (b in entry.oid.bytes) {
                result.add(b)
            }
        }

        // CRC32 表
        for (entry in entries) {
            if (let Some(crc) <- entry.crc32) {
                writeU32(result, crc)
            } else {
                writeU32(result, 0)
            }
        }

        // 4 字节偏移量 + 大偏移量
        var largeOffsets = ArrayList<Int64>()
        for (entry in entries) {
            let offset = entry.packOffset
            if (offset > LARGE_OFFSET_THRESHOLD) {
                let largeIdx = largeOffsets.size
                largeOffsets.add(offset)
                writeU32(result, Int64(N32_HIGH_BIT) | largeIdx)
            } else {
                writeU32(result, offset)
            }
        }

        // 8 字节大偏移量表
        for (ofs in largeOffsets) {
            writeU64(result, ofs)
        }

        // pack 校验和（调用者需提供，此处写入全零占位）
        // 对齐 Rust: index::encode — pack_checksum 由调用者填入
        if (packChecksum.isSome()) {
            for (b in packChecksum.getOrThrow().bytes) {
                result.add(b)
            }
        } else {
            for (_ in 0..hashLen) {
                result.add(UInt8(0))
            }
        }

        // idx 校验和 — 对前面所有字节计算哈希
        // 对齐 Rust: index::encode — 写入索引后计算尾部校验和
        let idxContentBytes = result.toArray()
        let hasher = GixHasher(hashKind)
        hasher.update(idxContentBytes)
        let idxChecksum = hasher.tryFinalize()
        for (b in idxChecksum.bytes) {
            result.add(b)
        }

        result.toArray()
    }

    // 带 pack 校验和的编码
    // 对齐 Rust: index::encode — 从 pack 文件获取校验和
    public func encodeWithPackChecksum(entries: ArrayList<IndexEntry>, packChecksum: ObjectId): Array<Byte> {
        this.packChecksum = Some(packChecksum)
        encode(entries)
    }

    public static func fanout(entries: ArrayList<IndexEntry>): Array<Int64> {
        var fan = Array<Int64>(256, repeat: Int64(0))
        for (entry in entries) {
            if (entry.oid.bytes.size > 0) {
                let idx = Int64(entry.oid.bytes[0]) & 0xFF
                fan[idx] += 1
            }
        }
        var cumulative: Int64 = 0
        for (i in 0..256) {
            cumulative += fan[i]
            fan[i] = cumulative
        }
        fan
    }
}

func writeU32(result: ArrayList<Byte>, value: Int64): Unit {
    result.add(UInt8((value >> 24) & 0xFF))
    result.add(UInt8((value >> 16) & 0xFF))
    result.add(UInt8((value >> 8) & 0xFF))
    result.add(UInt8(value & 0xFF))
}

func writeU64(result: ArrayList<Byte>, value: Int64): Unit {
    result.add(UInt8((value >> 56) & 0xFF))
    result.add(UInt8((value >> 48) & 0xFF))
    result.add(UInt8((value >> 40) & 0xFF))
    result.add(UInt8((value >> 32) & 0xFF))
    result.add(UInt8((value >> 24) & 0xFF))
    result.add(UInt8((value >> 16) & 0xFF))
    result.add(UInt8((value >> 8) & 0xFF))
    result.add(UInt8(value & 0xFF))
}
