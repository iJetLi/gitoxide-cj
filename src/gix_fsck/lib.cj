// 文件：lib.cj
// 用途：提供仓库完整性检查（fsck）功能，检测缺失对象、损坏对象和悬空引用
// 所属包：gix.gix_fsck
// 关键类型：FsckResult, FsckError, FsckErrorKind
// 关键函数：checkRepository

package gitoxide.gix_fsck

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_ref.*
import gitoxide.repository.*
import std.collection.*

// fsck 检查结果，包含所有发现的错误
public class FsckResult {
    // 发现的错误列表
    public var errors: ArrayList<FsckError>

    public init() {
        this.errors = ArrayList<FsckError>()
    }

    // 判断仓库是否无错误
    // 返回值：无错误时返回 true
    public func isClean(): Bool {
        errors.size == 0
    }
}

// 单个 fsck 错误
public class FsckError {
    // 错误类型
    public var kind: FsckErrorKind
    // 相关的对象 ID，可选
    public var objectId: ?ObjectId
    // 错误描述信息
    public var message: String

    // 构造函数
    // 参数 kind：错误类型
    // 参数 message：错误描述
    public init(kind: FsckErrorKind, message: String) {
        this.kind = kind
        this.objectId = None
        this.message = message
    }
}

// fsck 错误类型枚举
public enum FsckErrorKind {
    | MissingObject // 缺失对象
    | CorruptObject // 损坏对象
    | DanglingReference // 悬空引用
    | MissingReference // 缺失引用
}

extend FsckErrorKind <: Equatable<FsckErrorKind> {
    public operator func ==(other: FsckErrorKind): Bool {
        match (this) {
            case FsckErrorKind.MissingObject =>
                match (other) {
                    case FsckErrorKind.MissingObject => true
                    case _ => false
                }
            case FsckErrorKind.CorruptObject =>
                match (other) {
                    case FsckErrorKind.CorruptObject => true
                    case _ => false
                }
            case FsckErrorKind.DanglingReference =>
                match (other) {
                    case FsckErrorKind.DanglingReference => true
                    case _ => false
                }
            case FsckErrorKind.MissingReference =>
                match (other) {
                    case FsckErrorKind.MissingReference => true
                    case _ => false
                }
        }
    }
}

extend FsckErrorKind <: ToString {
    public func toString(): String {
        match (this) {
            case FsckErrorKind.MissingObject => "MissingObject"
            case FsckErrorKind.CorruptObject => "CorruptObject"
            case FsckErrorKind.DanglingReference => "DanglingReference"
            case FsckErrorKind.MissingReference => "MissingReference"
        }
    }
}

// 检查仓库的完整性
// 遍历所有引用，验证引用指向的对象是否存在
// 参数 repo：待检查的仓库
// 返回值：包含所有发现的错误的 FsckResult
public func checkRepository(repo: Repository): FsckResult {
    let result = FsckResult()
    let refs = repo.iterReferences()
    for (ref in refs) {
        match (ref.target) {
            case Target.Object(id) => checkObjectRef(repo, id, ref.name.value, result)
            case Target.Symbolic(_) => ()
        }
    }
    result
}

func checkObjectRef(repo: Repository, id: ObjectId, refName: String, result: FsckResult): Unit {
    let obj = repo.readObject(id)
    if (obj.isNone()) {
        let err = FsckError(FsckErrorKind.MissingObject, "missing object for ref " + refName)
        err.objectId = Some(id)
        result.errors.add(err)
    }
}
