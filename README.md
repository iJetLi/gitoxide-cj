# gitoxide-cj

A native Git library implemented in [Cangjie (仓颉)](https://cangjie-lang.cn/), ported from the Rust [gitoxide](https://github.com/Byron/gitoxide) project.

gitoxide-cj provides a complete set of Git plumbing packages for building Git-compatible applications in Cangjie, covering object storage, reference management, protocol communication, index operations, and more.

## Usage

### As a Library

Add `gitoxide` as a dependency in your `cjpm.toml`:

```toml
[dependencies]
  gitoxide = { path = "path/to/gitoxide-cj" }
```

Then import the packages you need:

```cangjie
import gitoxide.repository.*
import gitoxide.gix_object.*
import gitoxide.gix_ref.*
```

### As a CLI Tool

The companion CLI project [gitoxide-cli](https://gitee.com/iJetLi/gitoxide-cli) provides command-line access to gitoxide-cj functionality.

## Feature Status

### High-Level Features

| Feature | Status | Notes |
|---------|--------|-------|
| init | ✅ Implemented | Create `.git` directory structure, HEAD, config |
| open / discover | ✅ Implemented | Upward `.git` search, bare repo support |
| clone | ⚠️ Partial | Inits repo + adds remote, but does not fetch pack data yet |
| fetch | ⚠️ Partial | Want/have negotiation works, but fetched pack not written to ODB |
| push (HTTP/HTTPS) | ✅ Implemented | Smart HTTP push with TLS, Basic Auth, pack generation |
| push (SSH) | ⚠️ Fallback | Falls back to system `git push` command |
| status | ✅ Implemented | Index vs worktree comparison, untracked file detection |
| diff | ✅ Implemented | Tree-to-tree diff, revspec-based diff |
| commit (sign/verify) | ✅ Implemented | GPG sign/verify via external `gpg` command |
| log / revwalk | ✅ Implemented | Topological commit graph traversal |
| revision resolve | ✅ Implemented | Parses specs like `HEAD~3`, `v1.0^` |
| branch list | ✅ Implemented | Local and remote branch listing |
| merge | ✅ Implemented | Three-way text merge |
| write-tree | ✅ Implemented | Build tree objects from index entries |
| clean | ✅ Implemented | Remove untracked files (dry-run support) |
| archive | ✅ Implemented | Tree traversal to build archive entries |
| blame | ⚠️ Partial | Finds blob in tree, no line-by-line tracking |
| checkout | ❌ Not implemented | |
| rebase | ❌ Not implemented | |
| reset | ❌ Not implemented | |
| commit hooks | ❌ Not implemented | |
| merge commits | ❌ Not implemented | Only blob/tree merge |
| credential helper | ⚠️ Stub | `fill()` returns input unchanged |

### Protocol & Transport

| Feature | Status | Notes |
|---------|--------|-------|
| Smart HTTP (fetch) | ✅ Implemented | V1 & V2 protocol |
| Smart HTTP (push) | ✅ Implemented | With `report-status`, `side-band-6k` |
| HTTPS (TLS) | ✅ Implemented | Via `stdx.net.tls` (OpenSSL 3) |
| SSH | ⚠️ Fallback | Falls back to system `git` command |
| Git protocol | ❌ Not implemented | `git://` scheme |
| Local protocol | ❌ Not implemented | |

### Object & Storage

| Feature | Status | Notes |
|---------|--------|-------|
| Read/write loose objects | ✅ Implemented | Blob, tree, commit, tag |
| Read/write pack files | ✅ Implemented | Pack index, delta encoding, pack writer |
| Read/write refs | ✅ Implemented | File, packed, general stores, transactions |
| Read/write index | ✅ Implemented | DIRC format parse/encode |
| Read/write config | ✅ Implemented | INI-style config file parse/write |
| commit-graph | ✅ Implemented | File parsing for accelerated traversal |
| shallow | ✅ Implemented | Shallow clone boundary management |

## Packages

| Package | Description |
|---------|-------------|
| `gix_actor` | Git signature/identity types (author, committer) |
| `gix_archive` | Git archive generation (tar format) |
| `gix_attributes` | `.gitattributes` file parsing and path matching |
| `gix_bitmap` | Bitmap data structure for efficient boolean set operations |
| `gix_blame` | Git blame — track last commit for each line |
| `gix_chunk` | Chunk file format parsing (used by commit-graph) |
| `gix_command` | External command execution wrapper (GPG, git, etc.) |
| `gix_commitgraph` | commit-graph file read/write for accelerated traversal |
| `gix_config` | Git configuration file parsing and writing |
| `gix_config_value` | Typed Git config value parsing (bool, color, integer, etc.) |
| `gix_credentials` | Git credential data structures and helper interface |
| `gix_date` | Git date/time types with timezone offset parsing |
| `gix_diff` | Tree-to-tree diff computation |
| `gix_dir` | Directory walking — recursive file and subdirectory scanning |
| `gix_discover` | Git repository discovery — upward `.git` directory search |
| `gix_error` | Base error type hierarchy (generic, message, validation errors) |
| `gix_features` | Runtime feature detection and progress reporting interface |
| `gix_fetchhead` | `.git/FETCH_HEAD` file parsing for fetch result tracking |
| `gix_filter` | Git filter pipeline (smudge/clean, CRLF, ident) |
| `gix_fs` | Filesystem capability detection and file attribute queries |
| `gix_fsck` | Repository integrity check — detect missing/corrupt objects |
| `gix_glob` | Git-style glob pattern matching with negation |
| `gix_hash` | Object identifier (OID) — SHA-1 hash representation |
| `gix_hashtable` | Chained hash table and thread-safe ObjectIdMap |
| `gix_ignore` | `.gitignore` file parsing and path exclusion |
| `gix_imara_diff` | Line-level diff via imara-diff algorithm (Myers O(ND)) |
| `gix_index` | Git index file (`.git/index`) parsing and encoding |
| `gix_lfs` | Git LFS pointer file parsing and serialization |
| `gix_lock` | Git file locking for mutual exclusion |
| `gix_mailmap` | `.mailmap` file parsing and email address mapping |
| `gix_merge` | Three-way merge (blob, tree, commit) |
| `gix_negotiate` | Fetch negotiation — track known commits for want/have |
| `gix_note` | Git notes — attach remarks to commit objects |
| `gix_object` | Git object types (blob/tree/commit/tag) parsing and serialization |
| `gix_odb` | Object database (ODB) facade — loose, pack, and compound stores |
| `gix_pack` | Git pack file format encoding/decoding, pack index, delta |
| `gix_packetline` | Git pkt-line format encoding/decoding for protocol framing |
| `gix_path` | Cross-platform path utilities — normalization, joining, conversion |
| `gix_pathspec` | Git pathspec parsing and path matching |
| `gix_prompt` | Interactive user prompt abstraction |
| `gix_protocol` | Git protocol layer — handshake, fetch, push connections |
| `gix_quote` | Git-style shell quoting and unquoting |
| `gix_rebase` | Git rebase todo list parsing |
| `gix_ref` | Git reference management — read/write refs under `refs/` |
| `gix_refspec` | Git refspec parsing — fetch/push reference mapping rules |
| `gix_revision` | Git revision spec parsing, merge-base, describe algorithms |
| `gix_revwalk` | Commit graph traversal in topological order |
| `gix_sec` | Security trust level and user identity abstraction |
| `gix_sequencer` | Git sequencer — parse and execute todo lists |
| `gix_shallow` | `.git/shallow` file parsing — shallow clone boundary management |
| `gix_status` | Git status query — staged and unstaged file state types |
| `gix_submodule` | Git submodule parsing from `.gitmodules` |
| `gix_tempfile` | Temporary file management with safe write and atomic persist |
| `gix_test_utils` | Test utility functions (fixture loading, hex conversion) |
| `gix_trace` | Lightweight log tracing infrastructure with level filtering |
| `gix_transport` | Git transport layer — HTTP/TLS transport, handshake, fetch, push |
| `gix_traverse` | Tree and commit traversal (BFS/DFS/topological) |
| `gix_url` | Git URL parsing (ssh://, https://, git@, file://, etc.) |
| `gix_utils` | General utilities (byte conversion, string normalization, backoff) |
| `gix_validate` | Git reference name validation |
| `gix_worktree` | Git worktree management — checkout and status queries |
| `gix_worktree_state` | Worktree state summary — clean/dirty detection |
| `gix_worktree_stream` | Worktree streaming output for checkout operations |
| `gix_zlib` | zlib compression/decompression for Git object storage |
| `repository` | Core Repository type — open, init, refs, objects, push, and more |

## Building

Requires [Cangjie SDK](https://cangjie-lang.cn/) 1.1.3+.

```bash
cjpm build
```

For TLS support (HTTPS push), the `stdx` library with OpenSSL 3 is required. See `cjpm.toml` for configuration.

## Relationship to gitoxide

gitoxide-cj is a port of [gitoxide](https://github.com/Byron/gitoxide) from Rust to Cangjie. The architecture and API design closely follow the original, with adaptations for Cangjie language conventions:

- No `any` / `unknown` types — explicit typing throughout
- `Option<T>` instead of Rust's `Result<T, E>` for fallible operations
- `if-let` pattern matching instead of `match` on `Result`
- `ArrayList<T>` / `HashMap<K,V>` from `std.collection`
- External process via `std.process.executeWithOutput` (no interactive stdin)

## License

Licensed under the [MIT License](LICENSE).
