// 文件：chunk_test.cj
// 用途：gix_chunk 包的单元测试，全量对齐 Rust gitoxide gix-chunk 测试
// 所属包：gix.gix_chunk
// 对齐来源：gix-chunk/tests/{parse,find}.rs, gix-chunk/src/file/decode.rs

package gitoxide.gix_chunk

import std.unittest.*
import std.collection.*

// ============================================================
// ChunkFile 测试 — 对齐 gix-chunk/tests/parse.rs
// ============================================================

@Test
func testChunkFileCreation(): Unit {
    // 对齐 Rust: ChunkFile::new()
    let cf = ChunkFile()
    if (cf.chunks.size != 0) {
        throw Exception("new ChunkFile should have 0 chunks")
    }
}

@Test
func testChunkFileParseTooShort(): Unit {
    // 对齐 Rust: ChunkFile::parse — 数据不足返回 None
    let result = ChunkFile.parse([UInt8(1), UInt8(2), UInt8(3)])
    if (!result.isNone()) {
        throw Exception("data < 12 bytes should return None")
    }
}

@Test
func testChunkFileParseEmptyData(): Unit {
    // 对齐 Rust: ChunkFile::parse — 空数据
    let result = ChunkFile.parse([])
    if (!result.isNone()) {
        throw Exception("empty data should return None")
    }
}

@Test
func testChunkFileParseZeroChunks(): Unit {
    // 对齐 Rust: gix_chunk::file::Index::from_bytes — numChunks=0 返回错误
    let data = Array<Byte>(24, repeat: UInt8(0))
    let result = ChunkFile.parse(data, 0, 0)
    if (!result.isNone()) {
        throw Exception("numChunks=0 should return None")
    }
}

@Test
func testChunkFileParseValidTwoChunks(): Unit {
    // 对齐 Rust: gix_chunk::file::Index::from_bytes — 两个 chunk 的有效数据
    // 构造一个包含 2 个 chunk 的文件：
    // 头部: signature(4) + version(4) + numChunks(4) = 12 字节
    // TOC: kind1(4)+offset1(8) + kind2(4)+offset2(8) + sentinel(4)+sentinelOffset(8) = 48 字节
    // 数据: chunk1_data(4) + chunk2_data(3) = 7 字节
    var data = ArrayList<Byte>()
    // 头部: signature = "CGPH"
    data.add(UInt8(67)) // C
    data.add(UInt8(71)) // G
    data.add(UInt8(80)) // P
    data.add(UInt8(72)) // H

    // version = 1
    data.add(UInt8(0))
    data.add(UInt8(0))
    data.add(UInt8(0))
    data.add(UInt8(1))
    // numChunks = 2
    data.add(UInt8(0))
    data.add(UInt8(0))
    data.add(UInt8(0))
    data.add(UInt8(2))
    // TOC entry 1: kind = "OIDF", offset = 60 (12+48)
    data.add(UInt8(79)) // O
    data.add(UInt8(73)) // I
    data.add(UInt8(68)) // D
    data.add(UInt8(70)) // F
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0))
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(60))
    // TOC entry 2: kind = "DATA", offset = 64 (60+4)
    data.add(UInt8(68)) // D
    data.add(UInt8(65)) // A
    data.add(UInt8(84)) // T
    data.add(UInt8(65)) // A
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0))
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(64))
    // Sentinel: kind = 0x00000000, offset = 67 (64+3)
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0))
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0))
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(0));
    data.add(UInt8(67))
    // Chunk 1 数据: "abcd" (4 字节)
    data.add(UInt8(97));
    data.add(UInt8(98));
    data.add(UInt8(99));
    data.add(UInt8(100))
    // Chunk 2 数据: "xyz" (3 字节)
    data.add(UInt8(120));
    data.add(UInt8(121));
    data.add(UInt8(122))
    let arr = data.toArray()
    let result = ChunkFile.parse(arr)
    if (result.isNone()) {
        throw Exception("valid chunk file should parse successfully")
    }
    let cf = result.getOrThrow()
    if (cf.chunks.size != 2) {
        throw Exception("should have 2 chunks, got " + cf.chunks.size.toString())
    }
}

// ============================================================
// ChunkIndex 测试 — 对齐 gix-chunk/src/file/index.rs
// ============================================================

