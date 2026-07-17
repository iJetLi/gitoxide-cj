// 文件：exclude.cj
// 用途：仓库层 exclude 胶水模块，桥接 gix_ignore 到 Repository
// 所属包：gix.repository
// 关键类型：ExcludeQuery
// 对齐原版：gitoxide-core/src/repository/exclude.rs

package gitoxide.repository

import gitoxide.gix_ignore.*
import std.collection.*
import std.fs.*

// 仓库排除规则查询器，桥接 gix_ignore 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/exclude.rs
public class ExcludeQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 查询指定路径是否被排除
    // 对齐原版：gitoxide-core/src/repository/exclude.rs::query()
    public func query(path: String): Bool {
        let ignore = loadIgnore()
        ignore.isIgnored(path)
    }

    func loadIgnore(): Ignore {
        let wtDirOpt = repo.workDir
        if (let Some(wtDir) <- wtDirOpt) {
            let ignorePath = wtDir + "/.gitignore"
            if (exists(ignorePath)) {
                let content = readFileContent(ignorePath)
                return Ignore.parse(content)
            }
        }
        let gitIgnorePath = repo.gitDir + "/info/exclude"
        if (exists(gitIgnorePath)) {
            let content = readFileContent(gitIgnorePath)
            return Ignore.parse(content)
        }
        Ignore()
    }

    func readFileContent(path: String): String {
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
            String.fromUtf8(bytes.toArray())
        } catch (_: Exception) {
            ""
        }
    }
}
