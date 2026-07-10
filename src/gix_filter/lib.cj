// 文件：lib.cj
// 用途：提供 Git filter 机制（smudge/clean），用于工作树和仓库之间的数据转换
// 所属包：gix.gix_filter
// 关键类型：Filter, EolMode, AutoCrlf, EolConfiguration, EolStats, AttributesDigest
// 关键函数：applySmudge, applyClean, identUndo, identApply, eolStatsFromBytes

package gitoxide.gix_filter

import std.collection.*
import std.process.*
import gitoxide.gix_hash.*

// Git 过滤器定义，包含 smudge 和 clean 命令
public class Filter {
    // 过滤器名称
    public var name: String
    // smudge 命令（检出时执行），可选
    public var smudge: ?String
    // clean 命令（入库时执行），可选
    public var clean: ?String
    public var required: Bool

    // 构造函数
    // 参数 name：过滤器名称
    public init(name: String) {
        this.name = name
        this.smudge = None
        this.clean = None
        this.required = false
    }
}

// 对数据应用 smudge 过滤器
// 对齐 Rust: gix_filter::driver::State::apply(Operation::Smudge)
public func applySmudge(filter: Filter, data: Array<Byte>): Array<Byte> {
    if (let Some(cmd) <- filter.smudge) {
        return runFilterCommand(cmd, data)
    }
    data
}

// 对数据应用 clean 过滤器
// 对齐 Rust: gix_filter::driver::State::apply(Operation::Clean)
public func applyClean(filter: Filter, data: Array<Byte>): Array<Byte> {
    if (let Some(cmd) <- filter.clean) {
        return runFilterCommand(cmd, data)
    }
    data
}

// 执行 filter 命令
func runFilterCommand(cmd: String, data: Array<Byte>): Array<Byte> {
    var parts = ArrayList<String>()
    var current = StringBuilder()
    var inQuote = false
    for (ch in cmd) {
        if (ch == 34) {
            inQuote = !inQuote
        } else if (ch == 32 && !inQuote) {
            if (current.size > 0) {
                parts.add(current.toString())
                current = StringBuilder()
            }
        } else {
            current.append(ch)
        }
    }
    if (current.size > 0) {
        parts.add(current.toString())
    }
    if (parts.size == 0) {
        return data
    }
    try {
        var fullCmd = parts[0]
        for (i in 1..parts.size) {
            fullCmd = fullCmd + " " + parts[i]
        }
        var result = executeWithOutput("cmd", ["/c", fullCmd])
        var (_, stdout, _) = result
        if (stdout.size == 0) {
            data
        } else {
            stdout
        }
    } catch (_: Exception) {
        data
    }
}

// ============================================================
// ident 模块 — 对齐 Rust gix_filter::ident
// ============================================================

// 对齐 Rust: gix_filter::ident::undo
public func identUndo(src: Array<Byte>): IdentResult {
    var srcStr = String.fromUtf8(src)
    var result = StringBuilder()
    var ofs: Int64 = 0
    var modified = false
    while (ofs < srcStr.size) {
        var idIdxOpt = srcStr[ofs..].indexOf("$Id:")
        if (idIdxOpt.isNone()) {
            break
        }
        var idIdx = idIdxOpt.getOrThrow()
        var absIdIdx = ofs + idIdx
        var afterId = absIdIdx + 4
        var endDollar: Int64 = -1
        var j = afterId
        while (j < srcStr.size) {
            if (srcStr[j] == 10) {
                break
            }
            if (srcStr[j] == 36) {
                endDollar = j
                break
            }
            j += 1
        }
        if (endDollar < 0) {
            result.append(srcStr[ofs..afterId])
            ofs = afterId
            continue
        }
        modified = true
        result.append(srcStr[ofs..absIdIdx])
        result.append("$Id$")
        ofs = endDollar + 1
    }
    if (modified) {
        result.append(srcStr[ofs..])
        return IdentResult(true, stringToBytes(result.toString()))
    }
    return IdentResult(false, src)
}

// 对齐 Rust: gix_filter::ident::apply
public func identApply(src: Array<Byte>): IdentResult {
    var srcStr = String.fromUtf8(src)
    var result = StringBuilder()
    var ofs = 0
    var modified = false
    var hash = ""
    while (ofs < srcStr.size) {
        var idIdxOpt = srcStr[ofs..].indexOf("$Id$")
        if (idIdxOpt.isNone()) {
            break
        }
        var idIdx = idIdxOpt.getOrThrow()
        var absIdIdx = ofs + idIdx
        if (!modified) {
            hash = filterSha1Hex(src)
            modified = true
        }
        result.append(srcStr[ofs..absIdIdx])
        result.append("$Id: ")
        result.append(hash)
        result.append("$")
        ofs = absIdIdx + 4
    }
    if (modified) {
        result.append(srcStr[ofs..])
    }
    if (modified) {
        return IdentResult(true, stringToBytes(result.toString()))
    }
    return IdentResult(false, src)
}

// ident 操作结果
public class IdentResult {
    public var modified: Bool
    public var data: Array<Byte>
    public init(modified: Bool, data: Array<Byte>) {
        this.modified = modified
        this.data = data
    }
}

// SHA-1 哈希计算（gix_filter 内部使用，使用 GixHasher 真实实现）
func filterSha1Hex(data: Array<Byte>): String {
    let h = GixHasher(HashKind.Sha1)
    h.update(data)
    h.tryFinalize().toHexString()
}

