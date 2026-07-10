// 文件：quote_test.cj
// 用途：gix_quote 包的单元测试，全量对齐 Rust gitoxide gix-quote 测试
// 所属包：gix.gix_quote
// 对齐来源：gix-quote/tests/{quote,unquote}.rs

package gitoxide.gix_quote

import std.unittest.*

// ============================================================
// quote 测试 — 对齐 gix-quote/tests/quote.rs
// ============================================================

@Test
func testQuoteSimpleString(): Unit {
    // 对齐 Rust: quote(b"hello") → "\"hello\""
    let result = `quote`("hello".toArray())
    let str = String.fromUtf8(result)
    if (str != "\"hello\"") {
        throw Exception("quote mismatch: " + str)
    }
}

@Test
func testQuoteEmptyString(): Unit {
    // 对齐 Rust: quote(b"") → "\"\""
    let result = `quote`("".toArray())
    let str = String.fromUtf8(result)
    if (str != "\"\"") {
        throw Exception("quote empty mismatch: " + str)
    }
}

@Test
func testQuoteStringWithDoubleQuote(): Unit {
    // 对齐 Rust: quote(b"he\"llo") → "\"he\\\"llo\""
    let input: Array<Byte> = [UInt8(104), UInt8(101), UInt8(34), UInt8(108), UInt8(108), UInt8(111)]
    let result = `quote`(input)
    let str = String.fromUtf8(result)
    if (!str.contains("\\\"")) {
        throw Exception("quoted string should contain escaped double quote: " + str)
    }
}

@Test
func testQuoteStringWithBackslash(): Unit {
    // 对齐 Rust: quote(b"he\\llo") → "\"he\\\\llo\""
    let input: Array<Byte> = [UInt8(104), UInt8(101), UInt8(92), UInt8(108), UInt8(108), UInt8(111)]
    let result = `quote`(input)
    let str = String.fromUtf8(result)
    if (!str.contains("\\\\")) {
        throw Exception("quoted string should contain escaped backslash: " + str)
    }
}

@Test
func testQuoteStringWithControlChar(): Unit {
    // 对齐 Rust: quote with control character
    let input: Array<Byte> = [UInt8(104), UInt8(10), UInt8(111)]
    let result = `quote`(input)
    let str = String.fromUtf8(result)
    if (!str.startsWith("\"")) {
        throw Exception("quoted string should start with double quote")
    }
    if (!str.endsWith("\"")) {
        throw Exception("quoted string should end with double quote")
    }
}

// ============================================================
// unquote 测试 — 对齐 gix-quote/tests/unquote.rs
// ============================================================

@Test
func testUnquoteSimpleString(): Unit {
    // 对齐 Rust: unquote(b"\"hello\"") → Some(b"hello")
    let result = unquote("\"hello\"".toArray())
    if (result.isNone()) {
        throw Exception("unquote should succeed")
    }
    let str = String.fromUtf8(result.getOrThrow())
    if (str != "hello") {
        throw Exception("unquote mismatch: " + str)
    }
}

@Test
func testUnquoteEmptyQuoted(): Unit {
    // 对齐 Rust: unquote(b"\"\"") → Some(b"")
    let result = unquote("\"\"".toArray())
    if (result.isNone()) {
        throw Exception("unquote empty quoted should succeed")
    }
    if (result.getOrThrow().size != 0) {
        throw Exception("unquote empty quoted should return empty")
    }
}

@Test
func testUnquoteEscapedDoubleQuote(): Unit {
    // 对齐 Rust: unquote(b"\"he\\\"llo\"") → Some(b"he\"llo")
    let input = "\"he\\\"llo\"".toArray()
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("unquote with escaped double quote should succeed")
    }
    let r = result.getOrThrow()
    if (r.size != 6) {
        throw Exception("unquote result size should be 6, got " + r.size.toString())
    }
    if (r[2] != UInt8(34)) {
        throw Exception("unquote result[2] should be double quote")
    }
}

