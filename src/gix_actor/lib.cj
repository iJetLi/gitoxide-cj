// 文件：lib.cj
// 所属包：gix.gix_actor
// 用途：定义 Git 签名/角色类型，用于表示提交者和作者的标识信息
// 关键类型：Sign, Time, Signature

package gitoxide.gix_actor

import std.convert.*
import gitoxide.gix_utils.*

// 时区偏移符号枚举
// 用于表示时区偏移的正负方向
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

// Git 签名中的时间类型
// 包含 Unix 时间戳和时区偏移信息，对应 Git 时间格式如 1234567890 +0800
public class Time {
    // Unix 时间戳（秒）
    public var seconds: Int64
    // 时区偏移量（分钟）
    public var offset: Int32
    // 偏移符号
    public var sign: Sign

    // 创建一个 Time 实例
    // 参数 seconds：Unix 时间戳（秒）
    // 参数 offset：时区偏移量（分钟）
    // 参数 sign：偏移符号
    public init(seconds: Int64, offset: Int32, sign: Sign) {
        this.seconds = seconds
        this.offset = offset
        this.sign = sign
    }
}

// Git 签名类型
// 表示 Git 提交中的作者或提交者信息
// 标准格式为 Name email timestamp signHHMM
public class Signature {
    // 姓名
    public var name: String
    // 电子邮件地址
    public var email: String
    // 时间信息
    public var time: Time

    // 创建一个 Signature 实例
    // 参数 name：姓名
    // 参数 email：电子邮件地址
    // 参数 time：时间信息
    public init(name: String, email: String, time: Time) {
        this.name = name
        this.email = email
        this.time = time
    }

    // 从字节数组解析 Git 签名
    // 格式为 Name email timestamp signHHMM
    // 参数 input：Git 格式签名的字节数组
    // 返回值：解析成功返回 Some(Signature)，格式错误返回 None
    public static func parse(input: Array<Byte>): ?Signature {
        let str = String.fromUtf8(input)
        let ltIdx = str.indexOf("<")
        let gtIdx = str.indexOf(">")
        if (let Some(lt) <- ltIdx) {
            if (let Some(gt) <- gtIdx) {
                if (gt <= lt) {
                    return None
                }
                let n = trimStr(substringStr(str, 0, lt))
                let e = trimStr(substringStr(str, lt + 1, gt))
                let rest = trimStr(substringFromStr(str, gt + 1))
                let parts = rest.split(" ")
                if (parts.size < 2) {
                    return None
                }
                let secondsOpt = parseInt(parts[0])
                if (let Some(sv) <- secondsOpt) {
                    parseOffset(parts[1], n, e, sv)
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    // 解析时区偏移部分并构造 Signature
    // 参数 offsetStr：时区偏移字符串，格式为 signHHMM
    // 参数 n：姓名
    // 参数 e：邮箱
    // 参数 sv：时间戳
    // 返回值：解析成功返回 Some(Signature)，格式错误返回 None
    static func parseOffset(offsetStr: String, n: String, e: String, sv: Int64): ?Signature {
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
                Some(Signature(n, e, Time(sv, off, sign)))
            } else {
                None
            }
        } else {
            None
        }
    }

    // 将签名序列化为字节数组
    // 输出格式为 Name email timestamp signHHMM
    // 返回值：Git 格式签名的字节数组
    public func toBytes(): Array<Byte> {
        let signStr = match (time.sign) {
            case Sign.Plus => "+"
            case Sign.Minus => "-"
        }
        let offsetHours = time.offset / 60
        let offsetMins = time.offset % 60
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
        let result = name + " <" + email + "> " + time.seconds.toString() + " " + signStr + hStr + mStr
        result.toArray()
    }
}
