// 文件：lib.cj
// 用途：Git refspec 解析与表示，用于描述 fetch/push 时的引用映射规则
// 所属包：gix.gix_refspec
// 关键类型：RefSpec, RefSpecDirection

package gitoxide.gix_refspec

import gitoxide.gix_utils.*

// Git refspec，描述源引用到目标引用的映射规则
public class RefSpec {
    // 源引用模式，如 "refs/heads/*"
    public var src: ?String
    // 目标引用模式，如 "refs/remotes/origin/*"
    public var dst: ?String
    // 是否强制更新（对应 "+" 前缀）
    public var force: Bool
    // refspec 方向（fetch 或 push）
    public var direction: RefSpecDirection

    // 参数 src: 源引用模式
    // 参数 dst: 目标引用模式
    // 参数 force: 是否强制更新
    // 参数 direction: 方向（Fetch/Push）
    public init(src: ?String, dst: ?String, force: Bool, direction: RefSpecDirection) {
        this.src = src
        this.dst = dst
        this.force = force
        this.direction = direction
    }

    // 从字符串解析 refspec，格式为 [+][src]:[dst] 或 [+][src]
    // 参数 s: refspec 字符串，如 "+refs/heads/*:refs/remotes/origin/*"
    // 返回值: 解析成功返回 RefSpec，空字符串返回 None
    public static func parse(s: String): ?RefSpec {
        if (s.size == 0) {
            return None
        }
        var force = false
        var remaining = s
        if (remaining.startsWith("+")) {
            force = true
            remaining = substringFromStr(remaining, 1)
        }
        let colonIdx = remaining.indexOf(":")
        if (let Some(ci) <- colonIdx) {
            let src = substringStr(remaining, 0, ci)
            let dst = substringFromStr(remaining, ci + 1)
            Some(RefSpec(Some(src), Some(dst), force, RefSpecDirection.Fetch))
        } else {
            Some(RefSpec(Some(remaining), None, force, RefSpecDirection.Fetch))
        }
    }
}

// refspec 方向，区分 fetch 与 push
public enum RefSpecDirection {
    | Fetch // 拉取方向（远程 → 本地）
    | Push // 推送方向（本地 → 远程）
}

extend RefSpecDirection <: Equatable<RefSpecDirection> {
    public operator func ==(other: RefSpecDirection): Bool {
        match (this) {
            case RefSpecDirection.Fetch => match (other) {
                case RefSpecDirection.Fetch => true;
                case _ => false
            }
            case RefSpecDirection.Push => match (other) {
                case RefSpecDirection.Push => true;
                case _ => false
            }
        }
    }

    public operator func !=(other: RefSpecDirection): Bool {
        !(this == other)
    }
}
