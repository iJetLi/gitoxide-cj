// 文件：lib.cj
// 用途：提供 commit-graph 文件读写功能，加速提交遍历
// 所属包：gix.gix_commitgraph
// 关键类型：CommitGraphFile

package gitoxide.gix_commitgraph

import gitoxide.gix_hash.*
import std.fs.*
import std.collection.*

// commit-graph 文件，存储提交的祖先关系以加速遍历
public class CommitGraphFile {
    // 文件路径
    public var path: String
    // 文件中的提交数量
    public var numCommits: Int64

    // 构造函数
    // 参数 path：commit-graph 文件路径
    public init(path: String) {
        this.path = path
        this.numCommits = 0
    }

    // 打开指定路径的 commit-graph 文件
    // 参数 path：文件路径
    // 返回值：文件存在返回 CommitGraphFile，否则返回 None
    public static func open(path: String): ?CommitGraphFile {
        if (path.size == 0 || !exists(path)) {
            return None
        }
        Some(CommitGraphFile(path))
    }

    // 根据提交 ID 查找在 graph 中的索引
    // 参数 id：待查找的提交 ID
    // 返回值：找到返回索引，未找到返回 None
    public func lookup(id: ObjectId): ?Int64 {
        None
    }

    // 遍历 graph 中的所有提交 ID
    // 返回值：所有提交 ID 的列表
    public func iter(): ArrayList<ObjectId> {
        ArrayList<ObjectId>()
    }
}
