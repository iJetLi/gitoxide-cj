// 文件：store/linked.cj
// 用途：链式存储，通过 alternates 机制链接多个对象数据库，实现跨库对象查找
// 所属包：gix.gix_odb
// 关键类型：LinkedStore

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import gitoxide.gix_object.*
import std.fs.*
import std.collection.*

// 链式存储，维护一个 alternates 列表，按顺序在多个对象数据库中查找对象
// 用于支持 Git 的 alternates 机制，允许一个仓库借用另一个仓库的对象
public class LinkedStore {
    // 备用对象数据库列表，每个元素是一个完整的复合存储
    public var alternates: ArrayList<CompoundStore>

    // 构造函数，初始化空的 alternates 列表
    public init() {
        this.alternates = ArrayList<CompoundStore>()
    }

    // 从对象目录创建链式存储，自动解析 alternates 文件并构建备用存储列表
    // 参数 objectsDir：Git 对象目录路径
    // 参数 hashKind：哈希算法类型
    // 返回值：包含所有 alternates 的链式存储实例
    public static func fromObjectsDir(objectsDir: String, hashKind: HashKind): LinkedStore {
        let store = LinkedStore()
        let altPath = objectsDir + "/info/alternates"
        if (exists(altPath)) {
            try {
                let bytes = readFileBytes(altPath)
                let content = String.fromUtf8(bytes)
                let lines = content.split("\n")
                for (line in lines) {
                    let trimmed = trimStr(line)
                    if (trimmed.size > 0) {
                        let loose = LooseStore(trimmed, hashKind)
                        let dynamic = DynamicStore(trimmed, hashKind)
                        store.alternates.add(CompoundStore(loose, dynamic))
                    }
                }
            } catch (_: Exception) {}
        }
        store
    }

    // 在所有 alternates 中按顺序查找对象数据，找到第一个即返回
    // 参数 id：要查找的对象 ID
    // 返回值：在任一 alternate 中找到则返回 Data，全部未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        for (alt in alternates) {
            let result = alt.tryFind(id)
            if (!result.isNone()) {
                return result
            }
        }
        None
    }
}
