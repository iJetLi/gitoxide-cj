// 文件：merge.cj
// 用途：仓库层 merge 胶水模块，桥接 gix_merge 到 Repository
// 所属包：gix.repository
// 关键类型：MergeQuery
// 对齐原版：gitoxide-core/src/repository/merge/

package gitoxide.repository

import gitoxide.gix_merge.*
import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*

// 仓库合并查询器，桥接 gix_merge 底层模块到 Repository
// 对齐原版：gitoxide-core/src/repository/merge/
public class MergeQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 执行三路文本合并
    // 对齐原版：gitoxide-core/src/repository/merge/::file()
    public func file(base: String, ours: String, theirs: String, options: TextMergeOptions, labels: Labels): MergeResult {
        textMerge(base, ours, theirs, options, labels)
    }

    // 简化三路合并
    public func threeWayMerge(base: ArrayList<String>, ours: ArrayList<String>, theirs: ArrayList<String>): MergeResult {
        let baseStr = linesToString(base)
        let oursStr = linesToString(ours)
        let theirsStr = linesToString(theirs)
        let opts = TextMergeOptions()
        let labels = Labels()
        textMerge(baseStr, oursStr, theirsStr, opts, labels)
    }

    func linesToString(lines: ArrayList<String>): String {
        var result = ""
        for (line in lines) {
            result = result + line
        }
        result
    }
}
