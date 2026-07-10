// 文件：lib.cj
// 用途：Git pkt-line 格式编解码，用于 Git 协议中行数据的分帧传输
// 所属包：gix.gix_packetline
// 关键类型：PacketLine

package gitoxide.gix_packetline

import std.collection.*
import gitoxide.gix_utils.*

// Git pkt-line 数据行，封装一行协议数据
public class PacketLine {
    // 行数据内容（不含 4 字节长度前缀）
    public var data: Array<Byte>

    // 参数 data: 行数据内容
    public init(data: Array<Byte>) {
        this.data = data
    }

    // 将行数据编码为 pkt-line 格式（4 字节十六进制长度前缀 + 数据）
    // 参数 line: 原始行数据
    // 返回值: 带 4 字节长度前缀的编码数据
    public static func encode(line: Array<Byte>): Array<Byte> {
        var result = ArrayList<Byte>()
        let len = line.size + 4
        let hex = int64ToHex(len)
        var padCount = 4 - hex.size
        var padIdx: Int64 = 0
        while (padIdx < padCount) {
            result.add(UInt8(48))
            padIdx++
        }
        for (b in hex.toArray()) {
            result.add(b)
        }
        for (b in line) {
            result.add(b)
        }
        result.toArray()
    }

    // 从原始数据解码 pkt-line 格式，提取行内容
    // 参数 data: 包含 pkt-line 帧的原始数据
    // 返回值: 解码成功返回 PacketLine，数据不足或格式错误返回 None
    public static func decode(data: Array<Byte>): ?PacketLine {
        if (data.size < 4) {
            return None
        }
        let hexStr = bytesToStringPL(data, 0, 4)
        let lenOpt = parseHexInt64(hexStr)
        if (let Some(len) <- lenOpt) {
            if (len < 4) {
                return Some(PacketLine(Array<Byte>()))
            }
            if (len > data.size) {
                return None
            }
            Some(PacketLine(sliceBytesPL(data, 4, len)))
        } else {
            None
        }
    }

    // 生成 flush-pkt 标记（"0000"），表示数据段结束
    // 返回值: flush-pkt 字节数组
    public static func flush(): Array<Byte> {
        "0000".toArray()
    }

    // 生成分隔符标记（"0001"），用于协议 V2 分隔不同部分
    // 返回值: 分隔符字节数组
    public static func delimiter(): Array<Byte> {
        "0001".toArray()
    }

    // 生成响应结束标记（"0002"），用于协议 V2 表示响应结束
    // 返回值: 响应结束字节数组
    public static func responseEnd(): Array<Byte> {
        "0002".toArray()
    }
}

func int64ToHex(v: Int64): String {
    if (v == 0) {
        return "0"
    }
    var val = v
    var chars = ArrayList<UInt8>()
    while (val > 0) {
        let digit = val % 16
        if (digit < 10) {
            chars.add(UInt8(digit + 48))
        } else {
            chars.add(UInt8(digit + 87))
        }
        val = val / 16
    }
    var sb = StringBuilder()
    var i = chars.size - 1
    while (i >= 0) {
        sb.append(Rune(chars[i]))
        i -= 1
    }
    sb.toString()
}

// 将字节数组的指定范围转换为字符串
// 参数 data: 源字节数组
// 参数 start: 起始位置（含）
// 参数 end: 结束位置（不含）
// 返回值: 转换后的字符串
func bytesToStringPL(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}

// 切片字节数组的指定范围
// 参数 data: 源字节数组
// 参数 start: 起始位置（含）
// 参数 end: 结束位置（不含）
// 返回值: 切片后的新字节数组
func sliceBytesPL(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}
