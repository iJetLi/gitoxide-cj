// 文件：revision.cj
// 用途：提供修订规格（如 HEAD~3、v1.0）解析为对象 ID 的查询功能，
//       包含仓库级别的引用解析和父提交查找实现
// 所属包：gix.repository
// 关键类型：RevisionQuery, RepoResolver

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_revision.*
import gitoxide.gix_object.*
import gitoxide.gix_ref.*

// 修订规格查询器，将字符串形式的修订规格解析为对象 ID
public class RevisionQuery {
    // 所属仓库实例
    public var repo: Repository

    // 参数 repo：仓库实例
    public init(repo: Repository) {
        this.repo = repo
    }

    // 解析修订规格为对象 ID
    // 参数 spec：修订规格字符串（如 "HEAD~3"、"v1.0"、"abc123^"）
    // 返回值：解析成功返回 ObjectId，解析失败返回 None
    public func resolve(spec: String): ?ObjectId {
        let s = Spec.parse(spec)
        if (let Some(sp) <- s) {
            resolve(sp, RepoResolver(repo))
        } else {
            None
        }
    }
}

// 仓库级别的引用解析器，实现 ResolveRef 接口，
// 用于在修订规格解析过程中查找引用和父提交
class RepoResolver <: ResolveRef {
    // 所属仓库实例
    var repo: Repository

    // 参数 repo：仓库实例
    init(repo: Repository) {
        this.repo = repo
    }

    // 解析引用名称为对象 ID，支持符号引用递归解析（仅一层）
    // 参数 name：引用名称
    // 返回值：解析到的对象 ID，失败返回 None
    public func resolveRef(name: String): ?ObjectId {
        let ref = repo.findReference(name)
        if (let Some(r) <- ref) {
            match (r.target) {
                case Target.Object(id) => Some(id)
                case Target.Symbolic(n) => resolveSymbolicRef(n)
            }
        } else {
            None
        }
    }

    // 解析符号引用（仅一层递归）
    func resolveSymbolicRef(n: FullName): ?ObjectId {
        let resolved = repo.findReference(n.value)
        if (let Some(res) <- resolved) {
            match (res.target) {
                case Target.Object(id) => Some(id)
                case Target.Symbolic(_) => None
            }
        } else {
            None
        }
    }

    // 查找给定提交对象的第一个父提交 ID
    // 参数 id：提交对象 ID
    // 返回值：第一个父提交 ID，无父提交或非提交对象返回 None
    public func resolveParent(id: ObjectId): ?ObjectId {
        let data = repo.readObject(id)
        if (let Some(d) <- data) {
            let obj = d.decode()
            if (let Some(ObjectRef.Commit(c)) <- obj) {
                if (c.parents.size > 0) {
                    Some(ObjectId.fromHexOrThrow(c.parents[0]))
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    public func resolveNthParent(id: ObjectId, n: Int64): ?ObjectId {
        let data = repo.readObject(id)
        if (let Some(d) <- data) {
            let obj = d.decode()
            if (let Some(ObjectRef.Commit(c)) <- obj) {
                if (n > 0 && n <= c.parents.size) {
                    Some(ObjectId.fromHexOrThrow(c.parents[Int64(n - 1)]))
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    public func resolveTree(id: ObjectId): ?ObjectId {
        let data = repo.readObject(id)
        if (let Some(d) <- data) {
            let obj = d.decode()
            if (let Some(ObjectRef.Commit(c)) <- obj) {
                Some(ObjectId.fromHexOrThrow(c.tree))
            } else if (let Some(ObjectRef.Tree(t)) <- obj) {
                Some(id)
            } else {
                None
            }
        } else {
            None
        }
    }

    public func resolvePath(path: String): ?ObjectId {
        None
    }

    public func resolveUpstream(refName: String): ?ObjectId {
        None
    }

    public func resolvePush(refName: String): ?ObjectId {
        None
    }

    public func resolveNthPrior(refName: String, n: Int64): ?ObjectId {
        None
    }
}
