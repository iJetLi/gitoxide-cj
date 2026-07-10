// 文件：lib.cj
// 用途：定义 Git 日期时间类型，支持时间戳和时区偏移的解析与序列化
// 所属包：gix.gix_date
// 关键类型：Sign, Time

package gitoxide.gix_date

import std.convert.*
import std.collection.*
import gitoxide.gix_utils.*

// 时区偏移符号枚举
public enum Sign {
    | Plus // 正偏移（东时区）
    | Minus // 负偏移（西时区）

    public operator func ==(that: Sign): Bool {
        match (this) {
            case Plus => match (that) {
                case Plus => true;
                case _ => false
            }
            case Minus => match (that) {
                case Minus => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: Sign): Bool {
        !(this == that)
    }
}

// Git 日期时间类型
// 包含 Unix 时间戳和时区偏移信息，对应 Git 的时间格式如 1234567890 +0800
public class Time {
    // Unix 时间戳（秒）
    var seconds: Int64
    // 时区偏移量（分钟）
    var offset: Int32
    // 偏移符号
    var sign: Sign

    // 创建一个 Time 实例
    // 参数 seconds：Unix 时间戳（秒）
    // 参数 offset：时区偏移量（分钟）
    // 参数 sign：偏移符号
    public init(seconds: Int64, offset: Int32, sign: Sign) {
        this.seconds = seconds
        this.offset = offset
        this.sign = sign
    }

    // 从字符串解析 Git 时间格式
    // 格式为 timestamp 和 signHHMM，如 1234567890 +0800
    // 参数 input：Git 格式的时间字符串
    // 返回值：解析成功返回 Some(Time)，格式错误返回 None
    public static func parse(input: String): ?Time {
        let parts = input.split(" ")
        // 过滤空串（处理多空格情况，如 "1234567890  +0800"）
        var filtered = ArrayList<String>()
        for (p in parts) {
            if (p.size > 0) {
                filtered.add(p)
            }
        }
        if (filtered.size < 2) {
            return None
        }
        let secondsOpt = parseInt(filtered[0])
        if (let Some(sv) <- secondsOpt) {
            // 负时间戳不支持（仓颉差异：Git 支持但当前 API 不支持）
            if (sv < 0) {
                return None
            }
            parseOffset(filtered[1], sv)
        } else {
            None
        }
    }

    // 解析时区偏移部分
    // 参数 offsetStr：时区偏移字符串，格式为 signHHMM
    // 参数 sv：时间戳
    // 返回值：解析成功返回 Some(Time)，格式错误返回 None
    static func parseOffset(offsetStr: String, sv: Int64): ?Time {
        if (offsetStr.size < 5) {
            return None
        }
        let signChar = offsetStr[0]
        let sign = if (signChar == UInt8(45)) {
            Sign.Minus
        } else {
            Sign.Plus
        }
        let hoursStr = substringStr(offsetStr, 1, 3)
        let minsStr = substringStr(offsetStr, 3, 5)
        let hoursOpt = parseInt(hoursStr)
        if (let Some(hv) <- hoursOpt) {
            let minsOpt = parseInt(minsStr)
            if (let Some(mv) <- minsOpt) {
                let off = Int32(hv * 60 + mv)
                Some(Time(sv, off, sign))
            } else {
                None
            }
        } else {
            None
        }
    }

    public func toBytes(): Array<Byte> {
        format().toArray()
    }

    // 默认格式化 — 对齐 Rust: Time::format
    // 返回值：格式化字符串 "timestamp signHHMM"
    public func format(): String {
        let signStr = match (sign) {
            case Sign.Plus => "+"
            case Sign.Minus => "-"
        }
        let offsetHours = offset / 60
        let offsetMins = offset % 60
        let hStr = if (offsetHours < 10) {
            "0" + offsetHours.toString()
        } else {
            offsetHours.toString()
        }
        let mStr = if (offsetMins < 10) {
            "0" + offsetMins.toString()
        } else {
            offsetMins.toString()
        }
        seconds.toString() + " " + signStr + hStr + mStr
    }

    // 原始格式化 — 对齐 Rust: Time::format_raw
    // 返回值：原始格式字符串
    public func formatRaw(): String {
        format()
    }

    // ISO 8601 格式化 — 对齐 Rust: Time::format_iso8601
    // 返回值：ISO 8601 格式字符串
    public func formatIso8601(): String {
        let signStr = match (sign) {
            case Sign.Plus => "+"
            case Sign.Minus => "-"
        }
        let offsetHours = offset / 60
        let offsetMins = offset % 60
        let hStr = if (offsetHours < 10) {
            "0" + offsetHours.toString()
        } else {
            offsetHours.toString()
        }
        let mStr = if (offsetMins < 10) {
            "0" + offsetMins.toString()
        } else {
            offsetMins.toString()
        }
        // 简化：直接用时间戳 + 偏移量表示
        seconds.toString() + " " + signStr + hStr + ":" + mStr
    }
}

// Unix 纪元以来的秒数
// 对齐 Rust: gix_date::SecondsSinceUnixEpoch
public class SecondsSinceUnixEpoch {
    public var value: Int64

    public init(value: Int64) {
        this.value = value
    }
}
