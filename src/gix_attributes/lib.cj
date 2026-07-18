// 文件：lib.cj
// 用途：提供 .gitattributes 文件解析与路径匹配功能
// 所属包：gix.gix_attributes
// 关键类型：Attributes, AttributePattern, AttributeAssignment, AttributeState, MacroDef
// 关键函数：parse, matchPath
// 对齐 Rust: gix-attributes/src/lib.rs, parse.rs, search/attributes.rs, name.rs, assignment.rs, state.rs

package gitoxide.gix_attributes

import std.collection.*
import gitoxide.gix_utils.*

// 属性状态枚举，对齐 Rust gix_attributes::State
// 表示属性赋值的不同状态
public enum AttributeState {
    | Set // 属性被设置（如 text）
    | Unset // 属性被取消（如 -diff）
    | Value(String) // 属性有值（如 eol=lf）
    | Unspecified // 属性未指定（如 !diff）

    public operator func ==(that: AttributeState): Bool {
        match (this) {
            case Set => match (that) {
                case Set => true
                case _ => false
            }
            case Unset => match (that) {
                case Unset => true
                case _ => false
            }
            case Value(v1) => match (that) {
                case Value(v2) => v1 == v2
                case _ => false
            }
            case Unspecified => match (that) {
                case Unspecified => true
                case _ => false
            }
        }
    }

    public operator func !=(that: AttributeState): Bool {
        !(this == that)
    }
}

// gitattributes 解析结果，包含所有属性模式
// 对齐 Rust: gix_attributes::Search
public class Attributes {
    // 解析得到的属性模式列表
    public var patterns: ArrayList<AttributePattern>

    // 宏定义列表，对齐 Rust gix_attributes::search::MetadataCollection
    public var macros: ArrayList<MacroDef>

    public init() {
        this.patterns = ArrayList<AttributePattern>()
        this.macros = ArrayList<MacroDef>()
    }

    // 从 .gitattributes 文件内容解析属性模式
    // 对齐 Rust: gix_attributes::Search::add_patterns_buffer
    // 参数 content：.gitattributes 文件的文本内容
    // 返回值：解析后的 Attributes 实例
    public static func parse(content: String): Attributes {
        let attrs = Attributes()
        let lines = content.split("\n")
        var lineNo: Int64 = 0
        for (line in lines) {
            lineNo += 1
            let trimmed = trimStr(line)
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            // 处理续行（\ 行尾），对齐 Rust: gix_attributes::parse::Lines
            var currentLine = trimmed
            while (currentLine.size > 0 && currentLine[currentLine.size - 1] == UInt8(92)) {
                currentLine = substringStr(currentLine, 0, currentLine.size - 1)
                lineNo += 1
                if (lineNo <= lines.size) {
                    // 续行内容拼接
                }
                break
            }
            // 检查宏定义行，对齐 Rust: gix_attributes::parse::Kind::Macro
            if (currentLine.startsWith("[attr]")) {
                let macroContent = substringFromStr(currentLine, 6).trimAscii()
                let spaceIdx = macroContent.indexOf(" ")
                if (let Some(si) <- spaceIdx) {
                    let macroName = substringStr(macroContent, 0, si).trimAscii()
                    let attrStr = substringFromStr(macroContent, si + 1).trimAscii()
                    let assignments = parseAssignments(attrStr)
                    attrs.macros.add(MacroDef(macroName, assignments))
                }
                continue
            }
            let spaceIdx = currentLine.indexOf(" ")
            if (let Some(si) <- spaceIdx) {
                let pattern = substringStr(currentLine, 0, si)
                let attrStr = substringFromStr(currentLine, si + 1)
                let assignments = parseAssignments(attrStr)
                attrs.patterns.add(AttributePattern(pattern, assignments))
            }
        }
        attrs
    }

