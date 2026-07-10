// 文件：lib.cj
// 用途：提供 Git 风格的 glob 模式匹配功能
// 所属包：gix.gix_glob
// 关键类型：Pattern, Mode, Case, WildmatchMode

package gitoxide.gix_glob

import gitoxide.gix_utils.*
import std.collection.*

// 模式标志位掩码
// 对齐 Rust: gix_glob::pattern::Mode (bitflags)
public enum ModeFlag <: Hashable & Equatable<ModeFlag> {
    | NoSubDir
    | EndsWith
    | MustBeDir
    | Negative
    | Absolute

    public func hashCode(): Int64 {
        match (this) {
            case NoSubDir => 0
            case EndsWith => 1
            case MustBeDir => 2
            case Negative => 3
            case Absolute => 4
        }
    }

    public operator func ==(that: ModeFlag): Bool {
        match (this) {
            case NoSubDir => match (that) {
                case NoSubDir => true;
                case _ => false
            }
            case EndsWith => match (that) {
                case EndsWith => true;
                case _ => false
            }
            case MustBeDir => match (that) {
                case MustBeDir => true;
                case _ => false
            }
            case Negative => match (that) {
                case Negative => true;
                case _ => false
            }
            case Absolute => match (that) {
                case Absolute => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: ModeFlag): Bool {
        !(this == that)
    }
}

// 模式标志集合
public class Mode {
    var flags: HashSet<ModeFlag>

    public init() {
        flags = HashSet<ModeFlag>()
    }

    public init(flags: HashSet<ModeFlag>) {
        this.flags = flags
    }

    public static func empty(): Mode {
        Mode()
    }

    public static func from(flag: ModeFlag): Mode {
        let m = Mode()
        m.flags.add(flag)
        m
    }

    public func contains(flag: ModeFlag): Bool {
        flags.contains(flag)
    }

    public func insert(flag: ModeFlag): Unit {
        flags.add(flag)
    }

    public func isEmpty(): Bool {
        flags.isEmpty()
    }

    public operator func ==(that: Mode): Bool {
        flags == that.flags
    }

    public operator func !=(that: Mode): Bool {
        !(this == that)
    }
}

// 大小写匹配策略
// 对齐 Rust: gix_glob::pattern::Case
public enum Case {
    | Sensitive // 区分大小写
    | Fold // 忽略 ASCII 大小写

    public operator func ==(that: Case): Bool {
        match (this) {
            case Sensitive => match (that) {
                case Sensitive => true;
                case _ => false
            }
            case Fold => match (that) {
                case Fold => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: Case): Bool {
        !(this == that)
    }
}

// wildmatch 模式
// 对齐 Rust: gix_glob::wildmatch::Mode
public class WildmatchMode {
    var noMatchSlashLiteral: Bool
    var ignoreCase: Bool

    public init() {
        noMatchSlashLiteral = false
        ignoreCase = false
    }

    public static func empty(): WildmatchMode {
        WildmatchMode()
    }

    public static func withNoMatchSlashLiteral(): WildmatchMode {
        let m = WildmatchMode()
        m.noMatchSlashLiteral = true
        m
    }

    public static func withIgnoreCase(): WildmatchMode {
        let m = WildmatchMode()
        m.ignoreCase = true
        m
    }

    public func containsNoMatchSlashLiteral(): Bool {
        noMatchSlashLiteral
    }

    public func containsIgnoreCase(): Bool {
        ignoreCase
    }
}

public class Pattern {
    // 模式文本
    var text: String
    // 匹配模式标志
    var mode: Mode
    // 第一个通配符的位置（None 表示无通配符）
    var firstWildcardPos: ?Int64

    // 兼容旧接口：简单模式（File/Directory）
    public init(text: String, mode: SimpleMode, isNegated: Bool) {
        this.text = text
        this.mode = Mode()
        if (isNegated) {
            this.mode.insert(ModeFlag.Negative)
        }
        if (mode == SimpleMode.Directory) {
            this.mode.insert(ModeFlag.MustBeDir)
        }
        if (!text.contains("/")) {
            this.mode.insert(ModeFlag.NoSubDir)
        }
        this.firstWildcardPos = findFirstWildcard(text)
    }

    // 完整模式构造
    public init(text: String, mode: Mode, firstWildcardPos: ?Int64) {
        this.text = text
        this.mode = mode
        this.firstWildcardPos = firstWildcardPos
    }

    // 从字节数组解析 glob 模式（支持否定、转义、绝对路径、目录模式）
    // 对齐 Rust: Pattern::from_bytes
    public static func fromBytes(bytes: Array<Byte>): ?Pattern {
        let str = String.fromUtf8(bytes)
        if (str.size == 0) {
            return None
        }
        var allWhitespace = true
        for (i in 0..str.size) {
            let c = str[i]
            if (c != UInt8(32) && c != UInt8(9) && c != UInt8(10) && c != UInt8(13)) {
                allWhitespace = false
                break
            }
        }
        if (allWhitespace) {
            return None
        }
        let mode = Mode()
        var idx: Int64 = 0
        if (str[0] == UInt8(33)) {
            mode.insert(ModeFlag.Negative)
            idx = 1
        } else if (str.size > 1 && str[0] == UInt8(92) && (str[1] == UInt8(33) || str[1] == UInt8(35))) {
            idx = 1
        }
        if (idx < str.size && str[idx] == UInt8(47)) {
            mode.insert(ModeFlag.Absolute)
            idx += 1
        }
        var pattern = substringFromStr(str, idx)
        if (pattern.size > 0 && pattern[pattern.size - 1] == UInt8(47)) {
            mode.insert(ModeFlag.MustBeDir)
            pattern = substringStr(pattern, 0, pattern.size - 1)
        }
        if (!pattern.contains("/")) {
            mode.insert(ModeFlag.NoSubDir)
        }
        let fwp = findFirstWildcard(pattern)
        if (fwp == Some(0) && !(pattern.size > 1 && pattern[1] == UInt8(42))) {
            mode.insert(ModeFlag.EndsWith)
        }
        Some(Pattern(pattern, mode, fwp))
    }

    public static func fromBytesWithoutNegation(bytes: Array<Byte>): ?Pattern {
        let str = String.fromUtf8(bytes)
        if (str.size == 0) {
            return None
        }
        var allWhitespace = true
        for (i in 0..str.size) {
            let c = str[i]
            if (c != UInt8(32) && c != UInt8(9) && c != UInt8(10) && c != UInt8(13)) {
                allWhitespace = false
                break
            }
        }
        if (allWhitespace) {
            return None
        }
        let mode = Mode()
        var idx: Int64 = 0
        if (idx < str.size && str[idx] == UInt8(47)) {
            mode.insert(ModeFlag.Absolute)
            idx += 1
        }
        var pattern = substringFromStr(str, idx)
        if (pattern.size > 0 && pattern[pattern.size - 1] == UInt8(47)) {
            mode.insert(ModeFlag.MustBeDir)
            pattern = substringStr(pattern, 0, pattern.size - 1)
        }
        if (!pattern.contains("/")) {
            mode.insert(ModeFlag.NoSubDir)
        }
        let fwp = findFirstWildcard(pattern)
        if (fwp == Some(0) && !(pattern.size > 1 && pattern[1] == UInt8(42))) {
            mode.insert(ModeFlag.EndsWith)
        }
        Some(Pattern(pattern, mode, fwp))
    }

    // 是否为否定模式
    public func isNegative(): Bool {
        mode.contains(ModeFlag.Negative)
    }

    // 简单匹配（兼容旧接口）
    public func matches(path: String): Bool {
        let result = globMatch(text, path)
        if (isNegative()) {
            !result
        } else {
            result
        }
    }

    // 匹配仓库相对路径
    // 对齐 Rust: Pattern::matches_repo_relative_path
    public func matchesRepoRelativePath(path: String, basenameStartPos: ?Int64, isDir: ?Bool, `case`: Case,
        wmMode: WildmatchMode): Bool {
        let isDirVal = if (let Some(v) <- isDir) {
            v
        } else {
            false
        }
        if (!isDirVal && mode.contains(ModeFlag.MustBeDir)) {
            return false
        }
        let effectiveMode = WildmatchMode()
        if (wmMode.containsNoMatchSlashLiteral()) {
            effectiveMode.noMatchSlashLiteral = true
        }
        if (`case` == Case.Fold) {
            effectiveMode.ignoreCase = true
        }
        if (mode.contains(ModeFlag.NoSubDir) && !mode.contains(ModeFlag.Absolute)) {
            let bsp = if (let Some(v) <- basenameStartPos) {
                v
            } else {
                let lastSlash = path.lastIndexOf('/')
                if (let Some(ls) <- lastSlash) {
                    ls + 1
                } else {
                    0
                }
            }
            let basename = if (bsp < path.size) {
                substringFromStr(path, bsp)
            } else {
                path
            }
            matchesWithValue(basename, effectiveMode)
        } else {
            matchesWithValue(path, effectiveMode)
        }
    }

    // 带模式的匹配
    // 对齐 Rust: Pattern::matches
    public func matchesWithValue(value: String, wmMode: WildmatchMode): Bool {
        match (firstWildcardPos) {
            case Some(pos) =>
                if (mode.contains(ModeFlag.EndsWith) && (!wmMode.containsNoMatchSlashLiteral() || !value.contains("/"))) {
                    let suffix = substringFromStr(text, pos + 1)
                    if (wmMode.containsIgnoreCase()) {
                        value.size >= suffix.size && eqIgnoreCase(
                            substringStr(value, value.size - suffix.size, value.size), suffix)
                    } else {
                        value.endsWith(suffix)
                    }
                } else {
                    if (wmMode.containsIgnoreCase()) {
                        if (!eqIgnoreCase(substringStr(value, 0, pos), substringStr(text, 0, pos))) {
                            return false
                        }
                    } else {
                        if (!value.startsWith(substringStr(text, 0, pos))) {
                            return false
                        }
                    }
                    wildmatch(text, value, wmMode)
                }
            case None =>
                if (wmMode.containsIgnoreCase()) {
                    eqIgnoreCase(value, text)
                } else {
                    value == text
                }
        }
    }

    // 格式化显示
    // 对齐 Rust: Pattern::Display
    public func display(): String {
        var s = ""
        if (mode.contains(ModeFlag.Negative)) {
            s += "!"
        }
        if (mode.contains(ModeFlag.Absolute)) {
            s += "/"
        }
        s += text
        if (mode.contains(ModeFlag.MustBeDir)) {
            s += "/"
        }
        s
    }
}

// 简单模式枚举（兼容旧接口）
public enum SimpleMode {
    | File
    | Directory

    public operator func ==(that: SimpleMode): Bool {
        match (this) {
            case File => match (that) {
                case File => true;
                case _ => false
            }
            case Directory => match (that) {
                case Directory => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: SimpleMode): Bool {
        !(this == that)
    }
}

// wildmatch 函数
// 对齐 Rust: gix_glob::wildmatch()
public func wildmatch(pattern: String, value: String, mode: WildmatchMode): Bool {
    matchRecursive(pattern, value, mode, 0) == WildmatchResult.Match
}

// 查找第一个通配符位置
func findFirstWildcard(s: String): ?Int64 {
    for (i in 0..s.size) {
        let c = s[i]
        if (c == UInt8(42) || c == UInt8(63) || c == UInt8(91) || c == UInt8(92)) {
            return Some(i)
        }
    }
    None
}

// ASCII 大小写不敏感比较
func eqIgnoreCase(a: String, b: String): Bool {
    if (a.size != b.size) {
        return false
    }
    for (i in 0..a.size) {
        if (toLower(a[i]) != toLower(b[i])) {
            return false
        }
    }
    true
}

func toLower(c: UInt8): UInt8 {
    if (c >= UInt8(65) && c <= UInt8(90)) {
        c + UInt8(32)
    } else {
        c
    }
}

func substringFromStr(s: String, from: Int64): String {
    if (from >= s.size) {
        ""
    } else {
        substringStr(s, from, s.size)
    }
}

enum WildmatchResult {
    | Match
    | NoMatch
    | AbortAll
    | AbortToStarStar
    | RecursionLimitReached

    public operator func ==(that: WildmatchResult): Bool {
        match (this) {
            case Match => match (that) {
                case Match => true;
                case _ => false
            }
            case NoMatch => match (that) {
                case NoMatch => true;
                case _ => false
            }
            case AbortAll => match (that) {
                case AbortAll => true;
                case _ => false
            }
            case AbortToStarStar => match (that) {
                case AbortToStarStar => true;
                case _ => false
            }
            case RecursionLimitReached => match (that) {
                case RecursionLimitReached => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: WildmatchResult): Bool {
        !(this == that)
    }
}

const RECURSION_LIMIT: Int64 = 64

func matchRecursive(pattern: String, text: String, mode: WildmatchMode, depth: Int64): WildmatchResult {
    if (depth >= RECURSION_LIMIT) {
        return WildmatchResult.RecursionLimitReached
    }
    var pi: Int64 = 0
    var ti: Int64 = 0
    var pLen = pattern.size
    var tLen = text.size
    while (pi < pLen) {
        var pc = pattern[pi]
        if (mode.containsIgnoreCase()) {
            pc = toLower(pc)
        }
        if (ti >= tLen) {
            // 文本已耗尽，跳过剩余 *
            if (pc == UInt8(42)) {
                pi += 1
                while (pi < pLen && pattern[pi] == UInt8(42)) {
                    pi += 1
                }
                if (pi == pLen) {
                    return WildmatchResult.Match
                }
            }
            return WildmatchResult.AbortAll
        }
        var tc = text[ti]
        if (mode.containsIgnoreCase()) {
            tc = toLower(tc)
        }
        // 反斜杠转义
        if (pc == UInt8(92)) {
            pi += 1
            if (pi >= pLen) {
                return WildmatchResult.NoMatch
            }
            let escaped = if (mode.containsIgnoreCase()) {
                toLower(pattern[pi])
            } else {
                pattern[pi]
            }
            if (escaped != tc) {
                return WildmatchResult.NoMatch
            }
            pi += 1
            ti += 1
            continue
        }
        // ? 匹配
        if (pc == UInt8(63)) {
            if (mode.containsNoMatchSlashLiteral() && tc == UInt8(47)) {
                return WildmatchResult.NoMatch
            }
            pi += 1
            ti += 1
            continue
        }
        // * 匹配
        if (pc == UInt8(42)) {
            var isDoubleStar = false
            if (pi + 1 < pLen && pattern[pi + 1] == UInt8(42)) {
                isDoubleStar = true
                let starBeforeSlash = pi == 0 || pattern[pi - 1] == UInt8(47)
                let starAfterSlash = pi + 2 >= pLen || pattern[pi + 2] == UInt8(47)
                isDoubleStar = starBeforeSlash && starAfterSlash
                while (pi < pLen && pattern[pi] == UInt8(42)) {
                    pi += 1
                }
            } else {
                pi += 1
            }
            if (pi == pLen) {
                // * 是最后一个字符
                if (!mode.containsNoMatchSlashLiteral()) {
                    return WildmatchResult.Match
                }
                // 检查剩余文本是否包含 /
                var hasSlash = false
                for (i in ti..tLen) {
                    if (text[i] == UInt8(47)) {
                        hasSlash = true
                        break
                    }
                }
                if (hasSlash && !isDoubleStar) {
                    return WildmatchResult.AbortToStarStar
                }
                return WildmatchResult.Match
            }
            // * 后面还有字符
            var matchSlash = !mode.containsNoMatchSlashLiteral()
            if (isDoubleStar && mode.containsNoMatchSlashLiteral()) {
                matchSlash = true
            }
            let nextPc = if (mode.containsIgnoreCase()) {
                toLower(pattern[pi])
            } else {
                pattern[pi]
            }
            if (isDoubleStar && mode.containsNoMatchSlashLiteral()) {
                if (nextPc == UInt8(47)) {
                    pi += 1
                    let restPattern = substringFromStr(pattern, pi)
                    var tryTi = ti
                    while (true) {
                        let res = matchRecursive(restPattern, substringFromStr(text, tryTi), mode, depth + 1)
                        if (res == WildmatchResult.Match) {
                            return WildmatchResult.Match
                        }
                        if (tryTi >= tLen) {
                            break
                        }
                        if (text[tryTi] == UInt8(47)) {
                            tryTi += 1
                        } else {
                            tryTi += 1
                            continue
                        }
                    }
                    return WildmatchResult.NoMatch
                }
                let restPattern = substringFromStr(pattern, pi)
                var tryTi = ti
                while (true) {
                    let res = matchRecursive(restPattern, substringFromStr(text, tryTi), mode, depth + 1)
                    if (res == WildmatchResult.Match) {
                        return WildmatchResult.Match
                    }
                    if (tryTi >= tLen) {
                        break
                    }
                    tryTi += 1
                }
                return WildmatchResult.NoMatch
            }
            if (!matchSlash && nextPc == UInt8(47)) {
                // 找到下一个 /
                var foundSlash = false
                while (ti < tLen) {
                    let t = if (mode.containsIgnoreCase()) {
                        toLower(text[ti])
                    } else {
                        text[ti]
                    }
                    if (t == UInt8(47)) {
                        foundSlash = true
                        ti += 1
                        pi += 1
                        break
                    }
                    ti += 1
                }
                if (!foundSlash) {
                    return WildmatchResult.AbortAll
                }
                continue
            }
            // 贪心匹配：用 * 匹配尽可能少的字符，然后递归
            while (true) {
                let res = matchRecursive(substringFromStr(pattern, pi), substringFromStr(text, ti), mode, depth + 1)
                if (res == WildmatchResult.Match) {
                    return WildmatchResult.Match
                }
                if (res != WildmatchResult.NoMatch) {
                    if (!matchSlash && res == WildmatchResult.AbortToStarStar) {
                        return WildmatchResult.AbortToStarStar
                    }
                    if (res == WildmatchResult.AbortAll) {
                        return WildmatchResult.AbortAll
                    }
                }
                // * 不匹配 /
                if (!matchSlash && ti < tLen && text[ti] == UInt8(47)) {
                    return WildmatchResult.AbortToStarStar
                }
                ti += 1
                if (ti > tLen) {
                    return WildmatchResult.AbortAll
                }
            }
        }
        // [ 字符类
        if (pc == UInt8(91)) {
            pi += 1
            if (pi >= pLen) {
                return WildmatchResult.AbortAll
            }
            var negated = false
            var classPc = pattern[pi]
            if (mode.containsIgnoreCase()) {
                classPc = toLower(classPc)
            }
            if (classPc == UInt8(94) || classPc == UInt8(33)) {
                negated = true
                pi += 1
                if (pi >= pLen) {
                    return WildmatchResult.AbortAll
                }
                classPc = pattern[pi]
                if (mode.containsIgnoreCase()) {
                    classPc = toLower(classPc)
                }
            }
            var matched = false
            var prevChar: UInt8 = 0
            var firstInBracket = true
            var bracketClosed = false
            while (pi < pLen) {
                var curPc = pattern[pi]
                if (mode.containsIgnoreCase()) {
                    curPc = toLower(curPc)
                }
                if (curPc == UInt8(93) && !firstInBracket) {
                    bracketClosed = true
                    pi += 1
                    break
                }
                firstInBracket = false
                if (curPc == UInt8(92)) {
                    pi += 1
                    if (pi >= pLen) {
                        return WildmatchResult.AbortAll
                    }
                    curPc = pattern[pi]
                    if (mode.containsIgnoreCase()) {
                        curPc = toLower(curPc)
                    }
                    if (curPc == tc) {
                        matched = true
                    }
                    prevChar = curPc
                    pi += 1
                    continue
                }
                if (curPc == UInt8(45) && prevChar != UInt8(0) && pi + 1 < pLen) {
                    var nextPi = pi + 1
                    var rangeEndOrig = pattern[nextPi]
                    if (mode.containsIgnoreCase()) {
                        rangeEndOrig = toLower(rangeEndOrig)
                    }
                    if (pattern[pi + 1] == UInt8(92) && pi + 2 < pLen) {
                        nextPi = pi + 2
                        rangeEndOrig = pattern[nextPi]
                        if (mode.containsIgnoreCase()) {
                            rangeEndOrig = toLower(rangeEndOrig)
                        }
                    }
                    let nextCharCheck = rangeEndOrig
                    if (nextCharCheck != UInt8(93)) {
                        pi = nextPi + 1
                        let rangeStartOrig = if (mode.containsIgnoreCase() && prevChar >= UInt8(97) && prevChar <= UInt8(122)) {
                            prevChar - UInt8(32)
                        } else {
                            prevChar
                        }
                        if (tc >= rangeStartOrig && tc <= rangeEndOrig) {
                            matched = true
                        } else if (tc >= prevChar && tc <= rangeEndOrig) {
                            matched = true
                        } else if (mode.containsIgnoreCase()) {
                            let tcUpper = if (tc >= UInt8(97) && tc <= UInt8(122)) {
                                tc - UInt8(32)
                            } else {
                                tc
                            }
                            if (tcUpper >= rangeStartOrig && tcUpper <= rangeEndOrig) {
                                matched = true
                            } else if (tcUpper >= prevChar && tcUpper <= rangeEndOrig) {
                                matched = true
                            }
                        }
                        prevChar = UInt8(0)
                        continue
                    }
                }
                if (curPc == UInt8(91) && pi + 1 < pLen && pattern[pi + 1] == UInt8(58)) {
                    let classStart = pi + 2
                    var classEnd = classStart
                    while (classEnd < pLen &&
                            !(pattern[classEnd] == UInt8(58) && classEnd + 1 < pLen && pattern[classEnd + 1] == UInt8(93))) {
                        classEnd += 1
                    }
                    if (classEnd < pLen && classEnd + 1 < pLen) {
                        let className = substringStr(pattern, classStart, classEnd)
                        if (className == "alnum") {
                            if ((tc >= UInt8(48) && tc <= UInt8(57)) || (tc >= UInt8(65) && tc <= UInt8(90)) || (tc >=
                                UInt8(97) && tc <= UInt8(122))) {
                                matched = true
                            }
                        } else if (className == "alpha") {
                            if ((tc >= UInt8(65) && tc <= UInt8(90)) || (tc >= UInt8(97) && tc <= UInt8(122))) {
                                matched = true
                            }
                        } else if (className == "digit") {
                            if (tc >= UInt8(48) && tc <= UInt8(57)) {
                                matched = true
                            }
                        } else if (className == "lower") {
                            if (tc >= UInt8(97) && tc <= UInt8(122)) {
                                matched = true
                            }
                        } else if (className == "upper") {
                            if (tc >= UInt8(65) && tc <= UInt8(90) || (mode.containsIgnoreCase() && tc >= UInt8(97) &&
                                tc <= UInt8(122))) {
                                matched = true
                            }
                        } else if (className == "space") {
                            if (tc == UInt8(32) || tc == UInt8(9) || tc == UInt8(10) || tc == UInt8(13)) {
                                matched = true
                            }
                        } else if (className == "xdigit") {
                            if ((tc >= UInt8(48) && tc <= UInt8(57)) || (tc >= UInt8(65) && tc <= UInt8(70)) || (tc >=
                                UInt8(97) && tc <= UInt8(102))) {
                                matched = true
                            }
                        } else if (className == "blank") {
                            if (tc == UInt8(32) || tc == UInt8(9)) {
                                matched = true
                            }
                        } else if (className == "cntrl") {
                            if (tc <= UInt8(31) || tc == UInt8(127)) {
                                matched = true
                            }
                        } else if (className == "graph") {
                            if (tc >= UInt8(33) && tc <= UInt8(126)) {
                                matched = true
                            }
                        } else if (className == "print") {
                            if (tc >= UInt8(32) && tc <= UInt8(126)) {
                                matched = true
                            }
                        } else if (className == "punct") {
                            if ((tc >= UInt8(33) && tc <= UInt8(47)) || (tc >= UInt8(58) && tc <= UInt8(64)) || (tc >=
                                UInt8(91) && tc <= UInt8(96)) || (tc >= UInt8(123) && tc <= UInt8(126))) {
                                matched = true
                            }
                        } else {
                            return WildmatchResult.AbortAll
                        }
                        pi = classEnd + 2
                        prevChar = UInt8(0)
                        continue
                    }
                }
                if (curPc == tc) {
                    matched = true
                }
                prevChar = curPc
                pi += 1
            }
            if (!bracketClosed) {
                return WildmatchResult.NoMatch
            }
            if (matched == negated) {
                return WildmatchResult.NoMatch
            }
            if (mode.containsNoMatchSlashLiteral() && tc == UInt8(47)) {
                return WildmatchResult.NoMatch
            }
            ti += 1
            continue
        }
        // 普通字符
        if (pc != tc) {
            return WildmatchResult.NoMatch
        }
        pi += 1
        ti += 1
    }
    // 模式已耗尽，检查文本是否也耗尽
    if (ti < tLen) {
        return WildmatchResult.NoMatch
    }
    WildmatchResult.Match
}

// 简单 glob 匹配（兼容旧接口）
func globMatch(pattern: String, path: String): Bool {
    if (pattern.size == 0) {
        return path.size == 0
    }
    let pLen = pattern.size
    let sLen = path.size
    var pi: Int64 = 0
    var si: Int64 = 0
    var starPi: Int64 = -1
    var starSi: Int64 = -1
    var doubleStarPi: Int64 = -1
    var doubleStarSi: Int64 = -1
    while (si < sLen) {
        if (pi < pLen) {
            let pc = pattern[pi]
            if (pc == UInt8(42) && pi + 1 < pLen && pattern[pi + 1] == UInt8(42)) {
                doubleStarPi = pi
                doubleStarSi = si
                pi += 2
                if (pi < pLen && pattern[pi] == UInt8(47)) {
                    pi += 1
                }
                continue
            }
            if (pc == UInt8(42)) {
                starPi = pi
                starSi = si
                pi += 1
                continue
            }
            if (pc == UInt8(63) || pc == path[si]) {
                pi += 1
                si += 1
                continue
            }
        }
        if (doubleStarPi >= 0) {
            pi = doubleStarPi + 2
            if (pi < pLen && pattern[pi] == UInt8(47)) {
                pi += 1
            }
            doubleStarSi += 1
            si = doubleStarSi
            continue
        }
        if (starPi >= 0) {
            pi = starPi + 1
            starSi += 1
            si = starSi
            continue
        }
        return false
    }
    while (pi < pLen && pattern[pi] == UInt8(42)) {
        pi += 1
    }
    pi == pLen
}

// 模式列表，用于从文件或字节流加载多个 glob 模式
// 对齐 Rust: gix_glob::search::pattern::List
public class PatternList {
    // 基础路径（相对于 root）
    public var base: ?String
    // 源文件路径
    public var source: String
    // 模式列表
    public var patterns: ArrayList<Pattern>

    public init(base: ?String, source: String) {
        this.base = base
        this.source = source
        this.patterns = ArrayList<Pattern>()
    }

    // 从字节数组创建模式列表
    // 对齐 Rust: List::from_bytes
    public static func fromBytes(bytes: Array<Byte>, source: String, root: ?String): PatternList {
        var baseVal: ?String = None
        if (let Some(r) <- root) {
            if (source.startsWith(r)) {
                let relPath = substringStr(source, r.size, source.size)
                let lastSlash = relPath.lastIndexOf('/')
                if (let Some(ls) <- lastSlash) {
                    baseVal = substringStr(relPath, 0, ls + 1)
                } else {
                    baseVal = ""
                }
            }
        }
        let list = PatternList(baseVal, source)
        if (bytes.size > 0) {
            let content = String.fromUtf8(bytes)
            let lines = content.split("\n")
            for (line in lines) {
                let p = Pattern.fromBytes(line.toArray())
                if (let Some(pat) <- p) {
                    list.patterns.add(pat)
                }
            }
        }
        list
    }

    // 从文件创建模式列表
    // 对齐 Rust: List::from_file
    public static func fromFile(path: String, root: ?String, followSymlinks: Bool): ?PatternList {
        // 占位实现：文件不存在或为目录时返回 None
        None
    }

    // 剥离基础路径并重新计算 basename 位置
    // 对齐 Rust: List::strip_base_handle_recompute_basename_pos
    public func stripBaseHandleRecomputeBasenamePos(path: String, basenameStartPos: ?Int64, `case`: Case): ?String {
        if (let Some(b) <- base) {
            if (b.size > 0 && path.startsWith(b)) {
                let stripped = substringFromStr(path, b.size)
                if (`case` == Case.Fold) {
                    return toLowerCaseAscii(stripped)
                }
                return stripped
            }
        }
        Some(path)
    }
}

func substringStr(s: String, start: Int64, end: Int64): String {
    var result = ArrayList<Byte>()
    let bytes = s.toArray()
    var i = start
    while (i < end && i < bytes.size) {
        result.add(bytes[i])
        i += 1
    }
    String.fromUtf8(result.toArray())
}

func toLowerCaseAscii(s: String): String {
    var result = ArrayList<Byte>()
    let bytes = s.toArray()
    for (b in bytes) {
        if (b >= UInt8(65) && b <= UInt8(90)) {
            result.add(b + UInt8(32))
        } else {
            result.add(b)
        }
    }
    String.fromUtf8(result.toArray())
}
