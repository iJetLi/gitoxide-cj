// 文件：lib.cj
// 用途：提供 Git 子模块解析功能，从 .gitmodules 文件提取子模块信息
// 所属包：gix.gix_submodule
// 关键类型：Submodule
// 关键函数：parseGitmodules

package gitoxide.gix_submodule

import std.collection.*
import gitoxide.gix_utils.*

// 子模块定义，描述仓库中的一个子模块
public class Submodule {
    // 子模块名称
    public var name: String
    // 子模块在工作树中的路径
    public var path: String
    // 子模块的远程仓库 URL
    public var url: String
    // 子模块跟踪的分支，可选
    public var branch: ?String

    // 构造函数
    // 参数 name：子模块名称
    // 参数 path：子模块路径
    // 参数 url：远程仓库 URL
    public init(name: String, path: String, url: String) {
        this.name = name
        this.path = path
        this.url = url
        this.branch = None
    }
}

// 从 .gitmodules 文件内容解析子模块列表
// 参数 content：.gitmodules 文件的文本内容
// 返回值：解析得到的子模块列表
public func parseGitmodules(content: String): ArrayList<Submodule> {
    var result = ArrayList<Submodule>()
    var currentSubmodule: ?Submodule = None
    let lines = content.split("\n")
    for (line in lines) {
        let trimmed = trimStr(line)
        if (trimmed.startsWith("[submodule")) {
            if (let Some(sub) <- currentSubmodule) {
                result.add(sub)
            }
            let nameStart = trimmed.indexOf("\"")
            if (let Some(ns) <- nameStart) {
                let nameEnd = trimmed.indexOf("\"", ns + 1)
                if (let Some(ne) <- nameEnd) {
                    let name = substringStr(trimmed, ns + 1, ne)
                    currentSubmodule = Some(Submodule(name, "", ""))
                }
            }
        } else {
            if (let Some(sub) <- currentSubmodule) {
                let eqIdx = trimmed.indexOf("=")
                if (let Some(eq) <- eqIdx) {
                    let key = trimStr(substringStr(trimmed, 0, eq))
                    let value = trimStr(substringFromStr(trimmed, eq + 1))
                    if (key == "path") {
                        sub.path = value
                    } else if (key == "url") {
                        sub.url = value
                    } else if (key == "branch") {
                        sub.branch = Some(value)
                    }
                }
            }
        }
    }
    if (let Some(sub) <- currentSubmodule) {
        result.add(sub)
    }
    result
}
