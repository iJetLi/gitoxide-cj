// 文件：worktree.cj
// 用途：定义工作树信息类型，包括主工作区和链接工作树
// 所属包：gix.repository
// 关键类型：WorktreeInfo, LinkedWorktree

package gitoxide.repository

import gitoxide.gix_worktree.*
import std.collection.*

// 工作树信息，包含主工作区和所有链接工作树
public class WorktreeInfo {
    // 主工作区路径
    public var mainWorktree: String
    // 链接工作树列表
    public var linkedWorktrees: ArrayList<LinkedWorktree>

    // 参数 mainWorktree：主工作区路径
    public init(mainWorktree: String) {
        this.mainWorktree = mainWorktree
        this.linkedWorktrees = ArrayList<LinkedWorktree>()
    }
}

// 链接工作树，表示主工作区之外检出到其他目录的工作树
public class LinkedWorktree {
    // 工作树唯一标识
    public var id: String
    // 工作树检出的目录路径
    public var path: String
    // 该工作树对应的 .git 目录路径
    public var gitDir: String

    // 参数 id：工作树标识
    // 参数 path：检出目录路径
    // 参数 gitDir：.git 目录路径
    public init(id: String, path: String, gitDir: String) {
        this.id = id
        this.path = path
        this.gitDir = gitDir
    }
}
