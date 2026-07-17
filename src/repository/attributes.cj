// 文件：attributes.cj
// 用途：仓库层 attributes 胶水模块，桥接 gix_attributes 到 Repository
// 所属包：gix.repository
// 关键类型：AttributesQuery
// 对齐原版：gitoxide-core/src/repository/attributes/

package gitoxide.repository

import gitoxide.gix_attributes.*
import std.collection.*
import std.fs.*

// 仓库属性查询器，桥接 gix_attributes 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/attributes/
public class AttributesQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 查询指定路径的属性
    // 对齐原版：gitoxide-core/src/repository/attributes/query.rs
    public func query(path: String): ArrayList<AttributeAssignment> {
        let attrs = loadAttributes()
        attrs.matchPath(path)
    }

    // 验证属性基线
    public func validateBaseline(): ArrayList<String> {
        let attrs = loadAttributes()
        var issues = ArrayList<String>()
        for (pattern in attrs.patterns) {
            for (a in pattern.assignments) {
                if (a.name.size == 0) {
                    issues.add("empty attribute name in pattern: ${pattern.pattern}")
                }
            }
        }
        issues
    }

    func loadAttributes(): Attributes {
        let wtDirOpt = repo.workDir
        if (let Some(wtDir) <- wtDirOpt) {
            let attrPath = wtDirOpt.getOrThrow() + "/.gitattributes"
            if (exists(attrPath)) {
                let content = readFileContent(attrPath)
                return Attributes.parse(content)
            }
        }
        let gitAttrPath = repo.gitDir + "/attributes"
        if (exists(gitAttrPath)) {
            let content = readFileContent(gitAttrPath)
            return Attributes.parse(content)
        }
        Attributes()
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
