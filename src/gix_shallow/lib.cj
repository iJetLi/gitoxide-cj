// 文件：lib.cj
// 用途：Git shallow 文件（.git/shallow）解析与写入，管理浅克隆的提交边界
// 所属包：gix.gix_shallow
// 关键类型：ShallowFile

package gitoxide.gix_shallow

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// shallow 文件，记录浅克隆的边界提交列表
public class ShallowFile {
    // 浅克隆边界提交的对象 ID 列表
    public var commits: ArrayList<ObjectId>

    // 初始化空的 shallow 文件
    public init() {
        this.commits = ArrayList<ObjectId>()
    }

    // 从磁盘打开并解析 shallow 文件
    // 参数 path: shallow 文件路径
    // 返回值: 解析成功返回 ShallowFile，文件不存在或解析失败返回 None
    public static func open(path: String): ?ShallowFile {
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
            let content = String.fromUtf8(bytes.toArray())
            let shallow = ShallowFile()
            let lines = content.split("\n")
            for (line in lines) {
                let trimmed = trimStr(line)
                if (trimmed.size > 0) {
                    shallow.commits.add(ObjectId.fromHexOrThrow(trimmed))
                }
            }
            Some(shallow)
        } catch (_: Exception) {
            None
        }
    }

    // 将 shallow 文件写入磁盘
    // 参数 path: 目标文件路径
    public func write(path: String): Unit {
        try {
            let file = File(path, OpenMode.Write)
            for (id in commits) {
                file.write((id.toHexString() + "\n").toArray())
            }
            file.close()
        } catch (_: Exception) {}
    }

    // 检查指定提交是否在 shallow 边界中
    // 参数 id: 待检查的提交对象 ID
    // 返回值: 在浅克隆边界中返回 true，否则返回 false
    public func isShallow(id: ObjectId): Bool {
        let hex = id.toHexString()
        for (commit in commits) {
            if (commit.toHexString() == hex) {
                return true
            }
        }
        false
    }
}
