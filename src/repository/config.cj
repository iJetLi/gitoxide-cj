// 文件：config.cj
// 用途：获取仓库的配置文件
// 所属包：gix.repository
// 关键类型：无（仅提供工具函数）

package gitoxide.repository

import gitoxide.gix_config.*

// 获取仓库的配置文件
// 参数 repo：仓库实例
// 返回值：配置文件，仓库无配置时返回 None
public func repositoryConfig(repo: Repository): ?ConfigFile {
    repo.config
}
