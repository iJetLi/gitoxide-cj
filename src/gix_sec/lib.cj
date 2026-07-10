// 文件：lib.cj
// 所属包：gix.gix_sec
// 用途：提供安全信任级别判断和用户身份抽象，用于判断 Git 仓库路径的可信程度

package gitoxide.gix_sec

// 路径信任级别
// 用于标识 Git 仓库所在目录的安全程度
public enum Trust {
    | Full // 完全信任，路径由当前用户拥有
    | Reduced // 降级信任，路径由其他用户拥有但可访问
    | None // 不信任，路径不可靠

    public operator func ==(that: Trust): Bool {
        match (this) {
            case Full => match (that) {
                case Full => true;
                case _ => false
            }
            case Reduced => match (that) {
                case Reduced => true;
                case _ => false
            }
            case None => match (that) {
                case None => true;
                case _ => false
            }
        }
    }

    public operator func !=(that: Trust): Bool {
        !(this == that)
    }
}

// 用户身份信息
// 抽象表示操作系统级别的用户标识
public class Identity {
    // 用户 ID（Unix 下为 uid，Windows 下无实际意义）
    var uid: Int64

    // 创建一个指定用户 ID 的身份
    // 参数 uid：用户 ID
    public init(uid: Int64) {
        this.uid = uid
    }
}

// 根据路径判断其信任级别
// 简化实现：Windows 下默认返回完全信任，Linux 下应检查文件所有权
// 参数 path：待判断的文件系统路径
// 返回值：该路径的信任级别
public func trustForPath(path: String): Trust {
    Trust.Full
}
