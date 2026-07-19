// 文件：mod.cj
// 用途：仓库核心类型 Repository 的定义，包含 Git 目录、对象库、引用库、配置等，
//       以及仓库的打开、初始化、引用查找、对象读写等基础操作
// 所属包：gix.repository
// 关键类型：Repository

package gitoxide.repository

import gitoxide.gix_hash.*
import gitoxide.gix_odb.*
import gitoxide.gix_odb.store.*
import gitoxide.gix_ref.*
import gitoxide.gix_ref.store.*
import gitoxide.gix_config.*
import gitoxide.gix_discover.*
import gitoxide.gix_object.*
import std.fs.*
import std.collection.*

// 仓库实例，代表一个已打开的 Git 仓库
public class Repository {
    // .git 目录的绝对路径
    public var gitDir: String
    // 工作区根目录，裸仓库为 None
    public var workDir: ?String
    // 仓库使用的哈希算法类型
    public var hashKind: HashKind
    // 对象数据库（松散 + 包文件的复合存储）
    public var odb: CompoundStore
    // 引用存储（文件引用 + packed-refs）
    public var refs: GeneralStore
    // 仓库配置文件，无配置时为 None
    public var config: ?ConfigFile

    // 参数 gitDir：.git 目录路径
    // 参数 workDir：工作区路径，裸仓库传 None
    // 参数 hashKind：哈希算法类型
    public init(gitDir: String, workDir: ?String, hashKind: HashKind) {
        this.gitDir = gitDir
        this.workDir = workDir
        this.hashKind = hashKind
        let objectsDir = gitDir + "/objects"
        let loose = LooseStore(objectsDir, hashKind)
        let dynamic = DynamicStore(objectsDir, hashKind)
        this.odb = CompoundStore(loose, dynamic)
        let packedPath = gitDir + "/packed-refs"
        let packed = PackedStore.open(packedPath, hashKind)
        let fileStore = FileStore(gitDir, hashKind)
        this.refs = GeneralStore(fileStore, packed)
        let configPath = gitDir + "/config"
        this.config = ConfigFile.fromPath(configPath)
    }

    // 从给定路径打开已有仓库，自动向上搜索 .git 目录
    // 参数 path：搜索起始路径
    // 返回值：成功打开返回 Repository，未找到返回 None
    public static func open(path: String): ?Repository {
        let discovered = discoverUpwards(path)
        if (let Some(repo) <- discovered) {
            match (repo.kind) {
                case RepoKind.WorkTree => Some(Repository(repo.path + "/.git", Some(repo.path), HashKind.Sha1))
                case RepoKind.Bare => Some(Repository(repo.path, Option<String>.None, HashKind.Sha1))
                case RepoKind.WorkTreeLinked => Some(Repository(repo.path + "/.git", Some(repo.path), HashKind.Sha1))
            }
        } else {
            None
        }
    }

    // 在指定路径初始化新仓库，创建 .git 目录结构、HEAD 和 config
    // 参数 path：仓库路径
    // 参数 bare：是否创建裸仓库
    // 返回值：成功返回 Repository，创建失败返回 None
    public static func `init`(path: String, bare: Bool): ?Repository {
        let gitDir = if (bare) {
            path
        } else {
            path + "/.git"
        }
        try {
            if (!exists(path)) {
                Directory.create(path, recursive: true)
            }
            if (!exists(gitDir)) {
                Directory.create(gitDir, recursive: true)
                Directory.create(gitDir + "/objects")
                Directory.create(gitDir + "/objects/pack")
                Directory.create(gitDir + "/objects/info")
                Directory.create(gitDir + "/refs")
                Directory.create(gitDir + "/refs/heads")
                Directory.create(gitDir + "/refs/tags")
                Directory.create(gitDir + "/info")
            }
            let headPath = gitDir + "/HEAD"
            if (!exists(headPath)) {
                let file = File(headPath, OpenMode.Write)
                file.write("ref: refs/heads/main\n".toArray())
                file.close()
            }
            let configPath = gitDir + "/config"
            if (!exists(configPath)) {
                let file = File(configPath, OpenMode.Write)
                let configContent = "[core]\n\trepositoryformatversion = 0\n\tfilemode = true\n\tbare = " + (if (bare) {
                    "true"
                } else {
                    "false"
                }) + "\n"
                file.write(configContent.toArray())
                file.close()
            }
            let workDir: ?String = if (bare) {
                None
            } else {
                Some(path)
            }
            Some(Repository(gitDir, workDir, HashKind.Sha1))
        } catch (e: Exception) {
            println("[init] Exception: ${e.message}")
            None
        }
    }

    // 按名称查找引用
    // 参数 name：引用名称（如 "HEAD"、"refs/heads/main"）
    // 返回值：找到返回 Reference，否则返回 None
    public func findReference(name: String): ?Reference {
        let fullName = FullName.tryFrom(name)
        if (let Some(fn) <- fullName) {
            refs.find(fn)
        } else {
            None
        }
    }

    // 获取 HEAD 引用
    // 返回值：HEAD 引用，无 HEAD 时返回 None
    public func head(): ?Reference {
        findReference("HEAD")
    }

    // 按对象 ID 读取对象数据
    // 参数 id：对象 ID
    // 返回值：对象数据，未找到返回 None
    public func readObject(id: ObjectId): ?Data {
        odb.tryFind(id)
    }

    public func lookupPrefix(prefix: Prefix): ?PrefixLookupOutcome {
        odb.lookupPrefix(prefix)
    }

    // 写入对象到对象数据库
    // 参数 kind：对象类型（commit/tree/blob/tag）
    // 参数 data：对象原始字节数据
    // 返回值：写入后返回对象 ID
    public func writeObject(kind: ObjectKind, data: Array<Byte>): ObjectId {
        odb.write(kind, data)
    }

    // 遍历仓库所有引用
    // 返回值：引用列表
    public func iterReferences(): ArrayList<Reference> {
        refs.iter()
    }

    // 将远程仓库信息写入仓库配置
    // 参数 remoteName：远程仓库名称
    // 参数 remoteUrl：远程仓库 URL
    public func addRemote(remoteName: String, remoteUrl: String): Unit {
        let configPath = gitDir + "/config"
        let cfgOpt = ConfigFile.fromPath(configPath)
        if (let Some(cfg) <- cfgOpt) {
            cfg.set("remote." + remoteName + ".url", remoteUrl)
            cfg.set("remote." + remoteName + ".fetch", "+refs/heads/*:refs/remotes/" + remoteName + "/*")
            cfg.write(configPath)
        }
    }
}
