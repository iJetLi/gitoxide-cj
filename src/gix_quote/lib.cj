// 文件：lib.cj
// 用途：提供 Git 风格的引用（quote）和反引用（unquote）功能
// 所属包：gix.gix_quote
// 关键函数：quote, unquote, single

package gitoxide.gix_quote

import std.collection.*

// 对字节数组进行引用（转义）处理
// 用双引号包裹输入，转义内部的双引号、反斜杠和控制字符
// 控制字符（ASCII 小于 32 或等于 127）以八进制转义序列表示
// 参数 input：待引用的字节数组
// 返回值：引用后的字节数组
public func `quote`(input: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    result.add(UInt8(34))
    for (b in input) {
        if (b == UInt8(34)) {
            result.add(UInt8(92))
            result.add(UInt8(34))
        } else if (b == UInt8(92)) {
            result.add(UInt8(92))
            result.add(UInt8(92))
        } else if (Int64(b) < 32 || b == UInt8(127)) {
            result.add(UInt8(92))
            let octal = Int64(b).toString()
            for (i in 0..octal.size) {
                result.add(UInt8(Int64(octal[i])))
            }
        } else {
            result.add(b)
        }
    }
    result.add(UInt8(34))
    result.toArray()
}

// 对齐 Rust: gix_quote::single
// 用单引号包裹输入，转义内部的单引号为 '\''，感叹号为 '\!'
// 用于 Bourne shell 参数引用
public func single(input: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    result.add(UInt8(39)) // '
    var i: Int64 = 0
    while (i < input.size) {
        var b = input[i]
        if (b == UInt8(39) || b == UInt8(33)) { // ' or !
            result.add(UInt8(39)) // '
            result.add(UInt8(92)) // \
            result.add(b)
            result.add(UInt8(39)) // '
        } else {
            result.add(b)
        }
        i += 1
    }
    result.add(UInt8(39)) // '
    result.toArray()
}

// single 的 String 版本
public func singleString(input: String): String {
    var result = StringBuilder()
    result.append("'")
    var i: Int64 = 0
    while (i < input.size) {
        var b = input[i]
        if (b == 39 || b == 33) { // ' or !
            result.append("'\\")
            result.append(b)
            result.append("'")
        } else {
            result.append(b)
        }
        i += 1
    }
    result.append("'")
    result.toString()
}

// 对字节数组进行反引用（反转义）处理
// 输入必须以双引号开头和结尾，支持转义双引号、反斜杠和八进制转义序列
// 参数 input：待反引用的字节数组
// 返回值：反引用成功返回 Some(字节数组)，格式错误返回 None
public func unquote(input: Array<Byte>): ?Array<Byte> {
    if (input.size == 0 || input[0] != UInt8(34)) {
        return Some(input)
    }
    if (input.size < 2 || input[input.size - 1] != UInt8(34)) {
        return None
    }
    var result = ArrayList<Byte>()
    var i: Int64 = 1
    while (i < input.size - 1) {
        if (input[i] == UInt8(92)) {
            i += 1
            if (i >= input.size - 1) {
                return None
            }
            if (input[i] == UInt8(110)) {
                result.add(UInt8(10))
            } else if (input[i] == UInt8(114)) {
                result.add(UInt8(13))
            } else if (input[i] == UInt8(116)) {
                result.add(UInt8(9))
            } else if (input[i] == UInt8(97)) {
                result.add(UInt8(7))
            } else if (input[i] == UInt8(98)) {
                result.add(UInt8(8))
            } else if (input[i] == UInt8(118)) {
                result.add(UInt8(0x0B))
            } else if (input[i] == UInt8(102)) {
                result.add(UInt8(0x0C))
            } else if (input[i] == UInt8(34) || input[i] == UInt8(92)) {
                result.add(input[i])
            } else if (Int64(input[i]) >= 48 && Int64(input[i]) <= 51) {
                let d1 = Int64(input[i]) - 48
                i += 1
                if (i >= input.size - 1) {
                    return None
                }
                let d2 = Int64(input[i]) - 48
                i += 1
                if (i >= input.size - 1) {
                    return None
                }
                let d3 = Int64(input[i]) - 48
                result.add(UInt8(((d1 * 64 + d2 * 8 + d3) & 0xFF)))
            } else {
                return None
            }
        } else {
            result.add(input[i])
        }
        i += 1
    }
    Some(result.toArray())
}
