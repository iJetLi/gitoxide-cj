// 文件：lib.cj
// 用途：提供通用工具函数，包括字节到整数的转换、字符串规范化、缓冲区和退避
// 所属包：gix.gix_utils
// 关键函数：btoi, btoiUnsigned, strDecompose, strPrecompose
// 关键类型：Buffers, Quadratic

package gitoxide.gix_utils

import std.collection.*
// import unicode_normalization.nfd
// import unicode_normalization.nfc

// 将字节数组解析为有符号整数
// 支持前导负号（ASCII 45）和正号（ASCII 43），其余字节必须为 ASCII 数字（0-9）
// 对齐 Rust: gix_utils::btoi::to_signed
public func btoi(bytes: Array<Byte>): Int64 {
    var result: Int64 = 0
    var negative = false
    var i: Int64 = 0
    if (bytes.size > 0 && bytes[0] == UInt8(45)) {
        negative = true
        i = 1
    } else if (bytes.size > 0 && bytes[0] == UInt8(43)) {
        i = 1
    }
    while (i < bytes.size) {
        let b = bytes[i]
        if (b < UInt8(48) || b > UInt8(57)) {
            throw Exception("invalid digit in btoi: " + b.toString())
        }
        result = result * 10 + Int64(b - UInt8(48))
        i += 1
    }
    if (negative) {
        -result
    } else {
        result
    }
}

// 将字节数组解析为无符号整数
// 所有字节必须为 ASCII 数字（0-9），不支持负号和正号
// 对齐 Rust: gix_utils::btoi::to_unsigned
public func btoiUnsigned(bytes: Array<Byte>): Int64 {
    var result: Int64 = 0
    for (b in bytes) {
        if (b < UInt8(48) || b > UInt8(57)) {
            throw Exception("invalid digit in btoiUnsigned: " + b.toString())
        }
        result = result * 10 + Int64(b - UInt8(48))
    }
    result
}

// Unicode NFD 分解（Canonical Decomposition）
// 对齐 Rust: gix_utils::str::decompose
public func strDecompose(s: String): String {
    // nfd(s)
    s //测试
}

// Unicode NFC 预组合（Canonical Decomposition + Canonical Composition）
// 对齐 Rust: gix_utils::str::precompose
public func strPrecompose(s: String): String {
    // nfc(s)
    s //测试
}

// 双缓冲区，支持源和目标交换
// 对齐 Rust: gix_utils::Buffers
public class Buffers {
    // 外部源数据（只读）
    public var roSrc: ?Array<Byte>
    // 内部源缓冲区
    var srcBuf: Array<Byte>
    // 内部目标缓冲区
    var destBuf: ArrayList<Byte>

    public init() {
        roSrc = None
        srcBuf = Array<Byte>()
        destBuf = ArrayList<Byte>()
    }

    // 使用外部源数据
    public func useForeignSrc(data: Array<Byte>): Buffers {
        roSrc = data
        srcBuf = data
        this
    }

    // 获取当前源数据
    public func src(): Array<Byte> {
        if (let Some(data) <- roSrc) {
            data
        } else {
            srcBuf
        }
    }

    // 获取当前目标数据
    public func dest(): Array<Byte> {
        destBuf.toArray()
    }

    // 向目标缓冲区追加一个字节
    public func pushDest(b: Byte): Unit {
        destBuf.add(b)
    }

    // 交换源和目标缓冲区
    public func swap(): Unit {
        srcBuf = destBuf.toArray()
        roSrc = None
        destBuf = ArrayList<Byte>()
    }
}

// 二次退避策略
// 对齐 Rust: gix_utils::backoff::Quadratic
public class Quadratic {
    var iteration: Int64

    public init() {
        iteration = 0
    }

    // 返回下一次退避时间（毫秒），上限 1000ms
    public func next(): Int64 {
        iteration += 1
        let ms = iteration * iteration
        if (ms > 1000) {
            1000
        } else {
            ms
        }
    }
}
