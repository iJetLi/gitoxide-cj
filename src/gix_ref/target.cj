// 文件：target.cj
// 所属包：gix.gix_ref
// 用途：定义引用目标枚举类型及引用分类枚举，描述引用指向的对象或符号引用
// 关键类型：Target, TargetRef, RefKind, RefCategory

package gitoxide.gix_ref

import gitoxide.gix_hash.*

// 引用目标枚举，表示引用指向的最终目标
// Object - 直接指向一个 Git 对象（通过 ObjectId）
// Symbolic - 符号引用，指向另一个引用（通过 FullName）
public enum Target {
    | Object(ObjectId)
    | Symbolic(FullName)
}

// 引用目标引用枚举，与 Target 类似但语义上表示引用而非拥有
// ObjectRef - 指向对象的引用
// SymbolicRef - 指向符号引用的引用
public enum TargetRef {
    | ObjectRef(ObjectId)
    | SymbolicRef(FullName)
}

// 引用类型枚举，标识引用是对象引用还是符号引用
public enum RefKind {
    | Object
    | Symbolic
}

extend RefKind <: Equatable<RefKind> {
    public operator func ==(other: RefKind): Bool {
        match (this) {
            case RefKind.Object => match (other) {
                case RefKind.Object => true
                case _ => false
            }
            case RefKind.Symbolic => match (other) {
                case RefKind.Symbolic => true
                case _ => false
            }
        }
    }
}

// 引用分类枚举，标识引用所属的类别
// Tag - 标签引用（refs/tags/）
// LocalBranch - 本地分支引用（refs/heads/）
// RemoteBranch - 远程分支引用（refs/remotes/）
// Note - 笔记引用（refs/notes/）
// PseudoRef - 伪引用（不以 refs/ 开头，如 HEAD、MERGE_HEAD）
// MainPseudoRef - 主伪引用
// MainRef - 主引用
// Bisect - 二分查找引用
// Rewritten - 重写引用
// WorktreePrivate - 工作区私有引用
public enum RefCategory {
    | Tag
    | LocalBranch
    | RemoteBranch
    | Note
    | PseudoRef
    | MainPseudoRef
    | MainRef
    | Bisect
    | Rewritten
    | WorktreePrivate
}

extend RefCategory <: Equatable<RefCategory> {
    public operator func ==(other: RefCategory): Bool {
        match (this) {
            case Tag => match (other) {
                case Tag => true;
                case _ => false
            }
            case LocalBranch => match (other) {
                case LocalBranch => true;
                case _ => false
            }
            case RemoteBranch => match (other) {
                case RemoteBranch => true;
                case _ => false
            }
            case Note => match (other) {
                case Note => true;
                case _ => false
            }
            case PseudoRef => match (other) {
                case PseudoRef => true;
                case _ => false
            }
            case MainPseudoRef => match (other) {
                case MainPseudoRef => true;
                case _ => false
            }
            case MainRef => match (other) {
                case MainRef => true;
                case _ => false
            }
            case Bisect => match (other) {
                case Bisect => true;
                case _ => false
            }
            case Rewritten => match (other) {
                case Rewritten => true;
                case _ => false
            }
            case WorktreePrivate => match (other) {
                case WorktreePrivate => true;
                case _ => false
            }
        }
    }
}

// 获取引用目标的类型（对象引用或符号引用）
// 参数 target - 引用目标
// 返回值 - 对应的 RefKind 枚举值
public func targetKind(target: Target): RefKind {
    match (target) {
        case Target.Object(_) => RefKind.Object
        case Target.Symbolic(_) => RefKind.Symbolic
    }
}

// 尝试从引用目标中提取 ObjectId
// 参数 target - 引用目标
// 返回值 - 若目标是对象引用则返回 Some(ObjectId)，符号引用返回 None
public func targetTryId(target: Target): ?ObjectId {
    match (target) {
        case Target.Object(id) => Some(id)
        case Target.Symbolic(_) => None
    }
}

// 尝试从引用目标中提取符号引用名
// 参数 target - 引用目标
// 返回值 - 若目标是符号引用则返回 Some(FullName)，对象引用返回 None
public func targetTryName(target: Target): ?FullName {
    match (target) {
        case Target.Symbolic(name) => Some(name)
        case Target.Object(_) => None
    }
}

// 判断引用目标是否为空（null hash）
// 参数 target - 引用目标
// 返回值 - 若目标是全零的 ObjectId 则返回 true，符号引用始终返回 false
public func targetIsNull(target: Target): Bool {
    match (target) {
        case Target.Object(id) => isNullHash(id)
        case Target.Symbolic(_) => false
    }
}

// 判断 ObjectId 是否为全零（null hash）
// 参数 id - 待检查的对象 ID
// 返回值 - 所有字节均为 0 则返回 true，否则返回 false
func isNullHash(id: ObjectId): Bool {
    for (b in id.bytes) {
        if (b != UInt8(0)) {
            return false
        }
    }
    true
}
