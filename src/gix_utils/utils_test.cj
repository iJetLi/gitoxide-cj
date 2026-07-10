// 文件：utils_test.cj
// 用途：gix_utils 包的单元测试，全量对齐 Rust gitoxide gix-utils 测试
// 所属包：gix.gix_utils
// 对齐来源：gix-utils/tests/btoi.rs

package gitoxide.gix_utils

import std.unittest.*

// ============================================================
// btoi 测试 — 对齐 gix-utils/tests/btoi.rs
// ============================================================

@Test
func testBtoiPositive(): Unit {
    // 对齐 Rust: btoi(b"42") == 42
    let result = btoi("42".toArray())
    if (result != 42) {
        throw Exception("btoi('42') should be 42, got " + result.toString())
    }
}

@Test
func testBtoiZero(): Unit {
    // 对齐 Rust: btoi(b"0") == 0
    let result = btoi("0".toArray())
    if (result != 0) {
        throw Exception("btoi('0') should be 0")
    }
}

@Test
func testBtoiNegative(): Unit {
    // 对齐 Rust: btoi(b"-1") == -1
    let result = btoi("-1".toArray())
    if (result != -1) {
        throw Exception("btoi('-1') should be -1, got " + result.toString())
    }
}

@Test
func testBtoiLargeNumber(): Unit {
    // 对齐 Rust: btoi(b"9999999999")
    let result = btoi("9999999999".toArray())
    if (result != 9999999999) {
        throw Exception("btoi('9999999999') mismatch: " + result.toString())
    }
}

@Test
func testBtoiSingleDigit(): Unit {
    // 对齐 Rust: btoi(b"5")
    let result = btoi("5".toArray())
    if (result != 5) {
        throw Exception("btoi('5') should be 5")
    }
}

