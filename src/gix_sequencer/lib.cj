// 文件：lib.cj
// 用途：提供 Git sequencer（序列器）功能，解析和执行 todo 列表
// 所属包：gix.gix_sequencer
// 关键类型：TodoList, TodoStep

package gitoxide.gix_sequencer

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.collection.*

// todo 列表，包含多个待执行步骤
public class TodoList {
    // 步骤列表
    public var steps: ArrayList<TodoStep>

    public init() {
        this.steps = ArrayList<TodoStep>()
    }

    // 从文本内容解析 todo 列表
    // 参数 content：todo 列表文件内容
    // 返回值：解析后的 TodoList 实例
    public static func parse(content: String): TodoList {
        let list = TodoList()
        let lines = content.split("\n")
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0 || trimmed.startsWith("#")) {
                continue
            }
            let parts = trimmed.split(" ")
            if (parts.size >= 2) {
                list.steps.add(TodoStep(parts[0], ObjectId.fromHex(parts[1])))
            }
        }
        list
    }
}

// 单个 todo 步骤
public class TodoStep {
    // 操作名称（如 pick、edit 等）
    public var action: String
    // 目标提交 ID
    public var commitId: ObjectId

    // 构造函数
    // 参数 action：操作名称
    // 参数 commitId：目标提交 ID
    public init(action: String, commitId: ObjectId) {
        this.action = action
        this.commitId = commitId
    }
}
