// 文件：lib.cj
// 用途：提供 Git pathspec 解析与路径匹配功能
// 所属包：gix.gix_pathspec
// 关键类型：Pattern, MagicSignature, SearchMode, Defaults, PathspecParseError, Pathspec, PathspecPattern
// 对齐来源：gix-pathspec/src/lib.rs, parse.rs, pattern.rs, defaults.rs

package gitoxide.gix_pathspec

import std.collection.*
import gitoxide.gix_utils.*

// ============================================================
// MagicSignature — 魔法签名枚举
// 对齐 Rust: gix_pathspec::MagicSignature (bitflags)
// ============================================================

public enum MagicSignature {
    | TOP
    | ICASE
    | EXCLUDE
    | MUST_BE_DIR
}

extend MagicSignature <: Hashable {
    public func hashCode(): Int64 {
        match (this) {
            case MagicSignature.TOP => 0
            case MagicSignature.ICASE => 1
            case MagicSignature.EXCLUDE => 2
            case MagicSignature.MUST_BE_DIR => 3
        }
    }
}

extend MagicSignature <: Equatable<MagicSignature> {
    public operator func ==(other: MagicSignature): Bool {
        match (this) {
            case MagicSignature.TOP => match (other) {
                case MagicSignature.TOP => true;
                case _ => false
            }
            case MagicSignature.ICASE => match (other) {
                case MagicSignature.ICASE => true;
                case _ => false
            }
            case MagicSignature.EXCLUDE => match (other) {
                case MagicSignature.EXCLUDE => true;
                case _ => false
            }
            case MagicSignature.MUST_BE_DIR => match (other) {
                case MagicSignature.MUST_BE_DIR => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: MagicSignature): Bool {
        !(this == other)
    }
}

// 魔法签名集合，模拟 Rust bitflags 行为
public class MagicSignatureSet {
    var flags: HashSet<MagicSignature>

    public init() {
        flags = HashSet<MagicSignature>()
    }

    public init(sig: MagicSignature) {
        flags = HashSet<MagicSignature>()
        flags.add(sig)
    }

    public init(sigs: ArrayList<MagicSignature>) {
        flags = HashSet<MagicSignature>()
        for (s in sigs) {
            flags.add(s)
        }
    }

    public func contains(sig: MagicSignature): Bool {
        flags.contains(sig)
    }

    public func add(sig: MagicSignature): Unit {
        flags.add(sig)
    }

    public func addAll(other: MagicSignatureSet): Unit {
        for (s in other.flags) {
            flags.add(s)
        }
    }

    public func isEmpty(): Bool {
        flags.isEmpty()
    }

    public func size(): Int64 {
        flags.size
    }

    public func toList(): ArrayList<MagicSignature> {
        let list = ArrayList<MagicSignature>()
        for (s in flags) {
            list.add(s)
        }
        list
    }

    public func equals(other: MagicSignatureSet): Bool {
        if (flags.size != other.flags.size) {
            return false
        }
        for (s in flags) {
            if (!other.flags.contains(s)) {
                return false
            }
        }
        true
    }
}

// ============================================================
// SearchMode — 搜索模式
// 对齐 Rust: gix_pathspec::SearchMode
// ============================================================

public enum SearchMode {
    | ShellGlob
    | Literal
    | PathAwareGlob
}

extend SearchMode <: Equatable<SearchMode> {
    public operator func ==(other: SearchMode): Bool {
        match (this) {
            case SearchMode.ShellGlob => match (other) {
                case SearchMode.ShellGlob => true;
                case _ => false
            }
            case SearchMode.Literal => match (other) {
                case SearchMode.Literal => true;
                case _ => false
            }
            case SearchMode.PathAwareGlob => match (other) {
                case SearchMode.PathAwareGlob => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: SearchMode): Bool {
        !(this == other)
    }
}

// ============================================================
// Defaults — 默认设置
// 对齐 Rust: gix_pathspec::Defaults
// ============================================================

public class Defaults {
    public var signature: MagicSignatureSet
    public var searchMode: SearchMode
    public var literal: Bool

    public init() {
        signature = MagicSignatureSet()
        searchMode = SearchMode.ShellGlob
        literal = false
    }

    public init(signature: MagicSignatureSet, searchMode: SearchMode, literal: Bool) {
        this.signature = signature
        this.searchMode = searchMode
        this.literal = literal
    }
}

// ============================================================
// PathspecParseError — 解析错误类型
// 对齐 Rust: gix_pathspec::parse::Error
// ============================================================

public enum PathspecParseError {
    | EmptyString
    | InvalidKeyword(String)
    | Unimplemented(String)
    | MissingClosingParenthesis
    | InvalidAttribute(String)
    | InvalidAttributeValue(String)
    | TrailingEscapeCharacter
    | EmptyAttribute
    | MultipleAttributeSpecifications
    | IncompatibleSearchModes
}

// 解析游标辅助类
class ParseCursor {
    var pos: Int64

    init() {
        pos = 0
    }

    init(p: Int64) {
        pos = p
    }
}

// ============================================================
// Pattern — pathspec 模式
// 属性规格，对齐 Rust: gix_pathspec::parse::signature::attribute::AttributeSpec
// 表示 attr: 后面的单个属性条件，如 "someAttr"、"!someAttr"、"someAttr=value"
public class AttributeSpec {
    // 属性名
    public var name: String
    // 属性状态：Set（存在）、Unset（!attr，不存在）、Value（attr=value）
    public var state: AttributeState
    // 当 state == Value 时的值
    public var value: String

    public init(name: String, state: AttributeState, value: String) {
        this.name = name
        this.state = state
        this.value = value
    }
}

// 属性状态，对齐 Rust: gix_pathspec::parse::signature::attribute::State
public enum AttributeState {
    | Set
    | Unset
    | Value
}

// 对齐 Rust: gix_pathspec::Pattern
// ============================================================

public class Pattern {
    // 路径部分
    public var path: String
    // 魔法签名
    public var signature: MagicSignatureSet
    // 搜索模式
    public var searchMode: SearchMode
    // 是否为 nil 模式（":" 解析结果，匹配所有）
    public var nilPattern: Bool
    // 前缀长度（normalize 后设置）
    public var prefixLen: Int64
    // 属性规格列表，对齐 Rust: gix_pathspec::Pattern::attributes
    // 仓颉差异：Rust 用 BString，仓颉用 String
    public var attributes: ArrayList<AttributeSpec>

    public init() {
        path = ""
        signature = MagicSignatureSet()
        searchMode = SearchMode.ShellGlob
        nilPattern = false
        prefixLen = 0
        attributes = ArrayList<AttributeSpec>()
    }

    public init(path: String, signature: MagicSignatureSet, searchMode: SearchMode, nilPattern: Bool) {
        this.path = path
        this.signature = signature
        this.searchMode = searchMode
        this.nilPattern = nilPattern
        this.prefixLen = 0
        attributes = ArrayList<AttributeSpec>()
    }

    // 是否为 nil 模式
    // 对齐 Rust: Pattern::is_nil()
    public func isNil(): Bool {
        nilPattern
    }

    // 是否为排除模式
    // 对齐 Rust: Pattern::is_excluded()
    public func isExcluded(): Bool {
        signature.contains(MagicSignature.EXCLUDE)
    }

    // 是否总是匹配（nil 或空路径）
    // 对齐 Rust: Pattern::always_matches()
    public func alwaysMatches(): Bool {
        isNil() || path.size == 0
    }

    // 前缀目录
    // 对齐 Rust: Pattern::prefix_directory()
    public func prefixDirectory(): String {
        if (prefixLen <= 0) {
            return ""
        }
        if (prefixLen > path.size) {
            return path
        }
        path[0..prefixLen]
    }

    // 转为长格式字符串
    // 对齐 Rust: Pattern::to_bstring()
    public func toBString(): String {
        if (isNil()) {
            return ":"
        }
        var buf = ":("
        if (signature.contains(MagicSignature.TOP)) {
            buf += "top,"
        }
        if (signature.contains(MagicSignature.EXCLUDE)) {
            buf += "exclude,"
        }
        if (signature.contains(MagicSignature.ICASE)) {
            buf += "icase,"
        }
        match (searchMode) {
            case SearchMode.ShellGlob => ()
            case SearchMode.Literal => buf += "literal,"
            case SearchMode.PathAwareGlob => buf += "glob,"
        }
        if (buf.endsWith(",")) {
            buf = buf[0..buf.size - 1]
        }
        buf += ")"
        buf += path
        if (signature.contains(MagicSignature.MUST_BE_DIR)) {
            buf += "/"
        }
        buf
    }
}

// ============================================================
// 解析函数
// 对齐 Rust: gix_pathspec::parse() / Pattern::from_bytes()
// ============================================================

// 解析 git 风格 pathspec 为 Pattern
// 返回 Some(Pattern) 解析成功，None 解析失败
// 对齐 Rust: gix_pathspec::parse(input, defaults)
public func parsePathspec(input: String, defaults: Defaults): ?Pattern {
    if (input.size == 0) {
        return None
    }
    if (defaults.literal) {
        return Some(fromLiteral(input, defaults.signature))
    }
    // ":" 单独出现为 nil 模式
    if (input == ":") {
        let p = Pattern()
        p.nilPattern = true
        return Some(p)
    }

    let p = Pattern()
    p.signature = MagicSignatureSet()
    p.searchMode = SearchMode.ShellGlob

    let cursor = ParseCursor()
    if (input[0] == UInt8(58)) {
        cursor.pos = 1
        // 解析短关键字
        let sig = parseShortKeywords(input, cursor)
        p.signature.addAll(sig)
        // 解析长关键字
        if (cursor.pos < input.size && input[cursor.pos] == UInt8(40)) {
            cursor.pos += 1
            let closeIdx = input.indexOf(")", cursor.pos)
            if (let Some(ci) <- closeIdx) {
                let err = parseLongKeywords(input, cursor.pos, ci, p)
                if (let Some(_) <- err) {
                    return None
                }
                cursor.pos = ci + 1
            } else {
                return None
            }
        }
    }

    // 应用默认搜索模式（仅在 Pattern 未指定时）
    if (defaults.searchMode != SearchMode.ShellGlob && p.searchMode == SearchMode.ShellGlob) {
        p.searchMode = defaults.searchMode
    }
    // 应用默认签名
    if (!defaults.signature.isEmpty()) {
        p.signature.addAll(defaults.signature)
    }

    // 提取路径部分
    var pathStr = input[cursor.pos..]
    // 尾部斜杠 → MUST_BE_DIR
    if (pathStr.size > 0 && pathStr[pathStr.size - 1] == UInt8(47)) {
        p.signature.add(MagicSignature.MUST_BE_DIR)
        pathStr = pathStr[0..pathStr.size - 1]
    }
    p.path = pathStr
    Some(p)
}

// 从字面量构造 Pattern
// 对齐 Rust: Pattern::from_literal()
public func fromLiteral(input: String, defaultSignature: MagicSignatureSet): Pattern {
    Pattern(input, defaultSignature, SearchMode.Literal, false)
}

// 解析短关键字（:/, :^, :! 等）
// 对齐 Rust: parse_short_keywords()
func parseShortKeywords(input: String, cursor: ParseCursor): MagicSignatureSet {
    let sig = MagicSignatureSet()
    while (cursor.pos < input.size) {
        let ch = input[cursor.pos]
        if (ch == UInt8(47)) {
            sig.add(MagicSignature.TOP)
            cursor.pos++
        } else if (ch == UInt8(94) || ch == UInt8(33)) {
            sig.add(MagicSignature.EXCLUDE)
            cursor.pos++
        } else if (ch == UInt8(58)) {
            cursor.pos++
            break
        } else {
            break
        }
    }
    sig
}

// 解析长关键字（:(top,icase,literal,...)）
// 对齐 Rust: parse_long_keywords()
// 返回 None 表示成功，Some(String) 表示错误关键字
func parseLongKeywords(input: String, start: Int64, end: Int64, p: Pattern): ?String {
    let content = input[start..end]
    let keywords = content.split(",")

    for (kw in keywords) {
        let trimmed = kw.trimAscii()
        if (trimmed.size == 0) {
            continue
        }
        if (trimmed == "top") {
            p.signature.add(MagicSignature.TOP)
        } else if (trimmed == "icase") {
            p.signature.add(MagicSignature.ICASE)
        } else if (trimmed == "exclude") {
            p.signature.add(MagicSignature.EXCLUDE)
        } else if (trimmed == "literal") {
            if (p.searchMode == SearchMode.PathAwareGlob) {
                return Some("IncompatibleSearchModes")
            }
            p.searchMode = SearchMode.Literal
        } else if (trimmed == "glob") {
            if (p.searchMode == SearchMode.Literal) {
                return Some("IncompatibleSearchModes")
            }
            p.searchMode = SearchMode.PathAwareGlob
        } else if (trimmed == "attr") {
        // 空属性声明
        } else if (trimmed.startsWith("attr:")) {
        // 属性解析，对齐 Rust: gix_pathspec::parse::signature::attribute
        let attrStr = substringFromStr(trimmed, 5)
        let parsedAttrs = parseAttributes(attrStr)
        if (parsedAttrs.isSome()) {
            p.attributes = parsedAttrs.getOrThrow()
        }
        } else {
            return Some(trimmed)
        }
    }
    None
}

// 解析属性字符串，对齐 Rust: gix_pathspec::parse::signature::attribute::parse_attributes
// 格式：空格分隔的属性，如 "someAttr !otherAttr key=value"
// 返回值：解析成功返回属性列表，格式错误返回 None
func parseAttributes(input: String): ?ArrayList<AttributeSpec> {
    let result = ArrayList<AttributeSpec>()
    let parts = input.split(" ")
    for (part in parts) {
        if (part.size == 0) {
            continue
        }
        if (part[0] == UInt8(0x21)) {
            // !attr → Unset
            let name = substringFromStr(part, 1)
            if (name.size == 0) {
                return None
            }
            result.add(AttributeSpec(name, AttributeState.Unset, ""))
        } else if (part.contains("=")) {
            // attr=value → Value
            let eqIdx = part.indexOf("=")
            if (eqIdx.isNone() || eqIdx.getOrThrow() == 0 || eqIdx.getOrThrow() >= part.size - 1) {
                return None
            }
            let name = substringStr(part, 0, eqIdx.getOrThrow())
            let val = substringFromStr(part, eqIdx.getOrThrow() + 1)
            result.add(AttributeSpec(name, AttributeState.Value, val))
        } else {
            // attr → Set
            result.add(AttributeSpec(part, AttributeState.Set, ""))
        }
    }
    if (result.size == 0) {
        return None
    }
    Some(result)
}

// ============================================================
// Pathspec — 旧版兼容接口
// ============================================================

public class Pathspec {
    public var patterns: ArrayList<PathspecPattern>

    public init() {
        this.patterns = ArrayList<PathspecPattern>()
    }

    public static func parse(specs: ArrayList<String>): Pathspec {
        let ps = Pathspec()
        for (spec in specs) {
            ps.patterns.add(PathspecPattern(spec))
        }
        ps
    }

    public func matches(path: String): Bool {
        if (patterns.size == 0) {
            return true
        }
        for (pattern in patterns) {
            if (matchPathspecPattern(pattern.pattern, path)) {
                return true
            }
        }
        false
    }
}

func matchPathspecPattern(pattern: String, path: String): Bool {
    if (pattern == ".") {
        return true
    }
    path.startsWith(pattern) || path == pattern
}

public class PathspecPattern {
    public var pattern: String

    public init(pattern: String) {
        this.pattern = pattern
    }
}
