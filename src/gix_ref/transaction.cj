// 文件：transaction.cj
// 所属包：gix.gix_ref
// 用途：定义引用事务和编辑操作，用于批量创建、删除、更新引用
// 关键类型：Transaction, Edit, EditType

package gitoxide.gix_ref

import gitoxide.gix_hash.*
import gitoxide.gix_utils.*
import std.collection.*

// 引用事务类，用于批量执行引用的创建、删除和更新操作
// 支持链式调用
public class Transaction {
    // 待执行的编辑操作列表
    public var edits: ArrayList<Edit>

    // 构造函数，初始化空的编辑操作列表
    public init() {
        this.edits = ArrayList<Edit>()
    }

    // 添加一个创建引用的编辑操作
    // 参数 name - 要创建的引用全名
    // 参数 target - 引用的目标
    // 返回值 - 当前事务对象（支持链式调用）
    public func create(name: FullName, target: Target): Transaction {
        edits.add(Edit(name, target, EditType.Create))
        this
    }

    // 添加一个删除引用的编辑操作
    // 参数 name - 要删除的引用全名
    // 返回值 - 当前事务对象（支持链式调用）
    public func delete(name: FullName): Transaction {
        edits.add(Edit(name, Target.Object(ObjectId.fromHex(repeatStr("0", 40))), EditType.Delete))
        this
    }

    // 添加一个更新引用的编辑操作
    // 参数 name - 要更新的引用全名
    // 参数 target - 引用的新目标
    // 返回值 - 当前事务对象（支持链式调用）
    public func update(name: FullName, target: Target): Transaction {
        edits.add(Edit(name, target, EditType.Update))
        this
    }
}

// 引用编辑操作类，记录单次引用变更的详细信息
public class Edit {
    // 引用全名
    public var name: FullName
    // 引用目标
    public var target: Target
    // 编辑类型（创建/删除/更新）
    public var editType: EditType

    // 构造函数
    // 参数 name - 引用全名
    // 参数 target - 引用目标
    // 参数 editType - 编辑类型
    public init(name: FullName, target: Target, editType: EditType) {
        this.name = name
        this.target = target
        this.editType = editType
    }
}

// 编辑类型枚举，标识引用操作的类型
// Create - 创建新引用
// Delete - 删除引用
// Update - 更新已有引用
public enum EditType {
    | Create
    | Delete
    | Update

    public operator func ==(that: EditType): Bool {
        match (this) {
            case Create => match (that) {
                case Create => true;
                case _ => false
            }
            case Delete => match (that) {
                case Delete => true;
                case _ => false
            }
            case Update => match (that) {
                case Update => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: EditType): Bool {
        !(this == that)
    }
}
