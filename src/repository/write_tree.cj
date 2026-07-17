// 文件：write_tree.cj
// 用途：从索引（index）构建 tree 对象，实现 git write-tree 的核心逻辑
// 所属包：gix.repository
// 关键类型：WriteTreeQuery
// 对齐原版：git write-tree / gix-object/src/tree/editor.rs

package gitoxide.repository

import gitoxide.gix_index.*
import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*
import std.fs.*

// 从索引构建 tree 对象的查询器
// 对齐原版：git write-tree 将暂存区内容写入 tree 对象
public class WriteTreeQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 从索引构建 tree 并写入对象库
    // 对齐原版：git write-tree
    // 返回值：根 tree 的 ObjectId，无索引时返回 None
    public func writeTree(): ?ObjectId {
        let indexPath = repo.gitDir + "/index"
        println("[writeTree] indexPath=" + indexPath)
        println("[writeTree] exists=" + exists(indexPath).toString())
        println("[writeTree] gitDir=" + repo.gitDir)
        let indexFile = IndexFile.open(indexPath)
        if (let Some(idx) <- indexFile) {
            println("[writeTree] entries=" + idx.entries.size.toString())
            if (idx.entries.size == 0) {
                return None
            }
            Some(buildTreeFromEntries(repo, idx.entries))
        } else {
            println("[writeTree] indexFile is None")
            None
        }
    }
}

// 目录条目分组，用于按目录组织索引条目
class DirGroup {
    var dirPath: String
    var entries: ArrayList<IndexEntry>

    init(dirPath: String) {
        this.dirPath = dirPath
        this.entries = ArrayList<IndexEntry>()
    }
}

// 从索引条目列表构建 tree 层级结构并写入 ODB
// 算法：
// 1. 将所有条目按路径的目录前缀分组
// 2. 递归地从最深层子目录开始构建 tree
// 3. 每个目录对应一个 tree 对象，包含该目录下的直接子项（blob/subtree）
// 4. 条目按 Git tree 排序规则排序（目录名后追加 '/'）
func buildTreeFromEntries(repo: Repository, entries: ArrayList<IndexEntry>): ObjectId {
    var dirGroups = ArrayList<DirGroup>()
    for (entry in entries) {
        let dirPart = parentDir(entry.path)
        var foundGroup: ?DirGroup = None
        for (g in dirGroups) {
            if (g.dirPath == dirPart) {
                foundGroup = Some(g)
            }
        }
        if (let Some(g) <- foundGroup) {
            g.entries.add(entry)
        } else {
            let newGroup = DirGroup(dirPart)
            newGroup.entries.add(entry)
            dirGroups.add(newGroup)
        }
    }
    buildTreeRecursive(repo, "", dirGroups)
}

// 递归构建指定目录的 tree 对象
// 参数 dirPath：当前目录路径（相对于仓库根目录，如 "" 或 "src/lib"）
// 参数 dirGroups：按目录分组的索引条目列表
// 返回值：该目录对应的 tree 对象的 ObjectId
func buildTreeRecursive(repo: Repository, dirPath: String, dirGroups: ArrayList<DirGroup>): ObjectId {
    var treeEntries = ArrayList<Entry>()
    for (g in dirGroups) {
        if (g.dirPath == dirPath) {
            for (entry in g.entries) {
                let fileName = baseName(entry.path)
                let mode = indexModeToEntryMode(entry.mode)
                println("[buildTree] dir=" + dirPath + " file=" + fileName + " mode=" + mode.value.toString())
                treeEntries.add(Entry(mode, fileName, entry.id))
            }
        }
    }
    let childDirs = findChildDirs(dirPath, dirGroups)
    println("[buildTree] dir=" + dirPath + " childDirs=" + childDirs.size.toString())
    for (childDir in childDirs) {
        println("[buildTree] dir=" + dirPath + " childDir=" + childDir)
        let childTreeId = buildTreeRecursive(repo, childDir, dirGroups)
        let dirName = if (dirPath.size > 0) {
            childDir[(dirPath.size + 1)..]
        } else {
            childDir
        }
        treeEntries.add(Entry(EntryMode.Directory(), dirName, childTreeId))
    }
    sortTreeEntries(treeEntries)
    let tree = Tree(treeEntries)
    let treeBytes = tree.writeToArray()
    repo.writeObject(ObjectKind.Tree, treeBytes)
}

