// 文件：packetline_test.cj
// 用途：gix_packetline 包的单元测试，全量对齐 Rust gitoxide gix-packetline 测试
// 所属包：gix.gix_packetline
// 对齐来源：gix-packetline/tests/{encode,decode}.rs

package gitoxide.gix_packetline

import std.unittest.*

// ============================================================
// PacketLine.encode 测试 — 对齐 gix-packetline/tests/encode.rs
// ============================================================

@Test
func testPacketLineEncodeSimpleLine(): Unit {
    // 对齐 Rust: encode simple line
    let data = "hello".toArray()
    let encoded = PacketLine.encode(data)
    // 长度前缀 4 字节 + 5 字节数据 = 9 字节
    if (encoded.size != 9) {
        throw Exception("encoded size should be 9, got " + encoded.size.toString())
    }
    // 前 4 字节应为 "0009"
    let prefix = String.fromUtf8([encoded[0], encoded[1], encoded[2], encoded[3]])
    if (prefix != "0009") {
        throw Exception("prefix should be '0009', got '" + prefix + "'")
    }
}

@Test
func testPacketLineEncodeEmptyLine(): Unit {
    // 对齐 Rust: encode empty line — 4 字节长度前缀 "0004"
    let data: Array<Byte> = []
    let encoded = PacketLine.encode(data)
    if (encoded.size != 4) {
        throw Exception("encoded empty line should be 4 bytes, got " + encoded.size.toString())
    }
    let prefix = String.fromUtf8([encoded[0], encoded[1], encoded[2], encoded[3]])
    if (prefix != "0004") {
        throw Exception("prefix should be '0004', got '" + prefix + "'")
    }
}

@Test
func testPacketLineEncodeLongLine(): Unit {
    // 对齐 Rust: encode longer line
    let data = "want e69de29bb2d1d6434b8b29ae775ad8c2e48c5391".toArray()
    let encoded = PacketLine.encode(data)
    let expectedLen = data.size + 4
    if (encoded.size != expectedLen) {
        throw Exception("encoded size should be " + expectedLen.toString() + ", got " + encoded.size.toString())
    }
}

// ============================================================
// PacketLine.decode 测试 — 对齐 gix-packetline/tests/decode.rs
// ============================================================

@Test
func testPacketLineDecodeSimpleLine(): Unit {
    // 对齐 Rust: decode simple line
    let encoded = PacketLine.encode("hello".toArray())
    let decoded = PacketLine.decode(encoded)
    if (decoded.isNone()) {
        throw Exception("decode should succeed")
    }
    let line = decoded.getOrThrow()
    let text = String.fromUtf8(line.data)
    if (text != "hello") {
        throw Exception("decoded data should be 'hello', got '" + text + "'")
    }
}

@Test
func testPacketLineDecodeTooShort(): Unit {
    // 对齐 Rust: decode — data < 4 bytes returns None
    let result = PacketLine.decode([UInt8(0), UInt8(1), UInt8(2)])
    if (!result.isNone()) {
        throw Exception("data < 4 bytes should return None")
    }
}

@Test
func testPacketLineDecodeEmptyData(): Unit {
    // 对齐 Rust: decode — empty data returns None
    let result: ?PacketLine = PacketLine.decode([])
    if (!result.isNone()) {
        throw Exception("empty data should return None")
    }
}

@Test
func testPacketLineDecodeFlushPkt(): Unit {
    // 对齐 Rust: decode — "0000" flush-pkt returns empty data
    let flushData = "0000".toArray()
    let result = PacketLine.decode(flushData)
    if (result.isNone()) {
        throw Exception("flush-pkt should decode")
    }
    if (result.getOrThrow().data.size != 0) {
        throw Exception("flush-pkt should have empty data")
    }
}

@Test
func testPacketLineDecodeTruncatedData(): Unit {
    // 对齐 Rust: decode — length prefix says more data than available
    let data = "0009ab".toArray()
    let result = PacketLine.decode(data)
    if (!result.isNone()) {
        throw Exception("truncated data should return None")
    }
}

@Test
func testPacketLineDecodeRoundTrip(): Unit {
    // 对齐 Rust: encode → decode round-trip
    let original = "want abcdef0123456789".toArray()
    let encoded = PacketLine.encode(original)
    let decoded = PacketLine.decode(encoded)
    if (decoded.isNone()) {
        throw Exception("round-trip decode should succeed")
    }
    let roundTripped = decoded.getOrThrow().data
    if (roundTripped.size != original.size) {
        throw Exception("round-trip size mismatch")
    }
    for (i in 0..original.size) {
        if (roundTripped[i] != original[i]) {
            throw Exception("round-trip data mismatch at index " + i.toString())
        }
    }
}

// ============================================================
// PacketLine.flush/delimiter/responseEnd 测试
// ============================================================

@Test
func testPacketLineFlush(): Unit {
    // 对齐 Rust: flush-pkt is "0000"
    let flush = PacketLine.flush()
    let text = String.fromUtf8(flush)
    if (text != "0000") {
        throw Exception("flush should be '0000', got '" + text + "'")
    }
}

@Test
func testPacketLineDelimiter(): Unit {
    // 对齐 Rust: delimiter-pkt is "0001"
    let delim = PacketLine.delimiter()
    let text = String.fromUtf8(delim)
    if (text != "0001") {
        throw Exception("delimiter should be '0001', got '" + text + "'")
    }
}

@Test
func testPacketLineResponseEnd(): Unit {
    // 对齐 Rust: response-end-pkt is "0002"
    let end = PacketLine.responseEnd()
    let text = String.fromUtf8(end)
    if (text != "0002") {
        throw Exception("responseEnd should be '0002', got '" + text + "'")
    }
}
