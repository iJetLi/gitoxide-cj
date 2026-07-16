// 文件：lib.cj
// 用途：提供基于 imara-diff 算法的行级差异比较功能，实现 Myers O(ND) diff 算法
// 所属包：gix.gix_imara_diff
// 关键类型：Diff, Hunk, DiffLine, LineKind, Algorithm, InternedInput, Interner, Token
// 关键函数：diffLines, diffLinesWith
// 对齐来源：gix-imara-diff/src/lib.rs, gix-imara-diff/src/myers.rs, gix-imara-diff/src/intern.rs

package gitoxide.gix_imara_diff

import std.collection.ArrayList
import std.collection.HashSet
import gitoxide.gix_hashtable.HashMap
import gitoxide.gix_utils.*

// 对齐 Rust: gix_imara_diff::Algorithm
public enum Algorithm <: Equatable<Algorithm> {
    | Myers
    | Histogram
    | MyersMinimal

    public operator func ==(other: Algorithm): Bool {
        match (this) {
            case Myers => match (other) { case Myers => true case _ => false }
            case Histogram => match (other) { case Histogram => true case _ => false }
            case MyersMinimal => match (other) { case MyersMinimal => true case _ => false }
        }
    }
}

// 对齐 Rust: gix_imara_diff::intern::Token
public struct Token {
    public let value: UInt32
    public init(value: UInt32) {
        this.value = value
    }
    public operator func ==(that: Token): Bool {
        this.value == that.value
    }
    public operator func !=(that: Token): Bool {
        this.value != that.value
    }
}

// 对齐 Rust: gix_imara_diff::InternedInput
public class InternedInput {
    public var before: ArrayList<Token>
    public var after: ArrayList<Token>
    public var interner: Interner

    public init() {
        this.before = ArrayList<Token>()
        this.after = ArrayList<Token>()
        this.interner = Interner()
    }

    public static func new(beforeStr: String, afterStr: String): InternedInput {
        let input = InternedInput()
        input.updateBefore(beforeStr)
        input.updateAfter(afterStr)
        input
    }

    public func updateBefore(text: String): Unit {
        before.clear()
        let lines = splitLines(text)
        for (line in lines) {
            before.add(interner.intern(line))
        }
    }

    public func updateAfter(text: String): Unit {
        after.clear()
        let lines = splitLines(text)
        for (line in lines) {
            after.add(interner.intern(line))
        }
    }

    public func clear(): Unit {
        before.clear()
        after.clear()
        interner.clear()
    }
}

// 对齐 Rust: gix_imara_diff::intern::Interner
public class Interner {
    public var tokens: ArrayList<String>
    public var tokenMap: HashMap<String, UInt32>

    public init() {
        this.tokens = ArrayList<String>()
        this.tokenMap = HashMap<String, UInt32>()
    }

    public func intern(s: String): Token {
        match (tokenMap.get(s)) {
            case Some(id) => return Token(id)
            case None => ()
        }
        let id = UInt32(tokens.size)
        tokens.add(s)
        tokenMap.put(s, id)
        Token(id)
    }

    public func numTokens(): UInt32 {
        UInt32(tokens.size)
    }

    public func clear(): Unit {
        tokens.clear()
        tokenMap = HashMap<String, UInt32>()
    }

    public func get(token: Token): ?String {
        if (token.value < UInt32(tokens.size)) {
            Some(tokens[Int64(token.value)])
        } else {
            None
        }
    }
}

// 对齐 Rust: gix_imara_diff::Diff
public class Diff {
    public var removed: ArrayList<Bool>
    public var added: ArrayList<Bool>
    public var hunks: ArrayList<Hunk>

    public init() {
        this.removed = ArrayList<Bool>()
        this.added = ArrayList<Bool>()
        this.hunks = ArrayList<Hunk>()
    }

    public static func compute(algo: Algorithm, input: InternedInput): Diff {
        let diff = Diff()
        diff.computeWith(algo, input.before, input.after, input.interner.numTokens())
        diff
    }

