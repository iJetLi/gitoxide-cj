// 文件：parse.cj
// 用途：Git 配置文件的解析逻辑
// 所属包：gix.gix_config
// 关键类型：ParseError、parseConfig、parseSectionHeader

package gitoxide.gix_config

import std.collection.*
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
// 参数 data - Git 配置格式的字符串内容
// 返回值 - 解析成功返回 ConfigFile，失败返回 None
public func parseConfig(data: String): ?ConfigFile {
    let config = ConfigFile()
    var currentSection: ?Section = None
    var lineNum: Int64 = 0
    let lines = data.split("\n")
    for (line in lines) {
        lineNum += 1
        let trimmed = trimStr(line)
        if (trimmed.size == 0 || trimmed.startsWith("#") || trimmed.startsWith(";")) {
            continue
        }
        if (trimmed.startsWith("[")) {
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
                    let value = trimStr(rawValue)
                    sec.entries.add(ConfigEntry(key, value, rawValue))
                }
            }
        }
    }
    Some(config)
}

// 解析节头部行，如 [core] 或 [remote "origin"]
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
        if (name.size == 0) {
            return None
        }
        Some(Section(SectionHeader(name, None)))
    }
}
