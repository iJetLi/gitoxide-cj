// 文件：lib.cj
// 用途：提供 Git blame 功能，追踪文件每一行的最后修改提交
// 所属包：gix.gix_blame
// 关键类型：BlameResult, BlameEntry

package gitoxide.gix_blame

import gitoxide.gix_hash.*
import std.collection.*

// blame 结果，包含所有行的 blame 条目
public class BlameResult {
    // 每一行对应的 blame 条目列表
    public var entries: ArrayList<BlameEntry>

    public init() {
        this.entries = ArrayList<BlameEntry>()
    }
}

// 单个 blame 条目，描述一段连续行的归属信息
public class BlameEntry {
    // 起始行号（含）
    public var startLine: Int64
    // 结束行号（不含）
    public var endLine: Int64
    // 最后修改该行的提交 ID
    public var commitId: ObjectId
    // 原始文件路径（重命名时与当前路径不同），可选
    public var originalPath: ?String
    // 原始文件中的起始行号
    public var originalStartLine: Int64

    // 构造函数
    // 参数 startLine：起始行号
    // 参数 endLine：结束行号
    // 参数 commitId：提交 ID
    public init(startLine: Int64, endLine: Int64, commitId: ObjectId) {
        this.startLine = startLine
        this.endLine = endLine
        this.commitId = commitId
        this.originalPath = None
        this.originalStartLine = startLine
    }
}
