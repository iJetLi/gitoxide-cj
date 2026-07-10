// 文件：section.cj
// 用途：Git 配置文件中节（section）与节头部的数据结构
// 所属包：gix.gix_config
// 关键类型：Section、SectionHeader、ConfigEntry

package gitoxide.gix_config

import std.collection.*
import gitoxide.gix_utils.*

public class ConfigEntry {
    public var key: String
    public var value: String
    // 原始值（包含空白前缀/后缀），用于 set 时保留空白格式
    public var rawValue: String

    public init(key: String, value: String) {
        this.key = key
        this.value = value
        this.rawValue = value
    }

    public init(key: String, value: String, rawValue: String) {
        this.key = key
        this.value = value
        this.rawValue = rawValue
    }
}

public class Section {
    // 节头部信息（节名和子节名）
    public var header: SectionHeader
    public var entries: ArrayList<ConfigEntry>

    // 构造节
    // 参数 header - 节头部信息
    public init(header: SectionHeader) {
        this.header = header
        this.entries = ArrayList<ConfigEntry>()
    }

    // 向节中添加键值对
    // 参数 key - 键名
    // 参数 value - 值
    public func add(key: String, value: String): Unit {
        entries.add(ConfigEntry(key, value))
    }

    // 在节中查找指定键对应的第一个值（大小写不敏感）
    // 参数 key - 要查找的键名
    // 返回值 - 找到返回对应值，未找到返回 None
    public func find(key: String): ?String {
        let keyLower = toLowerStr(key)
        for (entry in entries) {
            if (toLowerStr(entry.key) == keyLower) {
                return Some(entry.value)
            }
        }
        None
    }

    // 在节中查找指定键对应的所有值（多值键，大小写不敏感）
    // 参数 key - 要查找的键名
    // 返回值 - 所有匹配值的列表
    public func findAll(key: String): ArrayList<String> {
        var result = ArrayList<String>()
        let keyLower = toLowerStr(key)
        for (entry in entries) {
            if (toLowerStr(entry.key) == keyLower) {
                result.add(entry.value)
            }
        }
        result
    }
}

// 节头部，描述节的名称和可选的子节名称
public class SectionHeader {
    // 节名称，如 "core"、"remote"
    public var name: String
    // 子节名称，如 "origin"（对应 [remote "origin"]），无子节时为 None
    public var subsection: ?String

    // 构造节头部
    // 参数 name - 节名称
    // 参数 subsection - 子节名称，无子节时为 None
    public init(name: String, subsection: ?String) {
        this.name = name
        this.subsection = subsection
    }
}
