// 文件：lib.cj
// 用途：提供 Git notes 功能，为提交对象附加备注信息
// 所属包：gix.gix_note
// 关键类型：Note, NoteMap

package gitoxide.gix_note

import gitoxide.gix_hash.*
import std.collection.*

// 单个备注，关联一个提交和备注消息
public class Note {
    // 关联的提交 ID
    public var commitId: ObjectId
    // 备注消息内容
    public var message: String

    // 构造函数
    // 参数 commitId：提交 ID
    // 参数 message：备注消息
    public init(commitId: ObjectId, message: String) {
        this.commitId = commitId
        this.message = message
    }
}

// 备注映射表，将对象 ID 映射到备注对象 ID
public class NoteMap {
    // 对象 ID 十六进制字符串到备注对象 ID 的映射
    public var notes: HashMap<String, ObjectId>

    public init() {
        this.notes = HashMap<String, ObjectId>()
    }

    // 根据对象 ID 查找关联的备注对象 ID
    // 参数 id：待查找的对象 ID
    // 返回值：找到返回备注对象 ID，未找到返回 None
    public func get(id: ObjectId): ?ObjectId {
        notes.get(id.toHexString())
    }

    // 设置对象 ID 关联的备注对象 ID
    // 参数 id：对象 ID
    // 参数 noteObjectId：备注对象 ID
    public func set(id: ObjectId, noteObjectId: ObjectId): Unit {
        notes[id.toHexString()] = noteObjectId
    }

    // 移除对象 ID 关联的备注
    // 参数 id：对象 ID
    public func remove(id: ObjectId): Unit {
        notes.remove(id.toHexString())
    }
}
