// 文件：lib.cj
// 用途：提供 Git blame 功能，追踪文件每一行的最后修改提交
// 所属包：gix.gix_blame
// 关键类型：BlameEntry, BlamePathEntry, BlameRanges, BlameOutcome, BlameStatistics,
//           BlameOptions, BlameChange, BlameOffset, UnblamedHunk
// 对齐来源：gix-blame/src/types.rs, gix-blame/src/lib.rs, gix-blame/src/error.rs

package gitoxide.gix_blame

import gitoxide.gix_hash.*
import std.collection.*

// ============================================================
// 核心数据结构 - 对齐 gix-blame/src/types.rs
// ============================================================

// 单个 blame 条目，描述被 blame 文件中一段连续行的归属信息
// 对齐 Rust: BlameEntry
public class BlameEntry {
    // 在被 blame 文件中的起始 token 索引（通常是行号，0-based）
    public var startInBlamedFile: Int64
    // 在源文件中的起始 token 索引（可能与 blamed 文件不同）
    public var startInSourceFile: Int64
    // 该 hunk 跨越的行数（始终 >= 1）
    public var len: Int64
    // 引入该段内容的提交 ID
    public var commitId: ObjectId
    // 源文件名（重命名时与被 blame 文件名不同），可选
    public var sourceFileName: ?String

    // 参数 startInBlamedFile：被 blame 文件中的起始索引
    // 参数 startInSourceFile：源文件中的起始索引
    // 参数 len：跨越行数
    // 参数 commitId：提交 ID
    public init(startInBlamedFile: Int64, startInSourceFile: Int64, len: Int64, commitId: ObjectId) {
        this.startInBlamedFile = startInBlamedFile
        this.startInSourceFile = startInSourceFile
        this.len = len
        this.commitId = commitId
        this.sourceFileName = None
    }

    // 返回该条目在被 blame 文件中的范围 [start, start+len)
    public func rangeInBlamedFile(): Range<Int64> {
        startInBlamedFile..(startInBlamedFile + len)
    }

    // 返回该条目在源文件中的范围 [start, start+len)
    public func rangeInSourceFile(): Range<Int64> {
        startInSourceFile..(startInSourceFile + len)
    }
}

// blame 路径条目，记录 blame 历史遍历中的变更信息（调试用）
// 对齐 Rust: BlamePathEntry
public class BlamePathEntry {
    // 变更后的源文件路径
    public var sourceFilePath: String
    // 变更前的源文件路径（None 表示根提交）
    public var previousSourceFilePath: ?String
    // 变更后的提交 ID
    public var commitId: ObjectId
    // 变更后的 blob ID
    public var blobId: ObjectId
    // 变更前的 blob ID
    public var previousBlobId: ObjectId
    // 当一个提交有多个 BlamePathEntry 时，指示与哪个父提交相关
    public var parentIndex: Int64

    public init(sourceFilePath: String, commitId: ObjectId, blobId: ObjectId) {
        this.sourceFilePath = sourceFilePath
        this.previousSourceFilePath = None
        this.commitId = commitId
        this.blobId = blobId
        this.previousBlobId = ObjectId.null(blobId.kind)
        this.parentIndex = 0
    }
}

// blame 结果，包含所有行的 blame 条目
// 对齐 Rust: Outcome
public class BlameOutcome {
    // 按顺序排列的 blame 条目列表
    public var entries: ArrayList<BlameEntry>
    // 被 blame 文件的内容
    public var blob: Array<Byte>
    // 统计信息
    public var statistics: BlameStatistics
    // blame 路径日志（调试用），可选
    public var blamePath: ?ArrayList<BlamePathEntry>

    public init() {
        this.entries = ArrayList<BlameEntry>()
        this.blob = []
        this.statistics = BlameStatistics()
        this.blamePath = None
    }
}

// blame 操作的统计信息
// 对齐 Rust: Statistics
public class BlameStatistics {
    // 遍历的提交数
    public var commitsTraversed: Int64
    // 解码的树对象数
    public var treesDecoded: Int64
    // 对文件路径做 diff 的树对象数
    public var treesDiffed: Int64
    // 对文件路径做重写检测 diff 的树对象数
    public var treesDiffedWithRewrites: Int64
    // 对比的 blob 数
    public var blobsDiffed: Int64

    public init() {
        this.commitsTraversed = 0
        this.treesDecoded = 0
        this.treesDiffed = 0
        this.treesDiffedWithRewrites = 0
        this.blobsDiffed = 0
    }
}

// ============================================================
// BlameRanges - 对齐 gix-blame/src/types.rs BlameRanges
// ============================================================

// 要 blame 的行范围
// 对齐 Rust: BlameRanges
public enum BlameRanges {
    | WholeFile
    | PartialFile(ArrayList<Range<Int64>>)
}

// ============================================================
// BlameOptions - 对齐 gix-blame/src/types.rs Options
// ============================================================

// blame 操作的选项
// 对齐 Rust: Options
public class BlameOptions {
    // 要 blame 的行范围
    public var ranges: BlameRanges
    // 不考虑给定日期之前的提交
    public var since: ?Int64
    // 是否进行重命名检测
    public var trackRenames: Bool
    // 是否收集调试路径信息
    public var debugTrackPath: Bool

    public init() {
        this.ranges = BlameRanges.WholeFile
        this.since = None
        this.trackRenames = false
        this.debugTrackPath = false
    }
}

// ============================================================
// BlameChange - 对齐 gix-blame/src/types.rs Change
// ============================================================

