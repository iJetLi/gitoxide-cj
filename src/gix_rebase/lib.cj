// 文件：lib.cj
// 用途：提供 Git rebase 操作的 todo 列表解析功能
// 所属包：gix.gix_rebase
// 关键类型：RebaseStep, RebaseAction
// 关键函数：parseTodo

package gitoxide.gix_rebase

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.collection.*

// rebase 步骤，描述一个待执行的 rebase 操作
public class RebaseStep {
    // 操作类型
    public var action: RebaseAction
    // 目标提交 ID
    public var commitId: ObjectId

    // 构造函数
    // 参数 action：操作类型
    // 参数 commitId：目标提交 ID
    public init(action: RebaseAction, commitId: ObjectId) {
        this.action = action
        this.commitId = commitId
    }
}

// rebase 操作类型枚举
public enum RebaseAction {
    | Pick // 应用提交
    | ReWord // 应用提交并修改消息
    | Edit // 应用提交并暂停
    | Squash // 合并到前一个提交
    | Fixup // 合并到前一个提交（丢弃消息）
    | Drop // 丢弃提交
}

extend RebaseAction <: Equatable<RebaseAction> {
    public operator func ==(other: RebaseAction): Bool {
        match (this) {
            case RebaseAction.Pick => match (other) {
                case RebaseAction.Pick => true;
                case _ => false
            }
            case RebaseAction.ReWord => match (other) {
                case RebaseAction.ReWord => true;
                case _ => false
            }
            case RebaseAction.Edit => match (other) {
                case RebaseAction.Edit => true;
                case _ => false
            }
            case RebaseAction.Squash => match (other) {
                case RebaseAction.Squash => true;
                case _ => false
            }
            case RebaseAction.Fixup => match (other) {
                case RebaseAction.Fixup => true;
                case _ => false
            }
            case RebaseAction.Drop => match (other) {
                case RebaseAction.Drop => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: RebaseAction): Bool {
        !(this == other)
    }
}

// 解析 rebase todo 列表
// 参数 content：todo 列表文件内容
// 返回值：解析得到的 RebaseStep 列表
public func parseTodo(content: String): ArrayList<RebaseStep> {
    var result = ArrayList<RebaseStep>()
    let lines = content.split("\n")
    for (line in lines) {
        let trimmed = trimStr(line)
        if (trimmed.size == 0 || trimmed.startsWith("#")) {
            continue
        }
        let parts = trimmed.split(" ")
        if (parts.size >= 2) {
            let action = match (toLowerStr(parts[0])) {
                case "pick" | "p" => RebaseAction.Pick
                case "reword" | "r" => RebaseAction.ReWord
                case "edit" | "e" => RebaseAction.Edit
                case "squash" | "s" => RebaseAction.Squash
                case "fixup" | "f" => RebaseAction.Fixup
                case "drop" | "d" => RebaseAction.Drop
                case _ => RebaseAction.Pick
            }
            result.add(RebaseStep(action, ObjectId.fromHex(parts[1])))
        }
    }
    result
}
