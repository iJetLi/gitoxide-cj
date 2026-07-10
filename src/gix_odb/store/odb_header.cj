// 文件：store/odb_header.cj
// 用途：定义 ODB 层的头部类型（区分 Loose/Packed 来源）+ 辅助函数
// 所属包：gix.gix_odb.store
// 对齐来源：gix-odb/src/find.rs Header 枚举
// 关键类型：OdbHeader、PackedHeaderOutcome

package gitoxide.gix_odb.store

import gitoxide.gix_hash.*
import gitoxide.gix_object.*

// 对齐 Rust: gix-odb/src/find.rs Header
// ODB 层头部信息，区分对象来源（松散 vs 打包）
public enum OdbHeader {
    // 对象位于松散存储中
    // 对齐 Rust: Header::Loose { kind, size }
    | Loose(ObjectKind, Int64)
    // 对象位于 pack 中
    // 对齐 Rust: Header::Packed(header::Outcome)
    | Packed(PackedHeaderOutcome)
}

// 对齐 Rust: gix-pack/src/data/file/decode/header.rs Outcome
// Pack 头部解码结果
public class PackedHeaderOutcome {
    // 对象类型
    public var kind: ObjectKind
    // 解压后对象大小
    public var objectSize: Int64
    // delta 链深度
    public var numDeltas: Int64

    public init(kind: ObjectKind, objectSize: Int64, numDeltas: Int64) {
        this.kind = kind
        this.objectSize = objectSize
        this.numDeltas = numDeltas
    }
}

// OdbHeader 便捷方法
extend OdbHeader {
    // 对齐 Rust: Header::kind()
    // 返回对象类型
    public func kind(): ObjectKind {
        match (this) {
            case OdbHeader.Loose(k, _) => k
            case OdbHeader.Packed(outcome) => outcome.kind
        }
    }

    // 对齐 Rust: Header::size()
    // 返回对象大小
    public func size(): Int64 {
        match (this) {
            case OdbHeader.Loose(_, s) => s
            case OdbHeader.Packed(outcome) => outcome.objectSize
        }
    }

    // 对齐 Rust: Header::num_deltas()
    // 返回 delta 链深度（仅 Packed 有意义）
    public func numDeltas(): ?Int64 {
        match (this) {
            case OdbHeader.Loose(_, _) => None
            case OdbHeader.Packed(outcome) => Some(outcome.numDeltas)
        }
    }

    // 是否来自 pack
    public func isPacked(): Bool {
        match (this) {
            case OdbHeader.Packed(_) => true
            case OdbHeader.Loose(_, _) => false
        }
    }

    // 是否来自松散存储
    public func isLoose(): Bool {
        !isPacked()
    }
}

// 从对象数据中构造松散头部信息（兼容旧接口）
// 参数 data：完整的对象数据（包含类型和内容）
// 返回值：包含对象类型和数据大小的 Header
public func headerFromData(data: Data): Header {
    Header(data.kind, data.data.size)
}
