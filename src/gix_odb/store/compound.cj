// 文件：store/compound.cj
// 用途：复合存储，组合松散存储（LooseStore）和动态存储（DynamicStore），提供统一的对象读写接口
// 所属包：gix.gix_odb
// 对齐来源：gix-odb/src/store_impls/dynamic/find.rs — 先查 pack 再查 loose
// 关键类型：CompoundStore

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_pack.*
import std.collection.*

// 复合存储，将松散对象存储和包文件动态存储组合在一起
// 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs
// 查找优先级：先查 pack（快），再查 loose（慢）
public class CompoundStore {
    // 松散对象存储，负责 .git/objects/xx/... 格式的单个对象文件读写
    public var loose: LooseStore
    // 动态存储，负责发现和管理 pack 文件
    public var dynamic: DynamicStore

    // 构造函数
    // 参数 loose：松散对象存储实例
    // 参数 dynamic：动态存储实例
    public init(loose: LooseStore, dynamic: DynamicStore) {
        this.loose = loose
        this.dynamic = dynamic
    }

    // 尝试根据对象 ID 查找对象数据
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs try_find_cached_inner
    // 查找优先级：先查 pack（快），再查 loose（慢）
    // 参数 id：要查找的对象 ID
    // 返回值：找到则返回 Data，未找到返回 None
    public func tryFind(id: ObjectId): ?Data {
        // 先查 pack
        let packResult = dynamic.tryFind(id)
        if (packResult.isSome()) {
            return packResult
        }
        // 再查 loose
        loose.read(id)
    }

    // 尝试根据对象 ID 查找对象数据，返回带位置信息的查找结果
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs try_find_cached_inner
    public func tryFindWithLocation(id: ObjectId, buffer: ArrayList<Byte>): PackResult<?FindResult> {
        // 先查 pack
        let packResult = dynamic.tryFindWithLocation(id, buffer)
        if (packResult.isOk()) {
            let data = packResult.unwrap()
            if (data.isSome()) {
                return packResult
            }
        }
        // 再查 loose — loose 不返回位置信息
        let looseData = loose.read(id)
        if (looseData.isSome()) {
            PackResult.PackOk(Some(FindResult(looseData.getOrThrow(), None)))
        } else {
            PackResult.PackOk(None)
        }
    }

    // 尝试根据对象 ID 获取对象头部信息
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/header.rs
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 Header（包含类型和大小），未找到返回 None
    public func tryHeader(id: ObjectId): ?Header {
        // 先查 pack
        let packData = dynamic.tryFind(id)
        if (packData.isSome()) {
            let d = packData.getOrThrow()
            return Some(Header(d.kind, d.data.size))
        }
        // 再查 loose
        let data = loose.read(id)
        if (let Some(d) <- data) {
            Some(Header(d.kind, d.data.size))
        } else {
            None
        }
    }

    // 检查指定 ID 的对象是否存在
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/find.rs Find::contains
    // 参数 id：要检查的对象 ID
    // 返回值：存在返回 true，否则返回 false
    public func exists(id: ObjectId): Bool {
        // 先查 pack
        if (dynamic.contains(id)) {
            return true
        }
        // 再查 loose
        loose.exists(id)
    }

    // 将对象写入松散存储
    // 参数 kind：对象类型
    // 参数 data：对象的原始字节数据
    // 返回值：写入后生成的对象 ID
    public func write(kind: ObjectKind, data: Array<Byte>): ObjectId {
        loose.write(kind, data)
    }

    // 尝试根据对象 ID 获取 ODB 层头部信息（区分 Loose/Packed 来源）
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/header.rs
    // 参数 id：要查询的对象 ID
    // 返回值：找到则返回 OdbHeader，未找到返回 None
    public func tryOdbHeader(id: ObjectId): ?OdbHeader {
        // 先查 pack
        let packData = dynamic.tryFind(id)
        if (packData.isSome()) {
            let d = packData.getOrThrow()
            return Some(OdbHeader.Packed(PackedHeaderOutcome(d.kind, d.data.size, 0)))
        }
        // 再查 loose
        let data = loose.read(id)
        if (data.isSome()) {
            let d = data.getOrThrow()
            return Some(OdbHeader.Loose(d.kind, d.data.size))
        }
        None
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/iter.rs
    // ============================================================

    // 遍历所有对象 ID（先 pack 后 loose，可能包含重复）
    // 对齐 Rust: Handle::iter() -> AllObjects
    public func iter(ordering: IterOrdering): AllObjectsIterator {
        let looseIds = loose.iter()
        dynamic.iterWithLoose(looseIds, ordering)
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/prefix.rs
    // ============================================================

    // 前缀查找：在所有 pack 索引和 loose 对象中查找匹配前缀的对象
    // 对齐 Rust: Handle::lookup_prefix() -> Option<Outcome>
    public func lookupPrefix(prefix: Prefix): ?PrefixLookupOutcome {
        // 先查 pack
        var result = dynamic.lookupPrefix(prefix)
        // 如果 pack 中有歧义，直接返回
        if (result.isSome()) {
            match (result.getOrThrow()) {
                case PrefixLookupOutcome.Ambiguous => return Some(PrefixLookupOutcome.Ambiguous)
                case PrefixLookupOutcome.Unique(_) => ()
            }
        }
        // 再查 loose
        let looseIds = loose.iter()
        var candidate: ?ObjectId = None
        // 提取 pack 中的候选
        if (let Some(PrefixLookupOutcome.Unique(packOid)) <- result) {
            candidate = Some(packOid)
        }
        // 在 loose 中查找匹配前缀的对象
        for (oid in looseIds) {
            if (prefix.matches(oid)) {
                if (let Some(existing) <- candidate) {
                    if (existing != oid) {
                        return Some(PrefixLookupOutcome.Ambiguous)
                    }
                } else {
                    candidate = Some(oid)
                }
            }
        }
        if (let Some(oid) <- candidate) {
            Some(PrefixLookupOutcome.Unique(oid))
        } else {
            None
        }
    }

    // ============================================================
    // 对齐 Rust: gix-odb/src/store_impls/dynamic/prefix.rs packed_object_count
    // ============================================================

    // 返回所有 pack 中的对象总数
    public func packedObjectCount(): Int64 {
        dynamic.packedObjectCount()
    }
}
