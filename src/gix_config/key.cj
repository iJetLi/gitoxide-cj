// 文件：key.cj
// 用途：Git 配置键的解析与表示
// 所属包：gix.gix_config
// 关键类型：Key

package gitoxide.gix_config

import gitoxide.gix_utils.*

// Git 配置键，将 "section.subsection.value" 格式拆分为三部分
public class Key {
    // 节名称，如 "core"、"remote"
    public var sectionName: String
    // 子节名称，如 "origin"（对应 [remote "origin"]）
    public var subsection: ?String
    // 值名称，如 "url"、"bare"
    public var valueName: String

    // 构造配置键
    // 参数 sectionName - 节名称
    // 参数 subsection - 子节名称，无子节时为 None
    // 参数 valueName - 值名称
    public init(sectionName: String, subsection: ?String, valueName: String) {
        this.sectionName = sectionName
        this.subsection = subsection
        this.valueName = valueName
    }

    // 从字符串解析配置键
    // 参数 s - 配置键字符串，格式为 "section.value" 或 "section.subsection.value"
    // 返回值 - 解析成功返回 Key，格式不合法返回 None
    public static func parse(s: String): ?Key {
        let dotIdx = s.lastIndexOf('.')
        if (let Some(dot) <- dotIdx) {
            let sectionPart = substringStr(s, 0, dot)
            let valuePart = substringFromStr(s, dot + 1)
            let subDot = sectionPart.indexOf('.')
            if (let Some(sd) <- subDot) {
                Some(
                    Key(toLowerStr(substringStr(sectionPart, 0, sd)), Some(substringFromStr(sectionPart, sd + 1)),
                        toLowerStr(valuePart)))
            } else {
                Some(Key(toLowerStr(sectionPart), None, toLowerStr(valuePart)))
            }
        } else {
            None
        }
    }
}

extend Key <: ToString {
    public func toString(): String {
        if (let Some(sub) <- subsection) {
            sectionName + "." + sub + "." + valueName
        } else {
            sectionName + "." + valueName
        }
    }
}
