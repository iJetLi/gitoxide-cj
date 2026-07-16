// 文件：lib.cj
// 用途：提供 .mailmap 文件解析与邮件地址映射功能
// 所属包：gix.gix_mailmap
// 关键类型：Mailmap, MailmapEntry
// 对齐 Rust: gix-mailmap/src/lib.rs, gix-mailmap/src/parse.rs, gix-mailmap/src/entry.rs, gix-mailmap/src/snapshot/mod.rs

package gitoxide.gix_mailmap

import std.collection.*
import gitoxide.gix_utils.*

// 邮件映射表，将提交者信息映射为规范化的名称和邮箱
// 对齐 Rust: gix_mailmap::Mailmap
public class Mailmap {
    // 映射条目列表
    public var entries: ArrayList<MailmapEntry>

    public init() {
        this.entries = ArrayList<MailmapEntry>()
    }

    // 从 .mailmap 文件内容解析映射表
    // 对齐 Rust: gix_mailmap::Mailmap::from_bytes
    // 参数 content：.mailmap 文件的文本内容
    // 返回值：解析后的 Mailmap 实例
    public static func parse(content: String): Mailmap {
        let map = Mailmap()
        // 处理续行（\ 行尾），对齐 Rust: gix_mailmap::parse::Lines
        var joinedLines = ArrayList<String>()
        var pending = ""
        let rawLines = content.split("\n")
        for (line in rawLines) {
            if (line.size > 0 && line[line.size - 1] == UInt8(92)) {
                // 反斜杠续行，对齐 Rust: continuation lines
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
        for (line in joinedLines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0) {
                continue
            }
            // 注释行处理，对齐 Rust: gix_mailmap::parse::Lines — # 开头为注释
            // 注意：只有原始行（未 trim 的行）的第一个字符为 # 才是注释
            // 前导空白后的 # 是名称的一部分，对齐 Rust: hash_before_name_counts_as_name
            if (line.size > 0 && line[0] == UInt8(35)) {
                continue
            }
            let entry = parseLine(trimmed)
            if (let Some(e) <- entry) {
                map.entries.add(e)
            }
        }
        map
    }

    // 解析单行 mailmap 条目
    // 对齐 Rust: gix_mailmap::parse::Line
    private static func parseLine(line: String): ?MailmapEntry {
        var pos: Int64 = 0
        let len = line.size
        while (pos < len && line[pos] == UInt8(32)) {
            pos += 1
        }
        if (pos >= len) {
            return None
        }
        var toName = ""
        var toEmail = ""
        var fromName = ""
        var fromEmail = ""
        var nameStart = pos
        while (pos < len && line[pos] != UInt8(60)) {
            pos += 1
        }
        if (pos < len && line[pos] == UInt8(60)) {
            toName = trimStr(substringStr(line, nameStart, pos))
            pos += 1
            var emailStart = pos
            while (pos < len && line[pos] != UInt8(62)) {
                pos += 1
            }
            if (pos >= len) {
                return None
            }
            toEmail = trimStr(substringStr(line, emailStart, pos))
            pos += 1
        } else {
            return None
        }
        while (pos < len && line[pos] == UInt8(32)) {
            pos += 1
        }
        if (pos < len) {
            nameStart = pos
            while (pos < len && line[pos] != UInt8(60)) {
                pos += 1
            }
            if (pos < len && line[pos] == UInt8(60)) {
                fromName = trimStr(substringStr(line, nameStart, pos))
                pos += 1
                var emailStart = pos
                while (pos < len && line[pos] != UInt8(62)) {
                    pos += 1
                }
                if (pos >= len) {
                    return None
                }
                fromEmail = trimStr(substringStr(line, emailStart, pos))
            } else {
                fromName = trimStr(substringStr(line, nameStart, len))
            }
        }
        Some(MailmapEntry(toName, toEmail, fromName, fromEmail))
    }

    // 根据原始名称和邮箱解析为规范化的名称和邮箱
    // 对齐 Rust: gix_mailmap::Snapshot::try_resolve
    // 邮箱比较不区分大小写，对齐 Rust: case-insensitive email matching
    // 参数 name：原始提交者名称
    // 参数 email：原始提交者邮箱
    // 返回值：(规范化名称, 规范化邮箱) 元组
    public func resolve(name: String, email: String): (String, String) {
        let emailLower = toLowerStr(email)
        let nameLower = toLowerStr(name)
        for (entry in entries) {
            if (entry.fromEmail.size > 0 && entry.fromName.size > 0) {
                // 邮箱和名称都匹配，对齐 Rust: name+email match
                if (toLowerStr(entry.fromEmail) == emailLower && toLowerStr(entry.fromName) == nameLower) {
                    let resolvedName = if (entry.toName.size > 0) {
                        entry.toName
                    } else {
                        name
                    }
                    let resolvedEmail = if (entry.toEmail.size > 0) {
                        entry.toEmail
                    } else {
                        email
                    }
                    return (resolvedName, resolvedEmail)
                }
            } else if (entry.fromEmail.size > 0) {
                // 仅邮箱匹配，对齐 Rust: email-only match (case-insensitive)
                if (toLowerStr(entry.fromEmail) == emailLower) {
                    let resolvedName = if (entry.toName.size > 0) {
                        entry.toName
                    } else {
                        name
                    }
                    let resolvedEmail = if (entry.toEmail.size > 0) {
                        entry.toEmail
                    } else {
                        email
                    }
                    return (resolvedName, resolvedEmail)
                }
            } else if (entry.fromName.size > 0) {
                // 仅名称匹配，对齐 Rust: name-only match
                if (toLowerStr(entry.fromName) == nameLower) {
                    let resolvedName = if (entry.toName.size > 0) {
                        entry.toName
                    } else {
                        name
                    }
                    let resolvedEmail = if (entry.toEmail.size > 0) {
                        entry.toEmail
                    } else {
                        email
                    }
                    return (resolvedName, resolvedEmail)
                }
            } else {
                // 无 from 字段，仅 toEmail 匹配（自身映射）
                // 对齐 Rust: to_email-only match (case-insensitive)
                if (toLowerStr(entry.toEmail) == emailLower) {
                    return (entry.toName, entry.toEmail)
                }
            }
        }
        (name, email)
    }
}

// 邮件映射条目
// 对齐 Rust: gix_mailmap::Entry
public class MailmapEntry {
    public var fromName: String
    public var fromEmail: String
    public var toName: String
    public var toEmail: String

    public init(toName: String, toEmail: String) {
        this.fromName = ""
        this.fromEmail = ""
        this.toName = toName
        this.toEmail = toEmail
    }

    public init(toName: String, toEmail: String, fromName: String, fromEmail: String) {
        this.fromName = fromName
        this.fromEmail = fromEmail
        this.toName = toName
        this.toEmail = toEmail
    }
}
