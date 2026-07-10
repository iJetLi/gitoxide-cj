// 文件：bitmap_test.cj
// 用途：gix_bitmap 包的单元测试，全量对齐 Rust gitoxide gix-bitmap 测试
// 所属包：gix.gix_bitmap
// 对齐来源：gix-bitmap/tests/{get,set,clear}.rs

package gitoxide.gix_bitmap

import std.unittest.*

// ============================================================
// Bitmap 测试 — 对齐 gix-bitmap/tests/get.rs
// ============================================================

@Test
func testBitmapGetUnset(): Unit {
    // 对齐 Rust: Bitmap::get — 未设置的位返回 false
    let bm = Bitmap(64)
    for (i in 0..64) {
        if (bm.get(i)) {
            throw Exception("unset bit " + i.toString() + " should be false")
        }
    }
}

@Test
func testBitmapGetOutOfRange(): Unit {
    // 对齐 Rust: Bitmap::get — 超出范围的位返回 false
    let bm = Bitmap(8)
    if (bm.get(100)) {
        throw Exception("out-of-range bit should return false")
    }
}

// ============================================================
// Bitmap 测试 — 对齐 gix-bitmap/tests/set.rs
// ============================================================

@Test
func testBitmapSetAndGet(): Unit {
    // 对齐 Rust: Bitmap::set + get
    let bm = Bitmap(64)
    bm.set(0)
    bm.set(7)
    bm.set(63)
    if (!bm.get(0)) {
        throw Exception("bit 0 should be set")
    }
    if (!bm.get(7)) {
        throw Exception("bit 7 should be set")
    }
    if (!bm.get(63)) {
        throw Exception("bit 63 should be set")
    }
    if (bm.get(1)) {
        throw Exception("bit 1 should not be set")
    }
}

@Test
func testBitmapSetMultipleBits(): Unit {
    // 对齐 Rust: Bitmap::set — 多个位
    let bm = Bitmap(16)
    for (i in 0..16) {
        bm.set(i)
    }
    for (i in 0..16) {
        if (!bm.get(i)) {
            throw Exception("all bits should be set")
        }
    }
}

@Test
func testBitmapSetSameBitTwice(): Unit {
    // 对齐 Rust: Bitmap::set — 重复设置同一位
    let bm = Bitmap(8)
    bm.set(3)
    bm.set(3)
    if (!bm.get(3)) {
        throw Exception("bit 3 should be set")
    }
}

// ============================================================
// Bitmap 测试 — 对齐 gix-bitmap/tests/clear.rs
// ============================================================

@Test
func testBitmapClear(): Unit {
    // 对齐 Rust: Bitmap::clear
    let bm = Bitmap(8)
    bm.set(3)
    if (!bm.get(3)) {
        throw Exception("bit 3 should be set before clear")
    }
    bm.clear(3)
    if (bm.get(3)) {
        throw Exception("bit 3 should be cleared")
    }
}

@Test
func testBitmapClearUnsetBit(): Unit {
    // 对齐 Rust: Bitmap::clear — 清除未设置的位
    let bm = Bitmap(8)
    bm.clear(3)
    if (bm.get(3)) {
        throw Exception("cleared unset bit should still be false")
    }
}

// ============================================================
// Bitmap 边界测试
// ============================================================

@Test
func testBitmapEmptyCreation(): Unit {
    // 对齐 Rust: Bitmap::new() — 空位图
    let bm = Bitmap()
    if (bm.size() != 0) {
        throw Exception("empty bitmap size should be 0")
    }
}

@Test
func testBitmapSizeCreation(): Unit {
    // 对齐 Rust: Bitmap::with_capacity(size)
    let bm = Bitmap(100)
    if (bm.size() < 100) {
        throw Exception("bitmap size should be at least 100")
    }
}

@Test
func testBitmapSetBitBeyondInitialSize(): Unit {
    // 对齐 Rust: Bitmap::set — 超出初始大小的位
    let bm = Bitmap(8)
    bm.set(100)
    if (!bm.get(100)) {
        throw Exception("bit 100 should be set after auto-expansion")
    }
}

@Test
func testBitmapFirstAndLastBit(): Unit {
    // 对齐 Rust: Bitmap — 首位和末位
    let bm = Bitmap(128)
    bm.set(0)
    bm.set(127)
    if (!bm.get(0)) {
        throw Exception("first bit should be set")
    }
    if (!bm.get(127)) {
        throw Exception("last bit should be set")
    }
    if (bm.get(64)) {
        throw Exception("middle bit should not be set")
    }
}

