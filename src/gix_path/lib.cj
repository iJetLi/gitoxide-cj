// 文件：lib.cj
// 用途：提供跨平台路径处理工具，支持路径规范化、拼接和格式转换
// 所属包：gix.gix_path
// 关键函数：toSlash, fromSlash, normalize, isAbsolute, join, parent, fileName
// 关键函数：toUnixSeparators, toWindowsSeparators, joinBstrUnixPathsep, relativizeWithPrefix

package gitoxide.gix_path

import std.collection.*
import std.env.*
import std.fs.*
import gitoxide.gix_utils.*

// 将 Windows 反斜杠路径转换为正斜杠路径
// 对齐 Rust: gix_path::to_unix_separators
public func toSlash(path: String): String {
    path.replace("\\", "/")
}

// 将正斜杠路径转换为 Windows 反斜杠路径
// 对齐 Rust: gix_path::to_windows_separators
public func fromSlash(path: String): String {
    path.replace("/", "\\")
}

// 无条件将反斜杠替换为正斜杠（字节级别）
// 对齐 Rust: gix_path::convert::to_unix_separators
public func toUnixSeparators(bytes: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    for (b in bytes) {
        if (b == UInt8(92)) {
            result.add(UInt8(47))
        } else {
            result.add(b)
        }
    }
    result.toArray()
}

// 无条件将正斜杠替换为反斜杠（字节级别）
// 对齐 Rust: gix_path::convert::to_windows_separators
public func toWindowsSeparators(bytes: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    for (b in bytes) {
        if (b == UInt8(47)) {
            result.add(UInt8(92))
        } else {
            result.add(b)
        }
    }
    result.toArray()
}

// 规范化路径，去除 . 和 .. 组件
// 对齐 Rust: gix_path::normalize — 将 / 视为普通分隔符，不保留绝对路径前缀
public func normalize(path: String): String {
    let parts = toSlash(path).split("/")
    var result = ArrayList<String>()
    for (part in parts) {
        if (part == "..") {
            if (result.size > 0) {
                result.remove(at: result.size - 1)
            }
        } else if (part != "." && part.size > 0) {
            result.add(part)
        }
    }
    var s = ""
    var first = true
    for (part in result) {
        if (!first) {
            s = s + "/"
        }
        s = s + part
        first = false
    }
    s
}

// 带当前目录的规范化路径
// 对齐 Rust: gix_path::normalize(path, current_dir)
// 参数 path：待规范化的路径
// 参数 currentDir：当前工作目录（绝对路径）
// 返回值：规范化后的路径，若 .. 超出根目录则返回 None
public func normalizeWithCwd(path: String, currentDir: String): ?String {
    let normalized = toSlash(path)
    if (!normalized.contains("..")) {
        return Some(path)
    }
    let parts = normalized.split("/")
    var cwdParts = ArrayList<String>()
    let cwdNormalized = toSlash(currentDir)
    for (p in cwdNormalized.split("/")) {
        if (p.size > 0) {
            cwdParts.add(p)
        }
    }
    var result = ArrayList<String>()
    var cwdUsed = false
    let wasRelative = !isAbsolute(path)
    for (part in parts) {
        if (part == "..") {
            let pathIsDot = result.size == 1 && result[0] == "."
            if (result.size == 0 || pathIsDot) {
                if (cwdUsed) {
                    return None
                }
                result.clear()
                for (p in cwdParts) {
                    result.add(p)
                }
                cwdUsed = true
            }
            if (result.size > 0) {
                result.remove(at: result.size - 1)
            } else {
                return None
            }
        } else if (part == ".") {
            if (result.size == 0 && wasRelative) {
                result.add(".")
            }
        } else if (part.size > 0) {
            result.add(part)
        }
    }
    if (result.size == 0) {
        return Some(".")
    }
    var s = ""
    if (cwdUsed) {
        s = "/"
    }
    var first = true
    for (part in result) {
        if (!first) {
            s = s + "/"
        }
        s = s + part
        first = false
    }
    if (s.size == 0) {
        return Some(".")
    }
    Some(s)
}

// 判断路径是否为绝对路径
// 支持 Unix 风格（/开头）和 Windows 风格（C:开头）
public func isAbsolute(path: String): Bool {
    path.startsWith("/") || (path.size > 1 && path[0].isAsciiLetter() && path[1] == UInt8(58))
}

