// 文件：pack_error.cj
// 用途：全量对齐 Rust gitoxide gix-pack 错误类型体系
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/{data/entry/decode,cache/delta,cache/delta/traverse,cache/delta/from_offsets}.rs
// 关键类型：PackResult, PackError, EntryDecodeError, DeltaTreeError, DeltaTraverseError, FromOffsetsError

package gitoxide.gix_pack

import gitoxide.gix_hash.ObjectId
import gitoxide.gix_error.GixError

// 对齐 Rust: Result<T, E> — 仓颉标准库无 Result，自行定义
// PackResult<T> = PackOk(value: T) | PackErr(error: PackError)
// 对齐 Rust: gix-pack 中 Result<T, Error> 模式
// 区分"未找到"（Ok(None)）和"读取失败"（Err）
public enum PackResult<T> {
    | PackOk(T)
    | PackErr(PackError)
}

extend<T> PackResult<T> {
    // 是否成功
    public func isOk(): Bool {
        match (this) {
            case PackResult.PackOk(_) => true
            case PackResult.PackErr(_) => false
        }
    }

    // 是否失败
    public func isErr(): Bool {
        !isOk()
    }

    // 获取成功值，失败时抛异常
    public func unwrap(): T {
        match (this) {
            case PackResult.PackOk(v) => v
            case PackResult.PackErr(e) => throw e
        }
    }

    // 获取错误，成功时返回 None
    public func err(): ?PackError {
        match (this) {
            case PackResult.PackOk(_) => None
            case PackResult.PackErr(e) => Some(e)
        }
    }

    // 成功时映射值
    public func map<R>(f: (T) -> R): PackResult<R> {
        match (this) {
            case PackResult.PackOk(v) => PackResult.PackOk(f(v))
            case PackResult.PackErr(e) => PackResult.PackErr(e)
        }
    }

    // 失败时返回默认值
    public func unwrapOr(default: T): T {
        match (this) {
            case PackResult.PackOk(v) => v
            case PackResult.PackErr(_) => default
        }
    }
}

// 对齐 Rust: gix-pack/src/data/entry/decode.rs Error
// Entry::from_bytes() 返回的错误
public class EntryDecodeError <: GixError {
    public init(message: String) {
        super(message)
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/mod.rs Error
// Delta Tree 构建过程中的错误
public class DeltaTreeError <: GixError {
    public var lastPackOffset: Int64
    public var packOffset: Int64

    public init(lastPackOffset: Int64, packOffset: Int64) {
        super("Pack offsets must only increment. Previous: ${lastPackOffset}, current: ${packOffset}")
        this.lastPackOffset = lastPackOffset
        this.packOffset = packOffset
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Error
// Delta Tree 遍历过程中的错误
public class DeltaTraverseError <: GixError {
    public var kind: DeltaTraverseErrorKind

    public init(kind: DeltaTraverseErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum DeltaTraverseErrorKind {
    | ZlibInflate(String)
    | ResolveFailed(Int64)
    | EntryDecode(String)
    | Interrupted
    | OutOfMemory
    | OutOfPackRefDelta(Int64)
    | DeltaApply(String)
}

extend DeltaTraverseErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case DeltaTraverseErrorKind.ZlibInflate(msg) => "Zlib inflate error: ${msg}"
            case DeltaTraverseErrorKind.ResolveFailed(offset) => "Failed to resolve pack entry at offset ${offset}"
            case DeltaTraverseErrorKind.EntryDecode(msg) => "Entry decode error: ${msg}"
            case DeltaTraverseErrorKind.Interrupted => "Interrupted"
            case DeltaTraverseErrorKind.OutOfMemory => "Entry too large to fit in memory"
            case DeltaTraverseErrorKind.OutOfPackRefDelta(offset) => "Out-of-pack ref-delta base at offset ${offset}"
            case DeltaTraverseErrorKind.DeltaApply(msg) => "Delta apply error: ${msg}"
        }
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/from_offsets.rs Error
// Tree::from_offsets_in_pack() 返回的错误
public class FromOffsetsError <: GixError {
    public var kind: FromOffsetsErrorKind

    public init(kind: FromOffsetsErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum FromOffsetsErrorKind {
    | Io(String)
    | Header(String)
    | UnresolvedRefDelta(ObjectId)
    | Tree(DeltaTreeError)
    | Interrupted
}

extend FromOffsetsErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case FromOffsetsErrorKind.Io(msg) => "IO error: ${msg}"
            case FromOffsetsErrorKind.Header(msg) => "Header error: ${msg}"
            case FromOffsetsErrorKind.UnresolvedRefDelta(id) => "Unresolved ref-delta: ${id.toHexString()}"
            case FromOffsetsErrorKind.Tree(err) => "Tree error: ${err.message}"
            case FromOffsetsErrorKind.Interrupted => "Interrupted"
        }
    }
}

// 对齐 Rust: gix-pack/src/index/verify.rs 和 gix-pack/src/data/file/verify.rs
// 索引/数据文件校验错误
public class PackVerifyError <: GixError {
    public var kind: PackVerifyErrorKind

    public init(kind: PackVerifyErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum PackVerifyErrorKind {
    | ChecksumMismatch(String)
    | FanoutNonMonotonic(Int64, Int64)
    | Crc32Mismatch(Int64, Int64, Int64)
    | ObjectCountMismatch(Int64, Int64)
    | TruncatedData
}

extend PackVerifyErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case PackVerifyErrorKind.ChecksumMismatch(msg) => "Checksum mismatch: ${msg}"
            case PackVerifyErrorKind.FanoutNonMonotonic(i, j) => "Fanout non-monotonic at index ${i}: ${j}"
            case PackVerifyErrorKind.Crc32Mismatch(idx, expected, actual) => "CRC32 mismatch at entry ${idx}: expected ${expected}, got ${actual}"
            case PackVerifyErrorKind.ObjectCountMismatch(expected, actual) => "Object count mismatch: expected ${expected}, got ${actual}"
            case PackVerifyErrorKind.TruncatedData => "Truncated pack data"
        }
    }
}

// 统一的 Pack 错误类型
// 对齐 Rust: gix-pack 中各种 Result<T, Error> 模式
// 仓颉差异：Rust 用 enum Error，仓颉用 class 继承体系 + kind 枚举
public class PackError <: GixError {
    public var kind: PackErrorKind

    public init(kind: PackErrorKind) {
        super(kind.toString())
        this.kind = kind
    }
}

public enum PackErrorKind {
    | EntryDecode(EntryDecodeError)
    | DeltaTree(DeltaTreeError)
    | DeltaTraverse(DeltaTraverseError)
    | FromOffsets(FromOffsetsError)
    | Verify(PackVerifyError)
    | Io(String)
    | NotFound(ObjectId)
    | InvalidData(String)
    | Interrupted
}

extend PackErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case PackErrorKind.EntryDecode(err) => err.message
            case PackErrorKind.DeltaTree(err) => err.message
            case PackErrorKind.DeltaTraverse(err) => err.message
            case PackErrorKind.FromOffsets(err) => err.message
            case PackErrorKind.Verify(err) => err.message
            case PackErrorKind.Io(msg) => "IO error: ${msg}"
            case PackErrorKind.NotFound(id) => "Object not found: ${id.toHexString()}"
            case PackErrorKind.InvalidData(msg) => "Invalid data: ${msg}"
            case PackErrorKind.Interrupted => "Interrupted"
        }
    }
}
