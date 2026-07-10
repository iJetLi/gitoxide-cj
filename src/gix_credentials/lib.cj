// 文件：lib.cj
// 用途：Git 凭证管理，定义凭证数据结构与凭证助手接口
// 所属包：gix.gix_credentials
// 关键类型：Credential, CredentialHelper

package gitoxide.gix_credentials

import std.collection.*
import gitoxide.gix_utils.substringStr
import gitoxide.gix_utils.substringFromStr
import gitoxide.gix_utils.trimStr

// Git 凭证，存储用于远程认证的用户名、密码及上下文信息
public class Credential {
    // 用户名，未设置时为 None
    public var username: ?String
    // 密码，未设置时为 None
    public var password: ?String
    // 协议名称，如 "https"
    public var protocol: ?String
    // 主机名，如 "github.com"
    public var host: ?String
    // 路径，如仓库路径
    public var path: ?String

    // 初始化空凭证，所有字段均为 None
    public init() {
        this.username = None
        this.password = None
        this.protocol = None
        this.host = None
        this.path = None
    }

    // 从 URL 解析凭证字段（protocol/host/username/password/path）
    // 对齐 Rust: gix_credentials::protocol::Context::destructure_url_in_place
    // 参数 url: 完整 URL，如 "https://user:pass@github.com:8080/org/repo"
    // 参数 useHttpPath: 对 http/https 协议是否包含路径（非 http 协议始终包含路径）
    public static func parseFromUrl(url: String, useHttpPath: Bool): ?Credential {
        let cred = Credential()
        let schemeEndOpt = url.indexOf("://")
        if (schemeEndOpt.isNone()) {
            return None
        }
        let schemeEnd = schemeEndOpt.getOrThrow()
        cred.protocol = Some(substringStr(url, 0, schemeEnd))
        var rest = substringFromStr(url, schemeEnd + 3)
        // 提取用户名和密码（如果存在）
        let atIdxOpt = rest.indexOf("@")
        if (let Some(atIdx) <- atIdxOpt) {
            let userInfo = substringStr(rest, 0, atIdx)
            let colonIdxOpt = userInfo.indexOf(":")
            if (let Some(colonIdx) <- colonIdxOpt) {
                cred.username = Some(substringStr(userInfo, 0, colonIdx))
                cred.password = Some(substringFromStr(userInfo, colonIdx + 1))
            } else {
                cred.username = Some(userInfo)
            }
            rest = substringFromStr(rest, atIdx + 1)
        }
        // 提取主机和路径
        let slashIdxOpt = rest.indexOf("/")
        if (let Some(slashIdx) <- slashIdxOpt) {
            cred.host = Some(substringStr(rest, 0, slashIdx))
            let pathPart = substringFromStr(rest, slashIdx + 1)
            // 非http协议始终包含路径；http/https根据useHttpPath决定
            let proto = cred.protocol
            let isHttp = proto == Some("http") || proto == Some("https")
            if (!isHttp || useHttpPath) {
                if (pathPart.size > 0) {
                    // 去掉尾部斜杠
                    if (pathPart.endsWith("/")) {
                        cred.path = Some(substringStr(pathPart, 0, pathPart.size - 1))
                    } else {
                        cred.path = Some(pathPart)
                    }
                }
            }
        } else {
            cred.host = Some(rest)
        }
        cred
    }

    // 将凭证字段构造为 URL 字符串（不含密码）
    // 对齐 Rust: gix_credentials::protocol::Context::to_url
    public func toUrl(): ?String {
        if (protocol == None) {
            return None
        }
        var url = protocol.getOrThrow() + "://"
        if (let Some(u) <- username) {
            url = url + u + "@"
        }
        if (let Some(h) <- host) {
            url = url + h
        }
        if (let Some(p) <- path) {
            if (p.size > 0 && p[0] != UInt8(47)) {
                url = url + "/" + p
            } else {
                url = url + p
            }
        }
        Some(url)
    }

    // 生成提示字符串，如 "Username: " 或 "Password for https://host: "
    // 对齐 Rust: gix_credentials::protocol::Context::to_prompt
    public func toPrompt(label: String): String {
        if (protocol == None) {
            return label + ": "
        }
        var prompt = label + " for " + protocol.getOrThrow() + "://"
        if (let Some(h) <- host) {
            prompt = prompt + h
        }
        prompt + ": "
    }

    // 将凭证序列化为 git-credential 协议格式
    // 对齐 Rust: gix_credentials::protocol::Context::write_to
    // 格式：每行 "key=value"，以空行结尾
    public func serialize(): String {
        var lines = ArrayList<String>()
        if (let Some(p) <- protocol) {
            lines.add("protocol=" + p)
        }
        if (let Some(h) <- host) {
            lines.add("host=" + h)
        }
        if (let Some(p) <- path) {
            lines.add("path=" + p)
        }
        if (let Some(u) <- username) {
            lines.add("username=" + u)
        }
        if (let Some(p) <- password) {
            lines.add("password=" + p)
        }
        var sb = String()
        for (line in lines) {
            sb = sb + line + "\n"
        }
        sb = sb + "\n"
        sb
    }

    // 从 git-credential 协议格式反序列化凭证
    // 对齐 Rust: gix_credentials::protocol::Context::from_bytes
    // 空行表示输入结束；未知字段被跳过
    public static func deserialize(input: String): ?Credential {
        let cred = Credential()
        let lines = input.split("\n")
        for (line in lines) {
            let trimmed = trimStr(line)
            if (trimmed.size == 0) {
                break
            }
            let eqIdxOpt = trimmed.indexOf("=")
            if (eqIdxOpt.isNone()) {
                continue
            }
            let eqIdx = eqIdxOpt.getOrThrow()
            let key = substringStr(trimmed, 0, eqIdx)
            let value = substringFromStr(trimmed, eqIdx + 1)
            // 检查值中是否包含空字节
            if (value.indexOf("\0").isSome()) {
                return None
            }
            if (key == "protocol") {
                cred.protocol = Some(value)
            } else if (key == "host") {
                cred.host = Some(value)
            } else if (key == "path") {
                cred.path = Some(value)
            } else if (key == "username") {
                cred.username = Some(value)
            } else if (key == "password") {
                cred.password = Some(value)
            }
            // 未知字段（如 quit、url）被跳过
        }
        cred
    }
}

// 凭证助手接口，定义获取、存储与删除凭证的操作
public interface CredentialHelper {
    // 从凭证助手获取凭证（填充缺失字段）
    // 参数 credential: 部分填充的凭证（通常包含 protocol/host）
    // 返回值: 填充完整后的凭证，获取失败返回 None
    func get(credential: Credential): ?Credential

    // 将凭证存储到凭证助手（用于缓存以便后续使用）
    // 参数 credential: 要存储的凭证
    func store(credential: Credential): Unit

    // 从凭证助手中删除凭证（用于认证失败后清除缓存）
    // 参数 credential: 要删除的凭证
    func erase(credential: Credential): Unit
}