// ============================================================
// Bitmap 位操作补充测试 — 对齐 gix-bitmap/src/lib.rs
// ============================================================

@Test
func testBitmapSetAndClearAlternating(): Unit {
    // 对齐 Rust: Bitmap set/clear 交替操作
    let bm = Bitmap(16)
    bm.set(0)
    bm.set(2)
    bm.set(4)
    bm.clear(2)
    if (!bm.get(0)) {
        throw Exception("bit 0 should be set")
    }
    if (bm.get(1)) {
        throw Exception("bit 1 should not be set")
    }
    if (bm.get(2)) {
        throw Exception("bit 2 should be cleared")
    }
    if (!bm.get(4)) {
        throw Exception("bit 4 should be set")
    }
}

@Test
func testBitmapClearThenSet(): Unit {
    // 对齐 Rust: Bitmap clear 后再 set
    let bm = Bitmap(8)
    bm.set(3)
    bm.clear(3)
    if (bm.get(3)) {
        throw Exception("bit 3 should be cleared")
    }
    bm.set(3)
    if (!bm.get(3)) {
        throw Exception("bit 3 should be set again")
    }
}

@Test
func testBitmapByteBoundaryBits(): Unit {
    // 对齐 Rust: Bitmap 跨字节边界位操作
    let bm = Bitmap(24)
    bm.set(7)
    bm.set(8)
    bm.set(15)
    bm.set(16)
    if (!bm.get(7)) {
        throw Exception("bit 7 (byte 0 last) should be set")
    }
    if (!bm.get(8)) {
        throw Exception("bit 8 (byte 1 first) should be set")
    }
    if (!bm.get(15)) {
        throw Exception("bit 15 (byte 1 last) should be set")
    }
    if (!bm.get(16)) {
        throw Exception("bit 16 (byte 2 first) should be set")
    }
    if (bm.get(6)) {
        throw Exception("bit 6 should not be set")
    }
    if (bm.get(9)) {
        throw Exception("bit 9 should not be set")
    }
}

@Test
func testBitmapAllBitsInByte(): Unit {
    // 对齐 Rust: Bitmap 设置字节中所有位
    let bm = Bitmap(8)
    for (i in 0..8) {
        bm.set(i)
    }
    for (i in 0..8) {
        if (!bm.get(i)) {
            throw Exception("all bits in byte should be set")
        }
    }
}

@Test
func testBitmapClearAllBitsInByte(): Unit {
    // 对齐 Rust: Bitmap 清除字节中所有位
    let bm = Bitmap(8)
    for (i in 0..8) {
        bm.set(i)
    }
    for (i in 0..8) {
        bm.clear(i)
    }
    for (i in 0..8) {
        if (bm.get(i)) {
            throw Exception("all bits should be cleared")
        }
    }
}

@Test
func testBitmapSetClearPattern(): Unit {
    // 对齐 Rust: Bitmap 设置/清除交替模式
    let bm = Bitmap(16)
    for (i in 0..16) {
        if (i % 2 == 0) {
            bm.set(i)
        }
    }
    for (i in 0..16) {
        if (i % 2 == 0) {
            if (!bm.get(i)) {
                throw Exception("even bit should be set")
            }
        } else {
            if (bm.get(i)) {
                throw Exception("odd bit should not be set")
            }
        }
    }
}

@Test
func testBitmapAutoExpansion(): Unit {
    // 对齐 Rust: Bitmap 自动扩展
    let bm = Bitmap(8)
    bm.set(200)
    if (!bm.get(200)) {
        throw Exception("bit 200 should be set after expansion")
    }
    if (bm.get(100)) {
        throw Exception("bit 100 should not be set")
    }
    if (bm.get(50)) {
        throw Exception("bit 50 should not be set")
    }
}

@Test
func testBitmapSizeAfterExpansion(): Unit {
    // 对齐 Rust: Bitmap 扩展后 size
    let bm = Bitmap(8)
    bm.set(200)
    if (bm.size() < 201) {
        throw Exception("size should be at least 201 after setting bit 200")
    }
}

// ============================================================
// Bitmap 补充测试 — 对齐 gix-bitmap/tests/bitmap.rs
// ============================================================

