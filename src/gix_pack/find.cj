// 文件：find.cj
// 用途：全量对齐 Rust gitoxide gix-pack/src/find-traits.rs — Find 接口及辅助类型
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/find.rs
// 关键类型：PackEntryLocation, Find, FindExt, FindEntry

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_utils.*
import std.collection.*

// ============================================================
// 对齐 Rust: gix-pack/src/data/entry/mod.rs Location
// pack 条目在 pack 文件中的位置
// ============================================================

// 对齐 Rust: gix-pack/src/data/entry/mod.rs Location
// 唯一标识 pack bundle 中一个条目的位置
public class PackEntryLocation {
    // pack 的唯一标识，在所属对象数据库范围内唯一
    public var packId: UInt32
    // 条目在磁盘上的大小（字节）
    public var entrySize: Int64
    // 条目在 pack 中的起始偏移
    public var packOffset: Int64

    public init(packId: UInt32, entrySize: Int64, packOffset: Int64) {
        this.packId = packId
        this.entrySize = entrySize
        this.packOffset = packOffset
    }

    // 对齐 Rust: Location::entry_range()
    // 计算条目在 pack 数据中的字节范围
    public func entryRange(baseOffset: Int64): Range<Int64> {
        baseOffset..(baseOffset + entrySize)
    }
}

extend PackEntryLocation <: Equatable<PackEntryLocation> {
    public operator func ==(other: PackEntryLocation): Bool {
        packId == other.packId && entrySize == other.entrySize && packOffset == other.packOffset
    }

    public operator func !=(other: PackEntryLocation): Bool {
        !(this == other)
    }
}

extend PackEntryLocation <: Hashable {
    public func hashCode(): Int64 {
        Int64(packId) ^ entrySize ^ packOffset
    }
}

extend PackEntryLocation <: ToString {
    public func toString(): String {
        "PackEntryLocation(pack_id=${packId}, offset=${packOffset}, size=${entrySize})"
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/find.rs Entry
// pack 中的条目，包含编码后的数据和版本
// ============================================================

// 对齐 Rust: gix-pack/src/find.rs Entry
public class FindEntry {
    // pack 数据中编码的字节（含 header + 压缩数据）
    public var data: Array<Byte>
    // 包含此数据的 pack 文件版本
    public var version: Version

    public init(data: Array<Byte>, version: Version) {
        this.data = data
        this.version = version
    }
}

extend FindEntry <: Equatable<FindEntry> {
    public operator func ==(other: FindEntry): Bool {
        data == other.data && version == other.version
    }

    public operator func !=(other: FindEntry): Bool {
        !(this == other)
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/find.rs Find trait
// 对象查找接口，支持带缓存查找
// ============================================================

// 对齐 Rust: gix-pack/src/find.rs Find trait
// 查找结果：(对象数据, 可选的 pack 位置)
public class FindResult {
    public var objectData: Data
    public var location: ?PackEntryLocation

    public init(objectData: Data, location: ?PackEntryLocation) {
        this.objectData = objectData
        this.location = location
    }
}

// 对齐 Rust: gix-pack/src/find.rs Find trait
// 对象查找接口
public interface Find {
    // 判断对象是否存在于数据库中
    func contains(id: ObjectId): Bool

    // 查找对象，不使用缓存
    // 返回 (对象数据, 可选 pack 位置)，未找到返回 None
    func tryFind(id: ObjectId, buffer: ArrayList<Byte>): PackResult<?FindResult>

    // 查找对象，使用缓存加速
    // pack_cache 用于加速后续查找
    func tryFindCached(id: ObjectId, buffer: ArrayList<Byte>, packCache: DecodeEntry): PackResult<?FindResult>

    // 查找对象的 pack 位置
    // 如果对象不在 pack 中（如 loose object），返回 None
    func locationByOid(id: ObjectId, buffer: ArrayList<Byte>): ?PackEntryLocation

    // 获取指定 pack 中所有偏移和 ObjectId
    func packOffsetsAndOid(packId: UInt32): ?ArrayList<(Int64, ObjectId)>

    // 根据 location 获取 pack 条目
    func entryByLocation(location: PackEntryLocation): ?FindEntry
}

// ============================================================
// 对齐 Rust: gix-pack/src/find.rs FindExt
// Find 接口的便捷扩展方法
// ============================================================

// 对齐 Rust: gix-pack/src/find.rs FindExt
// 为所有实现 Find 的类型提供便捷方法
public class FindExt {
    // 查找对象，失败时抛出异常
    public static func find(finder: Find, id: ObjectId, buffer: ArrayList<Byte>): ?FindResult {
        let result = finder.tryFind(id, buffer)
        match (result) {
            case PackResult.PackOk(v) => v
            case PackResult.PackErr(e) => throw e
        }
    }

    // 查找对象（带缓存），失败时抛出异常
    public static func findCached(finder: Find, id: ObjectId, buffer: ArrayList<Byte>, packCache: DecodeEntry): ?FindResult {
        let result = finder.tryFindCached(id, buffer, packCache)
        match (result) {
            case PackResult.PackOk(v) => v
            case PackResult.PackErr(e) => throw e
        }
    }

    // 查找对象数据，返回 Data 或 None
    public static func findData(finder: Find, id: ObjectId, buffer: ArrayList<Byte>): ?Data {
        let result = finder.tryFind(id, buffer)
        match (result) {
            case PackResult.PackOk(v) =>
                if (v.isSome()) {
                    Some(v.getOrThrow().objectData)
                } else {
                    None
                }
            case PackResult.PackErr(_) => None
        }
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/find.rs
// PackLocation 辅助类型
// ============================================================

// 对齐 Rust: gix-pack/src/data/mod.rs count::PackLocation
// pack 位置信息（pack 内偏移 + pack ID）
public class PackLocationInfo {
    public var packId: UInt32
    public var packOffset: Int64

    public init(packId: UInt32, packOffset: Int64) {
        this.packId = packId
        this.packOffset = packOffset
    }
}

extend PackLocationInfo <: Equatable<PackLocationInfo> {
    public operator func ==(other: PackLocationInfo): Bool {
        packId == other.packId && packOffset == other.packOffset
    }

    public operator func !=(other: PackLocationInfo): Bool {
        !(this == other)
    }
}
