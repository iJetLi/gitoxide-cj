// 文件：fullname.cj
// 用途：定义引用的全名类型 FullName，表示 Git 引用的完整路径名
// 所属包：gix.gix_ref
// 关键类型：FullName, RefCategory

package gitoxide.gix_ref

import gitoxide.gix_utils.*

// 引用全名，表示 Git 引用的完整路径名（如 refs/heads/main、HEAD）
public class FullName {
    // 引用名的字符串值
    public var value: String

    // 构造函数
    // 参数 value：引用名的字符串值
    public init(value: String) {
        this.value = value
    }

    // 尝试从字符串创建 FullName
    // 验证引用名是否合法（以 refs/ 开头或为特殊引用如 HEAD）
    // 参数 s：待验证的引用名字符串
    // 返回值：合法返回 Some(FullName)，非法返回 None
    public static func tryFrom(s: String): ?FullName {
        if (s.size == 0) {
            return None
        }
        if (s.startsWith("refs/")) {
            return Some(FullName(s))
        }
        if (s == "HEAD" || s == "FETCH_HEAD" || s == "ORIG_HEAD" || s == "MERGE_HEAD" || s == "REBASE_HEAD" || s ==
            "CHERRY_PICK_HEAD" || s == "REVERT_HEAD") {
            return Some(FullName(s))
        }
        None
    }

    // 获取引用的分类
    // 返回值：引用所属的 RefCategory 枚举值
    public func category(): RefCategory {
        if (value.startsWith("refs/tags/")) {
            RefCategory.Tag
        } else if (value.startsWith("refs/heads/")) {
            RefCategory.LocalBranch
        } else if (value.startsWith("refs/remotes/")) {
            RefCategory.RemoteBranch
        } else if (value.startsWith("refs/notes/")) {
            RefCategory.Note
        } else {
            RefCategory.PseudoRef
        }
    }

    // 获取引用的短名（去掉 refs/heads/ 前缀）
    // 返回值：短名字符串
    public func shorten(): String {
        if (value.startsWith("refs/heads/")) {
            substringFromStr(value, 11)
        } else if (value.startsWith("refs/tags/")) {
            substringFromStr(value, 10)
        } else if (value.startsWith("refs/remotes/")) {
            substringFromStr(value, 13)
        } else if (value.startsWith("refs/notes/")) {
            substringFromStr(value, 5)
        } else {
            value
        }
    }

    // 判断是否为远程跟踪分支
    // 对齐 Rust: FullName::is_remote_tracking_branch
    public func isRemoteTrackingBranch(): Bool {
        value.startsWith("refs/remotes/")
    }
}