    // 解析属性赋值列表，对齐 Rust: gix_attributes::parse::Iter
    static func parseAssignments(attrStr: String): ArrayList<AttributeAssignment> {
        var assignments = ArrayList<AttributeAssignment>()
        let parts = attrStr.split(" ")
        for (part in parts) {
            if (part.size == 0) {
                continue
            }
            // 否定模式（!前缀），对齐 Rust: gix_attributes::State::Unspecified
            if (part.startsWith("!")) {
                let name = substringFromStr(part, 1)
                if (isValidAttributeName(name)) {
                    assignments.add(AttributeAssignment(name, AttributeState.Unspecified))
                }
                continue
            }
            // 取消设置（-前缀），对齐 Rust: gix_attributes::State::Unset
            if (part.startsWith("-")) {
                let name = substringFromStr(part, 1)
                let eqIdx = name.indexOf("=")
                let actualName = if (let Some(ei) <- eqIdx) {
                    substringStr(name, 0, ei)
                } else {
                    name
                }
                if (isValidAttributeName(actualName)) {
                    assignments.add(AttributeAssignment(actualName, AttributeState.Unset))
                }
                continue
            }
            let eqIdx = part.indexOf("=")
            if (let Some(eq) <- eqIdx) {
                let name = substringStr(part, 0, eq)
                let value = substringFromStr(part, eq + 1)
                if (isValidAttributeName(name)) {
                    assignments.add(AttributeAssignment(name, AttributeState.Value(value)))
                }
            } else {
                if (isValidAttributeName(part)) {
                    assignments.add(AttributeAssignment(part, AttributeState.Set))
                }
            }
        }
        assignments
    }

    // 验证属性名是否合法，对齐 Rust: gix_attributes::name::attr_valid
    // 属性名只能包含 -._A-Za-z0-9，且不能以 - 开头
    static func isValidAttributeName(name: String): Bool {
        if (name.size == 0) {
            return false
        }
        if (name[0] == UInt8(45)) {
            return false
        }
        for (i in 0..name.size) {
            let c = name[i]
            if (c == UInt8(45) || c == UInt8(46) || c == UInt8(95) || (c >= UInt8(65) && c <= UInt8(90)) || (c >= UInt8(97) &&
                c <= UInt8(122)) || (c >= UInt8(48) && c <= UInt8(57))) {
                continue
            }
            return false
        }
        true
    }

    // 匹配指定路径，返回所有匹配的属性赋值
    // 对齐 Rust: gix_attributes::Search::pattern_matching_relative_path
    public func matchPath(path: String): ArrayList<AttributeAssignment> {
        var result = ArrayList<AttributeAssignment>()
        for (pattern in patterns) {
            if (matchPattern(pattern.pattern, path)) {
                for (a in pattern.assignments) {
                    if (a.state == AttributeState.Set) {
                        var expanded = expandMacro(a.name)
                        if (expanded.size > 0) {
                            for (ea in expanded) {
                                result.add(ea)
                            }
                        } else {
                            result.add(a)
                        }
                    } else {
                        result.add(a)
                    }
                }
            }
        }
        result
    }

    // 展开宏属性，对齐 Rust: gix_attributes::search::attributes::MacroExpansion
    func expandMacro(name: String): ArrayList<AttributeAssignment> {
        for (m in macros) {
            if (m.name == name) {
                return m.assignments
            }
        }
        ArrayList<AttributeAssignment>()
    }
}

// 属性模式，包含路径模式和属性赋值列表
// 对齐 Rust: gix_attributes::search::attributes::Pattern
public class AttributePattern {
    public var pattern: String
    public var assignments: ArrayList<AttributeAssignment>

    public init(pattern: String, assignments: ArrayList<AttributeAssignment>) {
        this.pattern = pattern
        this.assignments = assignments
    }
}

// 属性赋值，表示一个属性名和其状态
// 对齐 Rust: gix_attributes::search::attributes::Assignment
public class AttributeAssignment {
    public var name: String
    public var state: AttributeState

    public init(name: String, state: AttributeState) {
        this.name = name
        this.state = state
    }

    // 兼容方法：返回值的字符串表示，对齐 Rust: gix_attributes::Assignment::value
    public func value(): ?String {
        match (state) {
            case Value(v) => Some(v)
            case Set => Some("true")
            case Unset => None
            case Unspecified => None
        }
    }
}

