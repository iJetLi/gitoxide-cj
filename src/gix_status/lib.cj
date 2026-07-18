// 文件：lib.cj
// 用途：Git 状态查询，定义暂存区与工作区的文件状态类型
// 所属包：gix.gix_status
// 关键类型：Status, StatusEntry, IndexStatus, WorktreeStatus,
//           Change, EntryStatus, Conflict, ConflictIndexEntry, Outcome
// 对齐来源：gix-status/src/index_as_worktree/types.rs, gix-status/src/lib.rs

package gitoxide.gix_status

import gitoxide.gix_hash.*
import std.collection.*

// ============================================================
// 顶层状态聚合
// ============================================================

// Git 状态结果，包含所有文件的状态条目
public class Status {
    // 状态条目列表
    public var entries: ArrayList<StatusEntry>

    // 初始化空状态
    public init() {
        this.entries = ArrayList<StatusEntry>()
    }
}

// 状态条目，记录一个文件在暂存区和工作区的状态
public class StatusEntry {
    // 文件相对路径
    public var path: String
    // 暂存区状态
    public var indexStatus: IndexStatus
    // 工作区状态
    public var worktreeStatus: WorktreeStatus

    // 参数 path: 文件相对路径
    // 参数 indexStatus: 暂存区状态
    // 参数 worktreeStatus: 工作区状态
    public init(path: String, indexStatus: IndexStatus, worktreeStatus: WorktreeStatus) {
        this.path = path
        this.indexStatus = indexStatus
        this.worktreeStatus = worktreeStatus
    }
}

// 暂存区（索引）文件状态枚举
public enum IndexStatus {
    | Unmodified // 未修改
    | Added // 新添加到暂存区
    | Modified // 暂存区中已修改
    | Deleted // 从暂存区删除
    | Renamed // 重命名
    | Copied // 复制
}

