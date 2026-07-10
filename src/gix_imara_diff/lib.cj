// 文件：lib.cj
// 用途：提供基于 imara-diff 算法的行级差异比较功能
// 所属包：gix.gix_imara_diff
// 关键类型：Diff, Hunk, DiffLine, LineKind
// 关键函数：diffLines

package gitoxide.gix_imara_diff

import std.collection.*

// 差异比较结果，包含所有差异块
public class Diff {
    // 差异块列表
    public var hunks: ArrayList<Hunk>

    public init() {
        this.hunks = ArrayList<Hunk>()
    }
}

// 差异块，描述一段连续的变更区域
public class Hunk {
    // 旧文件中的起始行号
    public var oldStart: Int64
    // 旧文件中的行数
    public var oldLen: Int64
    // 新文件中的起始行号
    public var newStart: Int64
    // 新文件中的行数
    public var newLen: Int64
    // 块内的差异行列表
    public var lines: ArrayList<DiffLine>

    // 构造函数
    // 参数 oldStart：旧文件起始行号
    // 参数 oldLen：旧文件行数
    // 参数 newStart：新文件起始行号
    // 参数 newLen：新文件行数
    public init(oldStart: Int64, oldLen: Int64, newStart: Int64, newLen: Int64) {
        this.oldStart = oldStart
        this.oldLen = oldLen
        this.newStart = newStart
        this.newLen = newLen
        this.lines = ArrayList<DiffLine>()
    }
}

// 单行差异信息
public class DiffLine {
    // 行类型
    public var kind: LineKind
    // 行文本内容
    public var text: String

    // 构造函数
    // 参数 kind：行类型
    // 参数 text：行文本
    public init(kind: LineKind, text: String) {
        this.kind = kind
        this.text = text
    }
}

// 差异行类型枚举
public enum LineKind {
    | Context // 上下文行（未变更）
    | Addition // 新增行
    | Deletion // 删除行

    public operator func ==(that: LineKind): Bool {
        match (this) {
            case Context => match (that) {
                case Context => true;
                case _ => false
            }
            case Addition => match (that) {
                case Addition => true;
                case _ => false
            }
            case Deletion => match (that) {
                case Deletion => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: LineKind): Bool {
        !(this == that)
    }
}

// 对两行列表进行差异比较
// 参数 oldLines：旧文件的行列表
// 参数 newLines：新文件的行列表
// 返回值：包含所有差异的 Diff 结果
public func diffLines(oldLines: ArrayList<String>, newLines: ArrayList<String>): Diff {
    let result = Diff()
    let hunk = Hunk(1, Int64(oldLines.size), 1, Int64(newLines.size))
    var oldIdx: Int64 = 0
    var newIdx: Int64 = 0
    while (oldIdx < oldLines.size && newIdx < newLines.size) {
        if (oldLines[oldIdx] == newLines[newIdx]) {
            hunk.lines.add(DiffLine(LineKind.Context, oldLines[oldIdx]))
            oldIdx += 1
            newIdx += 1
        } else {
            hunk.lines.add(DiffLine(LineKind.Deletion, oldLines[oldIdx]))
            hunk.lines.add(DiffLine(LineKind.Addition, newLines[newIdx]))
            oldIdx += 1
            newIdx += 1
        }
    }
    while (oldIdx < oldLines.size) {
        hunk.lines.add(DiffLine(LineKind.Deletion, oldLines[oldIdx]))
        oldIdx += 1
    }
    while (newIdx < newLines.size) {
        hunk.lines.add(DiffLine(LineKind.Addition, newLines[newIdx]))
        newIdx += 1
    }
    result.hunks.add(hunk)
    result
}