// isAbsolute 的别名，对齐 Rust gix_path::is_absolute
public func isAbsolutePath(path: String): Bool {
    isAbsolute(path)
}

// 拼接基础路径和相对路径
public func join(base: String, relative: String): String {
    let b = toSlash(base)
    let r = toSlash(relative)
    if (isAbsolute(r)) {
        r
    } else if (b.endsWith("/")) {
        b + r
    } else {
        b + "/" + r
    }
}

// 以 Unix 路径分隔符拼接路径（字节级别）
// 对齐 Rust: gix_path::join_bstr_unix_pathsep
public func joinBstrUnixPathsep(base: String, path: String): String {
    if (base.size == 0) {
        return path
    }
    if (path.size == 0) {
        if (base[base.size - 1] == UInt8(47)) {
            return base
        }
        return base + "/"
    }
    if (base[base.size - 1] == UInt8(47)) {
        base + path
    } else {
        base + "/" + path
    }
}

// 获取路径的父目录
public func parent(path: String): ?String {
    var normalized = toSlash(path)
    while (normalized.size > 1 && normalized[normalized.size - 1] == UInt8(47)) {
        normalized = substringStr(normalized, 0, normalized.size - 1)
    }
    if (normalized == "/") {
        return None
    }
    let lastSlashOpt = normalized.lastIndexOf('/')
    if (let Some(lastSlash) <- lastSlashOpt) {
        if (lastSlash == 0) {
            return Some("/")
        }
        Some(substringStr(normalized, 0, lastSlash))
    } else {
        None
    }
}

public func fileName(path: String): ?String {
    var normalized = toSlash(path)
    while (normalized.size > 1 && normalized[normalized.size - 1] == UInt8(47)) {
        normalized = substringStr(normalized, 0, normalized.size - 1)
    }
    let lastSlashOpt = normalized.lastIndexOf('/')
    if (let Some(lastSlash) <- lastSlashOpt) {
        if (lastSlash >= normalized.size - 1) {
            return None
        }
        Some(substringFromStr(normalized, lastSlash + 1))
    } else {
        None
    }
}

// 相对路径验证错误类型
// 对齐 Rust: gix_path::relative_path::Error
public enum RelativePathError {
    | IsAbsolute
    | ContainsInvalidComponent(String)
}

extend RelativePathError <: Equatable<RelativePathError> {
    public operator func ==(other: RelativePathError): Bool {
        match (this) {
            case RelativePathError.IsAbsolute => match (other) {
                case RelativePathError.IsAbsolute => true;
                case _ => false
            }
            case RelativePathError.ContainsInvalidComponent(s) => match (other) {
                case RelativePathError.ContainsInvalidComponent(s2) => s == s2
                case _ => false
            }
        }
    }

    public operator func !=(other: RelativePathError): Bool {
        !(this == other)
    }
}

// 验证路径是否为合法的相对路径
// 对齐 Rust: gix_path::RelativePath
public func validateRelativePath(path: String): ?RelativePathError {
    if (isAbsolute(path)) {
        return RelativePathError.IsAbsolute
    }
    let parts = toSlash(path).split("/")
    for (part in parts) {
        if (part == "." || part == "..") {
            return RelativePathError.ContainsInvalidComponent(part)
        }
    }
    None
}

// 基于前缀的相对化
// 对齐 Rust: gix_path::relativize_with_prefix
// 参数 path：待相对化的路径
// 参数 prefix：前缀路径
// 返回值：相对化后的路径
public func relativizeWithPrefix(path: String, prefix: String): String {
    if (prefix.size == 0) {
        if (path.size == 0) {
            return "."
        }
        return path
    }
    let pathParts = toSlash(path).split("/")
    let prefixParts = toSlash(prefix).split("/")
    var buf = ArrayList<String>()
    var pathIdx: Int64 = 0
    var equalThusFar = true
    for (pcomp in prefixParts) {
        if (equalThusFar && pathIdx < pathParts.size) {
            if (pcomp == pathParts[pathIdx]) {
                pathIdx += 1
                continue
            } else {
                equalThusFar = false
            }
        }
        if (pcomp.size > 0) {
            buf.add("..")
        }
    }
    while (pathIdx < pathParts.size) {
        buf.add(pathParts[pathIdx])
        pathIdx += 1
    }
    if (buf.size == 0) {
        return "."
    }
    var s = ""
    var first = true
    for (part in buf) {
        if (!first) {
            s = s + "/"
        }
        s = s + part
        first = false
    }
    s
}

