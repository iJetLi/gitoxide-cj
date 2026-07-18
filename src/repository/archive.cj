// 文件：archive.cj
// 用途：仓库层 archive 胶水模块，桥接 gix_archive 到 Repository
// 所属包：gix.repository
// 关键类型：ArchiveQuery
// 对齐原版：gitoxide-core/src/repository/archive.rs

package gitoxide.repository

import gitoxide.gix_archive.*
import gitoxide.gix_object.*
import std.collection.*

// 仓库归档查询器，桥接 gix_archive 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/archive.rs
public class ArchiveQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 从 treeish 创建归档
    // 对齐原版：gitoxide-core/src/repository/archive.rs::stream()
    public func stream(treeish: String): ?Archive {
        let query = RevisionQuery(repo)
        let idOpt = query.resolve(treeish)
        if (let Some(id) <- idOpt) {
            let dataOpt = repo.readObject(id)
            if (let Some(data) <- dataOpt) {
                if (let Some(ObjectRef.Tree(treeRef)) <- data.decode()) {
                    let archive = Archive()
                    addTreeEntries(archive, treeRef, "")
                    return Some(archive)
                }
            }
        }
        None
    }

    func addTreeEntries(archive: Archive, tree: TreeRef, prefix: String): Unit {
        for (entry in tree.entries) {
            let path = if (prefix.size > 0) {
                prefix + "/" + entry.filename
            } else {
                entry.filename
            }
            if (entry.mode.isTree()) {
                let subDataOpt = repo.readObject(entry.oid)
                if (let Some(subData) <- subDataOpt) {
                    if (let Some(ObjectRef.Tree(subTree)) <- subData.decode()) {
                        addTreeEntries(archive, subTree, path)
                    }
                }
            } else {
                let blobDataOpt = repo.readObject(entry.oid)
                if (let Some(blobData) <- blobDataOpt) {
                    archive.addEntry(path, entry.mode.value, blobData.data)
                }
            }
        }
    }
}
