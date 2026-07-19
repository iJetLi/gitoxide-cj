// 文件：archive.cj
// 用途：仓库层 archive 胶水模块，桥接 gix_archive 到 Repository
// 所属包：gix.repository
// 关键类型：ArchiveQuery
// 对齐原版：gitoxide-core/src/repository/archive.rs

package gitoxide.repository

import gitoxide.gix_archive.*
import gitoxide.gix_object.*
import gitoxide.gix_hash.*
import std.collection.*

// 仓库归档查询器，桥接 gix_archive 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/archive.rs
public class ArchiveQuery {
    // 所属仓库实例
    public var repo: Repository

    // 参数 repo：仓库实例
    public init(repo: Repository) {
        this.repo = repo
    }

    // 从 treeish 创建归档，支持 commit/tree 两种输入
    // 若 treeish 解析为 commit，则自动提取其 tree 引用
    // 对齐原版：gitoxide-core/src/repository/archive.rs::stream()
    public func stream(treeish: String): ?Archive {
        let query = RevisionQuery(repo)
        let idOpt = query.resolve(treeish)
        if (let Some(id) <- idOpt) {
            var treeId = id
            // 若解析结果为 commit，提取其 tree 引用
            let dataOpt = repo.readObject(id)
            if (let Some(data) <- dataOpt) {
                let decoded = data.decode()
                if (let Some(d) <- decoded) {
                    match (d) {
                        case ObjectRef.Commit(commitRef) =>
                            let tid = ObjectId.fromHex(commitRef.tree)
                            if (let Some(t) <- tid) {
                                treeId = t
                            } else {
                                return None
                            }
                        case _ => ()
                    }
                }
            }
            // 读取 tree 对象并构建归档
            let treeDataOpt = repo.readObject(treeId)
            if (let Some(treeData) <- treeDataOpt) {
                if (let Some(ObjectRef.Tree(treeRef)) <- treeData.decode()) {
                    let archive = Archive()
                    archive.commitId = id.toHexString()
                    addTreeEntries(archive, treeRef, "")
                    return Some(archive)
                }
            }
        }
        None
    }

    // 递归添加树条目到归档
    // 参数 archive：归档容器
    // 参数 tree：树引用
    // 参数 prefix：路径前缀（子目录时递归拼接）
    func addTreeEntries(archive: Archive, tree: TreeRef, prefix: String): Unit {
        for (entry in tree.entries) {
            let path = if (prefix.size > 0) {
                prefix + "/" + entry.filename
            } else {
                entry.filename
            }
            if (entry.mode.isTree()) {
                // 子目录：递归遍历
                let subDataOpt = repo.readObject(entry.oid)
                if (let Some(subData) <- subDataOpt) {
                    if (let Some(ObjectRef.Tree(subTree)) <- subData.decode()) {
                        addTreeEntries(archive, subTree, path)
                    }
                }
            } else {
                // 文件：读取 blob 数据并添加条目
                let blobDataOpt = repo.readObject(entry.oid)
                if (let Some(blobData) <- blobDataOpt) {
                    archive.addEntry(path, entry.mode.value, blobData.data)
                }
            }
        }
    }
}
