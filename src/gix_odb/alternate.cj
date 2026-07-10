// 文件：alternate.cj
// 用途：解析 Git 对象目录的 alternates 文件，获取备用对象库路径列表
// 所属包：gix.gix_odb
// 对齐来源：gix-odb/src/alternate/{mod,parse}.rs
// 关键类型：AlternateError、AlternateResolveResult

package gitoxide.gix_odb

import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// 对齐 Rust: gix-odb/src/alternate/parse.rs Error
// Alternates 解析错误
public class AlternateParseError {
    public var message: String
    public var path: String

    public init(message: String, path: String) {
        this.message = message
        this.path = path
    }
}

// 对齐 Rust: gix-odb/src/alternate/mod.rs Error
// Alternates 解析错误
public class AlternateError {
    public var message: String

    public init(message: String) {
        this.message = message
    }
}

// Alternates 解析结果（含可能的错误）
public class AlternateResolveResult {
    public var paths: ArrayList<String>
    public var error: ?AlternateError

    public init(paths: ArrayList<String>, error: ?AlternateError) {
        this.paths = paths
        this.error = error
    }
}

// ASCII 常量
let ASCII_BACKSLASH: UInt8 = UInt8(92)
let ASCII_HASH: UInt8 = UInt8(35)
let ASCII_QUOTE: UInt8 = UInt8(34)
let ASCII_a: UInt8 = UInt8(97)
let ASCII_b: UInt8 = UInt8(98)
let ASCII_f: UInt8 = UInt8(102)
let ASCII_n: UInt8 = UInt8(110)
let ASCII_r: UInt8 = UInt8(114)
let ASCII_t: UInt8 = UInt8(116)
let ASCII_v: UInt8 = UInt8(118)
let ASCII_x: UInt8 = UInt8(120)
let ASCII_0: UInt8 = UInt8(48)
let ASCII_7: UInt8 = UInt8(55)
let ASCII_SLASH: UInt8 = UInt8(47)
let ASCII_COLON: UInt8 = UInt8(58)

// 解析 alternates 文件内容，返回路径列表
// 对齐 Rust: gix-odb/src/alternate/parse.rs content()
// 支持注释行（# 开头）、空行、ANSI C 引号路径（"..."）
func parseAlternateContent(input: String): ArrayList<String> {
    let result = ArrayList<String>()
    let lines = input.split("\n")
    for (line in lines) {
        let trimmed = trimStr(line)
        // 对齐 Rust: parse.rs — 空行跳过
        if (trimmed.size == 0) {
            continue
        }
        // 对齐 Rust: parse.rs — 注释行跳过
        if (trimmed.startsWith("#")) {
            continue
        }
        // 对齐 Rust: parse.rs — ANSI C 引号路径处理
        if (trimmed.startsWith("\"")) {
            let unquoted = unquoteAnsiC(trimmed)
            if (unquoted.isSome()) {
                result.add(unquoted.getOrThrow())
            }
        } else {
            result.add(trimmed)
        }
    }
    result
}

// ANSI C 引号字符串解码
// 对齐 Rust: gix-quote/src/ansi_c/undo.rs
// 支持 \t \n \\ \" \xHH 等转义序列
func unquoteAnsiC(input: String): ?String {
    if (input.size < 2) {
        return None
    }
    if (input[0] != ASCII_QUOTE || input[input.size - 1] != ASCII_QUOTE) {
        return None
    }
    // 去掉首尾引号，处理转义
    let inner = substringStr(input, 1, input.size - 1)
    var result = ArrayList<UInt8>()
    var i: Int64 = 0
    while (i < inner.size) {
        let c = inner[i]
        if (c == ASCII_BACKSLASH) {
            i += 1
            if (i >= inner.size) {
                return None
            }
            let next = inner[i]
            // 对齐 Rust: gix-quote/src/ansi_c/undo.rs — 转义序列处理
            if (next == ASCII_a) {
                result.add(UInt8(7))
            } else if (next == ASCII_b) {
                result.add(UInt8(8))
            } else if (next == ASCII_f) {
                result.add(UInt8(12))
            } else if (next == ASCII_n) {
                result.add(UInt8(10))
            } else if (next == ASCII_r) {
                result.add(UInt8(13))
            } else if (next == ASCII_t) {
                result.add(UInt8(9))
            } else if (next == ASCII_v) {
                result.add(UInt8(11))
            } else if (next == ASCII_BACKSLASH) {
                result.add(ASCII_BACKSLASH)
            } else if (next == ASCII_QUOTE) {
                result.add(ASCII_QUOTE)
            } else if (next == ASCII_x) {
                // \xHH 十六进制转义
                if (i + 2 >= inner.size) {
                    return None
                }
                var hexArr = ArrayList<UInt8>()
                hexArr.add(inner[i + 1])
                hexArr.add(inner[i + 2])
                let hexStr = String.fromUtf8(hexArr.toArray())
                let val = parseHexInt64(hexStr)
                if (val.isNone()) {
                    return None
                }
                result.add(UInt8(val.getOrThrow()))
                i += 2
            } else if (next >= ASCII_0 && next <= ASCII_7) {
                // \ooo 八进制转义（最多 3 位）
                var octalVal: Int64 = 0
                var j: Int64 = 0
                while (j < 3 && i < inner.size) {
                    let digit = inner[i]
                    if (digit >= ASCII_0 && digit <= ASCII_7) {
                        octalVal = octalVal * 8 + Int64(digit) - Int64(ASCII_0)
                        i += 1
                        j += 1
                    } else {
                        break
                    }
                }
                result.add(UInt8(octalVal))
                i -= 1
            } else {
                result.add(next)
            }
        } else {
            result.add(c)
        }
        i += 1
    }
    Some(String.fromUtf8(result.toArray()))
}

