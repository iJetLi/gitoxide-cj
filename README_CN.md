# gitoxide-cj

一个用 [仓颉语言 (Cangjie)](https://cangjie-lang.cn/) 实现的原生 Git 库，从 Rust 项目 [gitoxide](https://github.com/Byron/gitoxide) 移植而来。

gitoxide-cj 提供了一套完整的 Git 底层（plumbing）包，用于在仓颉语言中构建 Git 兼容的应用程序，涵盖对象存储、引用管理、协议通信、索引操作等功能。

Video: [Bilibili](https://www.bilibili.com/video/BV1pxKB6hEVA)

## 对应版本

commit:6d95da6e7082e19a03123ad765b3d5f117731621 Date:   Fri Jul 10 08:42:32 2026

## 使用方式

### 作为库使用

在 `cjpm.toml` 中添加 `gitoxide` 依赖：

```toml
[dependencies]
  gitoxide = { path = "path/to/gitoxide-cj" }
```

然后导入所需的包：

```cangjie
import gitoxide.repository.*
import gitoxide.gix_object.*
import gitoxide.gix_ref.*
```

### 作为命令行工具

配套 CLI 项目 [gitoxide-cli](https://gitee.com/iJetLi/gitoxide-cli) 提供了 gitoxide-cj 功能的命令行访问。

## 功能状态

### 高层功能

| 功能 | 状态 | 说明 |
|------|------|------|
| init | ✅ 已实现 | 创建 `.git` 目录结构、HEAD、配置 |
| open / discover | ✅ 已实现 | 向上搜索 `.git` 目录，支持裸仓库 |
| clone | ✅ 已实现 | Git Protocol V2，pack 写入 + 索引 + 引用 + checkout |
| fetch | ✅ 已实现 | Git Protocol V2，pack 数据写入 ODB，引用更新 |
| push (HTTP/HTTPS) | ✅ 已实现 | Smart HTTP push，支持 TLS、Basic Auth、pack 生成 |
| push (SSH) | ⚠️ 回退方案 | 回退到系统 `git push` 命令 |
| status | ✅ 已实现 | 索引与工作区比较，未跟踪文件检测 |
| diff | ✅ 已实现 | 树与树差异比较，基于 revspec 的 diff |
| commit（签名/验证） | ✅ 已实现 | 通过外部 `gpg` 命令进行 GPG 签名/验证 |
| log / revwalk | ✅ 已实现 | 拓扑排序的提交图遍历 |
| revision 解析 | ✅ 已实现 | 解析 `HEAD~3`、`v1.0^` 等修订规范 |
| branch 列表 | ✅ 已实现 | 本地和远程分支列表 |
| merge | ✅ 已实现 | 三路文本合并 |
| write-tree | ✅ 已实现 | 从索引条目构建树对象 |
| clean | ✅ 已实现 | 删除未跟踪文件（支持 dry-run） |
| archive | ✅ 已实现 | Tar 输出含 pax_global_header，支持 stdout/文件输出 |
| blame | ⚠️ 部分实现 | 查找树中的 blob，无逐行追踪 |
| checkout | ❌ 未实现 | |
| rebase | ❌ 未实现 | |
| reset | ❌ 未实现 | |
| commit hooks | ❌ 未实现 | |
| merge 提交 | ❌ 未实现 | 仅实现了 blob/树合并 |
| credential helper | ⚠️ 桩实现 | `fill()` 原样返回输入 |

### 协议与传输

| 功能 | 状态 | 说明 |
|------|------|------|
| Smart HTTP (fetch) | ✅ 已实现 | V1 和 V2 协议，ls-refs，sideband |
| Smart HTTP (push) | ✅ 已实现 | 支持 `report-status`、`side-band-6k` |
| HTTPS (TLS) | ✅ 已实现 | 通过 `stdx.net.http.Client` + CookieJar（OpenSSL 3） |
| SSH | ⚠️ 回退方案 | 回退到系统 `git` 命令 |
| Git 协议 | ❌ 未实现 | `git://` 协议 |
| 本地协议 | ❌ 未实现 | |

### 对象与存储

| 功能 | 状态 | 说明 |
|------|------|------|
| 读/写松散对象 | ✅ 已实现 | Blob、tree、commit、tag |
| 读/写 pack 文件 | ✅ 已实现 | Pack 索引、delta 编码、pack 写入器 |
| 读/写引用 | ✅ 已实现 | 文件、打包、通用存储，事务支持 |
| 读/写索引 | ✅ 已实现 | DIRC 格式解析与编码 |
| 读/写配置 | ✅ 已实现 | INI 风格配置文件解析与写入 |
| commit-graph | ✅ 已实现 | 文件解析，加速提交遍历 |
| shallow | ✅ 已实现 | 浅克隆边界管理 |

## 子包列表

| 包名 | 功能说明 |
|------|----------|
| `gix_actor` | Git 签名/身份类型（作者、提交者） |
| `gix_archive` | Git 归档生成（tar 格式） |
| `gix_attributes` | `.gitattributes` 文件解析与路径匹配 |
| `gix_bitmap` | 位图数据结构，高效布尔集合操作 |
| `gix_blame` | Git blame — 追踪每一行的最后修改提交 |
| `gix_chunk` | chunk 文件格式解析（用于 commit-graph 等） |
| `gix_command` | 外部命令执行封装（GPG、git 等） |
| `gix_commitgraph` | commit-graph 文件读写，加速提交遍历 |
| `gix_config` | Git 配置文件解析与写入 |
| `gix_config_value` | Git 配置值的类型化解析（布尔、颜色、整数等） |
| `gix_credentials` | Git 凭证数据结构与凭证助手接口 |
| `gix_date` | Git 日期时间类型，支持时区偏移解析 |
| `gix_diff` | 树与树的差异比较计算 |
| `gix_dir` | 目录遍历 — 递归扫描文件与子目录 |
| `gix_discover` | Git 仓库发现 — 向上搜索 `.git` 目录 |
| `gix_error` | 基础错误类型体系（通用错误、消息错误、验证错误） |
| `gix_features` | 运行时特性检测和进度报告接口 |
| `gix_fetchhead` | `.git/FETCH_HEAD` 文件解析，跟踪 fetch 结果 |
| `gix_filter` | Git filter 管道（smudge/clean、CRLF、ident） |
| `gix_fs` | 文件系统能力探测和文件属性查询 |
| `gix_fsck` | 仓库完整性检查 — 检测缺失/损坏对象 |
| `gix_glob` | Git 风格的 glob 模式匹配，支持取反 |
| `gix_hash` | 对象标识符（OID）— SHA-1 哈希表示 |
| `gix_hashtable` | 基于拉链法的哈希表和线程安全的 ObjectIdMap |
| `gix_ignore` | `.gitignore` 文件解析与路径排除 |
| `gix_imara_diff` | 基于 imara-diff 算法的行级差异比较（Myers O(ND)） |
| `gix_index` | Git 索引文件（`.git/index`）解析与编码 |
| `gix_lfs` | Git LFS 指针文件解析与序列化 |
| `gix_lock` | Git 文件锁机制，确保互斥访问 |
| `gix_mailmap` | `.mailmap` 文件解析与邮件地址映射 |
| `gix_merge` | 三路合并（blob、树、提交） |
| `gix_negotiate` | Fetch 协商 — 跟踪已知提交以优化 want/have |
| `gix_note` | Git notes — 为提交对象附加备注 |
| `gix_object` | Git 对象类型（blob/tree/commit/tag）解析与序列化 |
| `gix_odb` | 对象数据库（ODB）门面 — 松散、pack 和复合存储 |
| `gix_pack` | Git pack 文件格式编解码、pack 索引、delta |
| `gix_packetline` | Git pkt-line 格式编解码，协议分帧传输 |
| `gix_path` | 跨平台路径工具 — 规范化、拼接、格式转换 |
| `gix_pathspec` | Git pathspec 解析与路径匹配 |
| `gix_prompt` | 用户交互提示抽象 |
| `gix_protocol` | Git 协议层 — 握手、fetch、push 连接 |
| `gix_quote` | Git 风格的 shell 引用与反引用 |
| `gix_rebase` | Git rebase todo 列表解析 |
| `gix_ref` | Git 引用管理 — 读写 `refs/` 下的引用 |
| `gix_refspec` | Git refspec 解析 — fetch/push 引用映射规则 |
| `gix_revision` | Git 修订规范解析、merge-base、describe 算法 |
| `gix_revwalk` | 提交图遍历，拓扑排序 |
| `gix_sec` | 安全信任级别和用户身份抽象 |
| `gix_sequencer` | Git sequencer — 解析和执行 todo 列表 |
| `gix_shallow` | `.git/shallow` 文件解析 — 浅克隆边界管理 |
| `gix_status` | Git 状态查询 — 暂存区与工作区文件状态类型 |
| `gix_submodule` | Git 子模块解析，从 `.gitmodules` 提取信息 |
| `gix_tempfile` | 临时文件管理，安全写入和原子性持久化 |
| `gix_test_utils` | 测试辅助工具函数（夹具加载、十六进制转换） |
| `gix_trace` | 轻量级日志追踪基础设施，分级过滤 |
| `gix_transport` | Git 传输层 — HTTP/TLS 传输、握手、fetch、push |
| `gix_traverse` | 树和提交遍历（BFS/DFS/拓扑排序） |
| `gix_url` | Git URL 解析（ssh://、https://、git@、file:// 等） |
| `gix_utils` | 通用工具（字节转换、字符串规范化、退避） |
| `gix_validate` | Git 引用名称验证 |
| `gix_worktree` | Git 工作树管理 — 检出和状态查询 |
| `gix_worktree_state` | 工作树状态汇总 — 干净/脏检测 |
| `gix_worktree_stream` | 工作树流式输出，用于 checkout 操作 |
| `gix_zlib` | zlib 压缩/解压缩，用于 Git 对象存储 |
| `repository` | 核心 Repository 类型 — 打开、初始化、引用、对象、push 等 |

## 构建

需要 [仓颉 SDK](https://cangjie-lang.cn/) 1.1.3+。

```bash
cjpm build
```

TLS 支持（HTTPS push）需要带 OpenSSL 3 的 `stdx` 库，详见 `cjpm.toml` 配置。

## 与 gitoxide 的关系

gitoxide-cj 是 [gitoxide](https://github.com/Byron/gitoxide) 从 Rust 到仓颉语言的移植。架构和 API 设计紧密跟随原版，同时做了仓颉语言惯例的适配：

- 不使用 `any` / `unknown` 类型 — 全程显式类型
- 用 `Option<T>` 代替 Rust 的 `Result<T, E>` 处理可失败操作
- 用 `if-let` 模式匹配代替对 `Result` 的 `match`
- 使用 `std.collection` 的 `ArrayList<T>` / `HashMap<K,V>`
- 外部进程通过 `std.process.executeWithOutput` 调用（不支持交互式 stdin）

## 许可证

基于 [MIT 许可证](LICENSE) 授权。
