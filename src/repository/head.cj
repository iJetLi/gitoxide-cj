// 文件：head.cj
// 用途：封装仓库 HEAD 引用的查询操作，获取当前引用、目标 ID、分支名
// 所属包：gix.repository
// 关键类型：Head

package gitoxide.repository

import gitoxide.gix_ref.*
import gitoxide.gix_hash.*

// HEAD 引用访问器，提供对仓库当前 HEAD 的各种查询
public class Head {
    // 所属仓库实例
    public var repo: Repository

    // 参数 repo：仓库实例
    public init(repo: Repository) {
        this.repo = repo
    }

    // 获取 HEAD 当前指向的引用
    // 返回值：HEAD 引用，无 HEAD 时返回 None
    public func currentRef(): ?Reference {
        repo.head()
    }

    // 获取 HEAD 最终解析到的对象 ID
    // 若 HEAD 为符号引用则递归解析，若解析失败返回 None
    // 返回值：HEAD 目标的对象 ID
    public func targetId(): ?ObjectId {
        let ref = repo.head()
        if (let Some(r) <- ref) {
            match (r.target) {
                case Target.Object(id) => Some(id)
                case Target.Symbolic(name) => resolveSymbolicTarget(name)
            }
        } else {
            None
        }
    }

    // 解析符号引用目标
    func resolveSymbolicTarget(name: FullName): ?ObjectId {
        let resolved = repo.findReference(name.value)
        if (let Some(res) <- resolved) {
            targetTryId(res.target)
        } else {
            None
        }
    }

    // 获取 HEAD 指向的分支名称（短名）
    // 若 HEAD 处于游离（detached）状态则返回 None
    // 返回值：分支短名，游离 HEAD 返回 None
    public func branchName(): ?String {
        let ref = repo.head()
        if (let Some(r) <- ref) {
            match (r.target) {
                case Target.Symbolic(name) => Some(name.shorten())
                case Target.Object(_) => None
            }
        } else {
            None
        }
    }
}