    public func computeWith(algo: Algorithm, before: ArrayList<Token>, after: ArrayList<Token>, numTokens: UInt32): Unit {
        removed.clear()
        added.clear()
        var i: Int64 = 0
        while (i < before.size) {
            removed.add(false)
            i += 1
        }
        i = 0
        while (i < after.size) {
            added.add(false)
            i += 1
        }
        let edges = commonEdges(before, after)
        let commonPrefix = edges.prefix
        let commonPostfix = edges.postfix
        let beforeStart: Int64 = Int64(commonPrefix)
        let beforeEnd: Int64 = Int64(before.size) - Int64(commonPostfix)
        let afterStart: Int64 = Int64(commonPrefix)
        let afterEnd: Int64 = Int64(after.size) - Int64(commonPostfix)
        if (beforeStart >= beforeEnd && afterStart >= afterEnd) {
            return
        }
        if (beforeStart >= beforeEnd) {
            var j: Int64 = afterStart
            while (j < afterEnd) {
                added[j] = true
                j += 1
            }
            return
        }
        if (afterStart >= afterEnd) {
            var j: Int64 = beforeStart
            while (j < beforeEnd) {
                removed[j] = true
                j += 1
            }
            return
        }
        match (algo) {
            case Myers => myersDiff(before, after, removed, added, beforeStart, beforeEnd, afterStart, afterEnd, false)
            case MyersMinimal => myersDiff(before, after, removed, added, beforeStart, beforeEnd, afterStart, afterEnd, true)
            case Histogram => myersDiff(before, after, removed, added, beforeStart, beforeEnd, afterStart, afterEnd, false)
        }
    }

    public func countAdditions(): Int64 {
        var count: Int64 = 0
        for (a in added) {
            if (a) { count += 1 }
        }
        count
    }

    public func countRemovals(): Int64 {
        var count: Int64 = 0
        for (r in removed) {
            if (r) { count += 1 }
        }
        count
    }

    public func isRemoved(tokenIdx: Int64): Bool {
        if (tokenIdx < 0 || tokenIdx >= removed.size) { return false }
        removed[tokenIdx]
    }

    public func isAdded(tokenIdx: Int64): Bool {
        if (tokenIdx < 0 || tokenIdx >= added.size) { return false }
        added[tokenIdx]
    }

    public func computeHunks(): ArrayList<Hunk> {
        let result = ArrayList<Hunk>()
        var posBefore: Int64 = 0
        var posAfter: Int64 = 0
        var i: Int64 = 0
        var j: Int64 = 0
        while (i < removed.size && j < added.size) {
            var remCount: Int64 = 0
            var addCount: Int64 = 0
            while (i < removed.size && removed[i]) {
                remCount += 1
                i += 1
            }
            while (j < added.size && added[j]) {
                addCount += 1
                j += 1
            }
            if (remCount > 0 || addCount > 0) {
                result.add(Hunk(posBefore + 1, remCount, posAfter + 1, addCount))
                posBefore += remCount
                posAfter += addCount
            }
            if (i < removed.size && j < added.size) {
                i += 1
                j += 1
                posBefore += 1
                posAfter += 1
            }
        }
        while (i < removed.size) {
            if (removed[i]) {
                var remCount: Int64 = 0
                while (i < removed.size && removed[i]) {
                    remCount += 1
                    i += 1
                }
                result.add(Hunk(posBefore + 1, remCount, posAfter + 1, 0))
                posBefore += remCount
            } else {
                i += 1
                posBefore += 1
            }
        }
        while (j < added.size) {
            if (added[j]) {
                var addCount: Int64 = 0
                while (j < added.size && added[j]) {
                    addCount += 1
                    j += 1
                }
                result.add(Hunk(posBefore + 1, 0, posAfter + 1, addCount))
                posAfter += addCount
            } else {
                j += 1
                posAfter += 1
            }
        }
        result
    }

    public func postprocessLines(input: InternedInput): Unit {
        postprocessNoHeuristic(input)
    }

    public func postprocessNoHeuristic(input: InternedInput): Unit {
        // 仓颉中暂不实现完整的 slider heuristic
    }
}

// 对齐 Rust: gix_imara_diff::Hunk
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

    public func isPureInsertion(): Bool {
        oldLen == 0 && newLen > 0
    }

    public func isPureRemoval(): Bool {
        newLen == 0 && oldLen > 0
    }
}

// 对齐 Rust: gix_imara_diff DiffLine
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

// 对齐 Rust: gix_imara_diff LineKind
public enum LineKind {
    | Context // 上下文行（未变更）
    | Addition // 新增行
    | Deletion // 删除行

    public operator func ==(that: LineKind): Bool {
        match (this) {
            case Context => match (that) {
                case Context => true
                case _ => false
            }
            case Addition => match (that) {
                case Addition => true
                case _ => false
            }
            case Deletion => match (that) {
                case Deletion => true
                case _ => false
            }
        }
    }

    public operator func !=(that: LineKind): Bool {
        !(this == that)
    }
}

// ============================================================
// Myers diff 算法实现 — 对齐 Rust: gix-imara-diff/src/myers.rs
// ============================================================