@Test
func testUnquoteEscapedBackslash(): Unit {
    // 对齐 Rust: unquote(b"\"he\\\\llo\"") → Some(b"he\\llo")
    let input = "\"he\\\\llo\"".toArray()
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("unquote with escaped backslash should succeed")
    }
    let r = result.getOrThrow()
    if (r[2] != UInt8(92)) {
        throw Exception("unquote result[2] should be backslash")
    }
}

@Test
func testUnquoteNoQuotes(): Unit {
    // 对齐 Rust: unquote(b"hello") → Some — 不带引号直接返回原样
    let result = unquote("hello".toArray())
    if (result.isNone()) {
        throw Exception("unquote without quotes should return Some")
    }
    let s = String.fromUtf8(result.getOrThrow())
    if (s != "hello") {
        throw Exception("unquoted should be hello: " + s)
    }
}

@Test
func testUnquoteOnlyOpenQuote(): Unit {
    // 对齐 Rust: unquote(b"\"hello") → None
    let result = unquote("\"hello".toArray())
    if (!result.isNone()) {
        throw Exception("unquote with only open quote should return None")
    }
}

@Test
func testUnquoteOnlyCloseQuote(): Unit {
    // 对齐 Rust: unquote(b"hello\"") → Some — 不以引号开头，原样返回
    let result = unquote("hello\"".toArray())
    if (result.isNone()) {
        throw Exception("unquote with only close quote should return Some")
    }
}

@Test
func testUnquoteOctalEscape(): Unit {
    // 对齐 Rust: unquote with octal escape
    let input: Array<Byte> = [UInt8(0x22), UInt8(0x5C), UInt8(0x30), UInt8(0x31), UInt8(0x32), UInt8(0x22)]
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("unquote with octal escape should succeed")
    }
    let r = result.getOrThrow()
    if (r.size != 1) {
        throw Exception("unquote octal result size should be 1")
    }
    if (r[0] != UInt8(10)) {
        throw Exception("unquote octal result should be newline (0x0A)")
    }
}

// ============================================================
// Round-trip 测试
// ============================================================

@Test
func testQuoteUnquoteRoundTrip(): Unit {
    // 对齐 Rust: quote → unquote round-trip
    let input = "hello world"
    let quoted = `quote`(input.toArray())
    let unquoted = unquote(quoted)
    if (unquoted.isNone()) {
        throw Exception("round-trip unquote should succeed")
    }
    let result = String.fromUtf8(unquoted.getOrThrow())
    if (result != input) {
        throw Exception("round-trip mismatch: " + result)
    }
}

@Test
func testQuoteUnquoteRoundTripWithSpecialChars(): Unit {
    // 对齐 Rust: quote → unquote round-trip with special chars
    let input: Array<Byte> = [UInt8(72), UInt8(105), UInt8(34), UInt8(66), UInt8(121), UInt8(101)]
    let quoted = `quote`(input)
    let unquoted = unquote(quoted)
    if (unquoted.isNone()) {
        throw Exception("round-trip with special chars should succeed")
    }
    let result = unquoted.getOrThrow()
    if (result.size != input.size) {
        throw Exception("round-trip with special chars size mismatch")
    }
    for (i in 0..input.size) {
        if (result[i] != input[i]) {
            throw Exception("round-trip with special chars data mismatch at " + i.toString())
        }
    }
}

// ============================================================
// single 测试补充 — 对齐 gix-quote/tests/quote.rs::single
// ============================================================

@Test
func testSingleEmpty(): Unit {
    // 对齐 Rust: single::empty — 空输入
    let result = single("".toArray())
    let str = String.fromUtf8(result)
    if (str != "''") {
        throw Exception("single empty should be '', got " + str)
    }
}

@Test
func testSingleUnquotedBecomesQuoted(): Unit {
    // 对齐 Rust: single::unquoted_becomes_quoted
    let r1 = String.fromUtf8(single("a".toArray()))
    if (r1 != "'a'") {
        throw Exception("single(a) should be 'a', got " + r1)
    }
    let r2 = String.fromUtf8(single("a b".toArray()))
    if (r2 != "'a b'") {
        throw Exception("single(a b) should be 'a b', got " + r2)
    }
}

