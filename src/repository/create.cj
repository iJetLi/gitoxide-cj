// 文件：create.cj
// 用途：定义仓库创建选项，支持链式配置 bare/hashKind/initialBranch
// 所属包：gix.repository
// 关键类型：CreateOptions

package gitoxide.repository

import gitoxide.gix_hash.*

// 仓库创建选项，控制 init 时仓库的初始属性
public class CreateOptions {
    // 是否创建裸仓库
    public var bare: Bool
    // 哈希算法类型
    public var hashKind: HashKind
    // 初始分支名称，None 使用默认分支
    public var initialBranch: ?String

    // 初始化为默认值：非裸仓库、SHA-1、无指定初始分支
    public init() {
        this.bare = false
        this.hashKind = HashKind.Sha1
        this.initialBranch = None
    }

    // 设置是否为裸仓库
    // 参数 bare：是否裸仓库
    // 返回值：自身，支持链式调用
    public func withBare(bare: Bool): CreateOptions {
        this.bare = bare
        this
    }

    // 设置哈希算法类型
    // 参数 kind：哈希算法类型
    // 返回值：自身，支持链式调用
    public func withHashKind(kind: HashKind): CreateOptions {
        this.hashKind = kind
        this
    }

    // 设置初始分支名称
    // 参数 branch：初始分支名称
    // 返回值：自身，支持链式调用
    public func withInitialBranch(branch: String): CreateOptions {
        this.initialBranch = Some(branch)
        this
    }
}
