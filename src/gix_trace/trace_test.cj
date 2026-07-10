// 文件：trace_test.cj
// 用途：gix_trace 包的单元测试，全量对齐 Rust gitoxide gix-trace 测试
// 所属包：gix.gix_trace
// 对齐来源：gix-trace/tests/level.rs

package gitoxide.gix_trace

import std.unittest.*
import std.collection.*

// ============================================================
// Level 枚举测试 — 对齐 gix-trace/tests/level.rs
// ============================================================

@Test
func testLevelVariants(): Unit {
    // 对齐 Rust: Level 枚举变体
    var levels = ArrayList<Level>()
    levels.add(Level.Error)
    levels.add(Level.Warn)
    levels.add(Level.Info)
    levels.add(Level.Debug)
    levels.add(Level.Trace)
    if (levels.size != 5) {
        throw Exception("should have 5 Level variants")
    }
}

// ============================================================
// log 函数测试
// ============================================================

@Test
func testLogDoesNotCrash(): Unit {
    // 对齐 Rust: log! — 不崩溃
    log(Level.Error, "error message")
    log(Level.Warn, "warn message")
    log(Level.Info, "info message")
    log(Level.Debug, "debug message")
    log(Level.Trace, "trace message")
}

@Test
func testErrorDoesNotCrash(): Unit {
    // 对齐 Rust: error! — 不崩溃
    error("error message")
}

@Test
func testWarnDoesNotCrash(): Unit {
    // 对齐 Rust: warn! — 不崩溃
    warn("warn message")
}

@Test
func testInfoDoesNotCrash(): Unit {
    // 对齐 Rust: info! — 不崩溃
    info("info message")
}

@Test
func testDebugDoesNotCrash(): Unit {
    // 对齐 Rust: debug! — 不崩溃
    debug("debug message")
}

@Test
func testLogEmptyMessage(): Unit {
    // 对齐 Rust: log! — 空消息
    log(Level.Info, "")
}

@Test
func testLogLongMessage(): Unit {
    // 对齐 Rust: log! — 长消息
    var msg = ""
    for (i in 0..1000) {
        msg = msg + "a"
    }
    log(Level.Info, msg)
}

// ============================================================
// Level 补充测试 — 对齐 gix-trace/src/lib.rs
// ============================================================

@Test
func testLevelEquality(): Unit {
    // 对齐 Rust: Level equality
    if (Level.Error != Level.Error) {
        throw Exception("Error should equal Error")
    }
    if (Level.Warn != Level.Warn) {
        throw Exception("Warn should equal Warn")
    }
    if (Level.Info != Level.Info) {
        throw Exception("Info should equal Info")
    }
    if (Level.Debug != Level.Debug) {
        throw Exception("Debug should equal Debug")
    }
    if (Level.Trace != Level.Trace) {
        throw Exception("Trace should equal Trace")
    }
}

@Test
func testLevelInequality(): Unit {
    // 对齐 Rust: Level inequality
    if (Level.Error == Level.Warn) {
        throw Exception("Error should not equal Warn")
    }
    if (Level.Warn == Level.Info) {
        throw Exception("Warn should not equal Info")
    }
    if (Level.Info == Level.Debug) {
        throw Exception("Info should not equal Debug")
    }
    if (Level.Debug == Level.Trace) {
        throw Exception("Debug should not equal Trace")
    }
}

@Test
func testLogWithEmptyMessage(): Unit {
    // 对齐 Rust: log with empty message
    log(Level.Error, "")
    log(Level.Warn, "")
    log(Level.Info, "")
    log(Level.Debug, "")
    log(Level.Trace, "")
}

@Test
func testLogWithLongMessage(): Unit {
    // 对齐 Rust: log with long message
    var longMsg = ""
    for (i in 0..1000) {
        longMsg = longMsg + "a"
    }
    log(Level.Error, longMsg)
    log(Level.Info, longMsg)
}

@Test
func testTraceDoesNotCrash(): Unit {
    // 对齐 Rust: trace! — 不崩溃
    trace("trace message")
}

// ============================================================
// Level 补充测试 — 对齐 gix-trace/tests/level.rs
// ============================================================

@Test
func testLevelEqualityAllVariants(): Unit {
    // 对齐 Rust: Level — 所有变体等价性
    if (Level.Error != Level.Error) {
        throw Exception("Error should equal Error")
    }
    if (Level.Warn != Level.Warn) {
        throw Exception("Warn should equal Warn")
    }
    if (Level.Info != Level.Info) {
        throw Exception("Info should equal Info")
    }
    if (Level.Debug != Level.Debug) {
        throw Exception("Debug should equal Debug")
    }
    if (Level.Trace != Level.Trace) {
        throw Exception("Trace should equal Trace")
    }
}

@Test
func testLevelInequalityCrossVariants(): Unit {
    // 对齐 Rust: Level — 不同变体不等
    if (Level.Error == Level.Warn) {
        throw Exception("Error should not equal Warn")
    }
    if (Level.Warn == Level.Info) {
        throw Exception("Warn should not equal Info")
    }
    if (Level.Info == Level.Debug) {
        throw Exception("Info should not equal Debug")
    }
    if (Level.Debug == Level.Trace) {
        throw Exception("Debug should not equal Trace")
    }
    if (Level.Error == Level.Trace) {
        throw Exception("Error should not equal Trace")
    }
}

@Test
func testLevelAllDistinct(): Unit {
    // 对齐 Rust: Level — 所有变体互异
    let levels = [Level.Error, Level.Warn, Level.Info, Level.Debug, Level.Trace]
    for (i in 0..levels.size) {
        for (j in 0..levels.size) {
            if (i != j && levels[i] == levels[j]) {
                throw Exception("level " + i.toString() + " should not equal level " + j.toString())
            }
        }
    }
}

// ============================================================
// log 便捷函数补充测试
// ============================================================

@Test
func testAllConvenienceLogFunctionsDoNotCrash(): Unit {
    // 对齐 Rust: log — 所有便捷函数不崩溃
    error("error")
    warn("warn")
    info("info")
    debug("debug")
    trace("trace")
}

@Test
func testLogWithUnicodeMessage(): Unit {
    // 对齐 Rust: log — Unicode 消息
    // 仓颉差异：仓颉使用 \u{xxxx} 格式的 Unicode 转义
    log(Level.Error, "\u{9519}\u{8BEF}")
    log(Level.Info, "\u{4FE1}\u{606F}")
}

@Test
func testLogWithSpecialCharsMessage(): Unit {
    // 对齐 Rust: log — 特殊字符消息
    log(Level.Debug, "path: /foo/bar\\baz")
    log(Level.Trace, "newlinesand\ttabs")
}