// String → Array<Byte> 辅助函数
func stringToBytes(s: String): Array<Byte> {
    var buf = ArrayList<Byte>()
    for (ch in s) {
        buf.add(ch)
    }
    buf.toArray()
}

// ============================================================
// eol 模块 — 对齐 Rust gix_filter::eol
// ============================================================

public enum EolMode {
    | Lf
    | CrLf

    public operator func ==(that: EolMode): Bool {
        match (this) {
            case Lf => match (that) {
                case Lf => true;
                case _ => false
            }
            case CrLf => match (that) {
                case CrLf => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: EolMode): Bool {
        !(this == that)
    }
}

public enum AutoCrlf {
    | Input
    | Enabled
    | Disabled

    public operator func ==(that: AutoCrlf): Bool {
        match (this) {
            case Input => match (that) {
                case Input => true;
                case _ => false
            }
            case Enabled => match (that) {
                case Enabled => true;
                case _ => false
            }
            case Disabled => match (that) {
                case Disabled => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: AutoCrlf): Bool {
        !(this == that)
    }
}

public enum AttributesDigest {
    | Binary
    | Text
    | TextInput
    | TextCrlf
    | TextAuto
    | TextAutoCrlf
    | TextAutoInput

    public operator func ==(that: AttributesDigest): Bool {
        match (this) {
            case Binary => match (that) {
                case Binary => true;
                case _ => false
            }
            case Text => match (that) {
                case Text => true;
                case _ => false
            }
            case TextInput => match (that) {
                case TextInput => true;
                case _ => false
            }
            case TextCrlf => match (that) {
                case TextCrlf => true;
                case _ => false
            }
            case TextAuto => match (that) {
                case TextAuto => true;
                case _ => false
            }
            case TextAutoCrlf => match (that) {
                case TextAutoCrlf => true;
                case _ => false
            }
            case TextAutoInput => match (that) {
                case TextAutoInput => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: AttributesDigest): Bool {
        !(this == that)
    }
}

public class EolConfiguration {
    public var autoCrlf: AutoCrlf
    public var eol: ?EolMode

    public init() {
        this.autoCrlf = AutoCrlf.Disabled
        this.eol = None
    }
}

public class EolStats {
    public var null: Int64
    public var loneCr: Int64
    public var loneLf: Int64
    public var crlf: Int64
    public var printable: Int64
    public var nonPrintable: Int64

    public init() {
        this.null = 0
        this.loneCr = 0
        this.loneLf = 0
        this.crlf = 0
        this.printable = 0
        this.nonPrintable = 0
    }

    public init(null: Int64, loneCr: Int64, loneLf: Int64, crlf: Int64, printable: Int64, nonPrintable: Int64) {
        this.null = null
        this.loneCr = loneCr
        this.loneLf = loneLf
        this.crlf = crlf
        this.printable = printable
        this.nonPrintable = nonPrintable
    }
}

// 对齐 Rust: gix_filter::eol::Stats::from_bytes
public func eolStatsFromBytes(bytes: Array<Byte>): EolStats {
    var stats = EolStats()
    var i = 0
    while (i < bytes.size) {
        var b = bytes[i]
        if (b == 13) {
            if (i + 1 < bytes.size && bytes[i + 1] == 10) {
                stats.crlf++
                i += 2
                continue
            }
            stats.loneCr++
            i++
            continue
        }
        if (b == 10) {
            stats.loneLf++
            i++
            continue
        }
        if (b == 127) {
            stats.nonPrintable++
        } else if (b < 32) {
            if (b == 8 || b == 9 || b == 27 || b == 12) {
                stats.printable++
            } else if (b == 0) {
                stats.nonPrintable++
                stats.null++
            } else {
                stats.nonPrintable++
            }
        } else {
            stats.printable++
        }
        i++
    }
    return stats
}

// 对齐 Rust: gix_filter::eol::Stats::is_binary
public func eolStatsIsBinary(stats: EolStats): Bool {
    stats.loneCr > 0 || stats.null > 0 || (stats.printable >> 7) < stats.nonPrintable
}

// 对齐 Rust: gix_filter::eol::AttributesDigest::to_eol
public func attributesDigestToEol(digest: AttributesDigest, config: EolConfiguration): ?EolMode {
    match (digest) {
        case AttributesDigest.Binary => None
        case AttributesDigest.TextInput | AttributesDigest.TextAutoInput => Some(EolMode.Lf)
        case AttributesDigest.TextCrlf | AttributesDigest.TextAutoCrlf => Some(EolMode.CrLf)
        case AttributesDigest.Text | AttributesDigest.TextAuto => Some(eolConfigToEol(config))
    }
}

// 对齐 Rust: gix_filter::eol::Configuration::to_eol
public func eolConfigToEol(config: EolConfiguration): EolMode {
    match (config.autoCrlf) {
        case AutoCrlf.Enabled => EolMode.CrLf
        case AutoCrlf.Input => EolMode.Lf
        case AutoCrlf.Disabled =>
            if (let Some(eol) <- config.eol) {
                eol
            } else {
                EolMode.CrLf
            }
    }
}

// 对齐 Rust: gix_filter::eol::AttributesDigest::is_auto_text
public func attributesDigestIsAutoText(digest: AttributesDigest): Bool {
    match (digest) {
        case AttributesDigest.TextAuto | AttributesDigest.TextAutoCrlf | AttributesDigest.TextAutoInput => true
        case _ => false
    }
}
