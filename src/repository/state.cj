// 文件：state.cj
// 用途：定义仓库状态枚举，表示仓库当前所处的操作状态
// 所属包：gix.repository
// 关键类型：RepositoryState

package gitoxide.repository

// 仓库状态枚举，反映仓库当前正在进行的操作
public enum RepositoryState {
    | Clean // 干净状态，无进行中的操作
    | Merge // 正在合并
    | Revert // 正在 revert 单个提交
    | RevertSequence // 正在 revert 提交序列
    | CherryPick // 正在 cherry-pick 单个提交
    | CherryPickSequence // 正在 cherry-pick 提交序列
    | Bisect // 正在二分查找
    | Rebase // 正在变基
    | RebaseInteractive // 正在交互式变基
    | RebaseMerge // 正在 merge-based 变基
    | ApplyMailbox // 正在应用 mailbox 补丁
    | ApplyMailboxOrRebase // 正在应用 mailbox 补丁或变基
}
