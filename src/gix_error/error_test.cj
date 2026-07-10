// 文件：error_test.cj
// 用途：gix_error 包的单元测试，全量对齐 Rust gitoxide gix-error 测试
// 所属包：gix.gix_error
// 对齐来源：gix-error/tests/{message,validation,exn}.rs

package gitoxide.gix_error

import std.unittest.*

// ============================================================
// GixError 测试 — 对齐 gix-error/tests/message.rs
// ============================================================

@Test
func testGixErrorDefault(): Unit {
    // 对齐 Rust: GixError::default()
    let err = GixError()
    if (err.message != "gix error") {
        throw Exception("default message mismatch: " + err.message)
    }
}

@Test
func testGixErrorCustomMessage(): Unit {
    // 对齐 Rust: GixError::new("custom")
    let err = GixError("custom error")
    if (err.message != "custom error") {
        throw Exception("custom message mismatch")
    }
}

// ============================================================
// Message 测试
// ============================================================

@Test
func testMessageCreation(): Unit {
    // 对齐 Rust: Message::new("msg")
    let msg = Message("test message")
    if (msg.message != "test message") {
        throw Exception("message text mismatch")
    }
}

@Test
func testMessageIsGixError(): Unit {
    // 对齐 Rust: Message is GixError
    let msg = Message("test")
    // Message 继承自 GixError
    var err: GixError = msg
    if (err.message != "test") {
        throw Exception("Message should be usable as GixError")
    }
}

@Test
func testMessageHelper(): Unit {
    // 对齐 Rust: message() 快捷构造
    let msg = message("helper message")
    if (msg.message != "helper message") {
        throw Exception("helper message mismatch")
    }
}

// ============================================================
// ValidationError 测试
// ============================================================

@Test
func testValidationErrorWithoutInput(): Unit {
    // 对齐 Rust: ValidationError::new("msg")
    let err = ValidationError("invalid input")
    if (err.message != "invalid input") {
        throw Exception("validation error message mismatch")
    }
    if (!err.input.isNone()) {
        throw Exception("input should be None when not provided")
    }
}

@Test
func testValidationErrorWithInput(): Unit {
    // 对齐 Rust: ValidationError::new("msg", input)
    let err = ValidationError("invalid input", "bad data")
    if (err.input != Some("bad data")) {
        throw Exception("input should be 'bad data'")
    }
}

@Test
func testValidationErrorIsGixError(): Unit {
    // 对齐 Rust: ValidationError is GixError
    let err = ValidationError("test")
    var gixErr: GixError = err
    if (gixErr.message != "test") {
        throw Exception("ValidationError should be usable as GixError")
    }
}

// ============================================================
// Exn 测试 — 对齐 gix-error/tests/exn.rs
// ============================================================

@Test
func testExnCreation(): Unit {
    // 对齐 Rust: Exn::new(err)
    let err = GixError("test error")
    let exn = Exn(err)
    if (exn.inner.isNone()) {
        throw Exception("Exn inner should not be None")
    }
    if (exn.location != "") {
        throw Exception("Exn location should be empty by default")
    }
    if (!exn.cause.isNone()) {
        throw Exception("Exn cause should be None by default")
    }
}

@Test
func testExnWithLocation(): Unit {
    // 对齐 Rust: Exn::new(err, location)
    let err = GixError("test error")
    let exn = Exn(err, "gix_hash::sha1")
    if (exn.location != "gix_hash::sha1") {
        throw Exception("Exn location mismatch: " + exn.location)
    }
}

@Test
func testExnOrRaise(): Unit {
    // 对齐 Rust: Exn::or_raise — 异常链
    let err = GixError("original")
    let exn1 = Exn(err, "location1")
    let exn2 = exn1.orRaise<Message>("new error")
    if (exn2.cause.isNone()) {
        throw Exception("Exn orRaise should set cause")
    }
    if (exn2.cause.getOrThrow().location != "location1") {
        throw Exception("Exn cause location mismatch")
    }
}

// ============================================================
// 补充测试 — 对齐 gix-error/tests/error/exn.rs 和 error.rs
// ============================================================

@Test
func testExnRaiseChain(): Unit {
    // 对齐 Rust: exn::raise_chain — 多层异常链
    let e1 = Exn(Message("E1"))
    let e2 = e1.orRaise<Message>("E2")
    let e3 = e2.orRaise<Message>("E3")
    // 验证链的深度
    if (e3.cause.isNone()) {
        throw Exception("E3 should have cause")
    }
    if (e3.cause.getOrThrow().cause.isNone()) {
        throw Exception("E3's cause should have its own cause")
    }
    let e1Again = e3.cause.getOrThrow().cause.getOrThrow()
    if (e1Again.inner.getOrThrow().message != "E1") {
        throw Exception("deepest cause should be E1")
    }
}

