// 文件：lib.cj
// 用途：提供三路合并（three-way merge）功能，包括 blob 合并、树合并和提交合并
// 所属包：gix.gix_merge
// 关键类型：Resolution, BuiltinDriver, ResourceKind, ConflictStyle, ConflictStrategy, Labels, Options
//           MergeResult, MergedContent, ConflictContent, Conflict
// 关键函数：threeWayMerge, binaryMerge, textMerge
// 对齐来源：gix-merge/src/lib.rs, gix-merge/src/blob/mod.rs, gix-merge/src/blob/builtin_driver/mod.rs,
//           gix-merge/src/blob/builtin_driver/text/mod.rs, gix-merge/src/blob/builtin_driver/text/function.rs,
//           gix-merge/src/blob/builtin_driver/binary.rs

package gitoxide.gix_merge

import gitoxide.gix_hash.*
import gitoxide.gix_imara_diff.*
import gitoxide.gix_utils.*
import std.collection.*

// 对齐 Rust: gix_merge::blob::Resolution
// 定义合并是否有冲突
public enum Resolution {
    | Complete
    | CompleteWithAutoResolvedConflict
    | Conflict
}

extend Resolution <: Equatable<Resolution> {
    public operator func ==(other: Resolution): Bool {
        match (this) {
            case Resolution.Complete => match (other) {
                case Resolution.Complete => true
                case _ => false
            }
            case Resolution.CompleteWithAutoResolvedConflict => match (other) {
                case Resolution.CompleteWithAutoResolvedConflict => true
                case _ => false
            }
            case Resolution.Conflict => match (other) {
                case Resolution.Conflict => true
                case _ => false
            }
        }
    }
}

// 对齐 Rust: gix_merge::blob::ResourceKind
// 合并资源方的分类
public enum ResourceKind {
    | CurrentOrOurs
    | OtherOrTheirs
    | CommonAncestorOrBase
}

