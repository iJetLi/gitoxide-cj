// 文件：lib.cj
// 用途：提供 Git 树对象差异比较功能，计算两个树之间的文件变更
// 所属包：gix.gix_diff
// 关键类型：TreeDiff, DiffEntry, DiffStatus
// 关键函数：diffTrees

package gitoxide.gix_diff

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*

// 树差异比较结果，包含所有变更条目
public class TreeDiff {
    // 差异条目列表
    public var entries: ArrayList<DiffEntry>

    public init() {
        this.entries = ArrayList<DiffEntry>()
    }
}

// 单个差异条目，描述一个文件的变更信息
public class DiffEntry {
    // 文件路径
    public var path: String
    // 变更前的文件模式，新增时为 None
    public var oldMode: ?EntryMode
    // 变更后的文件模式，删除时为 None
    public var newMode: ?EntryMode
    // 变更前的对象 ID，新增时为 None
    public var oldId: ?ObjectId
    // 变更后的对象 ID，删除时为 None
    public var newId: ?ObjectId
    // 变更状态
    public var status: DiffStatus

    // 构造函数
    // 参数 path：文件路径
    // 参数 status：变更状态
    public init(path: String, status: DiffStatus) {
        this.path = path
        this.oldMode = None
        this.newMode = None
        this.oldId = None
        this.newId = None
        this.status = status
    }
}

// 差异状态枚举，表示文件变更的类型
public enum DiffStatus {
    | Added // 新增文件
    | Modified // 修改文件
    | Deleted // 删除文件
    | Renamed // 重命名文件
    | Copied // 复制文件
    | TypeChange // 类型变更（如文件变符号链接）
}

extend DiffStatus <: Equatable<DiffStatus> {
    public operator func ==(other: DiffStatus): Bool {
        match (this) {
            case DiffStatus.Added => match (other) {
                case DiffStatus.Added => true;
                case _ => false
            }
            case DiffStatus.Modified => match (other) {
                case DiffStatus.Modified => true;
                case _ => false
            }
            case DiffStatus.Deleted => match (other) {
                case DiffStatus.Deleted => true;
                case _ => false
            }
            case DiffStatus.Renamed => match (other) {
                case DiffStatus.Renamed => true;
                case _ => false
            }
            case DiffStatus.Copied => match (other) {
                case DiffStatus.Copied => true;
                case _ => false
            }
            case DiffStatus.TypeChange => match (other) {
                case DiffStatus.TypeChange => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: DiffStatus): Bool {
        !(this == other)
    }
}

// 比较两个树对象的差异
// 参数 oldTree：旧树对象，可为 None（表示空树）
// 参数 newTree：新树对象，可为 None（表示空树）
// 返回值：包含所有差异条目的 TreeDiff
public func diffTrees(oldTree: ?Tree, newTree: ?Tree): TreeDiff {
    let result = TreeDiff()
    var oldEntries = HashMap<String, Entry>()
    var newEntries = HashMap<String, Entry>()

    if (let Some(t) <- oldTree) {
        for (entry in t.entries) {
            oldEntries[entry.filename] = entry
        }
    }
    if (let Some(t) <- newTree) {
        for (entry in t.entries) {
            newEntries[entry.filename] = entry
        }
    }

    for ((name, entry) in newEntries) {
        let old = oldEntries.get(name)
        if (let Some(o) <- old) {
            if (o.oid.toHexString() != entry.oid.toHexString()) {
                let de = DiffEntry(name, DiffStatus.Modified)
                de.oldMode = Some(o.mode)
                de.newMode = Some(entry.mode)
                de.oldId = Some(o.oid)
                de.newId = Some(entry.oid)
                result.entries.add(de)
            }
        } else {
            let de = DiffEntry(name, DiffStatus.Added)
            de.newMode = Some(entry.mode)
            de.newId = Some(entry.oid)
            result.entries.add(de)
        }
    }

    for ((name, entry) in oldEntries) {
        if (!newEntries.contains(name)) {
            let de = DiffEntry(name, DiffStatus.Deleted)
            de.oldMode = Some(entry.mode)
            de.oldId = Some(entry.oid)
            result.entries.add(de)
        }
    }

    result
}