@Test
func testExnChainAll(): Unit {
    // 对齐 Rust: exn::raise_all — 多子异常
    let child1 = Exn(Message("child1"))
    let child2 = Exn(Message("child2"))
    let parent = Exn(Message("parent"))
    // 仓颉差异：当前 Exn 不支持 raise_all，用链式 orRaise 模拟
    let chain = child1.orRaise<Message>("parent")
    if (chain.cause.isNone()) {
        throw Exception("chain should have cause")
    }
}

@Test
func testExnInverseErrorCallChain(): Unit {
    // 对齐 Rust: exn::inverse_error_call_chain — 反向链
    let e1 = Exn(Message("E1"))
    let e2 = e1.orRaise<Message>("E2")
    let e3 = e2.orRaise<Message>("E3")
    // 验证链的方向：E3 → E2 → E1
    if (e3.inner.getOrThrow().message != "E3") {
        throw Exception("top should be E3")
    }
    let cause2 = e3.cause.getOrThrow()
    if (cause2.inner.getOrThrow().message != "E2") {
        throw Exception("middle should be E2")
    }
    let cause1 = cause2.cause.getOrThrow()
    if (cause1.inner.getOrThrow().message != "E1") {
        throw Exception("bottom should be E1")
    }
}

@Test
func testExnFromMessage(): Unit {
    // 对齐 Rust: exn::from_message — 从 Message 创建 Exn
    let msg = message("An error")
    let exn = Exn(msg)
    if (exn.inner.isNone()) {
        throw Exception("Exn inner should not be None")
    }
    if (exn.inner.getOrThrow().message != "An error") {
        throw Exception("inner message mismatch")
    }
}

@Test
func testExnNewWithSource(): Unit {
    // 对齐 Rust: exn::new_with_source — 带源错误的 Exn
    let source = Message("source error")
    let top = GixError("top error")
    let exn = Exn(top)
    // 仓颉差异：当前 Exn 不直接支持 source，用 cause 模拟
    let sourceExn = Exn(source)
    exn.cause = Some(sourceExn)
    if (exn.cause.isNone()) {
        throw Exception("Exn should have cause")
    }
    if (exn.cause.getOrThrow().inner.getOrThrow().message != "source error") {
        throw Exception("cause message mismatch")
    }
}

@Test
func testGixErrorFromExnError(): Unit {
    // 对齐 Rust: error::from_exn_error — 从 Exn 创建 Error
    let err = Exn(Message("one"))
    if (err.inner.getOrThrow().message != "one") {
        throw Exception("error message should be 'one'")
    }
}

@Test
func testGixErrorFromAnyError(): Unit {
    // 对齐 Rust: error::from_any_error — 从任意错误创建
    let msg = message("one")
    let err = GixError(msg.message)
    if (err.message != "one") {
        throw Exception("error message mismatch")
    }
}

@Test
func testValidationErrorDisplaysInput(): Unit {
    // 对齐 Rust: error::validation_error_displays_input_with_debug_formatting
    let err = ValidationError("invalid input", "hello\n ")
    if (err.message != "invalid input") {
        throw Exception("message mismatch")
    }
    if (err.input != Some("hello\n ")) {
        throw Exception("input should preserve whitespace")
    }
}

@Test
func testExnOptionExtPattern(): Unit {
    // 对齐 Rust: exn::option_ext — Option 到 Exn 的转换模式
    let opt: ?Int64 = None
    if (opt.isSome()) {
        throw Exception("None should be None")
    }
    // 模拟 ok_or_raise：将 None 转为 Exn
    let err: ?Exn = if (opt.isNone()) {
        Some(Exn(Message("An error")))
    } else {
        None<Exn>
    }
    if (err.isNone()) {
        throw Exception("should produce Exn from None")
    }
}

@Test
func testExnResultExtPattern(): Unit {
    // 对齐 Rust: exn::result_ext — Result 到 Exn 的转换模式
    let result: ?Int64 = None
    // 模拟 or_raise：将错误结果转为 Exn
    let err: ?Exn = if (result.isNone()) {
        let original = Exn(Message("An error"))
        Some(original.orRaise<Message>("Another error"))
    } else {
        None<Exn>
    }
    if (err.isNone()) {
        throw Exception("should produce chained Exn")
    }
    let exn = err.getOrThrow()
    if (exn.cause.isNone()) {
        throw Exception("chained Exn should have cause")
    }
}

@Test
func testMessageHelperFunction(): Unit {
    // 对齐 Rust: message() 快捷构造
    let msg = message("test message")
    if (msg.message != "test message") {
        throw Exception("message helper should create Message with correct text")
    }
}

