// 文件：lib.cj
// 用途：提供 Git 归档生成功能，将仓库文件打包为 tar 格式
// 所属包：gix.gix_archive
// 关键类型：Archive, ArchiveEntry
// 关键函数：writeTar

package gitoxide.gix_archive

import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*

// 归档容器，包含多个归档条目
public class Archive {
    // 归档中的条目列表
    public var entries: ArrayList<ArchiveEntry>

    public init() {
        this.entries = ArrayList<ArchiveEntry>()
    }

    // 向归档中添加一个条目
    // 参数 path：文件路径
    // 参数 mode：文件模式
    // 参数 data：文件内容
    public func addEntry(path: String, mode: Int64, data: Array<Byte>): Unit {
        entries.add(ArchiveEntry(path, mode, data))
    }
}

// 归档条目，表示归档中的单个文件
public class ArchiveEntry {
    // 文件路径
    public var path: String
    // 文件模式（如 0o100644）
    public var mode: Int64
    // 文件内容的字节数据
    public var data: Array<Byte>

    public init(path: String, mode: Int64, data: Array<Byte>) {
        this.path = path
        this.mode = mode
        this.data = data
    }
}

// 将归档写入为 tar 格式的字节数组
// 参数 archive：待写入的归档对象
// 返回值：tar 格式的字节数组
public func writeTar(archive: Archive): Array<Byte> {
    var result = ArrayList<Byte>()
    for (entry in archive.entries) {
        // 写入 tar header（512 字节）
        // name: 100 字节
        let pathBytes = entry.path.toArray()
        let nameLen = if (pathBytes.size > 100) {
            100
        } else {
            pathBytes.size
        }
        var i: Int64 = 0
        while (i < 100) {
            if (i < nameLen) {
                result.add(pathBytes[i])
            } else {
                result.add(UInt8(0))
            }
            i += 1
        }
        // mode: 8 字节
        writeOctal(result, entry.mode, 8)
        // uid: 8 字节
        writeOctal(result, 0, 8)
        // gid: 8 字节
        writeOctal(result, 0, 8)
        // size: 12 字节
        writeOctal(result, entry.data.size, 12)
        // mtime: 12 字节
        writeOctal(result, 0, 12)
        // checksum: 8 字节（占位，稍后计算）
        var checksumStart = result.size
        i = 0
        while (i < 8) {
            result.add(UInt8(32))
            i += 1
        }
        // typeflag: 1 字节
        result.add(UInt8(48))
        // linkname: 100 字节
        i = 0
        while (i < 100) {
            result.add(UInt8(0))
            i += 1
        }
        // magic: 6 字节
        for (b in "ustar".toArray()) {
            result.add(b)
        }
        result.add(UInt8(0))
        // version: 2 字节
        result.add(UInt8(48))
        result.add(UInt8(48))
        // uname: 32 字节
        i = 0
        while (i < 32) {
            result.add(UInt8(0))
            i += 1
        }
        // gname: 32 字节
        i = 0
        while (i < 32) {
            result.add(UInt8(0))
            i += 1
        }
        // devmajor: 8 字节
        writeOctal(result, 0, 8)
        // devminor: 8 字节
        writeOctal(result, 0, 8)
        // prefix: 155 字节
        i = 0
        while (i < 155) {
            result.add(UInt8(0))
            i += 1
        }
        // padding: 12 字节
        i = 0
        while (i < 12) {
            result.add(UInt8(0))
            i += 1
        }
        // 计算并写入 checksum
        var headerStart = result.size - 512
        var checksum: Int64 = 0
        i = 0
        while (i < 512) {
            let idx = headerStart + i
            if (i >= checksumStart - headerStart && i < checksumStart - headerStart + 8) {
                checksum += 32
            } else {
                checksum += Int64(result[idx])
            }
            i += 1
        }
        var checkRevDigits = ArrayList<Byte>()
        var cv = checksum
        if (cv == 0) {
            checkRevDigits.add(UInt8(48))
        } else {
            while (cv > 0) {
                checkRevDigits.add(UInt8(48 + (cv % 8)))
                cv = cv / 8
            }
        }
        // 格式: 6位八进制 + null + space = 8字节
        var padCheck = 6 - checkRevDigits.size
        if (padCheck < 0) {
            padCheck = 0
        }
        var ci: Int64 = 0
        while (ci < padCheck) {
            result[checksumStart + ci] = UInt8(48)
            ci += 1
        }
        var dj = checkRevDigits.size - 1
        while (dj >= 0) {
            result[checksumStart + ci] = checkRevDigits[dj]
            ci += 1
            dj -= 1
        }
        result[checksumStart + 6] = UInt8(0)
        result[checksumStart + 7] = UInt8(32)
        // 写入数据
        for (b in entry.data) {
            result.add(b)
        }
        // 数据填充到 512 字节边界
        let remainder = 512 - (entry.data.size % 512)
        if (remainder < 512) {
            i = 0
            while (i < remainder) {
                result.add(UInt8(0))
                i += 1
            }
        }
    }
    result.toArray()
}

// 写入八进制数字到结果数组
func writeOctal(result: ArrayList<Byte>, value: Int64, width: Int64): Unit {
    var revDigits = ArrayList<Byte>()
    var v = value
    if (v == 0) {
        revDigits.add(UInt8(48))
    } else {
        while (v > 0) {
            revDigits.add(UInt8(48 + (v % 8)))
            v = v / 8
        }
    }
    var padLen = width - revDigits.size
    if (padLen < 0) {
        padLen = 0
    }
    var i: Int64 = 0
    while (i < padLen) {
        result.add(UInt8(48))
        i += 1
    }
    var j = revDigits.size - 1
    while (j >= 0) {
        result.add(revDigits[j])
        j -= 1
    }
}
