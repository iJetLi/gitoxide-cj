// 文件：lib.cj
// 用途：提供 Git 仓库发现功能，从指定目录向上搜索 .git 目录
// 所属包：gix.gix_discover
// 关键类型：Repository, RepoKind
// 关键函数：discoverUpwards

package gitoxide.gix_discover

import std.fs.*
import gitoxide.gix_utils.*

// 发现的仓库信息，包含路径和仓库类型
public class Repository {
    // 仓库的工作目录或裸仓库根目录
    public var path: String
    // 仓库类型
    public var kind: RepoKind

    // 构造函数
    // 参数 path：仓库路径
    // 参数 kind：仓库类型
    public init(path: String, kind: RepoKind) {
        this.path = path
        this.kind = kind
    }
}

// 仓库类型枚举
public enum RepoKind {
    | WorkTree
    | Bare
    | WorkTreeLinked
}

extend RepoKind <: Equatable<RepoKind> {
    public operator func ==(other: RepoKind): Bool {
        match (this) {
            case RepoKind.WorkTree => match (other) {
                case RepoKind.WorkTree => true
                case _ => false
            }
            case RepoKind.Bare => match (other) {
                case RepoKind.Bare => true
                case _ => false
            }
            case RepoKind.WorkTreeLinked => match (other) {
                case RepoKind.WorkTreeLinked => true
                case _ => false
            }
        }
    }

    public operator func !=(other: RepoKind): Bool {
        !(this == other)
    }
}

// 从指定目录向上搜索 Git 仓库
// 依次检查每个目录是否包含 .git 目录或裸仓库特征
// 参数 startDir：搜索起始目录
// 返回值：找到返回 Repository，未找到返回 None
public func discoverUpwards(startDir: String): ?Repository {
    var dir = startDir
    var iterations: Int64 = 0
    while (iterations < 100) {
        let gitDir = dir + "/.git"
        if (exists(gitDir)) {
            return Some(Repository(dir, RepoKind.WorkTree))
        }
        if (isBareRepo(dir)) {
            return Some(Repository(dir, RepoKind.Bare))
        }
        let p = parentDir(dir)
        if (p == dir) {
            break
        }
        dir = p
        iterations += 1
    }
    None
}

// 判断目录是否为裸仓库
// 检查 HEAD、objects、refs 是否同时存在
// 参数 dir：待检查的目录路径
// 返回值：同时存在返回 true
func isBareRepo(dir: String): Bool {
    exists(dir + "/HEAD") && exists(dir + "/objects") && exists(dir + "/refs")
}

// 获取路径的父目录
// 参数 path：目录路径
// 返回值：父目录路径，已是根目录时返回自身
func parentDir(path: String): String {
    let idx = path.lastIndexOf('/')
    if (let Some(i) <- idx) {
        if (i == 0) {
            "/"
        } else {
            substringStr(path, 0, i)
        }
    } else {
        path
    }
}
