// 文件：lib.cj
// 用途：Git 工作树管理，提供检出树对象与工作区状态查询
// 所属包：gix.gix_worktree
// 关键类型：Worktree, StatusEntry, WorktreeStatus

package gitoxide.gix_worktree

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// 工作树，表示 Git 仓库的一个工作目录及其对应的 .git 目录
public class Worktree {
    // 工作树根目录路径
    public var root: String
    // 对应的 .git 目录路径
    public var gitDir: String

    // 参数 root: 工作树根目录路径
    // 参数 gitDir: .git 目录路径
    public init(root: String, gitDir: String) {
        this.root = root
        this.gitDir = gitDir
    }

    // 将树对象检出（checkout）到工作目录，递归创建目录并写入文件
    // 参数 tree: 要检出的树对象
    // 参数 prefix: 路径前缀（用于递归子目录时传递相对路径）
    public func checkoutTree(tree: Tree, prefix: String): Unit {
        for (entry in tree.entries) {
            let path = if (prefix.size > 0) {
                root + "/" + prefix + "/" + entry.filename
            } else {
                root + "/" + entry.filename
            }
            if (entry.mode.isTree()) {
                if (!exists(path)) {
                    try {
                        Directory.create(path)
                    } catch (_: Exception) {}
                }
            } else {
                try {
                    let parent = parentDirWt(path)
                    if (!exists(parent)) {
                        Directory.create(parent)
                    }
                    let file = File(path, OpenMode.Write)
                    file.write(entry.oid.bytes)
                    file.close()
                } catch (_: Exception) {}
            }
        }
    }

    // 获取工作树的状态条目列表（当前为占位实现，返回空列表）
    // 返回值: 工作树状态条目列表
    public func status(): ArrayList<StatusEntry> {
        var result = ArrayList<StatusEntry>()
        result
    }
}

// 工作树状态条目，记录一个文件的路径及其状态
public class StatusEntry {
    // 文件相对路径
    public var path: String
    // 文件状态
    public var status: WorktreeStatus

    // 参数 path: 文件相对路径
    // 参数 status: 文件状态
    public init(path: String, status: WorktreeStatus) {
        this.path = path
        this.status = status
    }
}

// 工作树文件状态枚举
public enum WorktreeStatus {
    | Unmodified // 未修改
    | Modified // 已修改
    | Added // 新添加
    | Deleted // 已删除
    | Untracked // 未跟踪
}

extend WorktreeStatus <: Equatable<WorktreeStatus> {
    public operator func ==(other: WorktreeStatus): Bool {
        match (this) {
            case WorktreeStatus.Unmodified => match (other) {
                case WorktreeStatus.Unmodified => true;
                case _ => false
            }
            case WorktreeStatus.Modified => match (other) {
                case WorktreeStatus.Modified => true;
                case _ => false
            }
            case WorktreeStatus.Added => match (other) {
                case WorktreeStatus.Added => true;
                case _ => false
            }
            case WorktreeStatus.Deleted => match (other) {
                case WorktreeStatus.Deleted => true;
                case _ => false
            }
            case WorktreeStatus.Untracked => match (other) {
                case WorktreeStatus.Untracked => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: WorktreeStatus): Bool {
        !(this == other)
    }
}

// 获取路径的父目录部分
// 参数 path: 文件路径
// 返回值: 父目录路径，若无 '/' 则返回原路径
func parentDirWt(path: String): String {
    let idx = path.lastIndexOf('/')
    if (let Some(i) <- idx) {
        substringStr(path, 0, i)
    } else {
        path
    }
}