// ============================================================
// env 函数 — 对齐 Rust: gix_path::env
// 注意：部分函数依赖 Git 二进制调用（installationConfig 等），
// 仓颉中无法实现，保持占位；其余使用 std.env 环境变量实现
// ============================================================

// 获取 Git 可执行文件调用路径
// 对齐 Rust: gix_path::env::exe_invocation
// 从 GIT_EXEC_PATH 环境变量获取，回退到 "git"
public func exeInvocation(): String {
    let envVal = getEnv("GIT_EXEC_PATH")
    match (envVal) {
        case Some(v) => v
        case None => "git"
    }
}

// 获取 shell 路径
// 对齐 Rust: gix_path::env::shell
// 从 SHELL 环境变量获取，Windows 回退到 "sh.exe"
public func shell(): String {
    let envVal = getEnv("SHELL")
    match (envVal) {
        case Some(v) => v
        case None => "sh.exe"
    }
}

// 获取 Git 安装配置路径
// 对齐 Rust: gix_path::env::installation_config
// 需要调用 Git 二进制获取，仓颉中无法实现
public func installationConfig(): ?String {
    None
}

// 获取 Git 安装配置前缀路径
// 对齐 Rust: gix_path::env::installation_config_prefix
// 依赖 installationConfig，仓颉中无法实现
public func installationConfigPrefix(): ?String {
    None
}

// 获取 Git 核心目录
// 对齐 Rust: gix_path::env::core_dir
// 需要调用 Git 二进制获取，仓颉中无法实现
public func coreDir(): ?String {
    None
}

// 获取系统前缀路径
// 对齐 Rust: gix_path::env::system_prefix
// Windows 下从 EXEPATH 环境变量获取
public func systemPrefix(): ?String {
    let envVal = getEnv("EXEPATH")
    match (envVal) {
        case Some(v) =>
            if (v.size > 0) {
                Some(v)
            } else {
                Option<String>.None
            }
        case None => Option<String>.None
    }
}

// 获取用户主目录
// 对齐 Rust: gix_path::env::home_dir
// 使用仓颉标准库 getHomeDirectory
public func homeDir(): ?String {
    try {
        let home = getHomeDirectory()
        Some(home.toString())
    } catch (_: Exception) {
        None
    }
}

// 获取 XDG 配置目录
// 对齐 Rust: gix_path::env::xdg_config
// 从 XDG_CONFIG_HOME 环境变量获取，回退到 ~/.config
public func xdgConfig(name: String): ?String {
    let envVal = getEnv("XDG_CONFIG_HOME")
    let configBase = match (envVal) {
        case Some(v) =>
            if (v.size > 0) {
                v
            } else {
                match (homeDir()) {
                    case Some(h) => h + "/.config"
                    case None => return None
                }
            }
        case None => match (homeDir()) {
            case Some(h) => h + "/.config"
            case None => return None
        }
    }
    Some(configBase + "/" + name)
}

// 辅助函数：获取环境变量
func getEnv(key: String): ?String {
    getVariable(key)
}

// ============================================================
// realpath 函数 — 对齐 Rust: gix_path::realpath
// 注意：仓颉版 realpath 使用 std.fs.canonicalize 实现符号链接解析
// ============================================================

// 解析真实路径
// 对齐 Rust: gix_path::realpath::function::realpath_opts
// 参数 path：待解析的路径
// 参数 currentDir：当前工作目录
// 参数 maxSymlinks：最大符号链接跟随次数（仓颉简化：不检查符号链接数量）
// 返回值: 解析后的真实路径，空路径返回空字符串
public func realpathOpts(path: String, currentDir: String, maxSymlinks: Int64): String {
    if (path.size == 0) {
        return ""
    }
    let isAbs = isAbsolute(path)
    let fullPath = if (isAbs) {
        path
    } else {
        join(currentDir, path)
    }
    let normalized = normalize(fullPath)
    // normalize 不保留绝对路径前缀，需要手动恢复
    let resolved = if (isAbs || isAbsolute(currentDir)) {
        "/" + normalized
    } else {
        normalized
    }
    try {
        let canon = canonicalize(resolved)
        canon.toString()
    } catch (_: Exception) {
        resolved
    }
}
