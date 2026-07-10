// 文件：tree.cj
// 所属包：gix.gix_object
// 用途：定义 Git Tree（树）对象相关的类型，包括条目模式、条目引用/拥有类型、树对象引用/拥有类型及迭代器
// 关键类型：EntryKind - 树条目类型枚举
//           EntryMode - 树条目的文件模式（权限和类型）
//           EntryRef/Entry - 树条目的引用和拥有类型
//           TreeRef/Tree - 树对象的引用和拥有类型
//           TreeRefIter - 树条目迭代器

package gitoxide.gix_object

import std.collection.*
import gitoxide.gix_hash.*

// 树条目类型枚举
// 表示树条目中文件系统对象的类型
public enum EntryKind {
    | Tree // 目录
    | Blob // 普通文件
    | BlobExecutable // 可执行文件
    | Link // 符号链接
    | Commit
}

extend EntryKind <: Equatable<EntryKind> {
    public operator func ==(other: EntryKind): Bool {
        match (this) {
            case EntryKind.Tree => match (other) {
                case EntryKind.Tree => true
                case _ => false
            }
            case EntryKind.Blob => match (other) {
                case EntryKind.Blob => true
                case _ => false
            }
            case EntryKind.BlobExecutable => match (other) {
                case EntryKind.BlobExecutable => true
                case _ => false
            }
            case EntryKind.Link => match (other) {
                case EntryKind.Link => true
                case _ => false
            }
            case EntryKind.Commit => match (other) {
                case EntryKind.Commit => true
                case _ => false
            }
        }
    }
}

// 树条目的文件模式
// 封装 Git 树条目中的模式值（如 100644、40000 等），用于判断条目类型
public class EntryMode {
    // 模式的原始数值，如 0o100644、0o040000 等
    public var value: Int64

    // 构造函数
    // 参数 value：模式的原始数值
    public init(value: Int64) {
        this.value = value
    }

    public static func Regular(): EntryMode {
        EntryMode(0o100644)
    }

    public static func Directory(): EntryMode {
        EntryMode(0o040000)
    }

    public static func Executable(): EntryMode {
        EntryMode(0o100755)
    }

    public static func Link(): EntryMode {
        EntryMode(0o120000)
    }

    public static func Commit(): EntryMode {
        EntryMode(0o160000)
    }

    // 从字节数组解析文件模式
    // 解析八进制数字字符串直到遇到空格为止
    // 参数 bytes：包含八进制模式数字的字节数组
    // 返回值：解析成功返回 EntryMode，格式错误返回 None
    public static func fromBytes(bytes: Array<Byte>): ?EntryMode {
        var mode: Int64 = 0
        var i: Int64 = 0
        while (i < bytes.size) {
            let b = bytes[i]
            if (b == UInt8(32)) {
                return Some(EntryMode(mode))
            }
            if (b < UInt8(48) || b > UInt8(55)) {
                return None
            }
            mode = (mode << 3) + Int64(b - 48)
            i += 1
        }
        if (mode >= 0 && i > 0) {
            Some(EntryMode(mode))
        } else {
            None
        }
    }

    // 根据模式值判断条目类型
    // 通过检查高位类型位（ifmt）确定对象类型，并进一步判断是否为可执行文件
    // 返回值：对应的 EntryKind 枚举值
    public func kind(): EntryKind {
        let ifmt: Int64 = 0o170000
        let etype = value & ifmt
        if (etype == 0o100000) {
            if ((value & 0o000100) == 0o000100) {
                EntryKind.BlobExecutable
            } else {
                EntryKind.Blob
            }
        } else if (etype == 0o120000) {
            EntryKind.Link
        } else if (etype == 0o040000) {
            EntryKind.Tree
        } else {
            EntryKind.Commit
        }
    }

    // 判断是否为目录类型
    // 返回值：模式类型为目录时返回 true
    public func isTree(): Bool {
        (value & 0o170000) == 0o040000
    }

    // 判断是否为普通文件类型
    // 返回值：模式类型为普通文件时返回 true
    public func isBlob(): Bool {
        (value & 0o170000) == 0o100000
    }

    // 判断是否为子模块提交类型
    // 返回值：模式类型为子模块提交时返回 true
    public func isCommit(): Bool {
        (value & 0o170000) == 0o160000
    }

