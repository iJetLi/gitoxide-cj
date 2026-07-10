// 文件：lib.cj
// 用途：提供临时文件管理功能，支持安全写入和原子性持久化
// 所属包：gix.gix_tempfile
// 关键类型：TempFile

package gitoxide.gix_tempfile

import std.fs.*
import std.time.*
import std.sync.*
import std.collection.*

// 临时文件注册表（全局）
// 对齐 Rust: gix_tempfile::registry
class TempFileRegistry {
    static let lock = ReentrantMutex()
    static var paths = ArrayList<String>()

    static func register(path: String): Unit {
        lock.lock()
        paths.add(path)
        lock.unlock()
    }

    static func unregister(path: String): Unit {
        lock.lock()
        var idx: Int64 = -1
        for (i in 0..paths.size) {
            if (paths[i] == path) {
                idx = i
                break
            }
        }
        if (idx >= 0) {
            paths.remove(at: idx)
        }
        lock.unlock()
    }

    static func cleanup(): Unit {
        lock.lock()
        for (p in paths) {
            try {
                remove(p)
            } catch (_: Exception) {}
        }
        paths.clear()
        lock.unlock()
    }

    static func count(): Int64 {
        lock.lock()
        let c = paths.size
        lock.unlock()
        c
    }
}

// 临时文件，支持写入后原子性地持久化为目标文件
// 关闭时自动清理临时文件
// 对齐 Rust: gix_tempfile::Handle
public class TempFile {
    // 临时文件路径
    var path: String
    // 是否已关闭
    var closed: Bool

    // 构造函数
    // 参数 path：临时文件路径
    public init(path: String) {
        this.path = path
        this.closed = false
        TempFileRegistry.register(path)
    }

    // 在指定目录下创建带前缀的临时文件
    // 对齐 Rust: gix_tempfile::new
    // 参数 dir：临时文件所在目录
    // 参数 prefix：文件名前缀
    // 返回值：TempFile 实例
    public static func new(dir: String, prefix: String): TempFile {
        let now = DateTime.now()
        let name = prefix + "_" + now.year.toString() + now.month.toString() + now.dayOfMonth.toString() +
            now.hour.toString() + now.minute.toString() + now.second.toString()
        let p = dir + "/" + name
        TempFile(p)
    }

    // 向临时文件写入数据
    // 参数 data：待写入的字节数据
    public func write(data: Array<Byte>): Unit {
        if (closed) {
            throw Exception("tempfile already closed")
        }
        let file = File(path, OpenMode.Write)
        file.write(data)
        file.close()
    }

    // 将临时文件原子性地重命名为目标路径
    // 参数 targetPath：目标文件路径
    public func persist(targetPath: String): Unit {
        if (closed) {
            throw Exception("tempfile already closed")
        }
        rename(path, to: targetPath)
        TempFileRegistry.unregister(path)
        closed = true
    }

    // 关闭临时文件，删除文件并标记为已关闭
    public func close(): Unit {
        if (!closed) {
            try {
                remove(path)
            } catch (_: Exception) {}
            TempFileRegistry.unregister(path)
            closed = true
        }
    }
}

// 清理所有已注册的临时文件
// 对齐 Rust: gix_tempfile::registry::cleanup_tempfiles
public func cleanupTempfiles(): Unit {
    TempFileRegistry.cleanup()
}
