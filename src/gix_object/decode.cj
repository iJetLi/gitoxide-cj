// 文件：decode.cj
// 所属包：gix.gix_object
// 用途：定义 Git 松散对象的头部解码函数
// 说明：解析松散对象头部格式 "<kind> <size>\0"，提取对象类型和数据大小

package gitoxide.gix_object

import std.collection.*

// 解码松散对象头部
// 从字节数据中解析 "<kind> <size>\0" 格式的头部
// 参数 input：松散对象的完整字节数据（含头部和对象体）
// 返回值：解析成功返回 (对象类型, 数据大小, 头部结束偏移量) 三元组，失败返回 None
public func decodeLooseHeader(input: Array<Byte>): ?(ObjectKind, Int64, Int64) {
    var pos: Int64 = 0
    let kindStart = pos
    while (pos < input.size && input[pos] != UInt8(32)) {
        pos += 1
    }
    if (pos >= input.size) {
        return None
    }
    let kindBytes = sliceBytes3(input, kindStart, pos)
    let kindOpt = kindFromBytes(kindBytes)
    if (let Some(k) <- kindOpt) {
        pos += 1
        let sizeStart = pos
        while (pos < input.size && input[pos] != UInt8(0)) {
            pos += 1
        }
        if (pos >= input.size) {
            return None
        }
        let sizeBytes = sliceBytes3(input, sizeStart, pos)
        let sizeOpt = parseSize(sizeBytes)
        if (let Some(s) <- sizeOpt) {
            pos += 1
            Some((k, s, pos))
        } else {
            None
        }
    } else {
        None
    }
}

// 截取字节数组的指定范围
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：截取得到的新字节数组
func sliceBytes3(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 解析十进制数字字节数组为整数
// 将 ASCII 数字字节（'0'-'9'）解析为对应的整数值
// 参数 bytes：包含 ASCII 数字字符的字节数组
// 返回值：解析成功返回整数值，包含非数字字符则返回 None
func parseSize(bytes: Array<Byte>): ?Int64 {
    var result: Int64 = 0
    for (b in bytes) {
        if (b < UInt8(48) || b > UInt8(57)) {
            return None
        }
        result = result * 10 + Int64(b - 48)
    }
    Some(result)
}