func myersDiff(
    before: ArrayList<Token>, after: ArrayList<Token>,
    removed: ArrayList<Bool>, added: ArrayList<Bool>,
    beforeStart: Int64, beforeEnd: Int64,
    afterStart: Int64, afterEnd: Int64,
    minimal: Bool
): Unit {
    let n = beforeEnd - beforeStart
    let m = afterEnd - afterStart
    if (n == 0) {
        var j: Int64 = afterStart
        while (j < afterEnd) { added[j] = true; j += 1 }
        return
    }
    if (m == 0) {
        var i: Int64 = beforeStart
        while (i < beforeEnd) { removed[i] = true; i += 1 }
        return
    }
    markDiffFromLCS(before, after, removed, added, beforeStart, beforeEnd, afterStart, afterEnd)
}

func markDiffFromLCS(
    before: ArrayList<Token>, after: ArrayList<Token>,
    removed: ArrayList<Bool>, added: ArrayList<Bool>,
    beforeStart: Int64, beforeEnd: Int64,
    afterStart: Int64, afterEnd: Int64
): Unit {
    let n = beforeEnd - beforeStart
    let m = afterEnd - afterStart
    var dp = Array<Array<Int64>>(n + 1, repeat: Array<Int64>(m + 1, repeat: 0))
    var i: Int64 = 1
    while (i <= n) {
        var j: Int64 = 1
        while (j <= m) {
            let bi = beforeStart + i - 1
            let ai = afterStart + j - 1
            if (bi < before.size && ai < after.size && before[bi] == after[ai]) {
                dp[i][j] = dp[i - 1][j - 1] + 1
            } else {
                dp[i][j] = if (dp[i - 1][j] > dp[i][j - 1]) { dp[i - 1][j] } else { dp[i][j - 1] }
            }
            j += 1
        }
        i += 1
    }
    var bi = n
    var ai = m
    while (bi > 0 && ai > 0) {
        let bIdx = beforeStart + bi - 1
        let aIdx = afterStart + ai - 1
        if (bIdx < before.size && aIdx < after.size && before[bIdx] == after[aIdx]) {
            bi -= 1
            ai -= 1
        } else if (dp[bi - 1][ai] > dp[bi][ai - 1]) {
            removed[bIdx] = true
            bi -= 1
        } else {
            added[aIdx] = true
            ai -= 1
        }
    }
    while (bi > 0) {
        removed[beforeStart + bi - 1] = true
        bi -= 1
    }
    while (ai > 0) {
        added[afterStart + ai - 1] = true
        ai -= 1
    }
}

// ============================================================
// 辅助函数 — 对齐 Rust: gix-imara-diff/src/util.rs
// ============================================================

// 辅助类型，替代 Tuple
class EdgeResult {
    var prefix: Int64
    var postfix: Int64
    init(prefix: Int64, postfix: Int64) {
        this.prefix = prefix
        this.postfix = postfix
    }
}

func commonPrefix(file1: ArrayList<Token>, file2: ArrayList<Token>): Int64 {
    var off: Int64 = 0
    while (off < file1.size && off < file2.size) {
        if (file1[off] != file2[off]) { break }
        off += 1
    }
    off
}

func commonPostfix(file1: ArrayList<Token>, file2: ArrayList<Token>): Int64 {
    var off: Int64 = 0
    var i1: Int64 = file1.size - 1
    var i2: Int64 = file2.size - 1
    while (i1 >= 0 && i2 >= 0) {
        if (file1[i1] != file2[i2]) { break }
        off += 1
        i1 -= 1
        i2 -= 1
    }
    off
}

func commonEdges(file1: ArrayList<Token>, file2: ArrayList<Token>): EdgeResult {
    let prefix = commonPrefix(file1, file2)
    var off: Int64 = 0
    var i1: Int64 = file1.size - 1
    var i2: Int64 = file2.size - 1
    while (i1 >= prefix && i2 >= prefix) {
        if (file1[i1] != file2[i2]) { break }
        off += 1
        i1 -= 1
        i2 -= 1
    }
    EdgeResult(prefix, off)
}


func strSubstring(s: String, start: Int64, len: Int64): String {
    var bytes = ArrayList<Byte>()
    var i: Int64 = start
    while (i < s.size && i < start + len) {
        bytes.add(s[i])
        i += 1
    }
    String.fromUtf8(bytes.toArray())
}

func strSubstringFrom(s: String, start: Int64): String {
    var bytes = ArrayList<Byte>()
    var i: Int64 = start
    while (i < s.size) {
        bytes.add(s[i])
        i += 1
    }
    String.fromUtf8(bytes.toArray())
}

