// 文件：lib.cj
// 用途：提供 Git 配置值的类型化解析
// 所属包：gix.gix_config_value

package gitoxide.gix_config_value

import std.collection.*
import gitoxide.gix_utils.*
import std.convert.*

public enum Boolean {
    | True // 真
    | False
}

extend Boolean <: Equatable<Boolean> {
    public operator func ==(other: Boolean): Bool {
        match (this) {
            case Boolean.True => match (other) {
                case Boolean.True => true
                case _ => false
            }
            case Boolean.False => match (other) {
                case Boolean.False => true
                case _ => false
            }
        }
    }
}

// 解析字符串为 Git 配置布尔值
// 参数 s - 待解析的字符串
// 返回值 - "true"/"yes"/"on"/"1" 返回 Some(True)，"false"/"no"/"off"/"0"/"" 返回 Some(False)，其他返回 None
public func parseBoolean(s: String): ?Boolean {
    let lower = toLowerStr(s)
    if (lower == "true" || lower == "yes" || lower == "on" || lower == "1") {
        Some(Boolean.True)
    } else if (lower == "false" || lower == "no" || lower == "off" || lower == "0" || lower == "") {
        Some(Boolean.False)
    } else {
        None
    }
}

// Git 配置整数值，包含数值和可选的单位后缀
public class Integer {
    // 原始数值（不含单位乘数）
    public var value: Int64
    // 原始单位后缀，如 "k"、"m"、"g"，无后缀时为 None
    public var unit: ?String

    // 构造整数值
    // 参数 value - 原始数值
    // 参数 unit - 单位后缀
    public init(value: Int64, unit: ?String) {
        this.value = value
        this.unit = unit
    }

    // 返回乘以单位倍数后的十进制值
    // 对齐 Rust: Integer::as_decimal()
    public func asDecimal(): Int64 {
        value * computeMultiplier(unit)
    }

    // 从字符串解析整数值，支持 k/m/g 后缀
    // 参数 s - 待解析的字符串
    // 返回值 - 解析成功返回 Some(Integer)，失败返回 None
    public static func parse(s: String): ?Integer {
        var numStr = ""
        var unitStr: ?String = None
        var i: Int64 = 0
        while (i < s.size) {
            let c = s[i]
            if ((c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(45)) {
                numStr += Rune(c).toString()
            } else {
                unitStr = Some(toLowerStr(substringFromStr(s, i)))
                break
            }
            i += 1
        }
        if (numStr.size == 0) {
            return None
        }
        let vOpt = parseInt(numStr)
        if (let Some(v) <- vOpt) {
            Some(Integer(v, unitStr))
        } else {
            None
        }
    }
}

// 计算单位乘数
// 参数 unitStr：单位字符串，如 "k"、"m"、"g"
// 返回值：对应的乘数值
func computeMultiplier(unitStr: ?String): Int64 {
    if (let Some(u) <- unitStr) {
        if (u == "k") {
            1024
        } else if (u == "m") {
            1024 * 1024
        } else if (u == "g") {
            1024 * 1024 * 1024
        } else {
            1
        }
    } else {
        1
    }
}

// Git 配置颜色值，包含前景色、背景色和属性列表
public class Color {
    // 前景色名称，如 "red"、"green"
    public var foreground: ?String
    // 背景色名称
    public var background: ?String
    // 属性列表，如 "bold"、"underline"
    public var attributes: ArrayList<String>

    // 构造颜色值
    // 参数 foreground - 前景色
    // 参数 background - 背景色
    // 参数 attributes - 属性列表
    public init(foreground: ?String, background: ?String, attributes: ArrayList<String>) {
        this.foreground = foreground
        this.background = background
        this.attributes = attributes
    }

    // 从字符串解析颜色值，格式为 "前景色 背景色 属性..."
    // 参数 s - 颜色字符串，如 "red black bold"
    // 返回值 - 解析成功返回 Some(Color)，空字符串返回 None
    public static func parse(s: String): ?Color {
        let parts = s.split(" ")
        if (parts.size == 0) {
            return None
        }
        var fg: ?String = None
        var bg: ?String = None
        var attrs = ArrayList<String>()
        for (part in parts) {
            let lower = toLowerStr(part)
            if (isColorName(lower)) {
                if (let Some(_) <- fg) {
                    bg = Some(lower)
                } else {
                    fg = Some(lower)
                }
            } else {
                attrs.add(lower)
            }
        }
        Some(Color(fg, bg, attrs))
    }
}

// 判断字符串是否为合法的颜色名称
// 参数 s - 待判断的字符串
// 返回值 - 是颜色名称返回 true，否则返回 false
func isColorName(s: String): Bool {
    if (s == "normal" || s == "default" || s == "black" || s == "red" || s == "green" || s == "yellow" || s == "blue" ||
        s == "magenta" || s == "cyan" || s == "white" || s == "brightblack" || s == "brightred" || s == "brightgreen" ||
        s == "brightyellow" || s == "brightblue" || s == "brightmagenta" || s == "brightcyan" || s == "brightwhite") {
        return true
    }
    if (s.size > 0 && s[0] >= UInt8(48) && s[0] <= UInt8(57)) {
        return true
    }
    false
}

// Git 配置路径值，包含路径字符串和是否为用户主目录相对路径的标记
public class PathValue {
    // 路径字符串
    public var value: String
    // 是否以 "~/" 开头（相对于用户主目录）
    public var isHomeRelative: Bool

    // 构造路径值
    // 参数 value - 路径字符串
    // 参数 isHomeRelative - 是否为用户主目录相对路径
    public init(value: String, isHomeRelative: Bool) {
        this.value = value
        this.isHomeRelative = isHomeRelative
    }

    public static func parse(s: String): PathValue {
        let isHome = s.startsWith("~/")
        PathValue(s, isHome)
    }
}