@Test
func testChunkIndexOffsetById(): Unit {
    // 对齐 Rust: file::Index::offset_by_id()
    let idx = ChunkIndex()
    idx.entries.add(ChunkIndexEntry(makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70)), 10, 20))
    let found = idx.offsetById(makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70)))
    if (found.isNone()) {
        throw Exception("should find OIDF chunk")
    }
    let entry = found.getOrThrow()
    if (entry.startOffset != 10 || entry.endOffset != 20) {
        throw Exception("offset mismatch")
    }
}

@Test
func testChunkIndexOffsetByIdNotFound(): Unit {
    // 对齐 Rust: file::Index::offset_by_id() — 未找到
    let idx = ChunkIndex()
    idx.entries.add(ChunkIndexEntry(makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70)), 10, 20))
    let found = idx.offsetById(makeChunkId(UInt8(68), UInt8(65), UInt8(84), UInt8(65)))
    if (!found.isNone()) {
        throw Exception("should not find DATA chunk")
    }
}

@Test
func testChunkIndexDataById(): Unit {
    // 对齐 Rust: file::Index::data_by_id()
    let idx = ChunkIndex()
    idx.entries.add(ChunkIndexEntry(makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70)), 0, 4))
    let data = [UInt8(97), UInt8(98), UInt8(99), UInt8(100)]
    let result = idx.dataById(data, makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70)))
    if (result.isNone()) {
        throw Exception("should find data for OIDF")
    }
    let chunkData = result.getOrThrow()
    if (chunkData.size != 4) {
        throw Exception("data size should be 4")
    }
    if (chunkData[0] != UInt8(97) || chunkData[3] != UInt8(100)) {
        throw Exception("data content mismatch")
    }
}

@Test
func testChunkIndexSizeForEntries(): Unit {
    // 对齐 Rust: file::Index::size_for_entries()
    // 每个 entry 12 字节 + 1 个 sentinel = (n+1)*12
    let size = ChunkIndex.sizeForEntries(2)
    if (size != 36) {
        throw Exception("size for 2 entries should be 36, got " + size.toString())
    }
}

// ============================================================
// Chunk 测试
// ============================================================

@Test
func testChunkCreation(): Unit {
    // 对齐 Rust: Chunk 基本构造
    let chunk = Chunk(12345, 100, 50)
    if (chunk.kind != 12345) {
        throw Exception("kind mismatch")
    }
    if (chunk.offset != 100) {
        throw Exception("offset mismatch")
    }
    if (chunk.size != 50) {
        throw Exception("size mismatch")
    }
}

@Test
func testFindChunkById(): Unit {
    // 对齐 Rust: file::Index::offset_by_id() — 通过 ChunkFile 查找
    let cf = ChunkFile()
    cf.chunks.add(Chunk(1111, 0, 10))
    cf.chunks.add(Chunk(2222, 10, 20))
    let found = cf.findChunk(UInt32(2222))
    if (found.isNone()) {
        throw Exception("should find chunk 2222")
    }
    if (found.getOrThrow().kind != UInt32(2222)) {
        throw Exception("found wrong chunk")
    }
}

@Test
func testFindChunkByIdNotFound(): Unit {
    // 对齐 Rust: file::Index::offset_by_id() — 未找到
    let cf = ChunkFile()
    cf.chunks.add(Chunk(1111, 0, 10))
    let found = cf.findChunk(UInt32(9999))
    if (!found.isNone()) {
        throw Exception("should not find chunk 9999")
    }
}

// ============================================================
// 辅助函数测试
// ============================================================

@Test
func testMakeChunkId(): Unit {
    // 对齐 Rust: gix_chunk::Id 构造
    let id = makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70))
    if (id == 0) {
        throw Exception("chunk ID should not be zero")
    }
}

@Test
func testReadChunkIdBigEndian(): Unit {
    // 对齐 Rust: gix_chunk::file::decode — 大端序读取
    let data = [UInt8(0), UInt8(0), UInt8(0), UInt8(2)]
    let id = readChunkId(data, 0)
    if (id != 2) {
        throw Exception("big-endian read should give 2, got " + id.toString())
    }
}

@Test
func testReadOffsetBigEndian(): Unit {
    // 对齐 Rust: gix_chunk::file::decode — 大端序偏移读取
    var data = Array<Byte>(8, repeat: UInt8(0))
    data[7] = UInt8(60)
    let offset = readOffset(data, 0)
    if (offset != 60) {
        throw Exception("big-endian offset should give 60, got " + offset.toString())
    }
}