// 两个 blob 之间的单次变更
// 对齐 Rust: Change
public enum BlameChange {
    // 未变更的 token 范围
    | Unchanged(Range<Int64>)
    // (添加的行范围, 删除的行数)
    | AddedOrReplaced(Range<Int64>, Int64)
    // (删除起始行, 删除的行数)
    | Deleted(Int64, Int64)
}

// ============================================================
// BlameOffset - 对齐 gix-blame/src/types.rs Offset
// ============================================================

// blame 过程中的行偏移量
// 对齐 Rust: Offset
public enum BlameOffset {
    | Added(Int64)
    | Deleted(Int64)
}

// 偏移量对范围的移位
public func offsetShiftedRange(offset: BlameOffset, range: Range<Int64>): Range<Int64> {
    match (offset) {
        case BlameOffset.Added(added) => (range.start - added)..(range.end - added)
        case BlameOffset.Deleted(deleted) => (range.start + deleted)..(range.end + deleted)
    }
}

// ============================================================
// UnblamedHunk - 对齐 gix-blame/src/types.rs UnblamedHunk
// ============================================================

// 尚未关联到引入提交的 hunk
// 对齐 Rust: UnblamedHunk
public class UnblamedHunk {
    // 在被 blame 文件中的范围
    public var rangeInBlamedFile: Range<Int64>
    // 嫌疑提交及其在源文件中的对应范围
    public var suspects: ArrayList<SuspectEntry>
    // 源文件名（重命名时不同）
    public var sourceFileName: ?String

    public init(rangeInBlamedFile: Range<Int64>, suspect: ObjectId) {
        this.rangeInBlamedFile = rangeInBlamedFile
        this.suspects = ArrayList<SuspectEntry>()
        this.suspects.add(SuspectEntry(suspect, rangeInBlamedFile))
        this.sourceFileName = None
    }

    public init(rangeInBlamedFile: Range<Int64>, suspects: ArrayList<SuspectEntry>, sourceFileName: ?String) {
        this.rangeInBlamedFile = rangeInBlamedFile
        this.suspects = suspects
        this.sourceFileName = sourceFileName
    }

    // 检查是否有指定嫌疑提交
    public func hasSuspect(suspect: ObjectId): Bool {
        for (entry in suspects) {
            if (entry.commitId == suspect) {
                return true
            }
        }
        false
    }

    // 获取指定嫌疑提交的范围
    public func getRange(suspect: ObjectId): ?Range<Int64> {
        for (entry in suspects) {
            if (entry.commitId == suspect) {
                return Some(entry.rangeInSourceFile)
            }
        }
        None
    }

    // 将嫌疑从 from 转移到 to
    public func passBlame(from: ObjectId, to: ObjectId): Unit {
        for (i in 0..suspects.size) {
            if (suspects[i].commitId == from) {
                suspects[i] = SuspectEntry(to, suspects[i].rangeInSourceFile)
                return
            }
        }
    }

    // 克隆嫌疑到另一个提交
    public func cloneBlame(from: ObjectId, to: ObjectId): Unit {
        if (let Some(range) <- getRange(from)) {
            suspects.add(SuspectEntry(to, range))
        }
    }

    // 移除指定嫌疑
    public func removeBlame(suspect: ObjectId): Unit {
        var i: Int64 = 0
        while (i < suspects.size) {
            if (suspects[i].commitId == suspect) {
                suspects.remove(at: i)
            } else {
                i += 1
            }
        }
    }

    // 按偏移量移位嫌疑范围
    public func shiftBy(suspect: ObjectId, offset: BlameOffset): UnblamedHunk {
        var newSuspects = ArrayList<SuspectEntry>()
        for (entry in suspects) {
            if (entry.commitId == suspect) {
                newSuspects.add(SuspectEntry(entry.commitId, offsetShiftedRange(offset, entry.rangeInSourceFile)))
            } else {
                newSuspects.add(entry)
            }
        }
        UnblamedHunk(rangeInBlamedFile, newSuspects, sourceFileName)
    }

    // 将嫌疑从 from 转移到 to 并返回新实例
    public func passedBlame(from: ObjectId, to: ObjectId): UnblamedHunk {
        var newSuspects = ArrayList<SuspectEntry>()
        for (entry in suspects) {
            if (entry.commitId == from) {
                newSuspects.add(SuspectEntry(to, entry.rangeInSourceFile))
            } else {
                newSuspects.add(entry)
            }
        }
        UnblamedHunk(rangeInBlamedFile, newSuspects, sourceFileName)
    }
}

// 嫌疑条目，关联提交 ID 与源文件范围
public class SuspectEntry {
    public var commitId: ObjectId
    public var rangeInSourceFile: Range<Int64>

    public init(commitId: ObjectId, rangeInSourceFile: Range<Int64>) {
        this.commitId = commitId
        this.rangeInSourceFile = rangeInSourceFile
    }
}

// ============================================================
// BlameError - 对齐 gix-blame/src/error.rs Error
// ============================================================

// blame 操作的错误类型
// 对齐 Rust: Error
public enum BlameError {
    | EmptyTraversal
    | FileMissing(String, ObjectId)
    | InvalidOneBasedLineRange
    | FindObject(String)
    | Traverse(String)
    | DiffTree(String)
    | DecodeCommit(String)
}

// ============================================================
// 兼容旧 API - BlameResult / BlameEntry（旧版）
// ============================================================

// blame 结果，包含所有行的 blame 条目
// 保留旧名 BlameResult 以兼容已有测试
public class BlameResult {
    // 每一行对应的 blame 条目列表
    public var entries: ArrayList<BlameEntry>

    public init() {
        this.entries = ArrayList<BlameEntry>()
    }
}
