// 文件：clone.cj
// 用途：克隆远程仓库到本地，提供克隆选项及克隆流程的各阶段表示
// 所属包：gix.repository
// 关键类型：CloneOptions, PrepareFetch, PrepareCheckout

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_protocol.*
import gitoxide.gix_refspec.*
import std.collection.*

// 克隆选项，控制克隆行为
public class CloneOptions {
    // 是否创建裸仓库（无工作区）
    public var bare: Bool
    // 克隆时使用的引用规格列表
    public var refSpecs: ArrayList<RefSpec>
    // 远程名称，默认为 "origin"
    public var remoteName: String
    // 指定克隆后检出的分支，None 表示检出默认分支
    public var branch: ?String

    // 初始化克隆选项为默认值
    public init() {
        this.bare = false
        this.refSpecs = ArrayList<RefSpec>()
        this.remoteName = "origin"
        this.branch = None
    }
}

// 准备抓取阶段，表示克隆过程中已解析 URL 即将开始抓取
public class PrepareFetch {
    // 远程仓库 URL
    public var url: Url
    // 克隆选项
    public var options: CloneOptions

    // 参数 url：远程仓库 URL
    // 参数 options：克隆选项
    public init(url: Url, options: CloneOptions) {
        this.url = url
        this.options = options
    }
}

// 准备检出阶段，表示抓取完成即将检出工作区
public class PrepareCheckout {
    // 已初始化的仓库实例
    public var repo: Repository

    // 参数 repo：已初始化的仓库
    public init(repo: Repository) {
        this.repo = repo
    }
}

// 克隆远程仓库到本地路径
// 参数 url：远程仓库 URL 字符串
// 参数 destPath：本地目标路径
// 参数 options：克隆选项
// 返回值：成功返回 Repository，失败返回 None
public func clone(url: String, destPath: String, options: CloneOptions): ?Repository {
    let parsedUrl = Url.parse(url)
    if (parsedUrl.isNone()) {
        return None
    }
    let repo = Repository.`init`(destPath, options.bare)
    if (let Some(r) <- repo) {
        let remote = Remote(options.remoteName, url)
        r.addRemote(remote)
        Some(r)
    } else {
        None
    }
}
