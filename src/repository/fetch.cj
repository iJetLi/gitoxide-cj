// 文件：fetch.cj
// 用途：仓库层 fetch 胶水模块，桥接 gix_transport 到 Repository
// 所属包：gix.repository
// 关键类型：FetchQuery
// 对齐原版：gitoxide-core/src/repository/fetch.rs

package gitoxide.repository

import gitoxide.gix_transport.*
import gitoxide.gix_url.*
import gitoxide.gix_hash.*
import gitoxide.gix_config.*
import std.collection.*

public class FetchQuery {
    public var repo: Repository

    public init(repo: Repository) {
        this.repo = repo
    }

    // 从远程仓库拉取数据
    // 对齐原版：gitoxide-core/src/repository/fetch.rs::fetch()
    public func fetch(remoteName: String): ?FetchResult {
        let remoteUrl = getRemoteUrl(remoteName)
        if (let Some(urlStr) <- remoteUrl) {
            let transport = HttpTransport()
            let service = Service.gitUploadPack()
            let url = Url.parse(urlStr)
            if (let Some(u) <- url) {
                let handshakeResult = transport.handshake(u, service)
                if (let Some(result) <- handshakeResult) {
                    let wants = ArrayList<ObjectId>()
                    let haves = ArrayList<ObjectId>()
                    let head = repo.head()
                    if (let Some(h) <- head) {
                        if (let Some(id) <- h.tryId()) {
                            haves.add(id)
                        }
                    }
                    for (`ref` in result.refs) {
                        if (let Some(id) <- refObjectId(`ref`)) {
                            wants.add(id)
                        }
                    }
                    transport.fetch(wants, haves)
                } else {
                    None
                }
            } else {
                None
            }
        } else {
            None
        }
    }

    // 获取远程引用列表
    public func remoteRefs(remoteName: String): ?HandshakeResult {
        let remoteUrl = getRemoteUrl(remoteName)
        if (let Some(urlStr) <- remoteUrl) {
            let transport = HttpTransport()
            let service = Service.gitUploadPack()
            let url = Url.parse(urlStr)
            if (let Some(u) <- url) {
                transport.handshake(u, service)
            } else {
                None
            }
        } else {
            None
        }
    }

    func getRemoteUrl(remoteName: String): ?String {
        let configOpt = repo.config
        if (let Some(cfg) <- configOpt) {
            let key = "remote." + remoteName + ".url"
            cfg.find(key)
        } else {
            None
        }
    }
}