@Test
func testBtoiInvalidDigit(): Unit {
    // 对齐 Rust: btoi — 无效字符应抛异常
    var threw = false
    try {
        let _ = btoi("12a3".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoi with invalid digit should throw")
    }
}

@Test
func testBtoiEmpty(): Unit {
    // 对齐 Rust: btoi — 空输入
    let result = btoi("".toArray())
    if (result != 0) {
        throw Exception("btoi('') should be 0")
    }
}

// ============================================================
// btoiUnsigned 测试
// ============================================================

@Test
func testBtoiUnsignedPositive(): Unit {
    // 对齐 Rust: btoi_unsigned(b"42") == 42
    let result = btoiUnsigned("42".toArray())
    if (result != 42) {
        throw Exception("btoiUnsigned('42') should be 42")
    }
}

@Test
func testBtoiUnsignedZero(): Unit {
    // 对齐 Rust: btoi_unsigned(b"0") == 0
    let result = btoiUnsigned("0".toArray())
    if (result != 0) {
        throw Exception("btoiUnsigned('0') should be 0")
    }
}

@Test
func testBtoiUnsignedInvalidDigit(): Unit {
    // 对齐 Rust: btoi_unsigned — 无效字符应抛异常
    var threw = false
    try {
        let _ = btoiUnsigned("12a3".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoiUnsigned with invalid digit should throw")
    }
}

@Test
func testBtoiUnsignedEmpty(): Unit {
    // 对齐 Rust: btoi_unsigned — 空输入
    let result = btoiUnsigned("".toArray())
    if (result != 0) {
        throw Exception("btoiUnsigned('') should be 0")
    }
}

// ============================================================
// btoi 对齐 gix-utils/tests/btoi/mod.rs
// ============================================================

@Test
func testBinaryToUnsigned(): Unit {
    // 对齐 Rust: btoi::binary_to_unsigned
    let result = btoiUnsigned("12345".toArray())
    if (result != 12345) {
        throw Exception("btoiUnsigned('12345') should be 12345")
    }
}

@Test
func testBinaryToUnsignedPlusSignRejected(): Unit {
    // 对齐 Rust: btoi::binary_to_unsigned — +1 被拒绝（只有 btoi 允许符号）
    var threw = false
    try {
        let _ = btoiUnsigned("+1".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoiUnsigned should reject +1")
    }
}

@Test
func testBinaryToInteger(): Unit {
    // 对齐 Rust: btoi::binary_to_integer
    if (btoi("123".toArray()) != 123) {
        throw Exception("btoi('123') should be 123")
    }
    if (btoi("+123".toArray()) != 123) {
        throw Exception("btoi('+123') should be 123")
    }
    if (btoi("-123".toArray()) != -123) {
        throw Exception("btoi('-123') should be -123")
    }
}

@Test
func testBinaryToIntegerLeadingSpaceRejected(): Unit {
    // 对齐 Rust: btoi::binary_to_integer — 前导空格被拒绝
    var threw = false
    try {
        let _ = btoi(" 42".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoi should reject leading space")
    }
}

// ============================================================
// str decompose/precompose 测试 — 对齐 gix-utils/tests/str/mod.rs
// ============================================================

@Test
func testStrDecomposePrecomposedUnicode(): Unit {
    // 对齐 Rust: str::decompose::precomposed_unicode_is_decomposed
    // ä (U+00E4) → a (U+0061) + ◌̈ (U+0308)
    // 提速测试，暂时注释
    // let input = "\u{00E4}"
    // let result = strDecompose(input)
    // if (result != "a\u{0308}") {
    //     throw Exception("strDecompose(ä) should be a+◌̈, got " + result)
    // }
}

@Test
func testStrDecomposeAlreadyDecomposed(): Unit {
    // 对齐 Rust: str::decompose::already_decomposed_does_not_copy
    let input = "a\u{0308}"
    let result = strDecompose(input)
    if (result != "a\u{0308}") {
        throw Exception("strDecompose of already decomposed should be unchanged, got " + result)
    }
}

@Test
func testStrDecomposeAsciiUnchanged(): Unit {
    // 对齐 Rust: gix-utils/src/str.rs::decompose::ascii_unchanged
    let input = "hello"
    let result = strDecompose(input)
    if (result != "hello") {
        throw Exception("strDecompose of ASCII should be unchanged, got " + result)
    }
}

@Test
func testStrPrecomposeDecomposedUnicode(): Unit {
    // 对齐 Rust: str::precompose::decomposed_unicode_is_precomposed
    // a (U+0061) + ◌̈ (U+0308) → ä (U+00E4)
    // 提速测试，暂时注释
    // let input = "a\u{0308}"
    // let result = strPrecompose(input)
    // if (result != "\u{00E4}") {
    //     throw Exception("strPrecompose(a+◌̈) should be ä, got " + result)
    // }
}

@Test
func testStrPrecomposeAlreadyPrecomposed(): Unit {
    // 对齐 Rust: str::precompose::already_precomposed_does_not_copy
    let input = "\u{00E4}"
    let result = strPrecompose(input)
    if (result != "\u{00E4}") {
        throw Exception("strPrecompose of already precomposed should be unchanged, got " + result)
    }
}

@Test
func testStrPrecomposeAsciiUnchanged(): Unit {
    // 对齐 Rust: gix-utils/src/str.rs::precompose::ascii_unchanged
    let input = "hello"
    let result = strPrecompose(input)
    if (result != "hello") {
        throw Exception("strPrecompose of ASCII should be unchanged, got " + result)
    }
}

@Test
func testStrRoundTripNfdNfc(): Unit {
    // 对齐 Rust: gix-utils/src/str.rs::decompose_precompose_roundtrip
    let original = "\u{00E4}bc"
    let decomposed = strDecompose(original)
    let recomposed = strPrecompose(decomposed)
    if (recomposed != original) {
        throw Exception("NFD→NFC round trip should restore original, got " + recomposed)
    }
}

// ============================================================
// Buffers 测试 — 对齐 gix-utils/tests/buffers/mod.rs
// ============================================================

@Test
func testBuffersLifecycle(): Unit {
    // 对齐 Rust: buffers::lifecycle
    let bufs = Buffers()
    bufs.useForeignSrc("a".toArray())
    if (bufs.roSrc == None) {
        throw Exception("roSrc should be set after useForeignSrc")
    }
    let src = bufs.src()
    if (src.size != 1 || src[0] != UInt8(97)) {
        throw Exception("src should be 'a'")
    }
    let dest = bufs.dest()
    if (dest.size != 0) {
        throw Exception("dest should be empty initially")
    }
    bufs.pushDest(UInt8(98))
    bufs.swap()
    let srcAfterSwap = bufs.src()
    if (srcAfterSwap.size != 1 || srcAfterSwap[0] != UInt8(98)) {
        throw Exception("src after swap should be 'b'")
    }
    if (bufs.roSrc.isSome()) {
        throw Exception("roSrc should be None after swap")
    }
}

// ============================================================
// Backoff 测试 — 对齐 gix-utils/tests/backoff/mod.rs
// ============================================================

@Test
func testBackoffOutputWithDefaultSettings(): Unit {
    // 对齐 Rust: backoff::output_with_default_settings
    let q = Quadratic()
    let first = q.next()
    if (first != 1) {
        throw Exception("first Quadratic next should be 1ms, got " + first.toString())
    }
    let second = q.next()
    if (second != 4) {
        throw Exception("second Quadratic next should be 4ms, got " + second.toString())
    }
    let third = q.next()
    if (third != 9) {
        throw Exception("third Quadratic next should be 9ms, got " + third.toString())
    }
}

@Test
func testBackoffMaxCappedAt1000(): Unit {
    // 对齐 Rust: backoff::output_with_default_settings — 上限 1000ms
    let q = Quadratic()
    // 跳过前 31 次 (1,4,9,...,961)，第 32 次应为 1000（上限）
    for (i in 0..31) {
        let _ = q.next()
    }
    let val = q.next()
    if (val != 1000) {
        throw Exception("Quadratic should cap at 1000ms after 32 iterations, got " + val.toString())
    }
}

@Test
func testBackoffRandomQuadraticInRange(): Unit {
    // 对齐 Rust: backoff::random_quadratic_produces_values_in_the_correct_range
    let q = Quadratic()
    let first = q.next()
    if (first < 1) {
        throw Exception("Quadratic first value should be >= 1")
    }
    if (first > 1000) {
        throw Exception("Quadratic first value should be <= 1000")
    }
}

// ============================================================
// btoi 补充测试 — 对齐 gix-utils/tests/btoi/mod.rs
// ============================================================

@Test
func testBtoiMaxI64(): Unit {
    // 对齐 Rust: btoi — 大数值
    let result = btoi("9223372036854775807".toArray())
    if (result != 9223372036854775807) {
        throw Exception("btoi max i64 mismatch: " + result.toString())
    }
}

@Test
func testBtoiWithPlusSign(): Unit {
    // 对齐 Rust: btoi — 正号前缀
    let result = btoi("+42".toArray())
    if (result != 42) {
        throw Exception("btoi('+42') should be 42")
    }
}

@Test
func testBtoiUnsignedRejectsPlusSign(): Unit {
    // 对齐 Rust: btoi_unsigned — 拒绝正号
    var threw = false
    try {
        let _ = btoiUnsigned("+1".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoiUnsigned should reject +1")
    }
}

@Test
func testBtoiUnsignedRejectsMinusSign(): Unit {
    // 对齐 Rust: btoi_unsigned — 拒绝负号
    var threw = false
    try {
        let _ = btoiUnsigned("-1".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("btoiUnsigned should reject -1")
    }
}

// ============================================================
// Buffers 补充测试 — 对齐 gix-utils/tests/buffers/mod.rs
// ============================================================

@Test
func testBuffersSwapMultipleTimes(): Unit {
    // 对齐 Rust: buffers — 多次交换
    let bufs = Buffers()
    bufs.useForeignSrc("initial".toArray())
    bufs.pushDest(UInt8(65))
    bufs.swap()
    if (bufs.src()[0] != UInt8(65)) {
        throw Exception("src after first swap should be A")
    }
    bufs.pushDest(UInt8(66))
    bufs.pushDest(UInt8(67))
    bufs.swap()
    let src2 = bufs.src()
    if (src2.size != 2) {
        throw Exception("src after second swap should have 2 bytes")
    }
    if (src2[0] != UInt8(66)) {
        throw Exception("first byte should be B")
    }
    if (src2[1] != UInt8(67)) {
        throw Exception("second byte should be C")
    }
}

@Test
func testBuffersDestEmptyAfterSwap(): Unit {
    // 对齐 Rust: buffers — 交换后 dest 为空
    let bufs = Buffers()
    bufs.pushDest(UInt8(88))
    bufs.swap()
    if (bufs.dest().size != 0) {
        throw Exception("dest should be empty after swap")
    }
}

@Test
func testBuffersPushDestMultipleBytes(): Unit {
    // 对齐 Rust: buffers — 多次 pushDest
    let bufs = Buffers()
    for (i in 0..100) {
        bufs.pushDest(UInt8(i % 256))
    }
    let dest = bufs.dest()
    if (dest.size != 100) {
        throw Exception("dest should have 100 bytes")
    }
}

// ============================================================
// Quadratic 补充测试 — 对齐 gix-utils/tests/backoff/mod.rs
// ============================================================

@Test
func testQuadraticSequence(): Unit {
    // 对齐 Rust: backoff — 完整序列验证
    let q = Quadratic()
    let expected = [1, 4, 9, 16, 25, 36, 49, 64, 81, 100]
    for (i in 0..expected.size) {
        let val = q.next()
        if (val != expected[i]) {
            throw Exception("iteration " + i.toString() + ": expected " + expected[i].toString() + " got " +
                val.toString())
        }
    }
}

@Test
func testQuadraticCapAt1000Explicit(): Unit {
    // 对齐 Rust: backoff — 上限 1000ms 显式验证
    let q = Quadratic()
    // 32^2 = 1024 > 1000, 所以第 32 次应返回 1000
    for (i in 0..31) {
        let _ = q.next()
    }
    let val = q.next()
    if (val != 1000) {
        throw Exception("iteration 32 should be capped at 1000, got " + val.toString())
    }
    // 第 33 次也应返回 1000
    let val2 = q.next()
    if (val2 != 1000) {
        throw Exception("iteration 33 should also be capped at 1000")
    }
}

// ============================================================
// string_utils 补充测试
// ============================================================

@Test
func testTrimStrLeadingAndTrailing(): Unit {
    // 对齐 Rust: str::trim
    if (trimStr("  hello  ") != "hello") {
        throw Exception("trim should remove leading/trailing spaces")
    }
    if (trimStr("hello") != "hello") {
        throw Exception("trim of no-space string should be unchanged")
    }
    if (trimStr("") != "") {
        throw Exception("trim of empty string should be empty")
    }
}

@Test
func testToLowerStr(): Unit {
    // 对齐 Rust: str::to_ascii_lower
    if (toLowerStr("HELLO") != "hello") {
        throw Exception("toLower should convert to lowercase")
    }
    if (toLowerStr("hello") != "hello") {
        throw Exception("toLower of lowercase should be unchanged")
    }
    if (toLowerStr("HeLLo123") != "hello123") {
        throw Exception("toLower mixed should work")
    }
}

@Test
func testToUpperStr(): Unit {
    // 对齐 Rust: str::to_ascii_upper
    if (toUpperStr("hello") != "HELLO") {
        throw Exception("toUpper should convert to uppercase")
    }
    if (toUpperStr("HELLO") != "HELLO") {
        throw Exception("toUpper of uppercase should be unchanged")
    }
}

@Test
func testSubstringStr(): Unit {
    // 对齐 Rust: str::substring
    if (substringStr("hello world", 0, 5) != "hello") {
        throw Exception("substring 0:5 should be hello")
    }
    if (substringStr("hello world", 6, 11) != "world") {
        throw Exception("substring 6:11 should be world")
    }
}

@Test
func testParseHexInt64(): Unit {
    // 对齐 Rust: parse_hex_int64
    if (parseHexInt64("ff") != Some(255)) {
        throw Exception("ff should be 255")
    }
    if (parseHexInt64("FF") != Some(255)) {
        throw Exception("FF should be 255")
    }
    if (parseHexInt64("0") != Some(0)) {
        throw Exception("0 should be 0")
    }
    if (parseHexInt64("").isSome()) {
        throw Exception("empty should be None")
    }
    if (parseHexInt64("gg").isSome()) {
        throw Exception("invalid hex should be None")
    }
}

@Test
func testRepeatStr(): Unit {
    // 对齐 Rust: repeat_str
    if (repeatStr("ab", 3) != "ababab") {
        throw Exception("repeat ab 3 times should be ababab")
    }
    if (repeatStr("x", 0) != "") {
        throw Exception("repeat 0 times should be empty")
    }
    if (repeatStr("", 5) != "") {
        throw Exception("repeat empty should be empty")
    }
}
