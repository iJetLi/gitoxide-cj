// 文件：lib.cj
// 用途：提供 .gitignore 文件解析与路径忽略判断功能
// 所属包：gix.gix_ignore
// 关键类型：Ignore, IgnorePattern
// 关键函数：parse, isIgnored

package gitoxide.gix_ignore

import std.collection.*
import gitoxide.gix_utils.*

// gitignore 解析结果，包含所有忽略模式
public class Ignore {
    // 解析得到的忽略模式列表
    public var patterns: ArrayList<IgnorePattern>

    public init() {
        this.patterns = ArrayList<IgnorePattern>()
    }

    // 从 .gitignore 文件内容解析忽略模式
    // 参数 content：.gitignore 文件的文本内容
    // 返回值：解析后的 Ignore 实例
    public static func parse(content: String): Ignore {
        let ignore = Ignore()
        let lines = content.split("\n")
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            let negated = trimmed.startsWith("!")
            let pattern = if (negated) {
                substringFromStr(trimmed, 1)
            } else {
                trimmed
            }
            ignore.patterns.add(IgnorePattern(pattern, negated))
        }
        ignore
    }

    // 判断指定路径是否被忽略
    // 按模式顺序依次匹配，后面的模式覆盖前面的结果
    // 参数 path：待判断的文件路径
    // 返回值：被忽略返回 true
    public func isIgnored(path: String): Bool {
        var result = false
        for (pattern in patterns) {
            if (matchIgnorePattern(pattern.pattern, path)) {
                result = !pattern.negated
            }
        }
        result
    }
}

// 简单的忽略模式匹配
// 支持通配符 *、前缀/后缀匹配和精确匹配
// 参数 pattern：匹配模式
// 参数 path：待匹配的路径
// 返回值：匹配成功返回 true
func matchIgnorePattern(pattern: String, path: String): Bool {
    if (pattern == "*") {
        return true
    }
    if (pattern.startsWith("*") && pattern.endsWith("*")) {
        let middle = substringStr(pattern, 1, pattern.size - 1)
        return path.contains(middle)
    }
    if (pattern.startsWith("*")) {
        return path.endsWith(substringFromStr(pattern, 1))
    }
    if (pattern.endsWith("*")) {
        return path.startsWith(substringStr(pattern, 0, pattern.size - 1))
    }
    path == pattern || path.endsWith("/" + pattern)
}

// 忽略模式，包含匹配模式和取反标志
public class IgnorePattern {
    // 匹配模式字符串
    public var pattern: String
    // 是否为取反模式（! 前缀）
    public var negated: Bool

    public init(pattern: String, negated: Bool) {
        this.pattern = pattern
        this.negated = negated
    }
}
