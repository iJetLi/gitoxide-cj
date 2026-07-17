// 文件：diff.cj
// 用途：仓库层 diff 胶水模块，桥接 gix_diff 到 Repository
// 所属包：gix.repository
// 关键类型：DiffQuery
// 对齐原版：gitoxide-core/src/repository/diff.rs

package gitoxide.repository

import gitoxide.gix_diff.*
import gitoxide.gix_hash.*
import gitoxide.gix_object.*

// 仓库差异查询器，桥接 gix_diff 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/diff.rs
public class DiffQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 比较两个 tree 对象的差异
    // 对齐原版：gitoxide-core/src/repository/diff.rs::tree()
    public func tree(oldTree: ?Tree, newTree: ?Tree): TreeDiff {
        diffTrees(oldTree, newTree)
    }

    // 通过 revspec 解析并比较两个 tree
    public func treeByRevspec(oldRevspec: String, newRevspec: String): ?TreeDiff {
        let query = RevisionQuery(repo)
        let oldOpt = query.resolve(oldRevspec)
        let newOpt = query.resolve(newRevspec)
        if (let Some(oldId) <- oldOpt) {
            if (let Some(newId) <- newOpt) {
                let oldDataOpt = repo.readObject(oldId)
                let newDataOpt = repo.readObject(newId)
                if (let Some(oldData) <- oldDataOpt) {
                    if (let Some(newData) <- newDataOpt) {
                        if (let Some(ObjectRef.Tree(oldTreeRef)) <- oldData.decode()) {
                            if (let Some(ObjectRef.Tree(newTreeRef)) <- newData.decode()) {
                                return Some(diffTrees(Some(oldTreeRef.intoOwned()), Some(newTreeRef.intoOwned())))
                            }
                        }
                    }
                }
            }
        }
        None
    }
}
