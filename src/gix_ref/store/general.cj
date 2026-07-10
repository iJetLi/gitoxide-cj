// 文件：general.cj
// 所属包：gix.gix_ref
// 用途：实现通用引用存储，组合松散引用存储和 packed-refs 存储，提供统一的引用查找和遍历接口
// 关键类型：GeneralStore

package gitoxide.gix_ref.store

import gitoxide.gix_hash.*
import gitoxide.gix_ref.*
import std.collection.*

// 通用引用存储类，组合 FileStore（松散引用）和 PackedStore（打包引用）
// 查找引用时优先查找松散引用，未找到再查找打包引用
// 遍历引用时合并两种存储的结果，松散引用优先（去重）
public class GeneralStore {
    // 松散引用文件存储
    public var fileStore: FileStore
    // 打包引用存储，若不存在则为 None
    public var packedStore: ?PackedStore

    // 构造函数
    // 参数 fileStore - 松散引用存储
    // 参数 packedStore - 打包引用存储，无则为 None
    public init(fileStore: FileStore, packedStore: ?PackedStore) {
        this.fileStore = fileStore
        this.packedStore = packedStore
    }

    // 根据引用全名查找引用
    // 优先在松散引用中查找，未找到则在打包引用中查找
    // 参数 name - 引用全名
    // 返回值 - 找到返回 Some(Reference)，均未找到返回 None
    public func find(name: FullName): ?Reference {
        let loose = fileStore.find(name)
        if (let Some(ref) <- loose) {
            return Some(ref)
        }
        if (let Some(packed) <- packedStore) {
            packed.find(name)
        } else {
            None
        }
    }

    // 遍历所有引用（松散引用 + 打包引用，去重）
    // 松散引用优先，打包引用中与松散引用同名的条目会被跳过
    // 返回值 - 所有引用的列表
    public func iter(): ArrayList<Reference> {
        var result = ArrayList<Reference>()
        let looseRefs = fileStore.iter()
        for (ref in looseRefs) {
            result.add(ref)
        }
        if (let Some(packed) <- packedStore) {
            for (entry in packed.iter()) {
                let fullName = FullName.tryFrom(entry.name)
                if (let Some(fn) <- fullName) {
                    result.add(Reference(fn, entry.toTarget(), entry.peeled))
                }
            }
        }
        result
    }
}
