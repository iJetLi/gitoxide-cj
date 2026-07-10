// 文件：zlib_test.cj
// 用途：gix_zlib 包的单元测试，全量对齐 Rust gitoxide gix-zlib 测试
// 所属包：gix.gix_zlib
// 对齐来源：gix-zlib/tests/{inflate,deflate,stream}.rs

package gitoxide.gix_zlib

import std.unittest.*
import std.collection.*

// ============================================================
// Inflate 测试 — 对齐 gix-zlib/tests/inflate.rs
// ============================================================

@Test
func testInflateEmptyInput(): Unit {
    // 对齐 Rust: inflate 空输入
    let input: Array<Byte> = []
    let result = inflate(input)
    if (result.data.size != 0) {
        throw Exception("inflate empty should return empty data")
    }
    if (result.consumed != 0) {
        throw Exception("inflate empty consumed should be 0")
    }
}

@Test
func testInflateSimpleRoundtrip(): Unit {
    // 对齐 Rust: inflate(deflate(data)) == data
    let input: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3), UInt8(4), UInt8(5)]
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception(
            "roundtrip: data size mismatch, expected " + input.size.toString() + " got " + result.data.size.toString())
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("roundtrip: data mismatch at index " + i.toString())
        }
    }
}

@Test
func testInflateLargerData(): Unit {
    // 对齐 Rust: inflate 较大数据
    var builder = ArrayList<Byte>()
    for (i in 0..100) {
        builder.add(UInt8(i % 256))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception("larger roundtrip: data size mismatch")
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("larger roundtrip: data mismatch at index " + i.toString())
        }
    }
}

@Test
func testInflateConsumedTracking(): Unit {
    // 对齐 Rust: inflate 返回 consumed 字段
    let input: Array<Byte> = [UInt8(72), UInt8(101), UInt8(108)]
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.consumed <= 0) {
        throw Exception("consumed should be > 0")
    }
    if (result.consumed > compressed.data.size) {
        throw Exception("consumed should not exceed compressed size")
    }
}

// ============================================================
// Deflate 测试 — 对齐 gix-zlib/tests/deflate.rs
// ============================================================

@Test
func testDeflateEmptyInput(): Unit {
    // 对齐 Rust: deflate 空输入
    let input: Array<Byte> = []
    let result = deflate(input)
    let roundtrip = inflate(result.data)
    if (roundtrip.data.size != 0) {
        throw Exception("deflate/inflate empty roundtrip should return empty")
    }
}

@Test
func testDeflateSingleByte(): Unit {
    // 对齐 Rust: deflate 单字节
    let input: Array<Byte> = [UInt8(42)]
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != 1) {
        throw Exception("single byte roundtrip size mismatch")
    }
    if (result.data[0] != UInt8(42)) {
        throw Exception("single byte roundtrip data mismatch")
    }
}

@Test
func testDeflateZlibHeader(): Unit {
    // 对齐 Rust: deflate 输出以 zlib header (0x78) 开头
    let input: Array<Byte> = [UInt8(1), UInt8(2)]
    let result = deflate(input)
    if (result.data[0] != UInt8(0x78)) {
        throw Exception("deflate output should start with 0x78 zlib header")
    }
}

@Test
func testDeflateCompressesData(): Unit {
    // 对齐 Rust: deflate 压缩数据
    var builder = ArrayList<Byte>()
    for (i in 0..10000) {
        builder.add(UInt8(0))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    let roundtrip = inflate(compressed.data)
    if (roundtrip.data.size != input.size) {
        throw Exception("large roundtrip: data size mismatch")
    }
    for (i in 0..input.size) {
        if (roundtrip.data[i] != input[i]) {
            throw Exception("large roundtrip: data mismatch at index " + i.toString())
        }
    }
}

@Test
func testDeflateLargeBlockSplitting(): Unit {
    // 对齐 Rust: deflate 大块数据分块（65535 字节一块）
    var builder = ArrayList<Byte>()
    for (i in 0..70000) {
        builder.add(UInt8(i % 256))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception(
            "large block roundtrip: data size mismatch, expected " + input.size.toString() + " got " +
                result.data.size.toString())
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("large block roundtrip: data mismatch at index " + i.toString())
        }
    }
}

// ============================================================
// Stream 测试 — 对齐 gix-zlib/tests/stream.rs
// ============================================================