// 获取文件路径的父目录部分
// 如 "src/lib/utils.cj" → "src/lib"
// 如 "README.md" → ""
func parentDir(path: String): String {
    let lastSlash = path.lastIndexOf("/")
    if (let Some(idx) <- lastSlash) {
        path[0..idx]
    } else {
        ""
    }
}

// 获取文件路径的文件名部分
// 如 "src/lib/utils.cj" → "utils.cj"
// 如 "README.md" → "README.md"
func baseName(path: String): String {
    let lastSlash = path.lastIndexOf("/")
    if (let Some(idx) <- lastSlash) {
        path[(idx + 1)..]
    } else {
        path
    }
}

// 将 index 条目的 mode 值转换为 EntryMode
// Git index 中的 mode 值：0o100644（普通文件）、0o100755（可执行文件）、
// 0o120000（符号链接）、0o040000（目录）、0o160000（子模块 commit）
func indexModeToEntryMode(mode: Int64): EntryMode {
    if (mode == 0o100755) {
        EntryMode.Executable()
    } else if (mode == 0o120000) {
        EntryMode.Link()
    } else if (mode == 0o160000) {
        EntryMode.Commit()
    } else if (mode == 0o040000) {
        EntryMode.Directory()
    } else {
        EntryMode.Regular()
    }
}

// 查找指定目录的直接子目录
// 如 dirPath="src"，dirGroups 包含 "src/lib"、"src/lib/core"、"src/test"
// 返回 ["src/lib", "src/test"]（不包含 "src/lib/core"，因为它是 "src/lib" 的子目录）
func findChildDirs(dirPath: String, dirGroups: ArrayList<DirGroup>): ArrayList<String> {
    var candidates = ArrayList<String>()
    let prefix = if (dirPath.size > 0) { dirPath + "/" } else { "" }
    let prefixLen = prefix.size
    for (g in dirGroups) {
        let key = g.dirPath
        if (dirPath.size == 0) {
            if (!key.contains("/") && key.size > 0) {
                var alreadyAdded = false
                for (c in candidates) {
                    if (c == key) { alreadyAdded = true }
                }
                if (!alreadyAdded) { candidates.add(key) }
            } else if (key.contains("/") && key.size > 0) {
                let firstSlash = key.indexOf("/")
                if (let Some(idx) <- firstSlash) {
                    let firstDir = key[0..idx]
                    var alreadyAdded = false
                    for (c in candidates) {
                        if (c == firstDir) { alreadyAdded = true }
                    }
                    if (!alreadyAdded) { candidates.add(firstDir) }
                }
            }
        } else {
            if (key.startsWith(prefix) && key.size > prefixLen) {
                let rest = key[prefixLen..]
                if (rest.contains("/")) {
                    let firstSlash = rest.indexOf("/")
                    if (let Some(idx) <- firstSlash) {
                        let firstDir = key[0..(prefixLen + idx)]
                        var alreadyAdded = false
                        for (c in candidates) {
                            if (c == firstDir) { alreadyAdded = true }
                        }
                        if (!alreadyAdded) { candidates.add(firstDir) }
                    }
                } else {
                    var alreadyAdded = false
                    for (c in candidates) {
                        if (c == key) { alreadyAdded = true }
                    }
                    if (!alreadyAdded) { candidates.add(key) }
                }
            }
        }
    }
    candidates
}

// 按 Git tree 排序规则排序条目
// Git tree 排序规则：blob 条目按文件名排序，tree 条目按目录名 + '/' 排序
// 即同名的 blob 和 tree，tree 排在后面
func sortTreeEntries(entries: ArrayList<Entry>): Unit {
    var i: Int64 = 0
    while (i < entries.size) {
        var j: Int64 = i + 1
        while (j < entries.size) {
            let a = entries[i]
            let b = entries[j]
            let aKey = if (a.mode.isTree()) { a.filename + "/" } else { a.filename }
            let bKey = if (b.mode.isTree()) { b.filename + "/" } else { b.filename }
            if (aKey > bKey) {
                entries[i] = b
                entries[j] = a
            }
            j += 1
        }
        i += 1
    }
}
