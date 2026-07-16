// 文件：file.cj
// 用途：Git 配置文件的加载、查找与写入
// 所属包：gix.gix_config
// 关键类型：ConfigFile

package gitoxide.gix_config

import std.fs.*
import std.collection.*
import gitoxide.gix_utils.*

// Git 配置文件，包含多个节（section）及其来源信息
public class ConfigFile {
    // 配置文件中的所有节
    public var sections: ArrayList<Section>
    // 配置文件的文件系统路径，内存中的配置无路径
    public var path: ?String
    // 配置来源（本地、系统、全局等）
    public var source: ConfigSource

    // 初始化空的配置文件
    public init() {
        this.sections = ArrayList<Section>()
        this.path = None
        this.source = ConfigSource.Local
    }

    // 从文件路径加载并解析配置文件
    // 参数 p - 配置文件的文件系统路径
    // 返回值 - 解析成功返回 ConfigFile，文件不存在或解析失败返回 None
    public static func fromPath(p: String): ?ConfigFile {
        if (!exists(p)) {
            return None
        }
        try {
            let contentOpt = readFileContent(p)
            if (let Some(content) <- contentOpt) {
                let config = parseConfig(content)
                if (let Some(c) <- config) {
                    c.path = Some(p)
                    Some(c)
                } else {
                    None
                }
            } else {
                None
            }
        } catch (_: Exception) {
            None
        }
    }

    // 从字符串内容解析配置文件
    // 参数 data - Git 配置格式的字符串内容
    // 返回值 - 解析成功返回 ConfigFile，失败返回 None
    public static func fromBytes(data: String): ?ConfigFile {
        parseConfig(data)
    }

    // 查找指定键对应的第一个值
    // 参数 key - 配置键，格式为 "section.subsection.value" 或 "section.value"
    // 返回值 - 找到返回对应的值，未找到返回 None
    public func find(key: String): ?String {
        let k = Key.parse(key)
        if (let Some(parsed) <- k) {
            for (section in sections) {
                if (section.header.name == parsed.sectionName) {
                    if (parsed.subsection.isNone() || section.header.subsection == parsed.subsection) {
                        let v = section.find(parsed.valueName)
                        if (!v.isNone()) {
                            return v
                        }
                    }
                }
            }
        }
        None
    }

    // 查找指定键对应的所有值（多值键）
    // 参数 key - 配置键，格式为 "section.subsection.value" 或 "section.value"
    // 返回值 - 所有匹配值的列表
    public func findAll(key: String): ArrayList<String> {
        var result = ArrayList<String>()
        let k = Key.parse(key)
        if (let Some(parsed) <- k) {
            for (section in sections) {
                if (section.header.name == parsed.sectionName) {
                    if (parsed.subsection.isNone() || section.header.subsection == parsed.subsection) {
                        let values = section.findAll(parsed.valueName)
                        for (v in values) {
                            result.add(v)
                        }
                    }
                }
            }
        }
        result
    }

    // 设置指定键的值，若键已存在则更新，否则新增
    // 参数 key - 配置键，格式为 "section.subsection.value" 或 "section.value"
    // 参数 value - 要设置的值
    public func set(key: String, value: String): Unit {
        let k = Key.parse(key)
        if (let Some(parsed) <- k) {
            var found = false
            for (section in sections) {
                if (section.header.name == parsed.sectionName) {
                    if (parsed.subsection.isNone() || section.header.subsection == parsed.subsection) {
                        let keyLower = toLowerStr(parsed.valueName)
                        for (i in 0..section.entries.size) {
                            let entryKey = section.entries[i].key
                            if (toLowerStr(entryKey) == keyLower) {
                                let oldRaw = section.entries[i].rawValue
                                var leading = ""
                                var trailing = ""
                                var j: Int64 = 0
                                while (j < oldRaw.size && (oldRaw[j] == 32 || oldRaw[j] == 9)) {
                                    leading += Rune(oldRaw[j]).toString()
                                    j += 1
                                }
                                var k2: Int64 = oldRaw.size - 1
                                while (k2 >= 0 && (oldRaw[k2] == 32 || oldRaw[k2] == 9)) {
                                    trailing = Rune(oldRaw[k2]).toString() + trailing
                                    k2 -= 1
                                }
                                let newRaw = leading + value + trailing
                                section.entries[i] = ConfigEntry(parsed.valueName, value, newRaw)
                                found = true
                                break
                            }
                        }
                        if (!found) {
                            section.add(parsed.valueName, value)
                            found = true
                        }
                        break
                    }
                }
            }
            if (!found) {
                let sec = Section(SectionHeader(parsed.sectionName, parsed.subsection))
                sec.add(parsed.valueName, value)
                sections.add(sec)
            }
        }
    }

