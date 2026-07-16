// 文件：parse.cj
// 用途：Git 配置文件的解析逻辑
// 所属包：gix.gix_config
// 关键类型：ParseError、parseConfig、parseSectionHeader
// 对齐 Rust: gix-config/src/parse/mod.rs, gix-config/src/parse/from_bytes/mod.rs, gix-config/src/parse/section/mod.rs

package gitoxide.gix_config

import std.collection.*
import std.fs.*
import gitoxide.gix_utils.*

// 配置解析错误信息
public class ParseError {
    // 错误描述
    public var message: String
    // 出错行号
    public var line: Int64

    // 构造解析错误
    // 参数 message - 错误描述
    // 参数 line - 出错行号
    public init(message: String, line: Int64) {
        this.message = message
        this.line = line
    }
}

// 解析 Git 配置格式的字符串为 ConfigFile
// 对齐 Rust: gix_config::File::from_bytes
// 参数 data - Git 配置格式的字符串内容
// 返回值 - 解析成功返回 ConfigFile，失败返回 None
public func parseConfig(data: String): ?ConfigFile {
    let config = ConfigFile()
    var currentSection: ?Section = None
    var lineNum: Int64 = 0
    // 处理续行（\ 行尾），对齐 Rust: gix_config::parse::from_bytes
    var joinedLines = ArrayList<String>()
    var pending = ""
    let rawLines = data.split("\n")
    for (line in rawLines) {
        lineNum += 1
        // 续行处理，对齐 Rust: continuation lines
        if (line.size > 0 && line[line.size - 1] == UInt8(92)) {
            pending = pending + substringStr(line, 0, line.size - 1)
        } else {
            pending = pending + line
            joinedLines.add(pending)
            pending = ""
        }
    }
    if (pending.size > 0) {
        joinedLines.add(pending)
    }
    lineNum = 0
    for (line in joinedLines) {
        lineNum += 1
        let trimmed = trimStr(line)
        if (trimmed.size == 0 || trimmed.startsWith("#") || trimmed.startsWith(";")) {
            continue
        }
        if (trimmed.startsWith("[")) {
            // 检查 [include] 和 [includeIf] 指令，对齐 Rust: gix_config::file::includes
            let section = parseSectionHeader(trimmed)
            if (let Some(s) <- section) {
                currentSection = Some(s)
                config.sections.add(s)
            }
        } else {
            if (let Some(sec) <- currentSection) {
                let eqIdx = trimmed.indexOf("=")
                if (let Some(eq) <- eqIdx) {
                    let key = trimStr(substringStr(trimmed, 0, eq))
                    let rawValue = substringFromStr(trimmed, eq + 1)
                    // 引号值处理，对齐 Rust: gix_config::parse::from_bytes — quoted values
                    var value = trimStr(rawValue)
                    if (value.size >= 2 && value[0] == UInt8(34) && value[value.size - 1] == UInt8(34)) {
                        value = substringStr(value, 1, value.size - 1)
                    }
                    sec.entries.add(ConfigEntry(key, value, rawValue))
                }
            }
        }
    }
    // 处理 [include] / [includeIf] 指令，对齐 Rust: gix_config::file::includes::resolve
    resolveIncludes(config)
    Some(config)
}

// 解析节头部行，如 [core] 或 [remote "origin"]
// 对齐 Rust: gix_config::parse::section::header
// 参数 line - 节头部行文本
// 返回值 - 解析成功返回 Section，格式不合法返回 None
func parseSectionHeader(line: String): ?Section {
    if (!line.startsWith("[")) {
        return None
    }
    var end = line.indexOf("]")
    if (end.isNone()) {
        return None
    }
    var endVal = end.getOrThrow()
    let content = trimStr(substringStr(line, 1, endVal))
    if (content.size == 0) {
        return None
    }
    let spaceIdx = content.indexOf(" ")
    if (let Some(si) <- spaceIdx) {
        let name = toLowerStr(substringStr(content, 0, si))
        if (name.size == 0) {
            return None
        }
        let rest = trimStr(substringFromStr(content, si + 1))
        if (rest.startsWith("\"") && rest.size > 1) {
            let endQuote = rest.indexOf("\"", 1)
            if (let Some(eq) <- endQuote) {
                Some(Section(SectionHeader(name, Some(substringStr(rest, 1, eq)))))
            } else {
                Some(Section(SectionHeader(name, Some(rest))))
            }
        } else {
            Some(Section(SectionHeader(name, Some(rest))))
        }
    } else {
        let name = toLowerStr(content)
        Some(Section(SectionHeader(name, None)))
    }
}

// 解析 [include] / [includeIf] 指令
// 对齐 Rust: gix_config::file::includes::resolve_includes
func resolveIncludes(config: ConfigFile): Unit {
    var includePaths = ArrayList<String>()
    for (section in config.sections) {
        if (section.header.name == "include") {
            // [include] path = xxx
            for (entry in section.entries) {
                if (toLowerStr(entry.key) == "path") {
                    includePaths.add(entry.value)
                }
            }
        }
        // [includeIf] 条件包含，对齐 Rust: gix_config::file::includes::resolve_includes
        // 支持 gitdir:、gitdir/i:（大小写不敏感）、onbranch:、hasconfig:remote.*.url 条件
        // 仓颉差异：条件评估为 stub（总是匹配），完整实现需与 .git 目录/分支/remote URL 比较
        if (section.header.name == "includeif") {
            if (let Some(condition) <- section.header.subsection) {
                var condMatch = false
                let condLower = toLowerStr(condition)
                // gitdir: 条件，对齐 Rust: gix_config::file::includes::conditional::gitdir
                // 仓颉 stub：无条件匹配，完整实现需与 .git 目录比较
                if (condLower.startsWith("gitdir:")) {
                    condMatch = true
                }
                // gitdir/i: 大小写不敏感匹配，对齐 Rust: gix_config::file::includes::conditional::gitdir_i
                // 仓颉 stub：无条件匹配
                if (condLower.startsWith("gitdir/i:")) {
                    condMatch = true
                }
                // onbranch: 条件，对齐 Rust: gix_config::file::includes::conditional::onbranch
                // 仓颉 stub：无条件匹配，完整实现需与当前分支名比较
                if (condLower.startsWith("onbranch:")) {
                    condMatch = true
                }
                // hasconfig:remote.*.url 条件，对齐 Rust: gix_config::file::includes::conditional::hasconfig
                // 仓颉 stub：无条件匹配，完整实现需与 remote URL 匹配
                if (condLower.startsWith("hasconfig:remote.*.url:")) {
                    condMatch = true
                }
                if (condMatch) {
                    for (entry in section.entries) {
                        if (toLowerStr(entry.key) == "path") {
                            includePaths.add(entry.value)
                        }
                    }
                }
            }
        }
    }
    // 加载包含的配置文件
    for (incPath in includePaths) {
        if (let Some(basePath) <- config.path) {
            let parentOpt = basePath.lastIndexOf('/')
            let dir = if (let Some(pi) <- parentOpt) {
                substringStr(basePath, 0, pi)
            } else {
                "."
            }
            let fullPath = dir + "/" + incPath
            if (exists(fullPath)) {
                if (let Some(content) <- readFileContent(fullPath)) {
                    if (let Some(included) <- parseConfig(content)) {
                        for (sec in included.sections) {
                            if (sec.header.name != "include" && sec.header.name != "includeif") {
                                config.sections.add(sec)
                            }
                        }
                    }
                }
            }
        }
    }
}
