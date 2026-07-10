// 文件：open.cj
// 用途：定义仓库打开选项，支持链式配置 bare/trust/hashKind
// 所属包：gix.repository
// 关键类型：OpenOptions

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_sec.*

// 仓库打开选项，控制打开仓库时的行为
public class OpenOptions {
    // 是否以裸仓库方式打开
    public var bare: Bool
    // 目录信任级别，决定是否使用该目录的配置
    public var trust: Trust
    // 哈希算法类型
    public var hashKind: HashKind

    // 初始化为默认值：非裸仓库、完全信任、SHA-1
    public init() {
        this.bare = false
        this.trust = Trust.Full
        this.hashKind = HashKind.Sha1
    }

    // 设置是否以裸仓库方式打开
    // 参数 bare：是否裸仓库
    // 返回值：自身，支持链式调用
    public func withBare(bare: Bool): OpenOptions {
        this.bare = bare
        this
    }

    // 设置目录信任级别
    // 参数 trust：信任级别
    // 返回值：自身，支持链式调用
    public func withTrust(trust: Trust): OpenOptions {
        this.trust = trust
        this
    }

    // 设置哈希算法类型
    // 参数 kind：哈希算法类型
    // 返回值：自身，支持链式调用
    public func withHashKind(kind: HashKind): OpenOptions {
        this.hashKind = kind
        this
    }
}