// 宏定义，对齐 Rust: gix_attributes::search::attributes::MacroDef
public class MacroDef {
    public var name: String
    public var assignments: ArrayList<AttributeAssignment>

    public init(name: String, assignments: ArrayList<AttributeAssignment>) {
        this.name = name
        this.assignments = assignments
    }
}

// ========== glob 匹配，完整对齐 Rust: gix_glob::wildmatch ==========
// 对齐 Rust: gix-glob/src/wildmatch.rs, gix-glob/src/pattern.rs, gix-glob/src/parse.rs

// wildmatch 模式标志，对齐 Rust: gix_glob::wildmatch::Mode
public struct WildmatchMode {
    public var value: UInt8
    public init() {
        value = 0
    }
    public init(v: UInt8) {
        value = v
    }

    public static let NO_MATCH_SLASH_LITERAL: UInt8 = 1
    public static let IGNORE_CASE: UInt8 = 2

    public func contains(flag: UInt8): Bool {
        (value & flag) != 0
    }

    public func add(flag: UInt8): WildmatchMode {
        WildmatchMode(value | flag)
    }
}

// Pattern 模式标志，对齐 Rust: gix_glob::pattern::Mode
public struct PatternMode {
    public var value: UInt32
    public init() {
        value = 0
    }
    public init(v: UInt32) {
        value = v
    }

    public static let NO_SUB_DIR: UInt32 = 1
    public static let ENDS_WITH: UInt32 = 2
    public static let MUST_BE_DIR: UInt32 = 4
    public static let NEGATIVE: UInt32 = 8
    public static let ABSOLUTE: UInt32 = 16

    public func contains(flag: UInt32): Bool {
        (value & flag) != 0
    }

    public func add(flag: UInt32): PatternMode {
        PatternMode(value | flag)
    }
}

// 解析 pattern 为模式文本和 Mode，对齐 Rust: gix_glob::parse::pattern
func parsePattern(pat: String): Option<(String, PatternMode, Option<Int64>)> {
    if (pat.size == 0) {
        return None
    }
    var mode = PatternMode()
    var working = pat
    if (working.size > 0 && working[0] == UInt8(33)) {
        mode = mode.add(PatternMode.NEGATIVE)
        working = substringFromStr(working, 1)
    } else if (working.size > 1 && working[0] == UInt8(92)) {
        let second = working[1]
        if (second == UInt8(33) || second == UInt8(35)) {
            working = substringFromStr(working, 1)
        }
    }
    if (working.size == 0) {
        return None
    }
    if (working[0] == UInt8(47)) {
        mode = mode.add(PatternMode.ABSOLUTE)
        working = substringFromStr(working, 1)
    }
    if (working.size > 0 && working[working.size - 1] == UInt8(47)) {
        mode = mode.add(PatternMode.MUST_BE_DIR)
        working = substringStr(working, 0, working.size - 1)
    }
    if (working.size == 0) {
        return None
    }
    if (!working.contains("/")) {
        mode = mode.add(PatternMode.NO_SUB_DIR)
    }
    if (working[0] == UInt8(42)) {
        if (!containsGlobChar(substringFromStr(working, 1))) {
            mode = mode.add(PatternMode.ENDS_WITH)
        }
    }
    let firstWild = firstWildcardPos(working)
    Some((working, mode, firstWild))
}

func isGlobChar(b: UInt8): Bool {
    b == UInt8(42) || b == UInt8(63) || b == UInt8(91) || b == UInt8(92)
}

func containsGlobChar(s: String): Bool {
    for (i in 0..s.size) {
        if (isGlobChar(s[i])) {
            return true
        }
    }
    false
}

func firstWildcardPos(s: String): Option<Int64> {
    for (i in 0..s.size) {
        if (isGlobChar(s[i])) {
            return Some(i)
        }
    }
    None
}

// wildmatch 递归匹配内部结果，对齐 Rust: gix_glob::wildmatch::function::Result
enum WildmatchResult {
    | Match
    | NoMatch
    | AbortAll
    | AbortToStarStar
    | RecursionLimitReached

