// 文件：value.cj
// 用途：Git 配置值的类型转换（字符串→布尔/整数）
// 所属包：gix.gix_config
// 关键类型：Value

package gitoxide.gix_config

import std.collection.*
import gitoxide.gix_utils.*

// Git 配置值，提供原始字符串到具体类型的转换方法
public class Value {
    // 原始字符串值
    public var raw: String

    // 构造配置值
    // 参数 raw - 原始字符串值
    public init(raw: String) {
        this.raw = raw
    }

    // 获取原始字符串值
    // 返回值 - 原始字符串
    public func asString(): String {
        raw
    }

    // 将值转换为布尔类型
    // 返回值 - "true"/"yes"/"on"/"1" 返回 Some(true)，"false"/"no"/"off"/"0"/"" 返回 Some(false)，其他返回 None
    public func asBoolean(): ?Bool {
        let lower = toLowerStr(trimStr(raw))
        if (lower == "true" || lower == "yes" || lower == "on" || lower == "1") {
            return Some(true)
        }
        if (lower == "false" || lower == "no" || lower == "off" || lower == "0" || lower == "") {
            return Some(false)
        }
        None
    }

    // 将值转换为整数类型，支持 k/m/g 后缀（1024 倍数）
    // 返回值 - 解析成功返回 Some(整数值)，解析失败返回 None
    public func asInteger(): ?Int64 {
        try {
            let trimmed = trimStr(raw)
            var numEnd: Int64 = 0
            while (numEnd < trimmed.size) {
                let c = trimmed[numEnd]
                if (!((c >= UInt8(48) && c <= UInt8(57)) || c == UInt8(45))) {
                    break
                }
                numEnd += 1
            }
            if (numEnd == 0) {
                return None
            }
            let numPart = substringStr(trimmed, 0, numEnd)
            let vOpt = parseInt(numPart)
            if (let Some(v) <- vOpt) {
                if (numEnd < trimmed.size) {
                    let unit = toLowerStr(substringFromStr(trimmed, numEnd))
                    let multiplier = if (unit == "k") {
                        Int64(1024)
                    } else if (unit == "m") {
                        Int64(1024) * Int64(1024)
                    } else if (unit == "g") {
                        Int64(1024) * Int64(1024) * Int64(1024)
                    } else {
                        Int64(1)
                    }
                    Some(v * multiplier)
                } else {
                    Some(v)
                }
            } else {
                None
            }
        } catch (_: Exception) {
            None
        }
    }
}
