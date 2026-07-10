// 文件：log.cj
// 所属包：gix.gix_ref
// 用途：实现 reflog（引用日志）的读写功能，记录引用的变更历史
// 关键类型：Reflog, ReflogEntry

package gitoxide.gix_ref

import gitoxide.gix_hash.*
import std.fs.*
import std.collection.*

// 引用日志类，记录某个引用的变更历史
// 每次引用被更新时，会添加一条 ReflogEntry 记录
public class Reflog {
    // 日志条目列表，按时间顺序排列
    public var entries: ArrayList<ReflogEntry>

    // 构造函数，初始化空的日志条目列表
    public init() {
        this.entries = ArrayList<ReflogEntry>()
    }

    // 从文件读取 reflog
    // 参数 path - reflog 文件路径
    // 返回值 - 读取成功返回 Some(Reflog)，文件不存在或读取失败返回 None
    public static func read(path: String): ?Reflog {
        if (!exists(path)) {
            return None
        }
        try {
            let file = File(path, OpenMode.Read)
            var allBytes = ArrayList<UInt8>()
            var buf = Array<UInt8>(4096, {_ => UInt8(0)})
            var n = file.read(buf)
            while (n > 0) {
                var i: Int64 = 0
                while (i < n) {
                    allBytes.add(buf[i])
                    i += 1
                }
                buf = Array<UInt8>(4096, {_ => UInt8(0)})
                n = file.read(buf)
            }
            file.close()
            let log = Reflog()
            log.parse(allBytes.toArray())
            Some(log)
        } catch (_: Exception) {
            None
        }
    }

    // 将 reflog 写入文件
    // 参数 path - 目标文件路径
    public func write(path: String): Unit {
        try {
            let file = File(path, OpenMode.Write)
            for (entry in entries) {
                file.write(entry.toBytes())
            }
            file.close()
        } catch (_: Exception) {}
    }

    // 解析字节数据为 reflog 条目
    // 逐行解析，每行对应一条 ReflogEntry
    // 参数 data - reflog 文件的原始字节数据
    func parse(data: Array<Byte>): Unit {
        var pos: Int64 = 0
        while (pos < data.size) {
            let lineStart = pos
            while (pos < data.size && data[pos] != UInt8(10)) {
                pos += 1
            }
            if (pos > lineStart) {
                let line = bytesToStringLog(data, lineStart, pos)
                let entry = ReflogEntry.fromLine(line)
                if (let Some(e) <- entry) {
                    entries.add(e)
                }
            }
            if (pos < data.size) {
                pos += 1
            }
        }
    }
}

// 引用日志条目类，记录单次引用变更的信息
// 格式：<旧ID> <新ID> <姓名> <<邮箱>> <时间戳>\t<消息>
public class ReflogEntry {
    // 变更前的对象 ID（十六进制字符串）
    public var oldId: String
    // 变更后的对象 ID（十六进制字符串）
    public var newId: String
    // 操作者姓名
    public var name: String
    // 操作者邮箱
    public var email: String
    // 时间戳字符串
    public var timestamp: String
    // 变更描述消息
    public var message: String

    // 构造函数
    // 参数 oldId - 变更前的对象 ID
    // 参数 newId - 变更后的对象 ID
    // 参数 name - 操作者姓名
    // 参数 email - 操作者邮箱
    // 参数 timestamp - 时间戳
    // 参数 message - 变更描述消息
    public init(oldId: String, newId: String, name: String, email: String, timestamp: String, message: String) {
        this.oldId = oldId
        this.newId = newId
        this.name = name
        this.email = email
        this.timestamp = timestamp
        this.message = message
    }

    // 从 reflog 行文本解析创建 ReflogEntry
    // 行格式：<旧ID> <新ID> <时间戳>\t<消息>
    // 参数 line - reflog 行文本
    // 返回值 - 解析成功返回 Some(ReflogEntry)，格式不合法返回 None
    public static func fromLine(line: String): ?ReflogEntry {
        let parts = line.split("\t")
        if (parts.size < 2) {
            return None
        }
        let header = parts[0]
        let message = parts[1]
        let headerParts = header.split(" ")
        if (headerParts.size < 4) {
            return None
        }
        Some(ReflogEntry(headerParts[0], headerParts[1], "", "", headerParts[2], message))
    }

    // 将日志条目序列化为字节数组
    // 格式：<旧ID> <新ID> <姓名> <<邮箱>> <时间戳>\t<消息>\n
    // 返回值 - 序列化后的字节数组
    public func toBytes(): Array<Byte> {
        let line = oldId + " " + newId + " " + name + " <" + email + "> " + timestamp + "\t" + message + "\n"
        line.toArray()
    }
}

// 将字节数组的指定范围转换为字符串
// 参数 data - 源字节数组
// 参数 start - 起始位置（包含）
// 参数 end - 结束位置（不包含）
// 返回值 - 转换后的字符串
func bytesToStringLog(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