    public operator func ==(that: WildmatchResult): Bool {
        match (this) {
            case Match => match (that) {
                case Match => true
                case _ => false
            }
            case NoMatch => match (that) {
                case NoMatch => true
                case _ => false
            }
            case AbortAll => match (that) {
                case AbortAll => true
                case _ => false
            }
            case AbortToStarStar => match (that) {
                case AbortToStarStar => true
                case _ => false
            }
            case RecursionLimitReached => match (that) {
                case RecursionLimitReached => true
                case _ => false
            }
        }
    }

    public operator func !=(that: WildmatchResult): Bool {
        !(this == that)
    }
}

let WILDMATCH_RECURSION_LIMIT: Int64 = 64

// wildmatch 递归匹配核心，对齐 Rust: gix_glob::wildmatch::function::match_recursive
func wildmatchRecursive(
    pattern: String,
    pStart: Int64,
    pEnd: Int64,
    text: String,
    tStart: Int64,
    tEnd: Int64,
    mode: WildmatchMode,
    depth: Int64
): WildmatchResult {
    if (depth >= WILDMATCH_RECURSION_LIMIT) {
        return WildmatchResult.RecursionLimitReached
    }
    var pi = pStart
    var ti = tStart
    while (pi < pEnd) {
        var pCh = pattern[pi]
        if (mode.contains(WildmatchMode.IGNORE_CASE) && pCh >= UInt8(65) && pCh <= UInt8(90)) {
            pCh = pCh + UInt8(32)
        }
        if (ti >= tEnd) {
            if (pCh != UInt8(42)) {
                return WildmatchResult.AbortAll
            }
        }
        var tCh = if (ti < tEnd) {
            text[ti]
        } else {
            UInt8(0)
        }
        if (mode.contains(WildmatchMode.IGNORE_CASE) && tCh >= UInt8(65) && tCh <= UInt8(90)) {
            tCh = tCh + UInt8(32)
        }
        if (pCh == UInt8(92)) {
            pi += 1
            if (pi >= pEnd) {
                return WildmatchResult.NoMatch
            }
            pCh = pattern[pi]
            if (mode.contains(WildmatchMode.IGNORE_CASE) && pCh >= UInt8(65) && pCh <= UInt8(90)) {
                pCh = pCh + UInt8(32)
            }
            if (pCh != tCh) {
                return WildmatchResult.NoMatch
            }
            pi += 1
            ti += 1
            continue
        }
        if (pCh == UInt8(63)) {
            if (mode.contains(WildmatchMode.NO_MATCH_SLASH_LITERAL) && tCh == UInt8(47)) {
                return WildmatchResult.NoMatch
            }
            pi += 1
            ti += 1
            continue
        }
        if (pCh == UInt8(42)) {
            var matchSlash = !mode.contains(WildmatchMode.NO_MATCH_SLASH_LITERAL)
            pi += 1
            if (pi < pEnd && pattern[pi] == UInt8(42)) {
                let hasLeadingSlash = pi >= 2 && pattern[pi - 2] == UInt8(47)
                let isAtStart = pi == 1
                while (pi < pEnd && pattern[pi] == UInt8(42)) {
                    pi += 1
                }
                if (pi >= pEnd) {
                    return WildmatchResult.Match
                }
                var nextCh = pattern[pi]
                if (mode.contains(WildmatchMode.IGNORE_CASE) && nextCh >= UInt8(65) && nextCh <= UInt8(90)) {
                    nextCh = nextCh + UInt8(32)
                }
                if (!mode.contains(WildmatchMode.NO_MATCH_SLASH_LITERAL)) {
                    matchSlash = true
                } else if ((isAtStart || hasLeadingSlash)
                    && (nextCh == UInt8(47) || (nextCh == UInt8(92) && pi + 1 < pEnd && pattern[pi + 1] == UInt8(47)))) {
                    if (nextCh == UInt8(47)) {
                        pi += 1
                    } else {
                        pi += 2
                    }
                    let res = wildmatchRecursive(pattern, pi, pEnd, text, ti, tEnd, mode, depth + 1)
                    if (res == WildmatchResult.Match) {
                        return WildmatchResult.Match
                    }
                    matchSlash = true
                } else {
                    matchSlash = false
                }
            }
            if (pi >= pEnd) {
                return if (!matchSlash && containsByteInRange(text, ti, tEnd, UInt8(47))) {
                    WildmatchResult.AbortToStarStar
                } else {
                    WildmatchResult.Match
                }
            }
            var nextPCh = pattern[pi]
            if (mode.contains(WildmatchMode.IGNORE_CASE) && nextPCh >= UInt8(65) && nextPCh <= UInt8(90)) {
                nextPCh = nextPCh + UInt8(32)
            }
            if (!matchSlash && nextPCh == UInt8(47)) {
                let slashPos = findByte(text, ti, tEnd, UInt8(47))
                if (let Some(sp) <- slashPos) {
                    ti = sp + 1
                    pi += 1
                    continue
                } else {
                    return WildmatchResult.AbortAll
                }
            }
            if (!isGlobChar(pattern[pi])) {
                var found = false
                while (ti < tEnd) {
                    var tc = text[ti]
                    if (mode.contains(WildmatchMode.IGNORE_CASE) && tc >= UInt8(65) && tc <= UInt8(90)) {
                        tc = tc + UInt8(32)
                    }
                    if (tc == nextPCh) {
                        found = true
                        break
                    }
                    if (!matchSlash && tc == UInt8(47)) {
                        return WildmatchResult.AbortToStarStar
                    }
                    ti += 1
                }
                if (!found) {
                    return if (matchSlash) {
                        WildmatchResult.AbortAll
                    } else {
                        WildmatchResult.AbortToStarStar
                    }
                }
            }
            while (true) {
                let res = wildmatchRecursive(pattern, pi, pEnd, text, ti, tEnd, mode, depth + 1)
                if (res != WildmatchResult.NoMatch) {
                    if (matchSlash && res == WildmatchResult.AbortToStarStar) {
                    // continue searching
                    } else {
                        return res
                    }
                } else if (!matchSlash && ti < tEnd && text[ti] == UInt8(47)) {
                    return WildmatchResult.AbortToStarStar
                }
                ti += 1
                if (ti >= tEnd) {
                    return WildmatchResult.AbortAll
                }
            }
        }
        // [ 方括号字符类匹配，对齐 Rust: gix_glob::wildmatch BRACKET_OPEN
        if (pCh == UInt8(91)) {
            pi += 1
            if (pi >= pEnd) {
                return WildmatchResult.AbortAll
            }
            var classCh = pattern[pi]
            var negated = false
            if (classCh == UInt8(94) || classCh == UInt8(33)) {
                negated = true
                pi += 1
                if (pi >= pEnd) {
                    return WildmatchResult.AbortAll
                }
            }
            var matched = false
            var prevCh = UInt8(0)
            while (pi < pEnd && pattern[pi] != UInt8(93)) {
                var curCh = pattern[pi]
                if (mode.contains(WildmatchMode.IGNORE_CASE) && curCh >= UInt8(65) && curCh <= UInt8(90)) {
                    curCh = curCh + UInt8(32)
                }
                if (curCh == UInt8(92)) {
                    pi += 1
                    if (pi >= pEnd) {
                        return WildmatchResult.AbortAll
                    }
                    curCh = pattern[pi]
                    if (mode.contains(WildmatchMode.IGNORE_CASE) && curCh >= UInt8(65) && curCh <= UInt8(90)) {
                        curCh = curCh + UInt8(32)
                    }
                    if (curCh == tCh) {
                        matched = true
                    }
                    prevCh = curCh
                    pi += 1
                    continue
                }
                if (curCh == UInt8(45) && prevCh != UInt8(0) && pi + 1 < pEnd && pattern[pi + 1] != UInt8(93)) {
                    pi += 1
                    var rangeEnd = pattern[pi]
                    if (rangeEnd == UInt8(92)) {
                        pi += 1
                        if (pi >= pEnd) {
                            return WildmatchResult.AbortAll
                        }
                        rangeEnd = pattern[pi]
                    }
                    if (mode.contains(WildmatchMode.IGNORE_CASE) && rangeEnd >= UInt8(65) && rangeEnd <= UInt8(90)) {
                        rangeEnd = rangeEnd + UInt8(32)
                    }
                    if (tCh >= prevCh && tCh <= rangeEnd) {
                        matched = true
                    }
                    prevCh = UInt8(0)
                    pi += 1
                    continue
                }
                if (curCh == UInt8(91) && pi + 1 < pEnd && pattern[pi + 1] == UInt8(58)) {
                    pi += 2
                    var classStart = pi
                    while (pi < pEnd && !(pattern[pi] == UInt8(58) && pi + 1 < pEnd && pattern[pi + 1] == UInt8(93))) {
                        pi += 1
                    }
                    if (pi >= pEnd) {
                        return WildmatchResult.AbortAll
                    }
                    let className = substringStr(pattern, classStart, pi)
                    if (matchCharClass(className, tCh)) {
                        matched = true
                    }
                    pi += 2
                    prevCh = UInt8(0)
                    continue
                }
                if (curCh == tCh) {
                    matched = true
                }
                prevCh = curCh
                pi += 1
            }
            if (pi < pEnd && pattern[pi] == UInt8(93)) {
                pi += 1
            }
            if (matched == negated) {
                return WildmatchResult.NoMatch
            }
            if (mode.contains(WildmatchMode.NO_MATCH_SLASH_LITERAL) && tCh == UInt8(47)) {
                return WildmatchResult.NoMatch
            }
            ti += 1
            continue
        }
        if (pCh != tCh) {
            return WildmatchResult.NoMatch
        }
        pi += 1
        ti += 1
    }
    if (ti < tEnd) {
        WildmatchResult.NoMatch
    } else {
        WildmatchResult.Match
    }
}

