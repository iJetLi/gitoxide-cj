// 文件：parse.cj
// 所属包：gix.gix_ref
// 用途：提供引用解析相关的工具函数，包括十六进制哈希解析和换行符解析
// 关键函数：parseHexHash, parseNewline

package gitoxide.gix_ref

import gitoxide.gix_hash.*

// 从字节数据的指定偏移位置解析十六进制哈希字符串
// 验证字符是否为合法的十六进制字符（0-9、A-F、a-f）
// 参数 data - 源字节数组
// 参数 offset - 起始偏移位置
// 参数 hashKind - 哈希算法类型，决定哈希长度（SHA-1: 40字符, SHA-256: 64字符）
// 返回值 - 解析成功返回 Some(十六进制字符串)，数据不足或包含非法字符返回 None
public func parseHexHash(data: Array<Byte>, offset: Int64, hashKind: HashKind): ?String {
    let len = hashKindLenInHexRef(hashKind)
    if (offset + len > data.size) {
        return None
    }
    var i: Int64 = 0
    while (i < len) {
        let b = data[offset + i]
        if (!((b >= UInt8(48) && b <= UInt8(57)) || (b >= UInt8(65) && b <= UInt8(70)) || (b >= UInt8(97) && b <= UInt8(102)))) {
            return None
        }
        i += 1
    }
    Some(bytesToStringParse(data, offset, offset + len))
}

// 解析换行符，支持 CRLF（\r\n）和 LF（\n）两种格式
// 参数 data - 源字节数组
// 参数 offset - 起始偏移位置
// 返回值 - 解析成功返回 Some(换行符后的偏移位置)，无换行符返回 None
public func parseNewline(data: Array<Byte>, offset: Int64): ?Int64 {
    if (offset + 1 < data.size && data[offset] == UInt8(13) && data[offset + 1] == UInt8(10)) {
        Some(offset + 2)
    } else if (offset < data.size && data[offset] == UInt8(10)) {
        Some(offset + 1)
    } else {
        None
    }
}

// 根据哈希算法类型获取十六进制表示的字符长度
// 参数 kind - 哈希算法类型
// 返回值 - SHA-1 返回 40，SHA-256 返回 64
func hashKindLenInHexRef(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 40
        case HashKind.Sha256 => 64
    }
}

// 将字节数组的指定范围转换为字符串
// 参数 data - 源字节数组
// 参数 start - 起始位置（包含）
// 参数 end - 结束位置（不包含）
// 返回值 - 转换后的字符串
func bytesToStringParse(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
