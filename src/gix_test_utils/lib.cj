// 文件：lib.cj
// 用途：提供测试辅助工具函数，包括夹具加载、十六进制转换和 CRLF 修复
// 所属包：gix.gix_test_utils
// 关键函数：fixture, fixtureBytes, hexToId, fixup

package gitoxide.gix_test_utils

import std.fs.*
import std.collection.*
import gitoxide.gix_hash.*

// 获取测试夹具文件的绝对路径
// 参数 relativePath：相对于 tests/fixtures/ 目录的路径
// 返回值：夹具文件的绝对路径
// 异常：文件不存在时抛出异常
public func fixture(relativePath: String): String {
    let baseDir = getProjectRoot()
    let p = baseDir + "/tests/fixtures/" + relativePath
    if (!exists(p)) {
        throw Exception("fixture not found: " + p)
    }
    p
}

// 读取测试夹具文件的字节数据
// 参数 relativePath：相对于 tests/fixtures/ 目录的路径
// 返回值：夹具文件的字节数据
public func fixtureBytes(relativePath: String): Array<Byte> {
    let p = fixture(relativePath)
    let file = File(p, OpenMode.Read)
    var bytes = ArrayList<Byte>()
    var buf = Array<Byte>(4096, repeat: 0)
    var n = file.read(buf)
    while (n > 0) {
        for (i in 0..n) {
            bytes.add(buf[i])
        }
        n = file.read(buf)
    }
    file.close()
    bytes.toArray()
}

// 将十六进制字符串转换为 ObjectId
// 参数 hex：40 或 64 字符的十六进制哈希字符串
// 返回值：对应的 ObjectId 实例
public func hexToId(hex: String): ObjectId {
    ObjectId.fromHex(hex)
}

// 修复字节数据中的 CRLF 换行符，将 \r\n 转换为 \n
// 用于 Windows 平台兼容，确保文本夹具内容一致
// 参数 bytes：待修复的字节数据
// 返回值：修复后的字节数据
public func fixup(bytes: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    var i: Int64 = 0
    while (i < bytes.size) {
        if (i + 1 < bytes.size && bytes[i] == UInt8(13) && bytes[i + 1] == UInt8(10)) {
            result.add(UInt8(10))
            i += 2
        } else {
            result.add(bytes[i])
            i += 1
        }
    }
    result.toArray()
}

// 获取项目根目录路径
// 返回值：包含 cjpm.toml 的目录路径
func getProjectRoot(): String {
    "."
}
