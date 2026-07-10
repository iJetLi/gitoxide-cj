// 文件：lib.cj
// 用途：提供提交和树的遍历功能，支持深度优先遍历提交图
// 所属包：gix.gix_traverse
// 关键类型：CommitIter, FindObject

package gitoxide.gix_traverse

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*

// 提交迭代器，按深度优先顺序遍历提交图
// 自动去重，避免重复访问同一提交
public class CommitIter {
    // 待访问的提交栈
    public var stack: ArrayList<ObjectId>
    // 已访问的提交集合（十六进制字符串）
    public var visited: HashSet<String>
    // 对象查找器，用于读取提交数据
    public var finder: FindObject

    // 构造函数
    // 参数 start：起始提交 ID
    // 参数 finder：对象查找器
    public init(start: ObjectId, finder: FindObject) {
        this.stack = ArrayList<ObjectId>()
        this.stack.add(start)
        this.visited = HashSet<String>()
        this.finder = finder
    }

    // 获取下一个未访问的提交
    // 返回值：有未访问提交返回 Commit，遍历完毕返回 None
    public func next(): ?Commit {
        while (stack.size > 0) {
            let id = stack[stack.size - 1]
            stack.remove(stack.size - 1..stack.size)
            let hex = id.toHexString()
            if (visited.contains(hex)) {
                continue
            }
            visited.add(hex)
            let dataOpt = finder.findObject(id)
            if (let Some(d) <- dataOpt) {
                let obj = d.decode()
                if (let Some(ObjectRef.Commit(c)) <- obj) {
                    for (parent in c.parents) {
                        stack.add(ObjectId.fromHex(parent))
                    }
                    let owned = c.intoOwned()
                    if (let Some(commit) <- owned) {
                        return Some(commit)
                    }
                }
            }
        }
        None
    }
}

// 对象查找接口，提供根据 ID 查找对象数据的能力
public interface FindObject {
    // 根据对象 ID 查找对象数据
    // 参数 id：对象 ID
    // 返回值：找到返回 Data，未找到返回 None
    func findObject(id: ObjectId): ?Data
}
