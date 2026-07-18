# AGENTS.md

## 项目
仓颉原生 Git 库 `gitoxide` — 从 Rust [gitoxide](https://github.com/Byron/gitoxide) 项目移植。输出静态库，供 `gix-cli` 等仓颉应用使用。

## 工具链
- **语言**：仓颉 (Cangjie)，不是 TypeScript/ArkTS
- **包管理器**：`cjpm`（仓颉包管理器）
- **编译器版本**：`cjc` 1.1.3（在 `cjpm.toml` 中固定）
- **构建**：`cjpm build` → 输出静态库 `target/release/gitoxide.a`

## 依赖
- `shell_words` 1.1.1 — shell 风格参数分割
- `crc32fast` 1.5.0 — CRC32 校验
- `cangjie_tpc::zlib4cj` 1.2.1 — zlib 压缩
- `stdx`（bin-dependency，static）— 通过 `stdx.net.tls` 提供 TLS 支持（OpenSSL 3），路径：`D:\tools\cangjie-stdx-1.1.3.1\windows_x86_64_cjnative\static\stdx`
- `unicode_normalization` — 当前为加速构建已禁用（在 cjpm.toml 中注释掉）

## 源码结构
- `src/` — 64 个 `gix_*` 包 + `repository/` 门面模块，214 个 `.cj` 文件，约 3MB
- 每个 `gix_*` 包遵循：`src/gix_<name>/lib.cj`（入口）+ 子模块
- `src/repository/` — 高层 Repository 类和胶水模块（clone、fetch、push、status、diff 等）
- `src/main.cj` — 最小入口（库模式下不使用）
- 包命名空间：`gitoxide.*`（如 `gitoxide.gix_object`、`gitoxide.repository`）

## 包组织

### 核心对象层
| 包 | 说明 |
|---|------|
| `gix_hash` | ObjectId（SHA-1）、哈希计算 |
| `gix_object` | Blob/tree/commit/tag 解码与编码 |
| `gix_odb` | 对象数据库门面（松散、pack、复合存储） |
| `gix_pack` | Pack 文件格式、delta 编码、pack 索引、pack 写入器 |
| `gix_zlib` | zlib 压缩/解压缩 |

### 引用与索引
| 包 | 说明 |
|---|------|
| `gix_ref` | 引用管理（文件、打包、事务） |
| `gix_refspec` | Refspec 解析（fetch/push） |
| `gix_index` | `.git/index`（DIRC 格式）解析与编码 |
| `gix_config` | Git 配置文件解析与写入 |
| `gix_config_value` | 类型化配置值解析 |

### 协议与传输
| 包 | 说明 |
|---|------|
| `gix_transport` | HTTP/TLS 传输、Smart HTTP 握手、fetch、push |
| `gix_protocol` | 协议层（握手、fetch/push 连接） |
| `gix_packetline` | pkt-line 格式编解码 |
| `gix_url` | Git URL 解析 |
| `gix_credentials` | 凭证数据结构与凭证助手接口 |

### 差异与合并
| 包 | 说明 |
|---|------|
| `gix_diff` | 树与树差异比较 |
| `gix_imara_diff` | 行级差异（Myers O(ND)） |
| `gix_merge` | 三路合并 |
| `gix_negotiate` | Fetch 协商（want/have） |

### 遍历与查询
| 包 | 说明 |
|---|------|
| `gix_traverse` | 树/提交遍历（BFS/DFS/拓扑排序） |
| `gix_revwalk` | 提交图遍历 |
| `gix_revision` | Revspec 解析、merge-base、describe |
| `gix_commitgraph` | commit-graph 文件读写 |
| `gix_status` | 索引与工作区状态 |

### 路径与模式
| 包 | 说明 |
|---|------|
| `gix_path` | 跨平台路径工具 |
| `gix_pathspec` | Git pathspec 解析与匹配 |
| `gix_glob` | Git 风格 glob 匹配 |
| `gix_ignore` | `.gitignore` 解析 |
| `gix_attributes` | `.gitattributes` 解析 |
| `gix_validate` | 引用名称验证 |
| `gix_quote` | Shell 引用/反引用 |

### 工作树与过滤器
| 包 | 说明 |
|---|------|
| `gix_worktree` | 工作树管理 |
| `gix_worktree_state` | 工作树状态汇总 |
| `gix_worktree_stream` | 流式 checkout 输出 |
| `gix_filter` | Git filter 管道（smudge/clean、CRLF） |
| `gix_dir` | 目录遍历 |

### 基础设施
| 包 | 说明 |
|---|------|
| `gix_error` | 错误类型体系 |
| `gix_features` | 运行时特性检测与进度报告 |
| `gix_command` | 外部命令执行 |
| `gix_prompt` | 交互式提示抽象 |
| `gix_fs` | 文件系统能力探测 |
| `gix_lock` | 文件锁 |
| `gix_tempfile` | 临时文件管理 |
| `gix_hashtable` | 哈希表与 ObjectIdMap |
| `gix_bitmap` | 位图数据结构 |
| `gix_chunk` | Chunk 文件格式 |
| `gix_trace` | 日志追踪 |
| `gix_utils` | 通用工具 |
| `gix_test_utils` | 测试辅助 |

### 其他
| 包 | 说明 |
|---|------|
| `gix_actor` | 签名/身份类型 |
| `gix_date` | 日期时间解析 |
| `gix_mailmap` | Mailmap 解析 |
| `gix_blame` | Blame 追踪 |
| `gix_note` | Git notes |
| `gix_lfs` | LFS 指针文件 |
| `gix_submodule` | 子模块解析 |
| `gix_archive` | 归档生成 |
| `gix_fetchhead` | FETCH_HEAD 解析 |
| `gix_shallow` | 浅克隆边界 |
| `gix_fsck` | 完整性检查 |
| `gix_sec` | 安全信任级别 |
| `gix_rebase` | Rebase todo 解析 |
| `gix_sequencer` | Sequencer todo 列表 |
| `repository` | 核心 Repository 门面（open、init、refs、objects、push 等） |

## 构建与测试
```sh
cjpm build                # 构建静态库
cjpm test                 # 运行单元测试
```

## 关键实现说明

### 对齐到rust gitoxide  6d95da6e7082e19a03123ad765b3d5f117731621

### Push（HTTP/HTTPS）
- `HttpTransport.push()` / `TlsHttpTransport.push()` — Smart HTTP push，pkt-line 编码的引用更新命令，`report-status side-band-6k` 能力声明，pack 数据，响应解析
- `TlsHttpTransport` 使用 `stdx.net.tls.TlsSocket`（OpenSSL 3），`CertificateVerifyMode.TrustAll`
- 凭证通过 `loadCredentialsForUrl()` 从 `~/.git-credentials` 加载，Base64 编码用于 `Authorization: Basic` 请求头

### Push（SSH）
- `pushViaGitCommand()` — 回退到 `git -C <workDir> push`（仓颉没有 SSH 库，也没有交互式 Process API）
- 使用 `git -C` 而非 `GIT_DIR` 环境变量，以保留 SSH 配置发现（`~/.ssh`）

### base64Encode
- 必须用 `ArrayList<Byte>` + `String.fromUtf8()`，不能用 `StringBuilder.append(UInt8)`，后者会把字节值当数字拼接

### resolvePushRefs
- 短分支名（如 `master`）必须扩展为 `refs/heads/master` 后才能传给 `FullName.tryFrom()`

## 注意事项
- 仓颉 `String[Int64]` 返回 `UInt8`；`StringBuilder.append(UInt8)` 会把数值当字符串拼接而非字符
- 仓颉 `if-let` 模式匹配不能用于表达式上下文；用 `Option<T>.None` 消除类型歧义
- `std.collection.HashSet` 使用 `add` 而非 `put`
- 仓颉 `executeWithOutput` 不支持 stdin 管道
- 仓颉 `String` 没有 `substring` 方法；用 `[0..n]` 切片
- 仓颉的按位取反用 `!`，x 的按位取反为 `!x`
- 仓颉的 match 中 `case => {}` 是错误的，`case => ()` 是正确的
- stdx 使用 static 链接模式（dynamic 模式下运行时无输出/崩溃）
- 仓颉文档在：D:\tools\cangjie-html-doc
- `gix_hash` 使用 `oid.cj` 作为入口（没有 `lib.cj`）；`repository` 使用 `mod.cj`
- `gix_object`、`gix_ref`、`gix_pack`、`gix_config` 有最小的 `lib.cj`，仅重新导出子模块