func splitLines(text: String): ArrayList<String> {
    let result = ArrayList<String>()
    if (text.size == 0) { return result }
    var start: Int64 = 0
    var i: Int64 = 0
    while (i < text.size) {
        if (text[i] == CHAR_LF) {
            result.add(strSubstring(text, start, Int64(i + 1 - start)))
            start = i + 1
            i += 1
        } else if (text[i] == CHAR_CR) {
            if (i + 1 < text.size && text[i + 1] == CHAR_LF) {
                result.add(strSubstring(text, start, Int64(i + 2 - start)))
                start = i + 2
                i += 2
            } else {
                result.add(strSubstring(text, start, Int64(i + 1 - start)))
                start = i + 1
                i += 1
            }
        } else {
            i += 1
        }
    }
    if (start < text.size) {
        result.add(strSubstringFrom(text, start))
    }
    result
}

// ============================================================
// 高级 API
// ============================================================

public func diffLines(oldLines: ArrayList<String>, newLines: ArrayList<String>): Diff {
    let input = InternedInput()
    for (line in oldLines) { input.before.add(input.interner.intern(line)) }
    for (line in newLines) { input.after.add(input.interner.intern(line)) }
    let diff = Diff.compute(Algorithm.Myers, input)
    let hunks = diff.computeHunks()
    let result = Diff()
    for (hunk in hunks) {
        let newHunk = Hunk(hunk.oldStart, hunk.oldLen, hunk.newStart, hunk.newLen)
        var oldIdx = hunk.oldStart - 1
        var newIdx = hunk.newStart - 1
        var oldRemaining = hunk.oldLen
        var newRemaining = hunk.newLen
        while (oldRemaining > 0 && newRemaining > 0) {
            if (oldIdx < oldLines.size) {
                newHunk.lines.add(DiffLine(LineKind.Deletion, oldLines[oldIdx]))
            }
            if (newIdx < newLines.size) {
                newHunk.lines.add(DiffLine(LineKind.Addition, newLines[newIdx]))
            }
            oldIdx += 1
            newIdx += 1
            oldRemaining -= 1
            newRemaining -= 1
        }
        while (oldRemaining > 0) {
            if (oldIdx < oldLines.size) {
                newHunk.lines.add(DiffLine(LineKind.Deletion, oldLines[oldIdx]))
            }
            oldIdx += 1
            oldRemaining -= 1
        }
        while (newRemaining > 0) {
            if (newIdx < newLines.size) {
                newHunk.lines.add(DiffLine(LineKind.Addition, newLines[newIdx]))
            }
            newIdx += 1
            newRemaining -= 1
        }
        result.hunks.add(newHunk)
    }
    result
}

public func diffLinesWith(algo: Algorithm, beforeStr: String, afterStr: String): Diff {
    let input = InternedInput.new(beforeStr, afterStr)
    let diff = Diff.compute(algo, input)
    let hunks = diff.computeHunks()
    let result = Diff()
    for (hunk in hunks) {
        let newHunk = Hunk(hunk.oldStart, hunk.oldLen, hunk.newStart, hunk.newLen)
        var oldIdx = hunk.oldStart - 1
        var newIdx = hunk.newStart - 1
        var oldRemaining = hunk.oldLen
        var newRemaining = hunk.newLen
        while (oldRemaining > 0 && newRemaining > 0) {
            if (oldIdx < input.before.size) {
                let oldToken = input.interner.get(input.before[oldIdx])
                if (let Some(ot) <- oldToken) {
                    newHunk.lines.add(DiffLine(LineKind.Deletion, ot))
                }
            }
            if (newIdx < input.after.size) {
                let newToken = input.interner.get(input.after[newIdx])
                if (let Some(nt) <- newToken) {
                    newHunk.lines.add(DiffLine(LineKind.Addition, nt))
                }
            }
            oldIdx += 1
            newIdx += 1
            oldRemaining -= 1
            newRemaining -= 1
        }
        while (oldRemaining > 0) {
            if (oldIdx < input.before.size) {
                let oldToken = input.interner.get(input.before[oldIdx])
                if (let Some(ot) <- oldToken) {
                    newHunk.lines.add(DiffLine(LineKind.Deletion, ot))
                }
            }
            oldIdx += 1
            oldRemaining -= 1
        }
        while (newRemaining > 0) {
            if (newIdx < input.after.size) {
                let newToken = input.interner.get(input.after[newIdx])
                if (let Some(nt) <- newToken) {
                    newHunk.lines.add(DiffLine(LineKind.Addition, nt))
                }
            }
            newIdx += 1
            newRemaining -= 1
        }
        result.hunks.add(newHunk)
    }
    result
}
