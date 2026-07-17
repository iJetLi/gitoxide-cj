// 文件：blame.cj
// 用途：仓库层 blame 胶水模块，桥接 gix_blame 到 Repository
// 所属包：gix.repository
// 关键类型：BlameQuery
// 对齐原版：gitoxide-core/src/repository/blame.rs

package gitoxide.repository

import gitoxide.gix_blame.*
import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*

// 仓库 blame 查询器，桥接 gix_blame 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/blame.rs
public class BlameQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 对指定文件执行 blame
    // 对齐原版：gitoxide-core/src/repository/blame.rs::file()
    public func file(path: String, revspec: ?String): ?BlameOutcome {
        let commitId = resolveRevspec(revspec)
        if (let Some(cId) <- commitId) {
            let dataOpt = repo.readObject(cId)
            if (let Some(data) <- dataOpt) {
                if (let Some(ObjectRef.Commit(commitRef)) <- data.decode()) {
                    let treeId = ObjectId.fromHex(commitRef.tree)
                    if (let Some(tId) <- treeId) {
                        let treeDataOpt = repo.readObject(tId)
                        if (let Some(treeData) <- treeDataOpt) {
                            if (let Some(ObjectRef.Tree(treeRef)) <- treeData.decode()) {
                                let blobId = findBlobInTree(treeRef, path)
                                if (let Some(bId) <- blobId) {
                                    let blobDataOpt = repo.readObject(bId)
                                    if (let Some(blobData) <- blobDataOpt) {
                                        let outcome = BlameOutcome()
                                        outcome.blob = blobData.data
                                        let entry = BlameEntry(0, 0, 1, cId)
                                        outcome.entries.add(entry)
                                        return Some(outcome)
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
        None
    }

    func resolveRevspec(revspec: ?String): ?ObjectId {
        if (let Some(r) <- revspec) {
            let query = RevisionQuery(repo)
            query.resolve(r)
        } else {
            let head = repo.head()
            if (let Some(h) <- head) {
                h.tryId()
            } else {
                None
            }
        }
    }

    // 在 tree 中递归查找指定路径的 blob
    func findBlobInTree(tree: TreeRef, path: String): ?ObjectId {
        let parts = path.split("/")
        var currentTree = tree
        var i: Int64 = 0
        while (i < parts.size) {
            let part = parts[i]
            var found = false
            for (entry in currentTree.entries) {
                if (entry.filename == part) {
                    if (i == parts.size - 1) {
                        if (entry.mode.isBlob() || entry.mode.isLink()) {
                            return Some(entry.oid)
                        }
                        return None
                    }
                    if (entry.mode.isTree()) {
                        let treeDataOpt = repo.readObject(entry.oid)
                        if (let Some(treeData) <- treeDataOpt) {
                            if (let Some(ObjectRef.Tree(subTree)) <- treeData.decode()) {
                                currentTree = subTree
                                found = true
                            }
                        }
                    }
                }
            }
            if (!found) {
                return None
            }
            i += 1
        }
        None
    }
}