    // 判断是否为符号链接类型
    // 返回值：模式类型为符号链接时返回 true
    public func isLink(): Bool {
        (value & 0o170000) == 0o120000
    }

    // 将文件模式转换为字节数组
    // 返回值：对应的八进制模式字符串的字节数组，如 "100644"、"40000" 等
    public func asBytes(): Array<Byte> {
        match (kind()) {
            case EntryKind.Tree => "40000".toArray()
            case EntryKind.Blob => "100644".toArray()
            case EntryKind.BlobExecutable => "100755".toArray()
            case EntryKind.Link => "120000".toArray()
            case EntryKind.Commit => "160000".toArray()
        }
    }
}

// 树条目引用类型
// 表示树对象中的一个条目，包含模式、文件名和对象 ID
public class EntryRef {
    // 文件模式
    public var mode: EntryMode
    // 文件名
    public var filename: String
    // 对象 ID
    public var oid: ObjectId

    // 构造函数
    // 参数 mode：文件模式
    // 参数 filename：文件名
    // 参数 oid：对象 ID
    public init(mode: EntryMode, filename: String, oid: ObjectId) {
        this.mode = mode
        this.filename = filename
        this.oid = oid
    }

    // 将 EntryRef 转换为拥有类型的 Entry
    // 返回值：包含相同数据的 Entry 实例
    public func intoOwned(): Entry {
        Entry(mode, filename, oid)
    }
}

// 树条目拥有类型
// 表示树对象中的一个条目，与 EntryRef 结构相同但语义上表示拥有数据
public class Entry {
    // 文件模式
    public var mode: EntryMode
    // 文件名
    public var filename: String
    // 对象 ID
    public var oid: ObjectId

    // 构造函数
    // 参数 mode：文件模式
    // 参数 filename：文件名
    // 参数 oid：对象 ID
    public init(mode: EntryMode, filename: String, oid: ObjectId) {
        this.mode = mode
        this.filename = filename
        this.oid = oid
    }
}

// 树对象引用类型
// 表示对 Git 树对象的引用，持有条目引用列表
public class TreeRef {
    // 树中的条目引用列表
    public var entries: ArrayList<EntryRef>

    // 构造函数
    // 参数 entries：条目引用列表
    public init(entries: ArrayList<EntryRef>) {
        this.entries = entries
    }

    // 从字节数组解析 TreeRef
    // 参数 data：树对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 TreeRef，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?TreeRef {
        parseTree(data, hashKind)
    }

    // 将 TreeRef 转换为拥有类型的 Tree
    // 将所有条目引用转换为拥有类型
    // 返回值：包含所有条目的 Tree 实例
    public func intoOwned(): Tree {
        var ownedEntries = ArrayList<Entry>()
        for (e in entries) {
            ownedEntries.add(e.intoOwned())
        }
        Tree(ownedEntries)
    }
}

// 树条目迭代器
// 逐条解析树对象的字节数据，支持惰性遍历，避免一次性解析所有条目
public class TreeRefIter {
    // 待解析的原始字节数据
    var data: Array<Byte>
    // 哈希算法类型
    var hashKind: HashKind
    // 当前解析位置
    var pos: Int64

    // 构造函数
    // 参数 data：树对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    public init(data: Array<Byte>, hashKind: HashKind) {
        this.data = data
        this.hashKind = hashKind
        this.pos = 0
    }

    // 判断是否还有未解析的条目
    // 返回值：当前位置未到达数据末尾时返回 true
    public func hasNext(): Bool {
        pos < data.size
    }

    // 获取下一个条目
    // 返回值：解析成功返回 EntryRef，解析失败或已到达末尾返回 None
    public func next(): ?EntryRef {
        if (pos >= data.size) {
            return None
        }
        let entry = parseTreeEntry(data, pos, hashKind)
        if (let Some(e) <- entry) {
            pos = e[1]
            Some(e[0])
        } else {
            pos = data.size
            None
        }
    }

    // 收集所有剩余条目到列表
    // 返回值：包含所有剩余条目的 ArrayList
    public func collect(): ArrayList<EntryRef> {
        var result = ArrayList<EntryRef>()
        while (hasNext()) {
            let entry = next()
            if (let Some(e) <- entry) {
                result.add(e)
            }
        }
        result
    }
}

// 树对象拥有类型
// 表示完整的 Git 树对象，持有条目拥有类型列表
public class Tree {
    // 树中的条目列表
    public var entries: ArrayList<Entry>

