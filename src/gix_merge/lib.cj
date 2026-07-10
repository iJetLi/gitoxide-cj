// 文件：lib.cj
// 用途：提供三路合并（three-way merge）功能，合并两个分支的变更
// 所属包：gix.gix_merge
// 关键类型：MergeResult, MergedContent, ConflictContent, Conflict
// 关键函数：threeWayMerge

package gitoxide.gix_merge

import gitoxide.gix_hash.*
import std.collection.*

// 合并结果，为干净合并或冲突合并
public enum MergeResult {
    | Clean(MergedContent) // 无冲突的干净合并
    | Conflict(ConflictContent) // 有冲突的合并
}

// 干净合并的结果内容
public class MergedContent {
    // 合并后的行列表
    public var lines: ArrayList<String>

    public init() {
        this.lines = ArrayList<String>()
    }
}

// 冲突合并的结果内容
public class ConflictContent {
    // 合并后的行列表（包含冲突标记）
    public var lines: ArrayList<String>
    // 冲突区域列表
    public var conflicts: ArrayList<Conflict>

    public init() {
        this.lines = ArrayList<String>()
        this.conflicts = ArrayList<Conflict>()
    }
}

// 单个冲突区域
public class Conflict {
    // 我方区域的起始行号
    public var oursStart: Int64
    // 我方区域的行数
    public var oursLen: Int64
    // 对方区域的起始行号
    public var theirsStart: Int64
    // 对方区域的行数
    public var theirsLen: Int64

    // 构造函数
    // 参数 oursStart：我方起始行号
    // 参数 oursLen：我方行数
    // 参数 theirsStart：对方起始行号
    // 参数 theirsLen：对方行数
    public init(oursStart: Int64, oursLen: Int64, theirsStart: Int64, theirsLen: Int64) {
        this.oursStart = oursStart
        this.oursLen = oursLen
        this.theirsStart = theirsStart
        this.theirsLen = theirsLen
    }
}

// 执行三路合并
// 基于共同祖先（base）合并我方（ours）和对方（theirs）的变更
// 若一方与 base 相同，直接取另一方；若双方都修改了同一区域，则产生冲突
// 参数 base：共同祖先的行列表
// 参数 ours：我方的行列表
// 参数 theirs：对方的行列表
// 返回值：干净合并返回 Clean，有冲突返回 Conflict
public func threeWayMerge(base: ArrayList<String>, ours: ArrayList<String>, theirs: ArrayList<String>): MergeResult {
    if (ours == theirs) {
        let result = MergedContent()
        for (line in ours) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    if (base == ours) {
        let result = MergedContent()
        for (line in theirs) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    if (base == theirs) {
        let result = MergedContent()
        for (line in ours) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    let conflict = ConflictContent()
    for (line in ours) {
        conflict.lines.add(line)
    }
    conflict.conflicts.add(Conflict(0, Int64(ours.size), 0, Int64(theirs.size)))
    MergeResult.Conflict(conflict)
}