@Test
func testBitmapZeroPaddingBitsAccepted(): Unit {
    // 对齐 Rust: fuzzed::zero_padding_bits_in_last_literal_word_are_accepted
    let bm = Bitmap(3)
    bm.set(0)
    bm.set(2)
    if (!bm.get(0)) {
        throw Exception("bit 0 should be set")
    }
    if (!bm.get(2)) {
        throw Exception("bit 2 should be set")
    }
    if (bm.get(1)) {
        throw Exception("bit 1 should not be set (zero padding)")
    }
}

@Test
func testBitmapSingleBitAtVariousPositions(): Unit {
    // 对齐 Rust: Bitmap — 在不同位置设置单个位
    for (pos in [0, 1, 7, 8, 15, 16, 31, 32, 63, 64, 127, 128]) {
        let bm = Bitmap(pos + 1)
        bm.set(pos)
        if (!bm.get(pos)) {
            throw Exception("bit " + pos.toString() + " should be set")
        }
        if (pos > 0 && bm.get(pos - 1)) {
            throw Exception("bit before " + pos.toString() + " should not be set")
        }
        bm.clear(pos)
        if (bm.get(pos)) {
            throw Exception("bit " + pos.toString() + " should be cleared")
        }
    }
}

@Test
func testBitmapSetClearRepeatedly(): Unit {
    // 对齐 Rust: Bitmap — 重复设置和清除
    let bm = Bitmap(8)
    for (i in 0..10) {
        bm.set(3)
        if (!bm.get(3)) {
            throw Exception("bit 3 should be set at iteration " + i.toString())
        }
        bm.clear(3)
        if (bm.get(3)) {
            throw Exception("bit 3 should be cleared at iteration " + i.toString())
        }
    }
}

@Test
func testBitmapLargeSize(): Unit {
    // 对齐 Rust: Bitmap — 大位图
    let bm = Bitmap(1024)
    bm.set(0)
    bm.set(512)
    bm.set(1023)
    if (!bm.get(0)) {
        throw Exception("bit 0 should be set")
    }
    if (!bm.get(512)) {
        throw Exception("bit 512 should be set")
    }
    if (!bm.get(1023)) {
        throw Exception("bit 1023 should be set")
    }
    if (bm.get(1)) {
        throw Exception("bit 1 should not be set")
    }
    if (bm.get(511)) {
        throw Exception("bit 511 should not be set")
    }
}

@Test
func testBitmapEmptyBitmapGetAlwaysFalse(): Unit {
    // 对齐 Rust: Bitmap — 空位图 get 始终返回 false
    let bm = Bitmap()
    if (bm.get(0)) {
        throw Exception("empty bitmap get(0) should be false")
    }
    if (bm.get(100)) {
        throw Exception("empty bitmap get(100) should be false")
    }
}

@Test
func testBitmapSetAutoExpands(): Unit {
    // 对齐 Rust: Bitmap — set 自动扩展
    let bm = Bitmap(8)
    bm.set(100)
    if (!bm.get(100)) {
        throw Exception("bit 100 should be set after auto-expand")
    }
    if (bm.get(50)) {
        throw Exception("bit 50 should not be set")
    }
}

@Test
func testBitmapCountAllZero(): Unit {
    // 对齐 Rust: Bitmap::count — 全零
    let bm = Bitmap(64)
    if (bm.count() != 0) {
        throw Exception("count of all-zero bitmap should be 0")
    }
}

@Test
func testBitmapCountAllSet(): Unit {
    // 对齐 Rust: Bitmap::count — 全设置
    let bm = Bitmap(8)
    for (i in 0..8) {
        bm.set(i)
    }
    if (bm.count() != 8) {
        throw Exception("count of all-set 8-bit bitmap should be 8, got " + bm.count().toString())
    }
}

@Test
func testBitmapCountSparse(): Unit {
    // 对齐 Rust: Bitmap::count — 稀疏
    let bm = Bitmap(64)
    bm.set(0)
    bm.set(31)
    bm.set(63)
    if (bm.count() != 3) {
        throw Exception("count of sparse bitmap should be 3, got " + bm.count().toString())
    }
}

@Test
func testBitmapTogglePattern(): Unit {
    // 对齐 Rust: Bitmap — 交替设置和清除
    let bm = Bitmap(16)
    for (i in 0..16) {
        if (i % 3 == 0) {
            bm.set(i)
        }
    }
    var count: Int64 = 0
    for (i in 0..16) {
        if (bm.get(i)) {
            count += 1
        }
    }
    // 0,3,6,9,12,15 = 6 个位被设置
    if (count != 6) {
        throw Exception("expected 6 set bits, got " + count.toString())
    }
}