    // 构造函数
    // 参数 entries：条目列表
    public init(entries: ArrayList<Entry>) {
        this.entries = entries
    }

    public init() {
        this.entries = ArrayList<Entry>()
    }

    // 创建空树对象
    // 返回值：不含任何条目的空 Tree 实例
    public static func empty(): Tree {
        Tree(ArrayList<Entry>())
    }

    // 从字节数组解析 Tree
    // 参数 data：树对象的原始字节数据
    // 参数 hashKind：哈希算法类型
    // 返回值：解析成功返回 Tree，失败返回 None
    public static func fromBytes(data: Array<Byte>, hashKind: HashKind): ?Tree {
        let ref = TreeRef.fromBytes(data, hashKind)
        if (let Some(r) <- ref) {
            Some(r.intoOwned())
        } else {
            None
        }
    }

    // 将 Tree 序列化为字节数组
    // 按照 Git 树对象格式输出：每个条目为 "<mode> <filename>\0<oid-bytes>"
    // 返回值：序列化后的字节数组
    public func writeToArray(): Array<Byte> {
        var result = ArrayList<Byte>()
        for (entry in entries) {
            let modeBytes = entry.mode.asBytes()
            for (b in modeBytes) {
                result.add(b)
            }
            result.add(UInt8(32))
            for (b in entry.filename.toArray()) {
                result.add(b)
            }
            result.add(UInt8(0))
            for (b in entry.oid.bytes) {
                result.add(b)
            }
        }
        result.toArray()
    }
}

// 解析树对象的字节数据为 TreeRef
// 逐条解析所有树条目
// 参数 data：树对象的原始字节数据
// 参数 hashKind：哈希算法类型
// 返回值：解析成功返回 TreeRef，任一条目解析失败则返回 None
func parseTree(data: Array<Byte>, hashKind: HashKind): ?TreeRef {
    var entries = ArrayList<EntryRef>()
    var pos: Int64 = 0
    while (pos < data.size) {
        let entry = parseTreeEntry(data, pos, hashKind)
        if (let Some(e) <- entry) {
            entries.add(e[0])
            pos = e[1]
        } else {
            return None
        }
    }
    Some(TreeRef(entries))
}

// 解析单个树条目
// 格式为 "<mode> <filename>\0<oid-bytes>"
// 参数 data：原始字节数据
// 参数 start：起始解析位置
// 参数 hashKind：哈希算法类型，用于确定 OID 字节长度
// 返回值：解析成功返回 (EntryRef, 解析结束位置)，失败返回 None
func parseTreeEntry(data: Array<Byte>, start: Int64, hashKind: HashKind): ?(EntryRef, Int64) {
    var pos = start
    // 解析模式字段（八进制数字，以空格结尾）
    let modeStart = pos
    while (pos < data.size && data[pos] != UInt8(32)) {
        pos += 1
    }
    if (pos >= data.size) {
        return None
    }
    let modeBytes = sliceBytes(data, modeStart, pos)
    let modeOpt = EntryMode.fromBytes(modeBytes)
    if (let Some(m) <- modeOpt) {
        pos += 1
        let nameStart = pos
        while (pos < data.size && data[pos] != UInt8(0)) {
            pos += 1
        }
        if (pos >= data.size) {
            return None
        }
        let filename = bytesToString2(data, nameStart, pos)
        pos += 1
        let hashLen = hashKindLenInHex2(hashKind) / 2
        if (pos + hashLen > data.size) {
            return None
        }
        let oidBytes = sliceBytes(data, pos, pos + hashLen)
        let oid = ObjectId(oidBytes, hashKind)
        pos += hashLen
        return Some((EntryRef(m, filename, oid), pos))
    }
    None
}

// 根据哈希算法类型获取十六进制哈希值的字符长度
// 参数 kind：哈希算法类型
// 返回值：SHA1 返回 40，SHA256 返回 64
func hashKindLenInHex2(kind: HashKind): Int64 {
    match (kind) {
        case HashKind.Sha1 => 40
        case HashKind.Sha256 => 64
    }
}

// 截取字节数组的指定范围
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：截取得到的新字节数组
func sliceBytes(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 将字节数组的指定范围转换为字符串
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：由字节转换得到的字符串
func bytesToString2(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
