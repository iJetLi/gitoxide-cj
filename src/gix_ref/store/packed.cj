// 文件：packed.cj
// 用途：实现 packed-refs 文件存储，支持打包引用的解析、查找和遍历
// 所属包：gix.gix_ref
// 关键类型：PackedStore, PackedEntry

package gitoxide.gix_ref.store

import gitoxide.gix_hash.*
import gitoxide.gix_ref.*
import std.fs.*
import std.collection.*

// packed-refs 存储，管理 .git/packed-refs 文件中的引用
public class PackedStore {
    // packed-refs 文件路径
    public var path: String
    // 哈希算法类型
    public var hashKind: HashKind
    // 解析得到的条目列表
    public var entries: ArrayList<PackedEntry>

    // 构造函数
    // 参数 path：packed-refs 文件路径
    // 参数 hashKind：哈希算法类型
    public init(path: String, hashKind: HashKind) {
        this.path = path
        this.hashKind = hashKind
        this.entries = ArrayList<PackedEntry>()
    }

    // 打开指定路径的 packed-refs 文件
    // 参数 path：文件路径
    // 参数 hashKind：哈希算法类型
    // 返回值：文件存在且可读返回 PackedStore，否则返回 None
    public static func open(p: String, hashKind: HashKind): ?PackedStore {
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
            let store = PackedStore(p, hashKind)
            store.parse(allBytes.toArray())
            Some(store)
        } catch (_: Exception) {
            None
        }
    }

    // 根据引用名查找打包引用
    // 参数 name：引用的完整名称
    // 返回值：找到返回 Reference，未找到返回 None
    public func find(name: FullName): ?Reference {
        for (entry in entries) {
            if (entry.name == name.value) {
                return Some(Reference(name, entry.toTarget(), entry.peeled))
            }
        }
        None
    }

    // 遍历所有打包引用条目
    // 返回值：所有条目的列表
    public func iter(): ArrayList<PackedEntry> {
        entries
    }

    // 解析 packed-refs 文件的字节数据
    // 跳过注释行（# 开头），解析带 ^ 前缀的 peel 行和普通条目行
    // 参数 data：packed-refs 文件的原始字节数据
    func parse(data: Array<Byte>): Unit {
        var pos: Int64 = 0
        while (pos < data.size) {
            if (data[pos] == UInt8(35)) {
                while (pos < data.size && data[pos] != UInt8(10)) {
                    pos += 1
                }
                if (pos < data.size) {
                    pos += 1
                }
                continue
            }
            if (data[pos] == UInt8(94)) {
                pos += 1
                let nameStart = pos
                while (pos < data.size && data[pos] != UInt8(32)) {
                    pos += 1
                }
                let refName = bytesToStringPacked(data, nameStart, pos)
                pos += 1
                let targetStart = pos
                while (pos < data.size && data[pos] != UInt8(10)) {
                    pos += 1
                }
                let target = bytesToStringPacked(data, targetStart, pos)
                if (pos < data.size) {
                    pos += 1
                }
                entries.add(PackedEntry(refName, target, None))
            } else {
                while (pos < data.size && data[pos] != UInt8(10)) {
                    pos += 1
                }
                if (pos < data.size) {
                    pos += 1
                }
            }
        }
    }
}

// 打包引用条目
public class PackedEntry {
    // 引用名
    public var name: String
    // 目标对象的十六进制哈希值
    public var targetHex: String
    // 已 peel 的 ObjectId，可选
    public var peeled: ?ObjectId

    // 构造函数
    // 参数 name：引用名
    // 参数 targetHex：目标哈希值
    // 参数 peeled：已 peel 的 ObjectId
    public init(name: String, targetHex: String, peeled: ?ObjectId) {
        this.name = name
        this.targetHex = targetHex
        this.peeled = peeled
    }

    // 将条目转换为目标引用类型
    // 返回值：Target.Object 实例
    public func toTarget(): Target {
        Target.Object(ObjectId.fromHex(targetHex))
    }
}

// 将字节数组的指定范围转换为字符串
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：转换得到的字符串
func bytesToStringPacked(data: Array<Byte>, start: Int64, end: Int64): String {
    var sb = StringBuilder()
    var i = start
    while (i < end) {
        sb.append(Rune(data[i]))
        i += 1
    }
    sb.toString()
}
