// 文件：lib.cj
// 用途：Git 索引文件（.git/index）解析与编码，管理暂存区条目
// 所属包：gix.gix_index
// 关键类型：IndexEntry, IndexFile
// 对齐 Rust: gix-index/src/lib.rs, gix-index/src/decode/mod.rs, gix-index/src/file/mod.rs, gix-index/src/entry/mod.rs

package gitoxide.gix_index

import gitoxide.gix_hash.*
import std.fs.*
import std.collection.*

// 索引条目，对应暂存区中的一个文件记录
// 对齐 Rust: gix_index::entry::Stat
public class IndexEntry {
    // 创建时间的秒部分
    public var ctimeS: Int64
    // 创建时间的纳秒部分
    public var ctimeN: Int64
    // 修改时间的秒部分
    public var mtimeS: Int64
    // 修改时间的纳秒部分
    public var mtimeN: Int64
    // 设备号
    public var dev: Int64
    // inode 号
    public var ino: Int64
    // 文件模式（权限位），对齐 Rust: gix_index::entry::Mode
    public var mode: Int64
    // 用户 ID
    public var uid: Int64
    // 组 ID
    public var gid: Int64
    // 文件大小（字节）
    public var fileSize: Int64
    // 文件内容的对象 ID
    public var id: ObjectId
    // 条目标志位（包含名称长度等），对齐 Rust: gix_index::entry::Flags
    public var flags: Int64
    // 扩展标志位（版本 3+），对齐 Rust: gix_index::entry::FlagsExtended
    public var flagsExtended: Int64
    // 文件路径（相对于仓库根目录）
    public var path: String

    // 参数 path: 文件相对路径
    // 参数 id: 文件内容的对象 ID
    public init(path: String, id: ObjectId) {
        this.ctimeS = 0
        this.ctimeN = 0
        this.mtimeS = 0
        this.mtimeN = 0
        this.dev = 0
        this.ino = 0
        this.mode = 0
        this.uid = 0
        this.gid = 0
        this.fileSize = 0
        this.id = id
        this.flags = 0
        this.flagsExtended = 0
        this.path = path
    }
}

// 索引扩展数据，对齐 Rust: gix_index::extension
public class IndexExtension {
    // 扩展签名（4字节）
    public var signature: String
    // 扩展数据
    public var data: Array<Byte>

    public init(signature: String, data: Array<Byte>) {
        this.signature = signature
        this.data = data
    }
}

// 索引文件，对应 .git/index 暂存区文件
// 对齐 Rust: gix_index::File
public class IndexFile {
    // 索引文件格式版本号
    public var version: Int64
    // 暂存区条目列表
    public var entries: ArrayList<IndexEntry>
    // 扩展数据列表，对齐 Rust: gix_index::extension::decode
    public var extensions: ArrayList<IndexExtension>

    // 初始化空索引文件，默认版本号为 2
    public init() {
        this.version = 2
        this.entries = ArrayList<IndexEntry>()
        this.extensions = ArrayList<IndexExtension>()
    }

    // 从磁盘打开并解析索引文件
    // 对齐 Rust: gix_index::File::at
    // 参数 path: 索引文件路径
    // 返回值: 解析成功返回 IndexFile，文件不存在或解析失败返回 None
    public static func open(path: String): ?IndexFile {
        if (!exists(path)) {
            return None
        }
        try {
            let file = File(path, OpenMode.Read)
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
            let idx = IndexFile()
            idx.parse(bytes.toArray())
            Some(idx)
        } catch (_: Exception) {
            None
        }
    }

    // 将索引文件写入磁盘
    // 参数 path: 目标文件路径
    public func write(path: String): Unit {
        try {
            let file = File(path, OpenMode.Write)
            file.write(encode())
            file.close()
        } catch (_: Exception) {}
    }

    // 添加一条暂存区条目
    // 参数 entry: 要添加的索引条目
    public func add(entry: IndexEntry): Unit {
        entries.add(entry)
    }

    // 按路径查找暂存区条目（区分大小写）
    // 对齐 Rust: gix_index::File::entry_by_path
    // 参数 path: 文件相对路径
    // 返回值: 找到返回对应条目，未找到返回 None
    public func find(path: String): ?IndexEntry {
        for (entry in entries) {
            if (entry.path == path) {
                return Some(entry)
            }
        }
        None
    }

