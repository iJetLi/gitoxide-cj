// 文件：lib.cj
// 用途：提供 .gitattributes 文件解析与路径匹配功能
// 所属包：gix.gix_attributes
// 关键类型：Attributes, AttributePattern, AttributeAssignment
// 关键函数：parse, matchPath

package gitoxide.gix_attributes

import std.collection.*
import gitoxide.gix_utils.*

// gitattributes 解析结果，包含所有属性模式
public class Attributes {
    // 解析得到的属性模式列表
    public var patterns: ArrayList<AttributePattern>

    public init() {
        this.patterns = ArrayList<AttributePattern>()
    }

    // 从 .gitattributes 文件内容解析属性模式
    // 参数 content：.gitattributes 文件的文本内容
    // 返回值：解析后的 Attributes 实例
    public static func parse(content: String): Attributes {
        let attrs = Attributes()
        let lines = content.split("\n")
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            let spaceIdx = trimmed.indexOf(" ")
            if (let Some(si) <- spaceIdx) {
                let pattern = substringStr(trimmed, 0, si)
                let attrStr = substringFromStr(trimmed, si + 1)
                let attrParts = attrStr.split(" ")
                var assignments = ArrayList<AttributeAssignment>()
                for (part in attrParts) {
                    let eqIdx = part.indexOf("=")
                    if (let Some(eq) <- eqIdx) {
                        assignments.add(AttributeAssignment(substringStr(part, 0, eq),
                            Some(substringFromStr(part, eq + 1))))
                    } else if (part.startsWith("-")) {
                        assignments.add(AttributeAssignment(substringFromStr(part, 1), None))
                    } else {
                        assignments.add(AttributeAssignment(part, Some("true")))
                    }
                }
                attrs.patterns.add(AttributePattern(pattern, assignments))
            }
        }
        attrs
    }

    // 匹配指定路径，返回所有匹配的属性赋值
    // 参数 path：待匹配的文件路径
    // 返回值：所有匹配模式的属性赋值列表
    public func matchPath(path: String): ArrayList<AttributeAssignment> {
        var result = ArrayList<AttributeAssignment>()
        for (pattern in patterns) {
            if (matchPattern(pattern.pattern, path)) {
                for (a in pattern.assignments) {
                    result.add(a)
                }
            }
        }
        result
    }
}

// 简单模式匹配，支持通配符
// 参数 pattern：匹配模式
// 参数 path：待匹配的路径
// 返回值：匹配成功返回 true
func matchPattern(pattern: String, path: String): Bool {
    if (pattern == "*") {
        return true
    }
    if (pattern.startsWith("*.") && !pattern.contains("/")) {
        let suffix = substringFromStr(pattern, 1)
        return path.endsWith(suffix)
    }
    if (pattern.startsWith("*") && !pattern.contains("/")) {
        let suffix = substringFromStr(pattern, 1)
        return path.endsWith(suffix) || path.contains(substringFromStr(pattern, 1))
    }
    path.contains(pattern)
}

// 属性模式，包含路径模式和属性赋值列表
public class AttributePattern {
    // 路径匹配模式
    public var pattern: String
    // 属性赋值列表
    public var assignments: ArrayList<AttributeAssignment>

    public init(pattern: String, assignments: ArrayList<AttributeAssignment>) {
        this.pattern = pattern
        this.assignments = assignments
    }
}

// 属性赋值，表示一个属性名和其值
public class AttributeAssignment {
    // 属性名称
    public var name: String
    // 属性值，None 表示取消设置（-前缀）
    public var value: ?String

    public init(name: String, value: ?String) {
        this.name = name
        this.value = value
    }
}
