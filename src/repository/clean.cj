// 文件：clean.cj
// 用途：仓库层 clean 胶水模块，桥接 gix_dir/gix_status 到 Repository
// 所属包：gix.repository
// 关键类型：CleanQuery
// 对齐原版：gitoxide-core/src/repository/clean.rs

package gitoxide.repository

import gitoxide.gix_status.*
import gitoxide.gix_index.*
import gitoxide.gix_utils.*
import std.collection.*
import std.fs.*

public class CleanQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 删除未跟踪文件
    // 对齐原版：gitoxide-core/src/repository/clean.rs::remove_untracked()
    public func removeUntracked(dryRun: Bool): ArrayList<String> {
        let removed = ArrayList<String>()
        let wtDirOpt = repo.workDir
        if (let Some(wtDir) <- wtDirOpt) {
            let indexPath = repo.gitDir + "/index"
            let indexFile = IndexFile.open(indexPath)
            var indexPaths = HashSet<String>()
            if (let Some(idx) <- indexFile) {
                for (entry in idx.entries) {
                    indexPaths.add(entry.path)
                }
            }
            removeUntrackedRecursive(wtDir, "", indexPaths, dryRun, removed)
        }
        removed
    }

    func removeUntrackedRecursive(dir: String, prefix: String, indexPaths: HashSet<String>, dryRun: Bool,
        removed: ArrayList<String>): Unit {
        try {
            let names = listDirectory(dir)
            for (name in names) {
                if (name == "." || name == ".." || name == ".git") {
                    continue
                }
                let relPath = if (prefix.size > 0) {
                    prefix + "/" + name
                } else {
                    name
                }
                let absPath = dir + "/" + name
                if (isDir(absPath)) {
                    removeUntrackedRecursive(absPath, relPath, indexPaths, dryRun, removed)
                } else {
                    if (!indexPaths.contains(relPath)) {
                        removed.add(relPath)
                        if (!dryRun) {
                            try {
                                remove(absPath)
                            } catch (_: Exception) {}
                        }
                    }
                }
            }
        } catch (_: Exception) {}
    }

    func isDir(path: String): Bool {
        try {
            let _ = Directory.readFrom(path)
            true
        } catch (_: Exception) {
            false
        }
    }
}
