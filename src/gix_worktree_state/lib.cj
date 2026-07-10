// 文件：lib.cj
// 用途：工作树状态汇总，标识工作区是否干净、有无未暂存/未提交变更
// 所属包：gix.gix_worktree_state
// 关键类型：WorktreeState

package gitoxide.gix_worktree_state

// 工作树状态汇总，描述工作区的整体变更状况
public class WorktreeState {
    // 工作区是否干净（无任何变更）
    public var isClean: Bool
    // 是否存在未暂存的变更
    public var hasUnstagedChanges: Bool
    // 是否存在未提交的变更（已暂存但未提交）
    public var hasUncommittedChanges: Bool

    // 初始化为干净状态
    public init() {
        this.isClean = true
        this.hasUnstagedChanges = false
        this.hasUncommittedChanges = false
    }
}