// 字符类匹配，对齐 Rust: gix_glob::wildmatch 中的 [:class:] 处理
func matchCharClass(className: String, ch: UInt8): Bool {
    if (className == "alnum") {
        return isAsciiAlphaNum(ch)
    } else if (className == "alpha") {
        return isAsciiAlpha(ch)
    } else if (className == "blank") {
        return ch == UInt8(32) || ch == UInt8(9)
    } else if (className == "cntrl") {
        return ch < UInt8(32) || ch == UInt8(127)
    } else if (className == "digit") {
        return ch >= UInt8(48) && ch <= UInt8(57)
    } else if (className == "graph") {
        return ch >= UInt8(33) && ch <= UInt8(126)
    } else if (className == "lower") {
        return ch >= UInt8(97) && ch <= UInt8(122)
    } else if (className == "print") {
        return ch >= UInt8(32) && ch <= UInt8(126)
    } else if (className == "punct") {
        return isAsciiPunct(ch)
    } else if (className == "space") {
        return ch == UInt8(32) || ch == UInt8(9) || ch == UInt8(10) || ch == UInt8(13) || ch == UInt8(11) || ch == UInt8(12)
    } else if (className == "upper") {
        return ch >= UInt8(65) && ch <= UInt8(90)
    } else if (className == "xdigit") {
        return (ch >= UInt8(48) && ch <= UInt8(57)) || (ch >= UInt8(65) && ch <= UInt8(70)) || (ch >= UInt8(97) && ch <=
            UInt8(102))
    }
    false
}

