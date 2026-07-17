// 文件：dirwalk.cj
// 用途：仓库层 dirwalk 胶水模块，桥接 gix_dir 到 Repository
// 所属包：gix.repository
// 关键类型：DirwalkQuery
// 对齐原版：gitoxide-core/src/repository/dirwalk.rs

package gitoxide.repository

import gitoxide.gix_dir.*
import std.collection.*

// 仓库目录遍历查询器，桥接 gix_dir 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/dirwalk.rs
public class DirwalkQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 执行目录遍历
    // 对齐原版：gitoxide-core/src/repository/dirwalk.rs::collect()
    public func collect(): ArrayList<DirEntry> {
        let wtDirOpt = repo.workDir
        if (let Some(wtDir) <- wtDirOpt) {
            let walk = DirWalk(wtDir)
            walk.collect()
        } else {
            ArrayList<DirEntry>()
        }
    }
}
