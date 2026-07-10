// 文件：lib.cj
// 用途：提供 Git 风格的引用验证功能
// 所属包：gix.gix_validate
// 关键函数：referenceName, referenceNameOrThrow

package gitoxide.gix_validate

import gitoxide.gix_utils.*

// 验证 Git 引用名称是否合法
// 检查各种不允许的字符和模式，如点号开头、连续点号、波浪号、脱字符、
// 冒号、反斜杠、连续斜杠、尾部斜杠、.lock 后缀和控制字符等
// 参数 name：待验证的引用名称字节数组
// 返回值：合法时返回 None，非法时返回 Some(错误描述)
public func referenceName(name: Array<Byte>): ?String {
    let s = String.fromUtf8(name)
    if (s.size == 0) {
        return Some("empty reference name")
    }
    if (s.startsWith("/")) {
        return Some("reference name cannot start with /")
    }
    if (s.startsWith(".")) {
        return Some("reference name cannot start with .")
    }
    if (s.contains("..")) {
        return Some("reference name cannot contain ..")
    }
    if (s.contains("~")) {
        return Some("reference name cannot contain ~")
    }
    if (s.contains("^")) {
        return Some("reference name cannot contain ^")
    }
    if (s.contains(":")) {
        return Some("reference name cannot contain :")
    }
    if (s.contains("\\")) {
        return Some("reference name cannot contain \\")
    }
    if (s.contains("//")) {
        return Some("reference name cannot contain consecutive slashes")
    }
    if (s.contains("@{")) {
        return Some("reference name cannot contain @{ sequence")
    }
    if (s.contains("*")) {
        return Some("reference name cannot contain *")
    }
    if (s.endsWith(".")) {
        return Some("reference name cannot end with .")
    }
    if (s.endsWith("/")) {
        return Some("reference name cannot end with /")
    }
    if (s.endsWith(".lock")) {
        return Some("reference name cannot end with .lock")
    }
    let components = s.split("/")
    for (comp in components) {
        if (comp == ".") {
            return Some("reference name cannot contain . component")
        }
        if (comp == ".git") {
            return Some("reference name cannot contain .git component")
        }
    }
    for (c in s) {
        if (Int64(c) == 0 || Int64(c) < 32 || c == UInt8(32)) {
            return Some("reference name cannot contain control characters or spaces")
        }
    }
    None
}

// 验证 Git 引用名称，非法时直接抛出异常
// 参数 name：待验证的引用名称字节数组
// 异常：引用名称非法时抛出 Exception
public func referenceNameOrThrow(name: Array<Byte>): Unit {
    let err = referenceName(name)
    if (!err.isNone()) {
        throw Exception("invalid reference name")
    }
}

// 验证 Git 标签名称是否合法
// 对齐 Rust: gix_validate::tag::name
// 参数 name：待验证的标签名称字节数组
// 返回值：合法时返回 None，非法时返回 Some(错误描述)
public func tagName(name: Array<Byte>): ?String {
    let s = String.fromUtf8(name)
    if (s.size == 0) {
        return Some("empty tag name")
    }
    if (s.startsWith(".")) {
        return Some("tag name cannot start with .")
    }
    if (s.contains("..")) {
        return Some("tag name cannot contain ..")
    }
    if (s.endsWith(".lock")) {
        return Some("tag name cannot end with .lock")
    }
    if (s.endsWith("/")) {
        return Some("tag name cannot end with /")
    }
    if (s.contains("//")) {
        return Some("tag name cannot contain consecutive slashes")
    }
    if (s.contains("@{")) {
        return Some("tag name cannot contain @{")
    }
    if (s.contains("*")) {
        return Some("tag name cannot contain *")
    }
    if (s.startsWith("/")) {
        return Some("tag name cannot start with /")
    }
    if (s.endsWith(".")) {
        return Some("tag name cannot end with .")
    }
    None
}

// 验证 Git 路径组件是否合法
// 对齐 Rust: gix_validate::path::component
// 参数 name：待验证的路径组件字节数组
// 返回值：合法时返回 None，非法时返回 Some(错误描述)
public func pathComponent(name: Array<Byte>): ?String {
    let s = String.fromUtf8(name)
    if (s.size == 0) {
        return Some("empty path component")
    }
    if (s == "." || s == "..") {
        return Some("path component cannot be . or ..")
    }
    var sLower = ""
    for (i in 0..s.size) {
        let c = s[i]
        if (c >= UInt8(65) && c <= UInt8(90)) {
            sLower += String(Rune(c + UInt8(32)))
        } else {
            sLower += String(Rune(c))
        }
    }
    if (sLower == ".git") {
        return Some("path component cannot be .git")
    }
    None
}

// 检查路径组件是否为 Windows 设备名
// 对齐 Rust: gix_validate::path::component_is_windows_device
// 参数 component：路径组件字符串
// 返回值：是 Windows 设备名返回 true，否则返回 false
public func componentIsWindowsDevice(component: String): Bool {
    var lower = ""
    for (i in 0..component.size) {
        let c = component[i]
        if (c >= UInt8(65) && c <= UInt8(90)) {
            lower += String(Rune(c + UInt8(32)))
        } else {
            lower += String(Rune(c))
        }
    }
    lower = lower.trimEnd()
    let devices = ["con", "prn", "aux", "nul", "com1", "com2", "com3", "com4", "com5", "com6", "com7", "com8", "com9",
        "lpt1", "lpt2", "lpt3", "lpt4", "lpt5", "lpt6", "lpt7", "lpt8", "lpt9", "conin$", "conout$"]
    for (d in devices) {
        if (lower == d || lower.startsWith(d + ".")) {
            return true
        }
    }
    false
}