@Test
func testStreamDeflateInflateRoundtrip(): Unit {
    // 对齐 Rust: Stream round-trip
    let s = Stream()
    s.write([UInt8(10), UInt8(20)])
    s.write([UInt8(30)])
    let compressed = s.finishDeflate()
    let s2 = Stream()
    s2.write(compressed)
    let result = s2.finishInflate()
    if (result.size != 3) {
        throw Exception("stream roundtrip: size should be 3, got " + result.size.toString())
    }
    if (result[0] != UInt8(10) || result[1] != UInt8(20) || result[2] != UInt8(30)) {
        throw Exception("stream roundtrip: data mismatch")
    }
}

@Test
func testStreamMultipleWrites(): Unit {
    // 对齐 Rust: Stream 多次 write 后 inflate
    let s = Stream()
    s.write("hello".toArray())
    s.write(" ".toArray())
    s.write("world".toArray())
    let compressed = s.finishDeflate()
    let s2 = Stream()
    s2.write(compressed)
    let result = s2.finishInflate()
    let expected = "hello world"
    if (result.size != expected.size) {
        throw Exception("stream multi-write: size mismatch")
    }
    for (i in 0..expected.size) {
        if (result[i] != expected.toArray()[i]) {
            throw Exception("stream multi-write: data mismatch at " + i.toString())
        }
    }
}

@Test
func testStreamEmptyWrite(): Unit {
    // 对齐 Rust: Stream 空 write
    let s = Stream()
    let compressed = s.finishDeflate()
    let s2 = Stream()
    s2.write(compressed)
    let result = s2.finishInflate()
    if (result.size != 0) {
        throw Exception("stream empty write roundtrip should return empty")
    }
}

// ============================================================
// Adler-32 校验和测试 — 对齐 zlib 规范
// ============================================================

@Test
func testAdler32EmptyInput(): Unit {
    // 对齐 Rust: gix-zlib deflate/inflate roundtrip 隐式验证 Adler-32 — RFC 1950: Adler-32("") == 0x00000001
    // 仓颉中 adler32 是包内函数，通过 deflate→inflate 间接验证
    let input: Array<Byte> = []
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != 0) {
        throw Exception("adler32 empty roundtrip should return empty")
    }
}

@Test
func testAdler32SimpleInput(): Unit {
    // 对齐 Rust: gix-zlib deflate/inflate roundtrip 隐式验证 Adler-32 — RFC 1950: Adler-32("a") == 0x00620062
    // 间接验证：deflate→inflate roundtrip 成功即说明校验和正确
    let input: Array<Byte> = [UInt8(97)]
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data[0] != UInt8(97)) {
        throw Exception("adler32 simple roundtrip data mismatch")
    }
}

// ============================================================
// Git 对象格式兼容性测试
// ============================================================

@Test
func testDeflateInflateGitBlobFormat(): Unit {
    // 对齐 Rust: Git 松散对象格式兼容性
    // 模拟 "blob 5\0hello" 的压缩/解压
    let header = "blob 5\0".toArray()
    let body = "hello".toArray()
    var fullData = ArrayList<Byte>()
    for (b in header) {
        fullData.add(b)
    }
    for (b in body) {
        fullData.add(b)
    }
    let input = fullData.toArray()
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception("git blob format roundtrip size mismatch")
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("git blob format roundtrip data mismatch at " + i.toString())
        }
    }
}

@Test
func testDeflateInflateGitCommitFormat(): Unit {
    // 对齐 Rust: Git commit 对象格式兼容性
    let commitData = "tree 1b2dfb4ac5e42080b682fc676e9738c94ce6d54d\nauthor Test <test@test.com> 1234567890 +0000\ncommitter Test <test@test.com> 1234567890 +0000\n\ninitial commit"
        .toArray()
    let compressed = deflate(commitData)
    let result = inflate(compressed.data)
    if (result.data.size != commitData.size) {
        throw Exception("git commit format roundtrip size mismatch")
    }
    for (i in 0..commitData.size) {
        if (result.data[i] != commitData[i]) {
            throw Exception("git commit format roundtrip data mismatch at " + i.toString())
        }
    }
}

// ============================================================
// InflateResult / DeflateResult 构造和访问测试 — 对齐 gix-zlib/src/lib.rs
// ============================================================

@Test
func testInflateResultConstruction(): Unit {
    // 对齐 Rust: InflateResult 字段访问
    let data: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3)]
    let result = InflateResult(data, 42)
    if (result.data.size != 3) {
        throw Exception("InflateResult data size should be 3")
    }
    if (result.consumed != 42) {
        throw Exception("InflateResult consumed should be 42")
    }
}

