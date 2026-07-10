// 文件：lib.cj
// 用途：.git/FETCH_HEAD 文件解析，跟踪 fetch 操作的结果条目
// 所属包：gix.gix_fetchhead
// 关键类型：FetchHeadEntry, parseFetchHead

package gitoxide.gix_fetchhead

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.collection.*

// FETCH_HEAD 条目，表示一次 fetch 操作中获取的一个引用记录
public class FetchHeadEntry {
    // 引用指向的对象 ID
    public var id: ObjectId
    // 是否用于合并（非 "not-for-merge" 标记的条目）
    public var isMerge: Bool
    // 引用名称，如 "refs/heads/main"
    public var refName: ?String
    // 远程仓库 URL
    public var remoteUrl: ?String

    // 参数 id: 对象 ID
    // 参数 isMerge: 是否用于合并
    // 参数 refName: 引用名称
    // 参数 remoteUrl: 远程仓库 URL
    public init(id: ObjectId, isMerge: Bool, refName: ?String, remoteUrl: ?String) {
        this.id = id
        this.isMerge = isMerge
        this.refName = refName
        this.remoteUrl = remoteUrl
    }
}

// 解析 .git/FETCH_HEAD 文件内容
// 参数 data: FETCH_HEAD 文件的文本内容
// 返回值: 解析后的 FetchHeadEntry 列表
public func parseFetchHead(data: String): ArrayList<FetchHeadEntry> {
    var result = ArrayList<FetchHeadEntry>()
    let lines = data.split("\n")
    for (line in lines) {
        let trimmed = trimStr(line)
        if (trimmed.size == 0) {
            continue
        }
        let parts = trimmed.split("\t")
        if (parts.size < 2) {
            continue
        }
        let id = ObjectId.fromHex(trimStr(parts[0]))
        let isMerge = !trimStr(parts[1]).contains("not-for-merge")
        var refName: ?String = None
        var remoteUrl: ?String = None
        if (parts.size >= 2) {
            refName = Some(trimStr(parts[1]))
        }
        if (parts.size >= 3) {
            let p2 = trimStr(parts[2])
            remoteUrl = Some(substringStr(p2, 1, p2.size - 1))
        }
        result.add(FetchHeadEntry(id, isMerge, refName, remoteUrl))
    }
    result
}