// 对齐 Rust: gix_merge::blob::BuiltinDriver
// 内置合并驱动类型
public enum BuiltinDriver {
    | Text
    | Binary
    | Union
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::ConflictStyle
// 冲突标记的显示风格
public enum ConflictStyle {
    | Merge
    | Diff3
    | ZealousDiff3
}

extend ConflictStyle <: Equatable<ConflictStyle> {
    public operator func ==(other: ConflictStyle): Bool {
        match (this) {
            case ConflictStyle.Merge => match (other) {
                case ConflictStyle.Merge => true
                case _ => false
            }
            case ConflictStyle.Diff3 => match (other) {
                case ConflictStyle.Diff3 => true
                case _ => false
            }
            case ConflictStyle.ZealousDiff3 => match (other) {
                case ConflictStyle.ZealousDiff3 => true
                case _ => false
            }
        }
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::Conflict
// 仓颉枚举不支持命名字段，使用类包装
public enum ConflictStrategy {
    | Keep(ConflictKeep)
    | ResolveWithOurs
    | ResolveWithTheirs
    | ResolveWithUnion
}

// Conflict::Keep 的数据
public class ConflictKeep {
    public var style: ConflictStyle
    public var markerSize: UInt8

    public init(style: ConflictStyle, markerSize: UInt8) {
        this.style = style
        this.markerSize = markerSize
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::Labels
// 冲突标记的标签
public class Labels {
    public var ancestor: ?String
    public var current: ?String
    public var other: ?String

    public init() {
        this.ancestor = None
        this.current = None
        this.other = None
    }

    public init(ancestor: ?String, current: ?String, other: ?String) {
        this.ancestor = ancestor
        this.current = current
        this.other = other
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::Options
// 文本合并选项
public class TextMergeOptions {
    public var diffAlgorithm: Algorithm
    public var conflict: ConflictStrategy

    public init() {
        this.diffAlgorithm = Algorithm.Myers
        this.conflict = ConflictStrategy.Keep(ConflictKeep(ConflictStyle.Merge, 7))
    }

    public init(diffAlgorithm: Algorithm, conflict: ConflictStrategy) {
        this.diffAlgorithm = diffAlgorithm
        this.conflict = conflict
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::binary::ResolveWith
// 二进制合并冲突解决策略
public enum BinaryResolveWith {
    | Ancestor
    | Ours
    | Theirs
}

// 对齐 Rust: gix_merge::blob::builtin_driver::binary::Pick
// 二进制合并选择结果
public enum Pick <: Equatable<Pick> {
    | Ancestor
    | Ours
    | Theirs

    public operator func ==(other: Pick): Bool {
        match (this) {
            case Ancestor => match (other) { case Ancestor => true case _ => false }
            case Ours => match (other) { case Ours => true case _ => false }
            case Theirs => match (other) { case Theirs => true case _ => false }
        }
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::binary::merge
// 二进制合并：不查看实际数据，仅根据逻辑选择一方
public func binaryMerge(onConflict: ?BinaryResolveWith): PickResolution {
    match (onConflict) {
        case None => PickResolution(Pick.Ours, Resolution.Conflict)
        case Some(resolve) =>
            let pick = match (resolve) {
                case BinaryResolveWith.Ours => Pick.Ours
                case BinaryResolveWith.Theirs => Pick.Theirs
                case BinaryResolveWith.Ancestor => Pick.Ancestor
            }
            PickResolution(pick, Resolution.CompleteWithAutoResolvedConflict)
    }
}

// 二进制合并结果
public class PickResolution {
    public var pick: Pick
    public var resolution: Resolution

    public init(pick: Pick, resolution: Resolution) {
        this.pick = pick
        this.resolution = resolution
    }
}

// 合并结果，为干净合并或冲突合并
public enum MergeResult {
    | Clean(MergedContent)
    | Conflict(ConflictContent)
}

// 干净合并的结果内容
public class MergedContent {
    public var lines: ArrayList<String>

    public init() {
        this.lines = ArrayList<String>()
    }

    public init(lines: ArrayList<String>) {
        this.lines = lines
    }
}

// 冲突合并的结果内容
public class ConflictContent {
    public var lines: ArrayList<String>
    public var conflicts: ArrayList<Conflict>
    public var resolution: Resolution

    public init() {
        this.lines = ArrayList<String>()
        this.conflicts = ArrayList<Conflict>()
        this.resolution = Resolution.Conflict
    }
}

// 单个冲突区域
public class Conflict {
    public var oursStart: Int64
    public var oursLen: Int64
    public var theirsStart: Int64
    public var theirsLen: Int64

    public init(oursStart: Int64, oursLen: Int64, theirsStart: Int64, theirsLen: Int64) {
        this.oursStart = oursStart
        this.oursLen = oursLen
        this.theirsStart = theirsStart
        this.theirsLen = theirsLen
    }
}

func repeatChar(c: UInt8, count: Int64): String {
    var result = ""
    var i: Int64 = 0
    while (i < count) {
        result = result + String(Rune(UInt32(c)))
        i += 1
    }
    result
}

func handleKeepConflict(keep: ConflictKeep, baseLines: ArrayList<String>, oursLines: ArrayList<String>, theirsLines: ArrayList<String>, labels: Labels): MergeResult {
    let conflict = ConflictContent()
    let markerSize = Int64(keep.markerSize)
    // 对齐 Rust: 冲突标记 — <<<<<<<, =======, >>>>>>>
    var startMarker = ""
    var midMarker = ""
    var endMarker = ""
    var i: Int64 = 0
    while (i < markerSize) {
        startMarker = startMarker + "<"
        midMarker = midMarker + "="
        endMarker = endMarker + ">"
        i += 1
    }
    if (keep.style == ConflictStyle.Merge) {
        conflict.lines.add(startMarker + " " + labelOrEmpty(labels.current))
        for (line in oursLines) { conflict.lines.add(line) }
        conflict.lines.add(midMarker)
        for (line in theirsLines) { conflict.lines.add(line) }
        conflict.lines.add(endMarker + " " + labelOrEmpty(labels.other))
    } else {
        conflict.lines.add(startMarker + " " + labelOrEmpty(labels.current))
        for (line in oursLines) { conflict.lines.add(line) }
        // 生成 ||||||| 标记
        var baseMarkers = "|"
        var j: Int64 = 0
        while (j < markerSize - 1) {
            baseMarkers = baseMarkers + "|"
            j += 1
        }
        conflict.lines.add(baseMarkers + " " + labelOrEmpty(labels.ancestor))
        for (line in baseLines) { conflict.lines.add(line) }
        conflict.lines.add(midMarker)
        for (line in theirsLines) { conflict.lines.add(line) }
        conflict.lines.add(endMarker + " " + labelOrEmpty(labels.other))
    }
    conflict.conflicts.add(Conflict(0, Int64(oursLines.size), 0, Int64(theirsLines.size)))
    conflict.resolution = Resolution.Conflict
    MergeResult.Conflict(conflict)
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::merge
// 文本三路合并：基于行级 diff 的三路合并
// 参数 base：共同祖先的文本内容
// 参数 ours：我方的文本内容
// 参数 theirs：对方的文本内容
// 参数 options：合并选项
// 参数 labels：冲突标记标签
// 返回值：合并结果
public func textMerge(base: String, ours: String, theirs: String, options: TextMergeOptions, labels: Labels): MergeResult {
    if (ours == theirs) {
        return MergeResult.Clean(MergedContent(splitLines(ours)))
    }
    if (base == ours) {
        return MergeResult.Clean(MergedContent(splitLines(theirs)))
    }
    if (base == theirs) {
        return MergeResult.Clean(MergedContent(splitLines(ours)))
    }

    // 使用 imara-diff 计算差异
    let input = InternedInput.new(base, ours)
    let diffOurs = Diff.compute(options.diffAlgorithm, input)

    input.updateBefore(base)
    input.updateAfter(theirs)
    let diffTheirs = Diff.compute(options.diffAlgorithm, input)

    let oursHunks = diffOurs.computeHunks()
    let theirsHunks = diffTheirs.computeHunks()

    // 如果两边都没有差异，直接返回 base
    if (oursHunks.size == 0 && theirsHunks.size == 0) {
        return MergeResult.Clean(MergedContent(splitLines(base)))
    }

    // 如果只有一边有差异，直接取有差异的一边
    if (oursHunks.size == 0) {
        return MergeResult.Clean(MergedContent(splitLines(theirs)))
    }
    if (theirsHunks.size == 0) {
        return MergeResult.Clean(MergedContent(splitLines(ours)))
    }

    // 检查两边的差异是否重叠（冲突）
    let baseLines = splitLines(base)
    let oursLines = splitLines(ours)
    let theirsLines = splitLines(theirs)

    // 简单冲突检测：如果两边都修改了同一区域，产生冲突
    let hasOverlap = hunksOverlap(oursHunks, theirsHunks)
    if (hasOverlap) {
        match (options.conflict) {
            case ConflictStrategy.ResolveWithOurs =>
                return MergeResult.Clean(MergedContent(oursLines))
            case ConflictStrategy.ResolveWithTheirs =>
                return MergeResult.Clean(MergedContent(theirsLines))
            case ConflictStrategy.ResolveWithUnion =>
                let merged = ArrayList<String>()
                for (line in oursLines) { merged.add(line) }
                for (line in theirsLines) { merged.add(line) }
                return MergeResult.Clean(MergedContent(merged))
            case ConflictStrategy.Keep(keep) =>
                return handleKeepConflict(keep, baseLines, oursLines, theirsLines, labels)
        }
    }

    // 非重叠变更：合并两边
    let merged = mergeNonOverlapping(baseLines, oursLines, theirsLines, oursHunks, theirsHunks)
    MergeResult.Clean(MergedContent(merged))
}

// 执行三路合并，对齐 Rust: gix-merge::blob::merge
// 使用 diffLines 计算 base→ours 和 base→theirs 的差异，然后合并变更
// 对齐 Rust: gix_merge::blob::builtin_driver::text::function::merge
// 参数 base：共同祖先的行列表
// 参数 ours：我方的行列表
// 参数 theirs：对方的行列表
// 返回值：干净合并返回 Clean，有冲突返回 Conflict
public func threeWayMerge(base: ArrayList<String>, ours: ArrayList<String>, theirs: ArrayList<String>): MergeResult {
    // 对齐 Rust: 如果 ours == theirs，直接返回 ours
    if (ours == theirs) {
        let result = MergedContent()
        for (line in ours) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    // 对齐 Rust: 如果 base == ours，采用 theirs 的变更
    if (base == theirs) {
        let result = MergedContent()
        for (line in ours) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    // 对齐 Rust: 如果 base == theirs，采用 ours 的变更
    if (base == ours) {
        let result = MergedContent()
        for (line in theirs) {
            result.lines.add(line)
        }
        return MergeResult.Clean(result)
    }
    // 对齐 Rust: 使用 diff 计算 base→ours 和 base→theirs 的变更
    let oursDiff = diffLines(base, ours)
    let theirsDiff = diffLines(base, theirs)
    // 对齐 Rust: 将 diff hunks 转换为变更区域列表
    let oursChanges = hunksToChanges(oursDiff.hunks)
    let theirsChanges = hunksToChanges(theirsDiff.hunks)
    // 对齐 Rust: 合并变更，检测冲突
    let merged = mergeChanges(base, oursChanges, theirsChanges)
    merged
}

// 将 Hunk 列表转换为 Change 列表
// 对齐 Rust: gix_merge::blob::builtin_driver::text::function::Merge
class Change {
    var baseStart: Int64
    var baseLen: Int64
    var newLines: ArrayList<String>

    init(baseStart: Int64, baseLen: Int64, newLines: ArrayList<String>) {
        this.baseStart = baseStart
        this.baseLen = baseLen
        this.newLines = newLines
    }
}

func hunksToChanges(hunks: ArrayList<Hunk>): ArrayList<Change> {
    let changes = ArrayList<Change>()
    for (hunk in hunks) {
        var newLines = ArrayList<String>()
        for (dl in hunk.lines) {
            if (dl.kind == LineKind.Addition || dl.kind == LineKind.Context) {
                newLines.add(dl.text)
            }
        }
        changes.add(Change(hunk.oldStart - 1, hunk.oldLen, newLines))
    }
    changes
}

// 合并两方变更，检测冲突
// 对齐 Rust: gix_merge::blob::builtin_driver::text::function::merge — 逐区域合并
func mergeChanges(base: ArrayList<String>, oursChanges: ArrayList<Change>, theirsChanges: ArrayList<Change>): MergeResult {
    let result = MergedContent()
    var conflict = ConflictContent()
    var hasConflict = false
    var baseIdx: Int64 = 0
    var oi: Int64 = 0
    var ti: Int64 = 0

    while (oi < oursChanges.size || ti < theirsChanges.size) {
        let oc: ?Change = if (oi < oursChanges.size) { oursChanges[oi] } else { None }
        let tc: ?Change = if (ti < theirsChanges.size) { theirsChanges[ti] } else { None }

        if (oc.isSome() && tc.isSome()) {
            let oChange = oc.getOrThrow()
            let tChange = tc.getOrThrow()
            if (oChange.baseStart < tChange.baseStart) {
                // ours 变更在 theirs 之前，无重叠
                while (baseIdx < oChange.baseStart) {
                    result.lines.add(base[baseIdx])
                    baseIdx += 1
                }
                for (line in oChange.newLines) {
                    result.lines.add(line)
                }
                baseIdx += oChange.baseLen
                oi += 1
            } else if (tChange.baseStart < oChange.baseStart) {
                // theirs 变更在 ours 之前，无重叠
                while (baseIdx < tChange.baseStart) {
                    result.lines.add(base[baseIdx])
                    baseIdx += 1
                }
                for (line in tChange.newLines) {
                    result.lines.add(line)
                }
                baseIdx += tChange.baseLen
                ti += 1
            } else {
                // 同一位置的变更
                if (oChange.newLines == tChange.newLines) {
                    // 相同变更，无冲突
                    while (baseIdx < oChange.baseStart) {
                        result.lines.add(base[baseIdx])
                        baseIdx += 1
                    }
                    for (line in oChange.newLines) {
                        result.lines.add(line)
                    }
                    baseIdx += oChange.baseLen
                } else {
                    // 冲突
                    hasConflict = true
                    while (baseIdx < oChange.baseStart) {
                        conflict.lines.add(base[baseIdx])
                        baseIdx += 1
                    }
                    for (line in oChange.newLines) {
                        conflict.lines.add(line)
                    }
                    for (line in tChange.newLines) {
                        conflict.lines.add(line)
                    }
                    conflict.conflicts.add(Conflict(Int64(conflict.lines.size) - Int64(oChange.newLines.size) - Int64(tChange.newLines.size), Int64(oChange.newLines.size) + Int64(tChange.newLines.size), 0, 0))
                    baseIdx += oChange.baseLen
                }
                oi += 1
                ti += 1
            }
        } else if (oc.isSome()) {
            let oChange = oc.getOrThrow()
            while (baseIdx < oChange.baseStart) {
                result.lines.add(base[baseIdx])
                baseIdx += 1
            }
            for (line in oChange.newLines) {
                result.lines.add(line)
            }
            baseIdx += oChange.baseLen
            oi += 1
        } else if (tc.isSome()) {
            let tChange = tc.getOrThrow()
            while (baseIdx < tChange.baseStart) {
                result.lines.add(base[baseIdx])
                baseIdx += 1
            }
            for (line in tChange.newLines) {
                result.lines.add(line)
            }
            baseIdx += tChange.baseLen
            ti += 1
        }
    }
    // 处理剩余的 base 行
    while (baseIdx < base.size) {
        if (hasConflict) {
            conflict.lines.add(base[baseIdx])
        } else {
            result.lines.add(base[baseIdx])
        }
        baseIdx += 1
    }

    if (hasConflict) {
        MergeResult.Conflict(conflict)
    } else {
        MergeResult.Clean(result)
    }
}

// 对齐 Rust: gix_merge::blob::builtin_driver::text::utils::tokens
// 将文本按行拆分
func splitLines(text: String): ArrayList<String> {
    let result = ArrayList<String>()
    if (text.size == 0) {
        return result
    }
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < text.size) {
        let c = text[i]
        if (c == CHAR_LF) {
            if (i > start) {
                result.add(text[start..i])
            }
            result.add("\n")
            start = i + 1
        } else if (c == CHAR_CR) {
            if (i + 1 < text.size && text[i + 1] == CHAR_LF) {
                if (i > start) {
                    result.add(text[start..i])
                }
                result.add("\r\n")
                start = i + 2
                i += 1
            } else {
                if (i > start) {
                    result.add(text[start..i])
                }
                result.add("\r")
                start = i + 1
            }
        }
        i += 1
    }
    if (start < text.size) {
        result.add(text[start..text.size])
    }
    result
}

// 获取标签或空字符串
func labelOrEmpty(label: ?String): String {
    if (let Some(l) <- label) {
        return l
    }
    ""
}

// 检查两边的 hunks 是否重叠
func hunksOverlap(oursHunks: ArrayList<Hunk>, theirsHunks: ArrayList<Hunk>): Bool {
    for (oh in oursHunks) {
        for (th in theirsHunks) {
            let oStart = oh.oldStart
            let oEnd = oh.oldStart + oh.oldLen
            let tStart = th.oldStart
            let tEnd = th.oldStart + th.oldLen
            if (oStart < tEnd && tStart < oEnd) {
                return true
            }
        }
    }
    false
}

// 合并非重叠的变更
func mergeNonOverlapping(baseLines: ArrayList<String>, oursLines: ArrayList<String>, theirsLines: ArrayList<String>,
    oursHunks: ArrayList<Hunk>, theirsHunks: ArrayList<Hunk>): ArrayList<String> {
    let result = ArrayList<String>()
    var baseIdx: Int64 = 0
    var oursIdx: Int64 = 0
    var theirsIdx: Int64 = 0
    var ohIdx: Int64 = 0
    var thIdx: Int64 = 0

    while (baseIdx < baseLines.size) {
        let inOursHunk = ohIdx < oursHunks.size && baseIdx >= oursHunks[ohIdx].oldStart - 1 &&
            baseIdx < oursHunks[ohIdx].oldStart - 1 + oursHunks[ohIdx].oldLen
        let inTheirsHunk = thIdx < theirsHunks.size && baseIdx >= theirsHunks[thIdx].oldStart - 1 &&
            baseIdx < theirsHunks[thIdx].oldStart - 1 + theirsHunks[thIdx].oldLen

        if (inOursHunk) {
            while (oursIdx < oursLines.size && inOursHunk) {
                result.add(oursLines[oursIdx])
                oursIdx += 1
            }
            baseIdx += 1
            if (ohIdx < oursHunks.size) { ohIdx += 1 }
        } else if (inTheirsHunk) {
            while (theirsIdx < theirsLines.size && inTheirsHunk) {
                result.add(theirsLines[theirsIdx])
                theirsIdx += 1
            }
            baseIdx += 1
            if (thIdx < theirsHunks.size) { thIdx += 1 }
        } else {
            result.add(baseLines[baseIdx])
            baseIdx += 1
            oursIdx += 1
            theirsIdx += 1
        }
    }

    while (oursIdx < oursLines.size) {
        result.add(oursLines[oursIdx])
        oursIdx += 1
    }
    while (theirsIdx < theirsLines.size) {
        result.add(theirsLines[theirsIdx])
        theirsIdx += 1
    }

    result
}