extend IndexStatus <: Equatable<IndexStatus> {
    public operator func ==(other: IndexStatus): Bool {
        match (this) {
            case IndexStatus.Unmodified => match (other) {
                case IndexStatus.Unmodified => true;
                case _ => false
            }
            case IndexStatus.Added => match (other) {
                case IndexStatus.Added => true;
                case _ => false
            }
            case IndexStatus.Modified => match (other) {
                case IndexStatus.Modified => true;
                case _ => false
            }
            case IndexStatus.Deleted => match (other) {
                case IndexStatus.Deleted => true;
                case _ => false
            }
            case IndexStatus.Renamed => match (other) {
                case IndexStatus.Renamed => true;
                case _ => false
            }
            case IndexStatus.Copied => match (other) {
                case IndexStatus.Copied => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: IndexStatus): Bool {
        !(this == other)
    }
}

// 工作区文件状态枚举
public enum WorktreeStatus {
    | Unmodified // 未修改
    | Modified // 已修改
    | Deleted // 已删除
    | Untracked // 未跟踪
}

extend WorktreeStatus <: Equatable<WorktreeStatus> {
    public operator func ==(other: WorktreeStatus): Bool {
        match (this) {
            case WorktreeStatus.Unmodified => match (other) {
                case WorktreeStatus.Unmodified => true;
                case _ => false
            }
            case WorktreeStatus.Modified => match (other) {
                case WorktreeStatus.Modified => true;
                case _ => false
            }
            case WorktreeStatus.Deleted => match (other) {
                case WorktreeStatus.Deleted => true;
                case _ => false
            }
            case WorktreeStatus.Untracked => match (other) {
                case WorktreeStatus.Untracked => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: WorktreeStatus): Bool {
        !(this == other)
    }
}

// ============================================================
// index_as_worktree 类型 — 对齐 gix-status/src/index_as_worktree/types.rs
// ============================================================

// 索引条目相对于工作区的变更描述
// 对齐 Rust: Change<T, U>
public enum Change {
    // 对应文件在工作区已不存在
    | Removed
    // 文件类型发生变化（如普通文件变为符号链接）
    // worktreeMode: 工作区文件的模式
    | Type(UInt32)
    // 工作区文件被修改（权限或内容）
    // executableBitChanged: 可执行位是否变化
    // contentChange: 是否有内容变更
    // setEntryStatSizeZero: 是否需要将条目 stat.size 设为 0 以标记 racy-clean
    | Modification(Bool, Bool, Bool)
    // 子模块被修改
    | SubmoduleModification
}

extend Change <: Equatable<Change> {
    public operator func ==(other: Change): Bool {
        match (this) {
            case Change.Removed => match (other) {
                case Change.Removed => true;
                case _ => false
            }
            case Change.Type(wm) => match (other) {
                case Change.Type(owm) => wm == owm;
                case _ => false
            }
            case Change.Modification(ebc, cc, sesz) => match (other) {
                case Change.Modification(oebc, occ, osesz) => ebc == oebc && cc == occ && sesz == osesz;
                case _ => false
            }
            case Change.SubmoduleModification => match (other) {
                case Change.SubmoduleModification => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: Change): Bool {
        !(this == other)
    }
}

// 冲突类型枚举
// 对齐 Rust: Conflict
public enum Conflict {
    | BothDeleted // 双方都删除了不同版本
    | AddedByUs // 我们添加，他们修改
    | DeletedByThem // 他们删除，我们修改
    | AddedByThem // 他们添加，我们修改
    | DeletedByUs // 我们删除，他们修改
    | BothAdded // 双方都添加了不同版本
    | BothModified // 双方都修改了不同版本
}

extend Conflict <: Equatable<Conflict> {
    public operator func ==(other: Conflict): Bool {
        match (this) {
            case Conflict.BothDeleted => match (other) {
                case Conflict.BothDeleted => true;
                case _ => false
            }
            case Conflict.AddedByUs => match (other) {
                case Conflict.AddedByUs => true;
                case _ => false
            }
            case Conflict.DeletedByThem => match (other) {
                case Conflict.DeletedByThem => true;
                case _ => false
            }
            case Conflict.AddedByThem => match (other) {
                case Conflict.AddedByThem => true;
                case _ => false
            }
            case Conflict.DeletedByUs => match (other) {
                case Conflict.DeletedByUs => true;
                case _ => false
            }
            case Conflict.BothAdded => match (other) {
                case Conflict.BothAdded => true;
                case _ => false
            }
            case Conflict.BothModified => match (other) {
                case Conflict.BothModified => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: Conflict): Bool {
        !(this == other)
    }
}

// 冲突索引条目（不含磁盘元数据）
// 对齐 Rust: ConflictIndexEntry
public class ConflictIndexEntry {
    // 对象 ID
    public var id: ObjectId
    // 条目标志（含 stage 信息）
    public var flags: UInt32
    // 文件模式
    public var mode: UInt32

    public init(id: ObjectId, flags: UInt32, mode: UInt32) {
        this.id = id
        this.flags = flags
        this.mode = mode
    }
}

extend ConflictIndexEntry <: Equatable<ConflictIndexEntry> {
    public operator func ==(other: ConflictIndexEntry): Bool {
        this.id == other.id && this.flags == other.flags && this.mode == other.mode
    }

    public operator func !=(other: ConflictIndexEntry): Bool {
        !(this == other)
    }
}

// 索引条目的状态信息
// 对齐 Rust: EntryStatus<T, U>
public enum EntryStatus {
    // 条目处于冲突状态
    // summary: 冲突摘要
    // entries: stage 1~3 的冲突条目（最多 3 个，可能为 None）
    | Conflicted(Conflict, Array<Option<ConflictIndexEntry>>)
    // 发现变更
    | Changed(Change)
    // 条目未变但 stat 需要更新
    | NeedsUpdate
    // git add --intent-to-add 标记的条目
    | IntentToAdd
}

extend EntryStatus <: Equatable<EntryStatus> {
    public operator func ==(other: EntryStatus): Bool {
        match (this) {
            case EntryStatus.Conflicted(s, e) => match (other) {
                case EntryStatus.Conflicted(os, oe) => s == os && e == oe
                case _ => false
            }
            case EntryStatus.Changed(c) => match (other) {
                case EntryStatus.Changed(oc) => c == oc;
                case _ => false
            }
            case EntryStatus.NeedsUpdate => match (other) {
                case EntryStatus.NeedsUpdate => true;
                case _ => false
            }
            case EntryStatus.IntentToAdd => match (other) {
                case EntryStatus.IntentToAdd => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: EntryStatus): Bool {
        !(this == other)
    }
}

// index_as_worktree 操作的统计结果
// 对齐 Rust: Outcome
public class Outcome {
    // 待处理条目总数
    public var entriesToProcess: Int64
    // 实际处理条目数
    public var entriesProcessed: Int64
    // 因 pathspec 公共前缀跳过的条目数
    public var entriesSkippedByCommonPrefix: Int64
    // 因 pathspec 排除跳过的条目数
    public var entriesSkippedByPathspec: Int64
    // 因条目标志跳过的条目数
    public var entriesSkippedByEntryFlags: Int64
    // 符号链接元数据查询次数
    public var symlinkMetadataCalls: Int64
    // 需要更新 stat 的条目数
    public var entriesToUpdate: Int64
    // 被标记为 racy-clean 的条目数
    public var racyClean: Int64
    // 从工作区读取的字节数
    public var worktreeBytes: Int64
    // 从工作区读取的文件数
    public var worktreeFilesRead: Int64
    // 从对象库读取的字节数
    public var odbBytes: Int64
    // 从对象库读取的对象数
    public var odbObjectsRead: Int64

    public init() {
        this.entriesToProcess = 0
        this.entriesProcessed = 0
        this.entriesSkippedByCommonPrefix = 0
        this.entriesSkippedByPathspec = 0
        this.entriesSkippedByEntryFlags = 0
        this.symlinkMetadataCalls = 0
        this.entriesToUpdate = 0
        this.racyClean = 0
        this.worktreeBytes = 0
        this.worktreeFilesRead = 0
        this.odbBytes = 0
        this.odbObjectsRead = 0
    }

    // 跳过的条目总数
    public func skipped(): Int64 {
        entriesSkippedByCommonPrefix + entriesSkippedByPathspec + entriesSkippedByEntryFlags
    }
}

extend Outcome <: Equatable<Outcome> {
    public operator func ==(other: Outcome): Bool {
        this.entriesToProcess == other.entriesToProcess && this.entriesProcessed == other.entriesProcessed &&
            this.entriesSkippedByCommonPrefix == other.entriesSkippedByCommonPrefix && this.entriesSkippedByPathspec == other
            .entriesSkippedByPathspec && this.entriesSkippedByEntryFlags == other.entriesSkippedByEntryFlags &&
            this.symlinkMetadataCalls == other.symlinkMetadataCalls && this.entriesToUpdate == other.entriesToUpdate &&
            this.racyClean == other.racyClean && this.worktreeBytes == other.worktreeBytes && this.worktreeFilesRead == other
            .worktreeFilesRead && this.odbBytes == other.odbBytes && this.odbObjectsRead == other.odbObjectsRead
    }

    public operator func !=(other: Outcome): Bool {
        !(this == other)
    }
}

// index_as_worktree 的选项
// 对齐 Rust: Options
public class StatusOptions {
    // 是否使用 fs 缓存（仅 Windows 有效）
    public var fscache: Bool
    // 线程限制
    public var threadLimit: Int64

    public init() {
        this.fscache = false
        this.threadLimit = 0
    }
}

// 记录一个条目的变更信息
// 对齐 Rust: Record<'index, T, U>
public class StatusRecord {
    // 条目在索引中的位置
    public var entryIndex: Int64
    // 条目的相对路径
    public var relativePath: String
    // 条目的状态
    public var status: EntryStatus

    public init(entryIndex: Int64, relativePath: String, status: EntryStatus) {
        this.entryIndex = entryIndex
        this.relativePath = relativePath
        this.status = status
    }
}

// 收集所有非平凡变更的记录器
// 对齐 Rust: Recorder<'index, T, U>
public class StatusRecorder {
    // 收集到的变更记录
    public var records: ArrayList<StatusRecord>

    public init() {
        this.records = ArrayList<StatusRecord>()
    }

    // 添加一条记录
    public func visitEntry(entryIndex: Int64, relativePath: String, status: EntryStatus): Unit {
        records.add(StatusRecord(entryIndex, relativePath, status))
    }
}

// ============================================================
// index_as_worktree_with_renames 类型
// 对齐 gix-status/src/index_as_worktree_with_renames/types.rs
// ============================================================

// 变更摘要枚举
// 对齐 Rust: Summary
public enum StatusSummary {
    | Removed // 工作区中不存在
    | Added // 工作区新增（未跟踪）
    | Modified // 文件或子模块被修改
    | TypeChange // 文件类型变化
    | Renamed // 检测到重命名
    | Copied // 检测到复制
    | IntentToAdd // intent-to-add 标记
    | Conflict // 冲突条目
}

extend StatusSummary <: Equatable<StatusSummary> {
    public operator func ==(other: StatusSummary): Bool {
        match (this) {
            case StatusSummary.Removed => match (other) {
                case StatusSummary.Removed => true;
                case _ => false
            }
            case StatusSummary.Added => match (other) {
                case StatusSummary.Added => true;
                case _ => false
            }
            case StatusSummary.Modified => match (other) {
                case StatusSummary.Modified => true;
                case _ => false
            }
            case StatusSummary.TypeChange => match (other) {
                case StatusSummary.TypeChange => true;
                case _ => false
            }
            case StatusSummary.Renamed => match (other) {
                case StatusSummary.Renamed => true;
                case _ => false
            }
            case StatusSummary.Copied => match (other) {
                case StatusSummary.Copied => true;
                case _ => false
            }
            case StatusSummary.IntentToAdd => match (other) {
                case StatusSummary.IntentToAdd => true;
                case _ => false
            }
            case StatusSummary.Conflict => match (other) {
                case StatusSummary.Conflict => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: StatusSummary): Bool {
        !(this == other)
    }
}

// 从 EntryStatus 推导摘要
public func entryStatusSummary(status: EntryStatus): StatusSummary {
    match (status) {
        case EntryStatus.Conflicted(_, _) => StatusSummary.Conflict
        case EntryStatus.IntentToAdd => StatusSummary.IntentToAdd
        case EntryStatus.NeedsUpdate => StatusSummary.Modified
        case EntryStatus.Changed(c) => match (c) {
            case Change.Removed => StatusSummary.Removed
            case Change.Type(_) => StatusSummary.TypeChange
            case Change.Modification(_, _, _) => StatusSummary.Modified
            case Change.SubmoduleModification => StatusSummary.Modified
        }
    }
}

// 排序方式
// 对齐 Rust: Sorting
public enum Sorting {
    | ByPathCaseSensitive
    | ByPathCaseInsensitive
}

extend Sorting <: Equatable<Sorting> {
    public operator func ==(other: Sorting): Bool {
        match (this) {
            case Sorting.ByPathCaseSensitive => match (other) {
                case Sorting.ByPathCaseSensitive => true;
                case _ => false
            }
            case Sorting.ByPathCaseInsensitive => match (other) {
                case Sorting.ByPathCaseInsensitive => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: Sorting): Bool {
        !(this == other)
    }
}

// 重写跟踪的合并条目类型
// 对齐 Rust: Entry (index_as_worktree_with_renames)
public enum RewriteEntry {
    // 跟踪文件被修改
    | Modification(Int64, String, EntryStatus)
    // 目录遍历发现的条目
    | DirectoryContents(String, Bool)
    // 重写跟踪发现的匹配（重命名或复制）
    | Rewrite(String, String, Bool, Float64)
}

// 重写跟踪的合并结果
// 对齐 Rust: Outcome (index_as_worktree_with_renames)
public class RewriteOutcome {
    // 跟踪文件修改的结果
    public var trackedFileModification: Outcome
    // 目录遍历是否执行
    public var dirwalkPerformed: Bool
    // 重写跟踪是否执行
    public var rewritesPerformed: Bool

    public init() {
        this.trackedFileModification = Outcome()
        this.dirwalkPerformed = false
        this.rewritesPerformed = false
    }
}

// ============================================================
// SymlinkCheck — 对齐 gix-status/src/lib.rs + stack.rs
// ============================================================

// 符号链接检查栈，验证路径不经过符号链接
// 对齐 Rust: SymlinkCheck
public class SymlinkCheck {
    // 根路径
    public var root: String

    public init(root: String) {
        this.root = root
    }

    // 验证相对路径不经过符号链接（占位实现）
    public func verifiedPath(relativePath: String): String {
        root + "/" + relativePath
    }
}

// ============================================================
// index_as_worktree 错误类型 - 对齐 gix-status/src/index_as_worktree/types.rs Error
// ============================================================

// index_as_worktree 操作的错误类型
// 对齐 Rust: index_as_worktree::types::Error
public enum StatusError {
    | IllformedUtf8
    | Time(String)
    | Io(String)
    | Find(String)
    | SubmoduleStatus(String, String)
}

// ============================================================
// index_as_worktree_with_renames 错误类型
// 对齐 gix-status/src/index_as_worktree_with_renames/types.rs Error
// ============================================================

// index_as_worktree_with_renames 操作的错误类型
public enum RenameStatusError {
    | TrackedFileModifications(StatusError)
    | DirWalk(String)
    | SpawnThread(String)
    | SetAttributeContext(String)
    | OpenWorktreeFile(String)
    | HashFile(String)
    | ReadLink(String)
    | ConvertToGit(String)
    | RewriteTracker(String)
}

// ============================================================
// FsCapabilities - 对齐 gix-status/src/index_as_worktree/types.rs fs::Capabilities
// ============================================================

// 文件系统能力
// 对齐 Rust: gix_fs::Capabilities
public class FsCapabilities {
    // 是否区分大小写
    public var caseSensitive: Bool
    // 是否支持符号链接
    public var symlink: Bool
    // 是否支持可执行位
    public var executableBit: Bool
    // 是否预组合 Unicode
    public var precomposeUnicode: Bool

    public init() {
        this.caseSensitive = true
        this.symlink = true
        this.executableBit = true
        this.precomposeUnicode = false
    }
}