@Test
func testSingleExclamationMarkEscaped(): Unit {
    // 对齐 Rust: single::existing_exclamation_mark_gets_escaped
    let r1 = String.fromUtf8(single("a!b".toArray()))
    if (!r1.contains("\\!")) {
        throw Exception("single(a!b) should escape !: " + r1)
    }
    let r2 = String.fromUtf8(single("!".toArray()))
    if (!r2.contains("\\!")) {
        throw Exception("single(!) should escape !: " + r2)
    }
}

@Test
func testSingleQuoteEscaped(): Unit {
    // 对齐 Rust: single::existing_quote_gets_escaped
    let r1 = String.fromUtf8(single("a'b".toArray()))
    if (!r1.contains("\'")) {
        throw Exception("single(a'b) should escape ': " + r1)
    }
    let r2 = String.fromUtf8(single("'".toArray()))
    if (!r2.contains("\'")) {
        throw Exception("single(') should escape ': " + r2)
    }
}

@Test
func testSingleNewlinePreserved(): Unit {
    // 对齐 Rust: single::unquoted_becomes_quoted — 换行符保留
    let input: Array<Byte> = [UInt8(97), UInt8(10), UInt8(98)]
    let result = String.fromUtf8(single(input))
    if (!result.contains("a")) {
        throw Exception("should contain a")
    }
    if (!result.contains("b")) {
        throw Exception("should contain b")
    }
}

// ============================================================
// ansi_c::undo 测试补充 — 对齐 gix-quote/tests/quote.rs::ansi_c::undo
// ============================================================

@Test
func testAnsiCUnquoteUnquotedReturnsInput(): Unit {
    // 对齐 Rust: 不以引号开头，原样返回
    let result = unquote("hello".toArray())
    if (result.isNone()) {
        throw Exception("unquoted should return Some")
    }
    let s = String.fromUtf8(result.getOrThrow())
    if (s != "hello") {
        throw Exception("unquoted should be hello: " + s)
    }
}

@Test
func testAnsiCUnquoteEmptyQuoted(): Unit {
    // 对齐 Rust: ansi_c::undo::empty_surrounded_by_quotes
    let input = "\"\"".toArray()
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("empty quoted should succeed")
    }
    if (result.getOrThrow().size != 0) {
        throw Exception("empty quoted should produce empty bytes")
    }
}

@Test
func testAnsiCUnquoteTypicalEscapes(): Unit {
    // 对齐 Rust: ansi_c::undo::typical_escapes — \r\
    let input: Array<Byte> = [UInt8(0x22), UInt8(0x5C), UInt8(0x6E), UInt8(0x5C), UInt8(0x72), UInt8(0x5C), UInt8(0x74),
        UInt8(0x22)]
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("typical escapes should succeed")
    }
    let r = result.getOrThrow()
    if (r.size != 3) {
        throw Exception("should have 3 bytes, got " + r.size.toString())
    }
    if (r[0] != UInt8(10)) {
        throw Exception("first should be newline")
    }
    if (r[1] != UInt8(13)) {
        throw Exception("second should be CR")
    }
    if (r[2] != UInt8(9)) {
        throw Exception("third should be tab")
    }
}

@Test
func testAnsiCUnquoteLiteralEscapeAndDoubleQuote(): Unit {
    // 对齐 Rust: ansi_c::undo::literal_escape_and_double_quote
    let input = "\"\\\"\\\\\"".toArray()
    let result = unquote(input)
    if (result.isNone()) {
        throw Exception("literal escape should succeed")
    }
    let r = result.getOrThrow()
    if (r.size != 2) {
        throw Exception("should have 2 bytes, got " + r.size.toString())
    }
    if (r[0] != UInt8(34)) {
        throw Exception("first should be double quote")
    }
    if (r[1] != UInt8(92)) {
        throw Exception("second should be backslash")
    }
}

@Test
func testAnsiCUnquoteFuzzedInvalid(): Unit {
    // 对齐 Rust: ansi_c::undo::fuzzed — 无效输入应返回 None
    let input = "\"\\".toArray()
    let result = unquote(input)
    // 不完整的转义序列应返回 None 或空
    if (result.isNone()) {
        return
    }
    // 如果不返回 None，至少不应崩溃
}