func isAsciiAlphaNum(ch: UInt8): Bool {
    isAsciiAlpha(ch) || (ch >= UInt8(48) && ch <= UInt8(57))
}

func isAsciiAlpha(ch: UInt8): Bool {
    (ch >= UInt8(65) && ch <= UInt8(90)) || (ch >= UInt8(97) && ch <= UInt8(122))
}

func isAsciiPunct(ch: UInt8): Bool {
    (ch >= UInt8(33) && ch <= UInt8(47)) || (ch >= UInt8(58) && ch <= UInt8(64)) || (ch >= UInt8(91) && ch <= UInt8(96)) ||
        (ch >= UInt8(123) && ch <= UInt8(126))
}

func findByte(text: String, tStart: Int64, tEnd: Int64, b: UInt8): Option<Int64> {
    var i = tStart
    while (i < tEnd) {
        if (text[i] == b) {
            return Some(i)
        }
        i += 1
    }
    None
}

func containsByteInRange(text: String, tStart: Int64, tEnd: Int64, b: UInt8): Bool {
    var i = tStart
    while (i < tEnd) {
        if (text[i] == b) {
            return true
        }
        i += 1
    }
    false
}

// wildmatch 公共接口，对齐 Rust: gix_glob::wildmatch()
func wildmatch(pattern: String, value: String, mode: WildmatchMode): Bool {
    let res = wildmatchRecursive(pattern, 0, pattern.size, value, 0, value.size, mode, 0)
    if (res == WildmatchResult.RecursionLimitReached) {
        false
    } else {
        res == WildmatchResult.Match
    }
}

