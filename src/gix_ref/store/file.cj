// 文件：file.cj
// 用途：实现 loose ref 文件存储，支持引用的查找、遍历和写入
// 所属包：gix.gix_ref
// 关键类型：FileStore

package gitoxide.gix_ref.store

import gitoxide.gix_hash.*
import gitoxide.gix_ref.*
import gitoxide.gix_utils.*
import std.fs.*
import std.collection.*

// loose ref 文件存储，管理 .git/refs/ 目录下的引用文件
public class FileStore {
    // .git 目录路径
    public var gitDir: String
    // 哈希算法类型
    public var hashKind: HashKind

    // 构造函数
    // 参数 gitDir：.git 目录路径
    // 参数 hashKind：哈希算法类型
    public init(gitDir: String, hashKind: HashKind) {
        this.gitDir = gitDir
        this.hashKind = hashKind
    }

    // 根据引用名查找引用
    // 参数 name：引用的完整名称
    // 返回值：找到返回 Reference，未找到或读取失败返回 None
    public func find(name: FullName): ?Reference {
        let p = refPath(name.value)
        if (!exists(p)) {
            return None
        }
        try {
            let file = File(p, OpenMode.Read)
            var allBytes = ArrayList<UInt8>()
            var buf = Array<UInt8>(4096, {_ => UInt8(0)})
            var n = file.read(buf)
            while (n > 0) {
                var i: Int64 = 0
                while (i < n) {
                    allBytes.add(buf[i])
                    i += 1
                }
                buf = Array<UInt8>(4096, {_ => UInt8(0)})
                n = file.read(buf)
            }
            file.close()
            Reference.fromBytes(allBytes.toArray(), hashKind)
        } catch (_: Exception) {
            None
        }
    }

    // 根据引用全名查找引用，保留引用名
    // 参数 name：引用的完整名称
    // 返回值：找到返回 Reference（名称为传入的 name），未找到或读取失败返回 None
    public func findWithName(name: FullName): ?Reference {
        let p = refPath(name.value)
        if (!exists(p)) {
            return None
        }
        try {
            let file = File(p, OpenMode.Read)
            var allBytes = ArrayList<UInt8>()
            var buf = Array<UInt8>(4096, {_ => UInt8(0)})
            var n = file.read(buf)
            while (n > 0) {
                var i: Int64 = 0
                while (i < n) {
                    allBytes.add(buf[i])
                    i += 1
                }
                buf = Array<UInt8>(4096, {_ => UInt8(0)})
                n = file.read(buf)
            }
            file.close()
            Reference.fromBytesWithName(allBytes.toArray(), hashKind, name)
        } catch (_: Exception) {
            None
        }
    }

    // 遍历所有引用
    // 递归扫描 .git/refs/ 目录下的所有引用文件
    // 返回值：所有引用的列表
    public func iter(): ArrayList<Reference> {
        var result = ArrayList<Reference>()
        let refsDir = gitDir + "/refs"
        collectRefs(refsDir, "refs", result)
        result
    }

    // 写入引用到文件系统
    // 自动创建不存在的父目录
    // 参数 ref：待写入的引用
    public func write(ref: Reference): Unit {
        let p = refPath(ref.name.value)
        let par = parentDir(p)
        try {
            if (!exists(par)) {
                Directory.create(par)
            }
            let file = File(p, OpenMode.Write)
            file.write(ref.toBytes())
            file.close()
        } catch (_: Exception) {}
    }

    // 根据引用名计算文件路径
    // 参数 name：引用名
    // 返回值：引用文件的完整路径
    public func refPath(name: String): String {
        gitDir + "/" + name
    }

    // 递归收集目录下的所有引用
    // 参数 dir：当前扫描的目录
    // 参数 prefix：引用名前缀
    // 参数 result：收集结果的列表
    func collectRefs(dir: String, prefix: String, result: ArrayList<Reference>): Unit {
        if (!exists(dir)) {
            return
        }
        let entries = listDirectory(dir)
        for (name in entries) {
            let fullPath = dir + "/" + name
            let refName = if (prefix.isEmpty()) {
                name
            } else {
                prefix + "/" + name
            }
            if (isDir(fullPath)) {
                collectRefs(fullPath, refName, result)
            } else {
                let refOpt = findWithName(FullName(refName))
                if (let Some(r) <- refOpt) {
                    result.add(r)
                }
            }
        }
    }
}

// 判断路径是否为目录
func isDir(path: String): Bool {
    try {
        let entries = Directory.readFrom(path)
        true
    } catch (_: Exception) {
        false
    }
}

// 获取路径的父目录
// 参数 path：文件路径
// 返回值：父目录路径
func parentDir(path: String): String {
    let idx = path.lastIndexOf('/')
    if (let Some(i) <- idx) {
        substringStr(path, 0, i)
    } else {
        path
    }
}
