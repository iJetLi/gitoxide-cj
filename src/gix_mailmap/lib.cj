// 文件：lib.cj
// 用途：提供 .mailmap 文件解析与邮件地址映射功能
// 所属包：gix.gix_mailmap
// 关键类型：Mailmap, MailmapEntry

package gitoxide.gix_mailmap

import std.collection.*
import gitoxide.gix_utils.*

// 邮件映射表，将提交者信息映射为规范化的名称和邮箱
public class Mailmap {
    // 映射条目列表
    public var entries: ArrayList<MailmapEntry>

    public init() {
        this.entries = ArrayList<MailmapEntry>()
    }

    // 从 .mailmap 文件内容解析映射表
    // 参数 content：.mailmap 文件的文本内容
    // 返回值：解析后的 Mailmap 实例
    public static func parse(content: String): Mailmap {
        let map = Mailmap()
        let lines = content.split("\n")
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0) {
                continue
            }
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
    // 参数 name：原始提交者名称
    // 参数 email：原始提交者邮箱
    // 返回值：(规范化名称, 规范化邮箱) 元组
    public func resolve(name: String, email: String): (String, String) {
        let emailLower = toLowerStr(email)
        let nameLower = toLowerStr(name)
        for (entry in entries) {
            if (entry.fromEmail.size > 0 && entry.fromName.size > 0) {
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
                if (toLowerStr(entry.toEmail) == emailLower) {
                    return (entry.toName, entry.toEmail)
                }
            }
        }
        (name, email)
    }
}

// 邮件映射条目
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
