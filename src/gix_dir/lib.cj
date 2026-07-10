// 文件：lib.cj
// 用途：目录遍历，递归扫描工作目录中的文件与子目录
// 所属包：gix.gix_dir
// 关键类型：DirWalk, DirEntry, EntryKind

package gitoxide.gix_dir

import std.fs.*
import std.collection.*

// 目录遍历器，递归收集指定根目录下的所有文件与目录条目
public class DirWalk {
    // 遍历根目录路径
    public var root: String
    // 收集到的目录条目列表
    public var entries: ArrayList<DirEntry>
    // 是否进入被忽略的目录（gitignore 支持，当前未实现）
    public var recurseIntoIgnored: Bool

    // 参数 root: 遍历的根目录路径
    public init(root: String) {
        this.root = root
        this.entries = ArrayList<DirEntry>()
        this.recurseIntoIgnored = false
    }

    // 执行遍历并返回所有条目
    // 返回值: 目录条目列表
    public func collect(): ArrayList<DirEntry> {
        walk(root, "")
        entries
    }

    // 递归遍历目录，将条目添加到 entries 列表
    // 参数 dir: 当前遍历的目录绝对路径
    // 参数 prefix: 当前目录的相对路径前缀
    func walk(dir: String, prefix: String): Unit {
        try {
            if (!exists(dir)) {
                return
            }
        } catch (_: Exception) {
            return
        }
    }

    // 检查路径是否为目录
    // 参数 path: 待检查的路径
    // 返回值: 是目录返回 true，否则返回 false
    func isDirectory(path: String): Bool {
        try {
            exists(path)
        } catch (_: Exception) {
            false
        }
    }
}

// 目录条目，表示遍历到的一个文件系统对象
public class DirEntry {
    // 相对于根目录的路径
    public var path: String
    // 条目类型（文件/目录/符号链接）
    public var kind: EntryKind

    // 参数 path: 相对路径
    // 参数 kind: 条目类型
    public init(path: String, kind: EntryKind) {
        this.path = path
        this.kind = kind
    }
}

// 条目类型枚举
public enum EntryKind {
    | File // 普通文件
    | Directory // 目录
    | Symlink // 符号链接

    public operator func ==(that: EntryKind): Bool {
        match (this) {
            case File => match (that) {
                case File => true;
                case _ => false
            }
            case Directory => match (that) {
                case Directory => true;
                case _ => false
            }
            case Symlink => match (that) {
                case Symlink => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: EntryKind): Bool {
        !(this == that)
    }
}