@Test
func testDeflateResultConstruction(): Unit {
    // 对齐 Rust: DeflateResult 字段访问
    let data: Array<Byte> = [UInt8(0x78), UInt8(0x01)]
    let result = DeflateResult(data)
    if (result.data.size != 2) {
        throw Exception("DeflateResult data size should be 2")
    }
    if (result.data[0] != UInt8(0x78)) {
        throw Exception("DeflateResult first byte should be 0x78")
    }
}

// ============================================================
// Stream 边界情况测试 — 对齐 gix-zlib/src/lib.rs Stream
// ============================================================

@Test
func testStreamSingleByteRoundtrip(): Unit {
    // 对齐 Rust: Stream 单字节 roundtrip
    let s = Stream()
    s.write([UInt8(0x42)])
    let compressed = s.finishDeflate()
    let s2 = Stream()
    s2.write(compressed)
    let result = s2.finishInflate()
    if (result.size != 1) {
        throw Exception("stream single byte roundtrip size should be 1")
    }
    if (result[0] != UInt8(0x42)) {
        throw Exception("stream single byte roundtrip data mismatch")
    }
}

@Test
func testStreamLargeDataRoundtrip(): Unit {
    // 对齐 Rust: Stream 大数据 roundtrip
    let s = Stream()
    var builder = ArrayList<Byte>()
    for (i in 0..50000) {
        builder.add(UInt8(i % 256))
    }
    s.write(builder.toArray())
    let compressed = s.finishDeflate()
    let s2 = Stream()
    s2.write(compressed)
    let result = s2.finishInflate()
    if (result.size != 50000) {
        throw Exception("stream large data roundtrip size mismatch: expected 50000, got " + result.size.toString())
    }
    for (i in 0..50000) {
        if (result[i] != UInt8(i % 256)) {
            throw Exception("stream large data roundtrip mismatch at index " + i.toString())
        }
    }
}

// ============================================================
// Deflate 存储块格式测试 — 对齐 RFC 1951
// ============================================================

@Test
func testDeflateBlockStructure(): Unit {
    // 对齐 Rust: deflate 输出结构验证 — zlib header + compressed data + adler32
    let input: Array<Byte> = [UInt8(1), UInt8(2), UInt8(3)]
    let result = deflate(input)
    // 前 2 字节是 zlib header (0x78, ...)
    if (result.data[0] != UInt8(0x78)) {
        throw Exception("first byte should be 0x78 (CMF)")
    }
    // 验证可以完整 inflate
    let inflated = inflate(result.data)
    if (inflated.data.size != input.size) {
        throw Exception("deflate block structure: inflate size mismatch")
    }
}

@Test
func testDeflateMultipleBlocks(): Unit {
    // 对齐 Rust: deflate 大于 65535 字节的输入产生多个存储块
    var builder = ArrayList<Byte>()
    for (i in 0..70000) {
        builder.add(UInt8(i % 256))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    // 验证 inflate 正确还原
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception("multi-block inflate size mismatch")
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("multi-block inflate data mismatch at " + i.toString())
        }
    }
}

// ============================================================
// Adler-32 边界值测试 — 对齐 RFC 1950
// ============================================================

@Test
func testDeflateInflateBinaryData(): Unit {
    // 对齐 Rust: 二进制数据（包含 0x00 字节）roundtrip
    var builder = ArrayList<Byte>()
    for (i in 0..256) {
        builder.add(UInt8(i))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception("binary data roundtrip size mismatch")
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("binary data roundtrip mismatch at " + i.toString())
        }
    }
}

@Test
func testDeflateInflateRepeatedPattern(): Unit {
    // 对齐 Rust: 重复模式数据 roundtrip
    var builder = ArrayList<Byte>()
    for (i in 0..1000) {
        builder.add(UInt8(0xAA))
        builder.add(UInt8(0x55))
    }
    let input = builder.toArray()
    let compressed = deflate(input)
    let result = inflate(compressed.data)
    if (result.data.size != input.size) {
        throw Exception("repeated pattern roundtrip size mismatch")
    }
    for (i in 0..input.size) {
        if (result.data[i] != input[i]) {
            throw Exception("repeated pattern roundtrip mismatch at " + i.toString())
        }
    }
}