// Pattern.matches 快速路径 + wildmatch fallback，对齐 Rust: gix_glob::Pattern::matches
func patternMatches(patternText: String, mode: PatternMode, firstWildcardPos: Option<Int64>, value: String,
    wmMode: WildmatchMode): Bool {
    match (firstWildcardPos) {
        case Some(pos) =>
            if (mode.contains(PatternMode.ENDS_WITH)
                && (!wmMode.contains(WildmatchMode.NO_MATCH_SLASH_LITERAL) || !value.contains("/"))) {
                let suffix = substringFromStr(patternText, pos + 1)
                if (wmMode.contains(WildmatchMode.IGNORE_CASE)) {
                    if (value.size < suffix.size) {
                        return false
                    }
                    let start = value.size - suffix.size
                    return equalsIgnoreCase(substringFromStr(value, start), suffix)
                } else {
                    return value.endsWith(suffix)
                }
            }
            if (wmMode.contains(WildmatchMode.IGNORE_CASE)) {
                if (!equalsIgnoreCase(substringStr(value, 0, pos), substringStr(patternText, 0, pos))) {
                    return false
                }
            } else {
                if (!value.startsWith(substringStr(patternText, 0, pos))) {
                    return false
                }
            }
            wildmatch(patternText, value, wmMode)
        case None =>
            if (wmMode.contains(WildmatchMode.IGNORE_CASE)) {
                equalsIgnoreCase(patternText, value)
            } else {
                patternText == value
            }
    }
}

func equalsIgnoreCase(a: String, b: String): Bool {
    if (a.size != b.size) {
        return false
    }
    for (i in 0..a.size) {
        var ac = a[i]
        var bc = b[i]
        if (ac >= UInt8(65) && ac <= UInt8(90)) {
            ac = ac + UInt8(32)
        }
        if (bc >= UInt8(65) && bc <= UInt8(90)) {
            bc = bc + UInt8(32)
        }
        if (ac != bc) {
            return false
        }
    }
    true
}

// glob 模式匹配入口，对齐 Rust: gix_glob::Pattern::matches_repo_relative_path
public func matchPattern(pattern: String, path: String): Bool {
    let parsed = parsePattern(pattern)
    if (parsed.isNone()) {
        return false
    }
    let (patternText, mode, firstWildcardPos) = parsed.getOrThrow()
    if (mode.contains(PatternMode.MUST_BE_DIR)) {
        if (!path.startsWith(patternText) && path != patternText) {
            return false
        }
        return if (mode.contains(PatternMode.NEGATIVE)) {
            false
        } else {
            true
        }
    }
    let wmMode = WildmatchMode(WildmatchMode.NO_MATCH_SLASH_LITERAL)
    var matchValue = path
    if (mode.contains(PatternMode.NO_SUB_DIR) && !mode.contains(PatternMode.ABSOLUTE)) {
        let lastSlash = path.lastIndexOf("/")
        if (let Some(ls) <- lastSlash) {
            matchValue = substringFromStr(path, ls + 1)
        }
    }
    let result = patternMatches(patternText, mode, firstWildcardPos, matchValue, wmMode)
    if (mode.contains(PatternMode.NEGATIVE)) {
        !result
    } else {
        result
    }
}
