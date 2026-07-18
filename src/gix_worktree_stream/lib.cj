// 文件：lib.cj
// 用途：工作树流式输出，用于逐条输出树对象的条目（checkout 时按流式生成）
// 所属包：gix.gix_worktree_stream
// 关键类型：WorktreeStream, StreamEntry, StreamEntryMode, StreamEntryKind
// 对齐来源：gix-worktree-stream/src/lib.rs, gix-worktree-stream/src/entry.rs, gix-worktree-stream/src/protocol.rs

package gitoxide.gix_worktree_stream

import gitoxide.gix_object.*
import gitoxide.gix_hash.*
import std.collection.*

// ============================================================
// StreamEntryKind - 对齐 gix-worktree-stream/src/entry.rs Entry 内部类型
// ============================================================

// 流条目的内容类型
// 对齐 Rust: Entry 内部的内容形式
public enum StreamEntryKind {
    // 普通文件（blob）内容
    | Blob
    // 目录条目
    | Tree
}

extend StreamEntryKind <: Equatable<StreamEntryKind> {
    public operator func ==(other: StreamEntryKind): Bool {
        match (this) {
            case StreamEntryKind.Blob => match (other) {
                case StreamEntryKind.Blob => true;
                case _ => false
            }
            case StreamEntryKind.Tree => match (other) {
                case StreamEntryKind.Tree => true;
                case _ => false
            }
        }
    }
    public operator func !=(other: StreamEntryKind): Bool {
        !(this == other)
    }
}

// ============================================================
// StreamEntry - 对齐 gix-worktree-stream/src/entry.rs Entry
// ============================================================

// 流条目，表示工作树流中的一个文件条目
// 对齐 Rust: Entry
public class StreamEntry {
    // 文件相对路径
    public var path: String
    // 文件模式（权限/类型）
    public var mode: EntryMode
    // 对象 ID
    public var id: ObjectId

    // 参数 path: 文件相对路径
    // 参数 mode: 文件模式
    // 参数 id: 对象 ID
    public init(path: String, mode: EntryMode, id: ObjectId) {
        this.path = path
        this.mode = mode
        this.id = id
    }

    // 返回条目类型
    public func kind(): StreamEntryKind {
        if (mode.isTree()) {
            StreamEntryKind.Tree
        } else {
            StreamEntryKind.Blob
        }
    }

    // 是否为目录条目
    public func isTree(): Bool {
        mode.isTree()
    }

    // 是否为普通文件
    public func isBlob(): Bool {
        !mode.isTree()
    }
}

// ============================================================
// WorktreeStream - 对齐 gix-worktree-stream/src/lib.rs Stream
// ============================================================

// 工作树流，按条目逐个收集树对象内容，用于流式检出
// 对齐 Rust: Stream
public class WorktreeStream {
    // 流中的条目列表
    public var entries: ArrayList<StreamEntry>

    // 初始化空流
    public init() {
        this.entries = ArrayList<StreamEntry>()
    }

    // 添加一条流条目
    // 参数 path: 文件相对路径
    // 参数 mode: 文件模式
    // 参数 id: 对象 ID
    public func addEntry(path: String, mode: EntryMode, id: ObjectId): Unit {
        entries.add(StreamEntry(path, mode, id))
    }

    // 返回下一个条目（消费式）
    // 对齐 Rust: Stream::next_entry()
    public func nextEntry(): ?StreamEntry {
        if (entries.size == 0) {
            None
        } else {
            let entry = entries[0]
            entries.remove(at: 0)
            Some(entry)
        }
    }

    // 是否还有条目
    public func hasNext(): Bool {
        entries.size > 0
    }
}

// ============================================================
// Protocol 常量 - 对齐 gix-worktree-stream/src/protocol.rs
// ============================================================

// 流协议中的模式到字节转换
// 对齐 Rust: mode_to_byte
public func streamModeToByte(mode: EntryMode): UInt8 {
    match (mode.kind()) {
        case EntryKind.Tree => UInt8(0)
        case EntryKind.Blob => UInt8(1)
        case EntryKind.BlobExecutable => UInt8(1)
        case EntryKind.Link => UInt8(2)
        case EntryKind.Commit => UInt8(3)
    }
}

// 流协议中的字节到模式转换
// 对齐 Rust: byte_to_mode
public func streamByteToMode(byte: UInt8): ?EntryMode {
    if (byte == UInt8(0)) {
        return Some(EntryMode(0o040000))
    }
    if (byte == UInt8(1)) {
        return Some(EntryMode(0o100644))
    }
    if (byte == UInt8(2)) {
        return Some(EntryMode(0o120000))
    }
    if (byte == UInt8(3)) {
        return Some(EntryMode(0o160000))
    }
    None
}

// 流协议中的哈希类型到字节转换
// 对齐 Rust: hash_to_byte
public func streamHashKindToByte(kind: HashKind): UInt8 {
    match (kind) {
        case HashKind.Sha1 => UInt8(1)
        case HashKind.Sha256 => UInt8(2)
    }
}

// 流协议中的字节到哈希类型转换
// 对齐 Rust: byte_to_hash
public func streamByteToHashKind(byte: UInt8): ?HashKind {
    if (byte == UInt8(1)) {
        return Some(HashKind.Sha1)
    }
    if (byte == UInt8(2)) {
        return Some(HashKind.Sha256)
    }
    None
}