    // 按路径查找暂存区条目（不区分大小写）
    // 对齐 Rust: gix_index::File::entry_by_path_icase
    // 参数 path: 文件相对路径
    // 返回值: 找到返回对应条目，未找到返回 None
    public func findCaseInsensitive(path: String): ?IndexEntry {
        let pathLower = toLowerStr(path)
        for (entry in entries) {
            if (toLowerStr(entry.path) == pathLower) {
                return Some(entry)
            }
        }
        None
    }

    // 检查索引是否包含指定路径（不区分大小写）
    // 对齐 Rust: gix_index::File::has_path_icase
    // 参数 path: 文件相对路径
    // 返回值: 存在返回 true
    public func hasPathCaseInsensitive(path: String): Bool {
        findCaseInsensitive(path).isSome()
    }

    // 从字节数据解析索引文件内容
    // 对齐 Rust: gix_index::decode
    // 参数 data: 索引文件的原始字节数据
    func parse(data: Array<Byte>): Unit {
        if (data.size < 12) {
            return
        }
        let sig = bytesToStringIdx(data, 0, 4)
        if (sig != "DIRC") {
            return
        }
        version = readU32Idx(data, 4)
        let numEntries = readU32Idx(data, 8)
        var pos: Int64 = 12
        var i: Int64 = 0
        while (i < numEntries && pos + 62 <= data.size) {
            let entryStart = pos
            // 解析 stat 信息，对齐 Rust: gix_index::entry::Stat
            pos += 40
            let hashLen: Int64 = 20
            let hashStart = pos
            pos += hashLen
            let flagsStart = pos
            pos += 2
            let pathLen = (Int64(data[flagsStart]) << 8 | Int64(data[flagsStart + 1])) & 0xFFF
            // 版本 3+ 扩展标志，对齐 Rust: gix_index::entry::FlagsExtended
            if (version >= 3 && pathLen == 0xFFF) {
                if (pos + 2 <= data.size) {
                    pos += 2
                }
            }
            let pathStart = pos
            pos += pathLen
            let entryPath = bytesToStringIdx(data, pathStart, pos)
            let oidBytes = sliceBytesIdx(data, hashStart, hashStart + hashLen)
            let oid = ObjectId(oidBytes, HashKind.Sha1)
            let entry = IndexEntry(entryPath, oid)
            entry.flags = (Int64(data[flagsStart]) << 8 | Int64(data[flagsStart + 1]))
            entries.add(entry)
            let entryLen = 62 + pathLen
            let rawPad = (8 - (entryLen % 8)) % 8
            let padding = if (rawPad == 0) {
                8
            } else {
                rawPad
            }
            pos = entryStart + entryLen + padding
            i += 1
        }
        // 解析扩展数据，对齐 Rust: gix_index::extension::decode
        while (pos + 8 <= data.size) {
            let extSig = bytesToStringIdx(data, pos, pos + 4)
            pos += 4
            let extSize = readU32Idx(data, pos)
            pos += 4
            if (pos + extSize > data.size) {
                break
            }
            let extData = sliceBytesIdx(data, pos, pos + extSize)
            extensions.add(IndexExtension(extSig, extData))
            pos += extSize
        }
    }

