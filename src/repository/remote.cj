// 文件：remote.cj
// 用途：定义远程仓库类型及将远程信息写入配置的工具函数
// 所属包：gix.repository
// 关键类型：Remote

package gitoxide.repository

import gitoxide.gix_url.*
import gitoxide.gix_refspec.*
import gitoxide.gix_transport.*
import std.collection.*

// 远程仓库，表示一个远程 Git 仓库的连接信息
public class Remote {
    // 远程名称（如 "origin"）
    public var name: String
    // 抓取 URL
    public var url: String
    // 推送 URL，未单独设置时为 None
    public var pushUrl: ?String
    // 抓取引用规格列表
    public var fetchRefSpecs: ArrayList<RefSpec>
    // 推送引用规格列表
    public var pushRefSpecs: ArrayList<RefSpec>

    // 参数 name：远程名称
    // 参数 url：抓取 URL
    // 初始化时自动添加默认抓取引用规格 +refs/heads/*:refs/remotes/<name>/*
    public init(name: String, url: String) {
        this.name = name
        this.url = url
        this.pushUrl = None
        this.fetchRefSpecs = ArrayList<RefSpec>()
        this.pushRefSpecs = ArrayList<RefSpec>()
        let defaultSpec = RefSpec.parse("+refs/heads/*:refs/remotes/" + name + "/*")
        if (let Some(spec) <- defaultSpec) {
            fetchRefSpecs.add(spec)
        }
    }
}

// 将远程仓库的 URL 信息写入仓库配置文件
// 参数 repo：仓库实例
// 参数 remote：远程仓库实例
public func addRemoteToConfig(repo: Repository, remote: Remote): Unit {
    if (let Some(config) <- repo.config) {
        config.set("remote." + remote.name + ".url", remote.url)
        if (let Some(pushUrl) <- remote.pushUrl) {
            config.set("remote." + remote.name + ".pushurl", pushUrl)
        }
    }
}
