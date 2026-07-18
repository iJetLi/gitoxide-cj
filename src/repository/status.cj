// 文件：status.cj
// 用途：查询仓库工作区状态（文件变更、暂存区等）
// 所属包：gix.repository
// 关键类型：StatusQuery
// 对齐原版：gitoxide-core/src/repository/status.rs::index_worktree_overlays()

package gitoxide.repository

import gitoxide.gix_status.*
import gitoxide.gix_index.*
import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*
import std.fs.*

// 仓库状态查询器，用于获取工作区和暂存区的文件变更状态
public class StatusQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 执行状态查询
    // 遍历索引条目，对比工作区文件和 ODB 对象，填充 Status.entries
    // 对齐原版：gitoxide-core/src/repository/status.rs::index_worktree_overlays()
    public func query(): Status {
        let status = Status()
        let indexPath = repo.gitDir + "/index"
        let indexFile = IndexFile.open(indexPath)
        if (let Some(idx) <- indexFile) {
            let wtDirOpt = repo.workDir
            if (let Some(wtDir) <- wtDirOpt) {
                for (entry in idx.entries) {
                    let relPath = entry.path
                    let absPath = wtDir + "/" + relPath
                    let wtStatus = checkWorktreeStatus(entry, absPath)
                    if (wtStatus != WorktreeStatus.Unmodified) {
                        status.entries.add(StatusEntry(relPath, IndexStatus.Unmodified, wtStatus))
                    }
                }
                let indexPaths = HashSet<String>()
                for (entry in idx.entries) {
                    indexPaths.add(entry.path)
                }
                findUntrackedFiles(wtDir, "", indexPaths, status)
            }
        }
        status
    }

    // 检查单个索引条目在工作区的状态
    // 对齐原版：gix-status/src/index_as_worktree/mod.rs
    func checkWorktreeStatus(entry: IndexEntry, absPath: String): WorktreeStatus {
        try {
            if (!exists(absPath)) {
                return WorktreeStatus.Deleted
            }
            let fileBytes = readFileBytes(absPath)
            let normalized = normalizeToLf(fileBytes)
            let workHash = computeHash(repo.hashKind, ObjectKind.Blob, normalized)
            if (!(workHash == entry.id)) {
                return WorktreeStatus.Modified
            }
            WorktreeStatus.Unmodified
        } catch (_: Exception) {
            WorktreeStatus.Untracked
        }
    }

    // 递归查找工作区中未被索引跟踪的文件
    // 对齐原版：gix-status/src/index_as_worktree_with_renames/dirwalk.rs
    func findUntrackedFiles(dir: String, prefix: String, indexPaths: HashSet<String>, status: Status): Unit {
        try {
            if (!exists(dir)) {
                return
            }
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
                if (isDirectory(absPath)) {
                    findUntrackedFiles(absPath, relPath, indexPaths, status)
                } else {
                    if (!indexPaths.contains(relPath)) {
                        status.entries.add(StatusEntry(relPath, IndexStatus.Added, WorktreeStatus.Untracked))
                    }
                }
            }
        } catch (_: Exception) {
            return
        }
    }

    // 读取文件字节内容
    func readFileBytes(path: String): Array<Byte> {
        try {
            let file = File(path, OpenMode.Read)
            var bytes = ArrayList<Byte>()
            var buf = Array<Byte>(4096, repeat: 0)
            var n = file.read(buf)
            while (n > 0) {
                for (i in 0..n) {
                    bytes.add(buf[i])
                }
                n = file.read(buf)
            }
            file.close()
            bytes.toArray()
        } catch (_: Exception) {
            []
        }
    }

    // 判断路径是否为目录
    func isDirectory(path: String): Bool {
        try {
            let _ = Directory.readFrom(path)
            true
        } catch (_: Exception) {
            false
        }
    }

    func normalizeToLf(data: Array<Byte>): Array<Byte> {
        let result = ArrayList<Byte>()
        var i: Int64 = 0
        while (i < data.size) {
            if (i + 1 < data.size && data[i] == 13 && data[i + 1] == 10) {
                result.add(10)
                i += 2
            } else {
                result.add(data[i])
                i += 1
            }
        }
        result.toArray()
    }
}