    // 将索引文件编码为字节数组
    // 返回值: 编码后的字节数组
    func encode(): Array<Byte> {
        var result = ArrayList<Byte>()
        for (b in "DIRC".toArray()) {
            result.add(b)
        }
        result.add(UInt8((version >> 24) & 0xFF))
        result.add(UInt8((version >> 16) & 0xFF))
        result.add(UInt8((version >> 8) & 0xFF))
        result.add(UInt8(version & 0xFF))
        result.add(UInt8((entries.size >> 24) & 0xFF))
        result.add(UInt8((entries.size >> 16) & 0xFF))
        result.add(UInt8((entries.size >> 8) & 0xFF))
        result.add(UInt8(entries.size & 0xFF))
        for (entry in entries) {
            result.add(UInt8((entry.ctimeS >> 24) & 0xFF))
            result.add(UInt8((entry.ctimeS >> 16) & 0xFF))
            result.add(UInt8((entry.ctimeS >> 8) & 0xFF))
            result.add(UInt8(entry.ctimeS & 0xFF))
            result.add(UInt8((entry.ctimeN >> 24) & 0xFF))
            result.add(UInt8((entry.ctimeN >> 16) & 0xFF))
            result.add(UInt8((entry.ctimeN >> 8) & 0xFF))
            result.add(UInt8(entry.ctimeN & 0xFF))
            result.add(UInt8((entry.mtimeS >> 24) & 0xFF))
            result.add(UInt8((entry.mtimeS >> 16) & 0xFF))
            result.add(UInt8((entry.mtimeS >> 8) & 0xFF))
            result.add(UInt8(entry.mtimeS & 0xFF))
            result.add(UInt8((entry.mtimeN >> 24) & 0xFF))
            result.add(UInt8((entry.mtimeN >> 16) & 0xFF))
            result.add(UInt8((entry.mtimeN >> 8) & 0xFF))
            result.add(UInt8(entry.mtimeN & 0xFF))
            result.add(UInt8((entry.dev >> 24) & 0xFF))
            result.add(UInt8((entry.dev >> 16) & 0xFF))
            result.add(UInt8((entry.dev >> 8) & 0xFF))
            result.add(UInt8(entry.dev & 0xFF))
            result.add(UInt8((entry.ino >> 24) & 0xFF))
            result.add(UInt8((entry.ino >> 16) & 0xFF))
            result.add(UInt8((entry.ino >> 8) & 0xFF))
            result.add(UInt8(entry.ino & 0xFF))
            result.add(UInt8((entry.mode >> 24) & 0xFF))
            result.add(UInt8((entry.mode >> 16) & 0xFF))
            result.add(UInt8((entry.mode >> 8) & 0xFF))
            result.add(UInt8(entry.mode & 0xFF))
            result.add(UInt8((entry.uid >> 24) & 0xFF))
            result.add(UInt8((entry.uid >> 16) & 0xFF))
            result.add(UInt8((entry.uid >> 8) & 0xFF))
            result.add(UInt8(entry.uid & 0xFF))
            result.add(UInt8((entry.gid >> 24) & 0xFF))
            result.add(UInt8((entry.gid >> 16) & 0xFF))
            result.add(UInt8((entry.gid >> 8) & 0xFF))
            result.add(UInt8(entry.gid & 0xFF))
            result.add(UInt8((entry.fileSize >> 24) & 0xFF))
            result.add(UInt8((entry.fileSize >> 16) & 0xFF))
            result.add(UInt8((entry.fileSize >> 8) & 0xFF))
            result.add(UInt8(entry.fileSize & 0xFF))
            for (b in entry.id.bytes) {
                result.add(b)
            }
            let pathBytes = entry.path.toArray()
            result.add(UInt8((pathBytes.size >> 8) & 0xFF))
            result.add(UInt8(pathBytes.size & 0xFF))
            for (b in pathBytes) {
                result.add(b)
            }
            let entryLen = 62 + pathBytes.size
            let rawPad = (8 - (entryLen % 8)) % 8
            let padding = if (rawPad == 0) {
                8
            } else {
                rawPad
            }
            var p: Int64 = 0
            while (p < padding) {
                result.add(UInt8(0))
                p += 1
            }
        }
        // 编码扩展数据，对齐 Rust: gix_index::extension
        for (ext in extensions) {
            for (b in ext.signature.toArray()) {
                result.add(b)
            }
            result.add(UInt8((ext.data.size >> 24) & 0xFF))
            result.add(UInt8((ext.data.size >> 16) & 0xFF))
            result.add(UInt8((ext.data.size >> 8) & 0xFF))
            result.add(UInt8(ext.data.size & 0xFF))
            for (b in ext.data) {
                result.add(b)
            }
        }
        let contentBytes = result.toArray()
        let hasher = GixHasher(HashKind.Sha1)
        hasher.update(contentBytes)
        let hashOid = hasher.tryFinalize()
        for (b in hashOid.bytes) {
            result.add(b)
        }
        result.toArray()
    }
}

// 从字节数组指定偏移读取大端序 32 位无符号整数
// 参数 data: 源字节数组
// 参数 offset: 读取起始偏移
// 返回值: 读取的 32 位整数值
public func readU32Idx(data: Array<Byte>, offset: Int64): Int64 {
    (Int64(data[offset]) << 24) | (Int64(data[offset + 1]) << 16) | (Int64(data[offset + 2]) << 8) | Int64(data[offset +
            3])
}

// 将字节数组的指定范围转换为字符串
// 参数 data: 源字节数组
// 参数 start: 起始位置（含）
// 参数 end: 结束位置（不含）
// 返回值: 转换后的字符串
func bytesToStringIdx(data: Array<Byte>, start: Int64, end: Int64): String {
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
func sliceBytesIdx(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 小写转换辅助函数（用于不区分大小写查找）
func toLowerStr(s: String): String {
    var sb = StringBuilder()
    for (i in 0..s.size) {
        let c = s[i]
        if (c >= UInt8(65) && c <= UInt8(90)) {
            sb.append(Rune(c + 32))
        } else {
            sb.append(Rune(c))
        }
    }
    sb.toString()
}
