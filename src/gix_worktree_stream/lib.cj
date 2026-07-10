// 文件：lib.cj
// 用途：工作树流式输出，用于逐条输出树对象的条目（checkout 时按流式生成）
// 所属包：gix.gix_worktree_stream
// 关键类型：WorktreeStream, StreamEntry

package gitoxide.gix_worktree_stream

import gitoxide.gix_object.*
import gitoxide.gix_hash.*
import std.collection.*

// 工作树流，按条目逐个收集树对象内容，用于流式检出
public class WorktreeStream {
    // 流中的条目列表
    public var entries: ArrayList<StreamEntry>

    // 初始化空流
    public init() {
        this.entries = ArrayList<StreamEntry>()
    }

    // 添加一条流条目
    // 参数 path: 文件相对路径
    // 参数 mode: 文件模式
    // 参数 id: 对象 ID
    public func addEntry(path: String, mode: EntryMode, id: ObjectId): Unit {
        entries.add(StreamEntry(path, mode, id))
    }
}

// 流条目，表示工作树流中的一个文件条目
public class StreamEntry {
    // 文件相对路径
    public var path: String
    // 文件模式（权限/类型）
    public var mode: EntryMode
    // 对象 ID
    public var id: ObjectId

    // 参数 path: 文件相对路径
    // 参数 mode: 文件模式
    // 参数 id: 对象 ID
    public init(path: String, mode: EntryMode, id: ObjectId) {
        this.path = path
        this.mode = mode
        this.id = id
    }
}
