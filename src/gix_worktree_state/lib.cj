// 文件：lib.cj
// 用途：工作树状态汇总，标识工作区是否干净、有无未暂存/未提交变更
// 所属包：gix.gix_worktree_state
// 关键类型：WorktreeState, CheckoutOutcome, CheckoutOptions, CheckoutCollision, CheckoutErrorRecord
// 对齐来源：gix-worktree-state/src/lib.rs, gix-worktree-state/src/checkout/mod.rs

package gitoxide.gix_worktree_state

import gitoxide.gix_hash.*
import std.collection.*

// ============================================================
// WorktreeState - 对齐 gix-worktree-state 整体状态
// ============================================================

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

// ============================================================
// Checkout 类型 - 对齐 gix-worktree-state/src/checkout/mod.rs
// ============================================================

// 检出时路径冲突信息
// 对齐 Rust: Collision
public class CheckoutCollision {
    // 冲突的路径
    public var path: String
    // IO 错误类型
    public var errorKind: String

    public init(path: String, errorKind: String) {
        this.path = path
        this.errorKind = errorKind
    }
}

// 检出时遇到 IO 错误的路径记录
// 对齐 Rust: ErrorRecord
public class CheckoutErrorRecord {
    // 遇到错误的路径
    public var path: String
    // 错误信息
    public var error: String

    public init(path: String, error: String) {
        this.path = path
        this.error = error
    }
}

// 检出整个索引的结果
// 对齐 Rust: checkout::Outcome
public class CheckoutOutcome {
    // 更新或创建的文件数
    public var filesUpdated: Int64
    // 写入磁盘的字节数
    public var bytesWritten: Int64
    // 遇到的路径冲突（大小写不敏感文件系统上可能发生）
    public var collisions: ArrayList<CheckoutCollision>
    // 检出过程中的其他错误
    public var errors: ArrayList<CheckoutErrorRecord>
    // 被进程列为延迟但我们从未传递的相对路径
    public var delayedPathsUnknown: ArrayList<String>
    // 所有被传递给进程但未被列出的路径
    public var delayedPathsUnprocessed: ArrayList<String>

    public init() {
        this.filesUpdated = 0
        this.bytesWritten = 0
        this.collisions = ArrayList<CheckoutCollision>()
        this.errors = ArrayList<CheckoutErrorRecord>()
        this.delayedPathsUnknown = ArrayList<String>()
        this.delayedPathsUnprocessed = ArrayList<String>()
    }
}

// 检出操作的选项
// 对齐 Rust: checkout::Options
public class CheckoutOptions {
    // 是否允许冲突时取消链接
    public var unlinkOnCollision: Bool
    // 是否跳过已存在且内容相同的文件
    public var overwriteExisting: Bool
    // 是否保持文件可执行位
    public var keepExecutableBit: Bool
    // 线程限制
    public var threadLimit: Int64

    public init() {
        this.unlinkOnCollision = false
        this.overwriteExisting = true
        this.keepExecutableBit = true
        this.threadLimit = 0
    }
}

// 检出操作的错误类型
// 对齐 Rust: checkout::Error
public enum CheckoutError {
    | Io(String)
    | FindObject(String)
    | Filter(String)
    | Interrupted
}