    // 将配置内容写入文件
    // 参数 path - 目标文件路径
    public func write(p: String): Unit {
        var sb = StringBuilder()
        for (section in sections) {
            sb.append("[")
            sb.append(section.header.name)
            if (let Some(sub) <- section.header.subsection) {
                sb.append(" \"")
                sb.append(sub)
                sb.append("\"")
            }
            sb.append("]\n")
            for (entry in section.entries) {
                sb.append("\t")
                sb.append(entry.key)
                sb.append(" = ")
                sb.append(entry.value)
                sb.append("\n")
            }
            sb.append("\n")
        }
        try {
            writeFileContent(p, sb.toString())
        } catch (_: Exception) {}
    }

    // 删除指定键的所有值（多值键删除）
    // 对齐 Rust: gix_config::File::remove_key
    // 参数 key - 配置键，格式为 "section.subsection.value" 或 "section.value"
    // 返回值 - 是否成功删除了至少一个条目
    public func remove(key: String): Bool {
        let k = Key.parse(key)
        if (k.isNone()) {
            return false
        }
        if (let Some(parsed) <- k) {
            var removed = false
            for (section in sections) {
                if (section.header.name == parsed.sectionName) {
                    if (parsed.subsection.isNone() || section.header.subsection == parsed.subsection) {
                        let keyLower = toLowerStr(parsed.valueName)
                        var i = section.entries.size - 1
                        while (i >= 0) {
                            if (toLowerStr(section.entries[i].key) == keyLower) {
                                section.entries.remove(at: i)
                                removed = true
                            }
                            i -= 1
                        }
                    }
                }
            }
            removed
        } else {
            false
        }
    }

    // 验证配置值类型
    // 对齐 Rust: gix_config_value::Boolean, gix_config_value::Integer
    // 参数 key - 配置键
    // 参数 expectedType - 期望的类型（"bool", "int", "string"）
    // 返回值 - 值是否符合期望类型
    public func validateValue(key: String, expectedType: String): Bool {
        let valueOpt = find(key)
        if (valueOpt.isNone()) {
            return false
        }
        if (let Some(v) <- valueOpt) {
            if (expectedType == "bool") {
                let lower = toLowerStr(v)
                lower == "true" || lower == "false" || lower == "yes" || lower == "no" || lower == "on" || lower == "off" || lower == "1" || lower == "0"
            } else if (expectedType == "int") {
                var valid = true
                var start: Int64 = 0
                if (v.size > 0 && (v[0] == UInt8(45) || v[0] == UInt8(43))) {
                    start = 1
                }
                if (start >= v.size) {
                    return false
                }
                for (i in start..v.size) {
                    if (v[i] < UInt8(48) || v[i] > UInt8(57)) {
                        valid = false
                        break
                    }
                }
                valid
            } else {
                true
            }
        } else {
            false
        }
    }
}

func readFileContent(p: String): ?String {
    try {
        if (!exists(p)) {
            return None
        }
        let file = File(p, OpenMode.Read)
        var bytes = ArrayList<Byte>()
        var buf = Array<Byte>(4096, repeat: 0)
        var n = file.read(buf)
        while (n > 0) {
            for (i in 0..n) {
                bytes.add(buf[i])
            }
            n = file.read(buf)
        }
        file.close()
        Some(String.fromUtf8(bytes.toArray()))
    } catch (_: Exception) {
        None
    }
}

func writeFileContent(p: String, content: String): Unit {
    let file = File(p, OpenMode.Write)
    file.write(content.toArray())
    file.close()
}
