// 文件：string_utils.cj
// 用途：提供仓颉标准库缺失的字符串操作辅助函数
// 所属包：gix.gix_utils
// 关键函数：trimStr, toLowerStr, toUpperStr, substringStr, substringFromStr

package gitoxide.gix_utils

import std.collection.*
import std.convert.*
import std.fs.*

// 常用 ASCII 字符常量，用 Rune 字面量转换，直观可读
// 对齐 Rust: b'\n', b'\r', b'/', b'{', b':', b' ', b'\t' 等
public let CHAR_LF: UInt8 = UInt8(UInt32(r'\n')) // 换行 \n
public let CHAR_CR: UInt8 = UInt8(UInt32(r'\r')) // 回车 \r
public let CHAR_SLASH: UInt8 = UInt8(UInt32(r'/')) // 斜杠 /
public let CHAR_LBRACE: UInt8 = UInt8(UInt32(r'{')) // 左花括号 {
public let CHAR_COLON: UInt8 = UInt8(UInt32(r':')) // 冒号 :
public let CHAR_SPACE: UInt8 = UInt8(UInt32(r' ')) // 空格
public let CHAR_TAB: UInt8 = UInt8(UInt32(r'\t')) // 制表符 \t
public let CHAR_DOT: UInt8 = UInt8(UInt32(r'.')) // 点 .
public let CHAR_NULL: UInt8 = UInt8(UInt32(r'\0')) // 空字符 \0

public func parseInt(s: String): ?Int64 {
    try {
        Some(Int64.parse(s))
    } catch (_: Exception) {
        None
    }
}

public func trimStr(s: String): String {
    s.trimAscii()
}

public func trimLeadingStr(s: String): String {
    var i: Int64 = 0
    while (i < s.size && isWhitespace(s[i])) {
        i += 1
    }
    s[i..]
}

public func toLowerStr(s: String): String {
    s.toAsciiLower()
}

public func toUpperStr(s: String): String {
    s.toAsciiUpper()
}

public func substringStr(s: String, start: Int64, end: Int64): String {
    s[start..end]
}

public func substringFromStr(s: String, start: Int64): String {
    s[start..]
}

func isWhitespace(c: UInt8): Bool {
    c == CHAR_SPACE || c == CHAR_TAB || c == CHAR_LF || c == CHAR_CR
}

public func parseHexInt64(s: String): ?Int64 {
    if (s.size == 0) {
        return None
    }
    var result: Int64 = 0
    for (i in 0..s.size) {
        let c = s[i]
        let digit = if (c >= UInt8(48) && c <= UInt8(57)) {
            Int64(c - UInt8(48))
        } else if (c >= UInt8(65) && c <= UInt8(70)) {
            Int64(c - UInt8(55))
        } else if (c >= UInt8(97) && c <= UInt8(102)) {
            Int64(c - UInt8(87))
        } else {
            return None
        }
        result = result * 16 + digit
    }
    Some(result)
}

public func repeatStr(s: String, count: Int64): String {
    var sb = StringBuilder()
    var i: Int64 = 0
    while (i < count) {
        sb.append(s)
        i += 1
    }
    sb.toString()
}

public func listDirectory(path: String): ArrayList<String> {
    var result = ArrayList<String>()
    try {
        let entries = Directory.readFrom(path)
        for (entry in entries) {
            let name = entry.path.toString()
            var sepPos: Int64 = -1
            let fwdIdx = name.lastIndexOf("/")
            let bwdIdx = name.lastIndexOf("\\")
            if (let Some(fi) <- fwdIdx) {
                if (fi > sepPos) {
                    sepPos = fi
                }
            }
            if (let Some(bi) <- bwdIdx) {
                if (bi > sepPos) {
                    sepPos = bi
                }
            }
            if (sepPos >= 0) {
                result.add(substringFromStr(name, sepPos + 1))
            } else {
                result.add(name)
            }
        }
    } catch (_: Exception) {}
    result
}

public func readFileBytes(path: String): Array<Byte> {
    try {
        let f = File(path, OpenMode.Read)
        var buf = ArrayList<Byte>()
        let chunk = Array<UInt8>(4096, repeat: UInt8(0))
        while (true) {
            let n = f.read(chunk)
            if (n <= 0) {
                break
            }
            var i: Int64 = 0
            while (i < n) {
                buf.add(chunk[i])
                i += 1
            }
        }
        f.close()
        buf.toArray()
    } catch (_: Exception) {
        Array<Byte>()
    }
}

public func bytesToUInt8Array(data: Array<Byte>): Array<UInt8> {
    var result = Array<UInt8>(data.size, repeat: UInt8(0))
    var i: Int64 = 0
    while (i < data.size) {
        result[i] = UInt8(data[i])
        i += 1
    }
    result
}

public func writeFileBytes(path: String, data: Array<Byte>): Unit {
    try {
        let f = File(path, OpenMode.Write)
        f.write(bytesToUInt8Array(data))
        f.close()
    } catch (_: Exception) {}
}