// 解析 alternates 文件，返回备用对象库的路径列表
// 对齐 Rust: gix-odb/src/alternate/mod.rs resolve()
// 参数 objectsDir：Git 对象目录路径（如 .git/objects）
// 返回值：备用对象库路径的列表，若文件不存在则返回空列表
public func parseAlternates(objectsDir: String): ArrayList<String> {
    var result = ArrayList<String>()
    let altPath = objectsDir + "/info/alternates"
    if (!exists(altPath)) {
        return result
    }
    try {
        let bytes = readFileBytes(altPath)
        let content = String.fromUtf8(bytes)
        let paths = parseAlternateContent(content)
        // 对齐 Rust: alternate/mod.rs — 相对路径规范化
        for (path in paths) {
            let resolved = resolveAlternatePath(path, objectsDir)
            result.add(resolved)
        }
    } catch (_: Exception) {}
    result
}

// 解析 alternates 文件，返回备用对象库的路径列表（带循环检测）
// 对齐 Rust: gix-odb/src/alternate/mod.rs resolve() — 含 Cycle 检测
public func parseAlternatesWithCycleCheck(objectsDir: String, visitedDirs: ArrayList<String>): AlternateResolveResult {
    // 对齐 Rust: alternate/mod.rs — 循环检测
    for (visited in visitedDirs) {
        if (visited == objectsDir) {
            return AlternateResolveResult(ArrayList<String>(),
                AlternateError("cycle detected: ${visitedDirs} -> ${objectsDir}"))
        }
    }

    let altPath = objectsDir + "/info/alternates"
    if (!exists(altPath)) {
        return AlternateResolveResult(ArrayList<String>(), None)
    }

    var content: String
    try {
        let bytes = readFileBytes(altPath)
        content = String.fromUtf8(bytes)
    } catch (e: Exception) {
        return AlternateResolveResult(ArrayList<String>(), AlternateError(e.message))
    }

    let paths = parseAlternateContent(content)
    var result = ArrayList<String>()
    let newVisited = ArrayList<String>()
    for (v in visitedDirs) {
        newVisited.add(v)
    }
    newVisited.add(objectsDir)

    for (path in paths) {
        let resolved = resolveAlternatePath(path, objectsDir)
        result.add(resolved)
        // 对齐 Rust: alternate/mod.rs — 递归解析嵌套 alternates
        let nestedResult = parseAlternatesWithCycleCheck(resolved, newVisited)
        for (nested in nestedResult.paths) {
            result.add(nested)
        }
    }
    AlternateResolveResult(result, None)
}

// 规范化 alternates 路径
// 对齐 Rust: gix-odb/src/alternate/mod.rs — 相对路径解析 + 规范化
// 参数 path：alternates 文件中的路径
// 参数 objectsDir：当前对象目录（用于解析相对路径）
// 返回值：规范化后的绝对路径
func resolveAlternatePath(path: String, objectsDir: String): String {
    // 对齐 Rust: alternate/mod.rs — 绝对路径直接使用
    if (path.startsWith("/") || (path.size > 2 && path[1] == ASCII_COLON)) {
        return normalizePath(path)
    }
    // 对齐 Rust: alternate/mod.rs — 相对路径基于 objectsDir 的父目录解析
    // alternates 中的相对路径是相对于 .git 目录，即 objectsDir 的父目录
    let parentDir = getParentDir(objectsDir)
    let resolved = parentDir + "/" + path
    normalizePath(resolved)
}

// 获取父目录路径
func getParentDir(path: String): String {
    // 去掉末尾的 /
    var p = path
    while (p.size > 1 && p.endsWith("/")) {
        p = substringStr(p, 0, p.size - 1)
    }
    let lastSlash = p.lastIndexOf("/")
    if (lastSlash.isSome()) {
        return substringStr(p, 0, lastSlash.getOrThrow())
    }
    p
}

// 路径规范化：处理 . 和 .. 组件
// 对齐 Rust: gix-path/src/realpath.rs — 简化版本（不含符号链接解析）
func normalizePath(path: String): String {
    let parts = path.split("/")
    var stack = ArrayList<String>()
    for (part in parts) {
        if (part.size == 0) {
            continue
        }
        if (part == ".") {
            continue
        }
        if (part == "..") {
            if (stack.size > 0) {
                stack.remove(at: stack.size - 1)
            }
        } else {
            stack.add(part)
        }
    }
    if (stack.size == 0) {
        return "/"
    }
    var result = ""
    for (part in stack) {
        result = result + "/" + part
    }
    result
}
