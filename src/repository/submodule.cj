// 文件：submodule.cj
// 用途：仓库层 submodule 胶水模块，桥接 gix_submodule 到 Repository
// 所属包：gix.repository
// 关键类型：SubmoduleQuery
// 对齐原版：gitoxide-core/src/repository/submodule.rs

package gitoxide.repository

import gitoxide.gix_submodule.*
import std.collection.*
import std.fs.*

// 仓库子模块查询器，桥接 gix_submodule 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/submodule.rs
public class SubmoduleQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 列出所有子模块
    // 对齐原版：gitoxide-core/src/repository/submodule.rs::list()
    public func list(): ArrayList<Submodule> {
        let wtDirOpt = repo.workDir
        if (let Some(wtDir) <- wtDirOpt) {
            let modulesPath = wtDir + "/.gitmodules"
            if (exists(modulesPath)) {
                let content = readFileContent(modulesPath)
                parseGitmodules(content)
            } else {
                ArrayList<Submodule>()
            }
        } else {
            ArrayList<Submodule>()
        }
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