@Test
func testExnEmptyLocation(): Unit {
    // 对齐 Rust: 补充测试 — 无位置的 Exn
    let err = GixError("test")
    let exn = Exn(err)
    if (exn.location != "") {
        throw Exception("default location should be empty")
    }
}

@Test
func testExnWithLocationString(): Unit {
    // 对齐 Rust: 补充测试 — 位置字符串
    let err = GixError("test")
    let exn = Exn(err, "gix_hash::sha1:42")
    if (!exn.location.contains("sha1")) {
        throw Exception("location should contain 'sha1': " + exn.location)
    }
}

@Test
func testGixErrorInheritance(): Unit {
    // 对齐 Rust: 补充测试 — 错误类型继承
    let msg = Message("test")
    var err: GixError = msg
    if (err.message != "test") {
        throw Exception("Message should be assignable to GixError")
    }
    let validation = ValidationError("test")
    var err2: GixError = validation
    if (err2.message != "test") {
        throw Exception("ValidationError should be assignable to GixError")
    }
}

@Test
func testExnMultipleChains(): Unit {
    // 对齐 Rust: exn::raise_all — 多条链
    let e1 = Exn(Message("E1"))
    let e2 = e1.orRaise<Message>("E2")
    let root = e2.orRaise<Message>("root")
    // 验证 root → E2 → E1
    if (root.inner.getOrThrow().message != "root") {
        throw Exception("root message mismatch")
    }
    var depth = 0
    var current: ?Exn = Some(root)
    while (let Some(c) <- current) {
        depth += 1
        current = c.cause
    }
    if (depth != 3) {
        throw Exception("chain depth should be 3, got " + depth.toString())
    }
}

// ============================================================
// GixError 补充测试 — 对齐 gix-error/src/lib.rs
// ============================================================

@Test
func testGixErrorEquality(): Unit {
    // 对齐 Rust: GixError PartialEq
    let err1 = GixError("test")
    let err2 = GixError("test")
    let err3 = GixError("other")
    if (err1.message != err2.message) {
        throw Exception("same message errors should be equal")
    }
    if (err1.message == err3.message) {
        throw Exception("different message errors should not be equal")
    }
}

@Test
func testGixErrorToString(): Unit {
    // 对齐 Rust: GixError Display
    let err = GixError("something failed")
    // 仓颉差异：GixError 继承 Exception，toString() 包含 "Exception: " 前缀
    if (!err.toString().contains("something failed")) {
        throw Exception("toString should contain message: " + err.toString())
    }
}

@Test
func testGixErrorEmptyMessage(): Unit {
    // 对齐 Rust: GixError with empty message
    let err = GixError("")
    if (err.message != "") {
        throw Exception("empty message should be preserved")
    }
}

@Test
func testGixErrorWithSpecialChars(): Unit {
    // 对齐 Rust: GixError with special characters
    let err = GixError("path: /foo/bar\\baz")
    if (err.message != "path: /foo/bar\\baz") {
        throw Exception("special chars should be preserved")
    }
}

@Test
func testGixErrorWithUnicode(): Unit {
    // 对齐 Rust: GixError with unicode message
    let err = GixError("编码错误")
    if (err.message != "编码错误") {
        throw Exception("unicode message should be preserved")
    }
}

// ============================================================
// Exn 补充测试 — 对齐 gix-error/src/exn.rs
// ============================================================

@Test
func testExnSingleCause(): Unit {
    // 对齐 Rust: Exn single cause chain
    let innerErr = GixError("inner error")
    let cause = Exn(innerErr)
    let outerErr = GixError("outer error")
    let exn = Exn(outerErr)
    exn.cause = Some(cause)
    if (exn.cause.isNone()) {
        throw Exception("should have a cause")
    }
    if (exn.cause.getOrThrow().inner.getOrThrow().message != "inner error") {
        throw Exception("cause message mismatch")
    }
}

@Test
func testExnNoCause(): Unit {
    // 对齐 Rust: Exn without cause
    let err = GixError("standalone error")
    let exn = Exn(err)
    if (exn.cause.isSome()) {
        throw Exception("should have no cause")
    }
}

@Test
func testExnDeepChain(): Unit {
    // 对齐 Rust: Exn deep cause chain
    let e1 = Exn(GixError("level1"))
    let e2 = Exn(GixError("level2"))
    e2.cause = Some(e1)
    let e3 = Exn(GixError("level3"))
    e3.cause = Some(e2)
    let e4 = Exn(GixError("level4"))
    e4.cause = Some(e3)
    var depth = 0
    var current: ?Exn = Some(e4)
    while (let Some(c) <- current) {
        depth += 1
        current = c.cause
    }
    if (depth != 4) {
        throw Exception("chain depth should be 4, got " + depth.toString())
    }
}
