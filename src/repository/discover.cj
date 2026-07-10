// 文件：discover.cj
// 用途：从给定路径向上搜索 Git 仓库
// 所属包：gix.repository
// 关键类型：无（仅提供工具函数）

package gitoxide.repository

import gitoxide.gix_discover.*

// 从给定路径向上搜索 Git 仓库并打开
// 参数 path：起始搜索路径
// 返回值：找到并成功打开返回 Repository，否则返回 None
public func discover(path: String): ?Repository {
    Repository.open(path)
}
