// 文件：lib.cj
// 用途：提供 Git 归档生成功能，将仓库文件打包为 POSIX tar 格式（含 pax 扩展头）
// 所属包：gix.gix_archive
// 关键类型：Archive, ArchiveEntry
// 关键函数：writeTar, writeTarEntry, writeOctal
// 对齐 Rust: gix-archive/src/lib.rs, gix-archive/src/tar.rs

package gitoxide.gix_archive

import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*

// 归档容器，包含多个归档条目及对应的 commit 标识
public class Archive {
    // 归档中的条目列表
    public var entries: ArrayList<ArchiveEntry>
    // 归档对应的 commit SHA-1，写入 pax_global_header 的 comment 字段
    public var commitId: String

    // 初始化空归档
    public init() {
        this.entries = ArrayList<ArchiveEntry>()
        this.commitId = ""
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

    // 参数 path：文件路径
    // 参数 mode：文件模式
    // 参数 data：文件内容
    public init(path: String, mode: Int64, data: Array<Byte>) {
        this.path = path
        this.mode = mode
        this.data = data
    }
}

// 将归档写入为 POSIX ustar tar 格式字节数组
// 格式：pax_global_header + 文件条目 + 两个全零结束块
// 对齐 Rust: gix-archive/src/tar.rs::write()
public func writeTar(archive: Archive): Array<Byte> {
    var result = ArrayList<Byte>()
    // pax_global_header（typeflag='g'），包含 commit SHA-1 作为 comment
    var paxData = ArrayList<Byte>()
    var paxLine = " comment=" + archive.commitId + "\n"
    // 计算 pax 扩展头的长度前缀
    var paxLen = paxLine.size + 2
    if (paxLen >= 100) {
        paxLen = paxLen + 1
    }
    var paxFullLine = paxLen.toString() + paxLine
    for (b in paxFullLine.toArray()) {
        paxData.add(b)
    }
    writeTarEntry(result, "pax_global_header", 0o666, paxData.toArray(), UInt8(103))
    // 写入每个文件条目
    for (entry in archive.entries) {
        writeTarEntry(result, entry.path, entry.mode, entry.data, UInt8(48))
    }
    // 结束标记：两个 512 字节的全零块
    var i: Int64 = 0
    while (i < 1024) {
        result.add(UInt8(0))
        i += 1
    }
    result.toArray()
}

// 写入单个 tar 条目（512 字节 header + 数据 + 填充）
// 参数 result：输出字节缓冲
// 参数 name：文件名
// 参数 mode：文件模式（仅权限位会被写入 header）
// 参数 data：文件内容
// 参数 typeflag：类型标志（0=普通文件, g=pax_global_header）
// 对齐 Rust: gix-archive/src/tar.rs 内部 tar 头构建逻辑
func writeTarEntry(result: ArrayList<Byte>, name: String, mode: Int64, data: Array<Byte>, typeflag: UInt8): Unit {
    // name 字段：100 字节
    var pathBytes = name.toArray()
    var nameLen = if (pathBytes.size > 100) {
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
    // mode 字段：8 字节，仅保留权限位（0o7777），与 git archive 行为一致
    writeOctal(result, mode % 8192, 8)
    // uid 字段：8 字节
    writeOctal(result, 0, 8)
    // gid 字段：8 字节
    writeOctal(result, 0, 8)
    // size 字段：12 字节
    writeOctal(result, data.size, 12)
    // mtime 字段：12 字节
    writeOctal(result, 0, 12)
    // checksum 字段：8 字节占位（空格）
    var checksumStart = result.size
    i = 0
    while (i < 8) {
        result.add(UInt8(32))
        i += 1
    }
    // typeflag 字段：1 字节
    result.add(typeflag)
    // linkname 字段：100 字节
    i = 0
    while (i < 100) {
        result.add(UInt8(0))
        i += 1
    }
    // magic 字段：6 字节 "ustar\0"
    for (b in "ustar".toArray()) {
        result.add(b)
    }
    result.add(UInt8(0))
    // version 字段：2 字节 "00"
    result.add(UInt8(48))
    result.add(UInt8(48))
    // uname 字段：32 字节
    i = 0
    while (i < 32) {
        result.add(UInt8(0))
        i += 1
    }
    // gname 字段：32 字节
    i = 0
    while (i < 32) {
        result.add(UInt8(0))
        i += 1
    }
    // devmajor 字段：8 字节
    writeOctal(result, 0, 8)
    // devminor 字段：8 字节
    writeOctal(result, 0, 8)
    // prefix 字段：155 字节
    i = 0
    while (i < 155) {
        result.add(UInt8(0))
        i += 1
    }
    // padding 字段：12 字节
    i = 0
    while (i < 12) {
        result.add(UInt8(0))
        i += 1
    }
    // 计算并回写 checksum：对 header 512 字节求和，checksum 位按空格（32）计
    var headerStart = result.size - 512
    var checksum: Int64 = 0
    i = 0
    while (i < 512) {
        var idx = headerStart + i
        if (i >= checksumStart - headerStart && i < checksumStart - headerStart + 8) {
            checksum += 32
        } else {
            checksum += Int64(result[idx])
        }
        i += 1
    }
    // 将 checksum 写为 6 位八进制 + null + space
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
    // 写入文件数据
    for (b in data) {
        result.add(b)
    }
    // 数据填充到 512 字节边界
    var remainder = 512 - (data.size % 512)
    if (remainder < 512) {
        i = 0
        while (i < remainder) {
            result.add(UInt8(0))
            i += 1
        }
    }
}

// 写入八进制数字到结果数组
// 格式：前导零 + 数字 + 空终止符，总宽度 width 字节
// 参数 result：输出字节缓冲
// 参数 value：数值
// 参数 width：字段宽度（含空终止符）
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
    var padLen = width - 1 - revDigits.size
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
    result.add(UInt8(0))
}
