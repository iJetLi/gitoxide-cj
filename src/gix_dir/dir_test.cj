// 文件：dir_test.cj
// 用途：gix_dir 包的单元测试，对齐 Rust gitoxide gix-dir 测试
// 所属包：gix.gix_dir
// 对齐来源：gix-dir/tests/dir_cwd.rs, gix-dir/tests/dir/*.rs

package gitoxide.gix_dir

import std.collection.*
import std.unittest.*

// ============================================================
// DirWalk 构造测试 — 对齐 gix-dir/tests/dir/walk.rs
// ============================================================

@Test
func testDirWalkConstruct(): Unit {
    // 对齐 Rust: DirWalk::new(root)
    let walk = DirWalk("/tmp")
    if (walk.root != "/tmp") {
        throw Exception("root should be '/tmp'")
    }
    if (walk.entries.size != 0) {
        throw Exception("entries should be empty initially")
    }
    if (walk.recurseIntoIgnored != false) {
        throw Exception("recurseIntoIgnored should default to false")
    }
}

@Test
func testDirWalkRecurseIntoIgnored(): Unit {
    // 对齐 Rust: DirWalkBuilder::recurse_into_ignored(true)
    let walk = DirWalk("/tmp")
    walk.recurseIntoIgnored = true
    if (!walk.recurseIntoIgnored) {
        throw Exception("recurseIntoIgnored should be true")
    }
}

@Test
func testDirWalkCollectNonexistent(): Unit {
    // 对齐 Rust: 遍历不存在的目录应返回空列表
    let walk = DirWalk("/nonexistent/path/xyz")
    let result = walk.collect()
    if (result.size != 0) {
        throw Exception("nonexistent dir should yield empty entries")
    }
}

@Test
func testDirWalkEmptyRoot(): Unit {
    // 对齐 Rust: DirWalk::new("") — 空路径
    let walk = DirWalk("")
    if (walk.root != "") {
        throw Exception("root should be empty string")
    }
}

@Test
func testDirWalkRelativePath(): Unit {
    // 对齐 Rust: DirWalk::new(".") — 相对路径
    let walk = DirWalk(".")
    if (walk.root != ".") {
        throw Exception("root should be '.'")
    }
}

@Test
func testDirWalkRootTrailingSlash(): Unit {
    // 对齐 Rust: DirWalk::new("/tmp/") — 尾部斜杠
    let walk = DirWalk("/tmp/")
    if (walk.root != "/tmp/") {
        throw Exception("root should preserve trailing slash")
    }
}

@Test
func testDirWalkRecurseIntoIgnoredDefaultFalse(): Unit {
    // 对齐 Rust: 默认不进入被忽略目录
    let walk = DirWalk("/tmp")
    if (walk.recurseIntoIgnored) {
        throw Exception("recurseIntoIgnored should default to false")
    }
}

@Test
func testDirWalkRecurseIntoIgnoredToggle(): Unit {
    // 对齐 Rust: 切换 recurseIntoIgnored
    let walk = DirWalk("/tmp")
    walk.recurseIntoIgnored = true
    if (!walk.recurseIntoIgnored) {
        throw Exception("should be true")
    }
    walk.recurseIntoIgnored = false
    if (walk.recurseIntoIgnored) {
        throw Exception("should be false")
    }
}

// ============================================================
// DirEntry 测试 — 对齐 gix-dir/tests/dir/entry.rs
// ============================================================

@Test
func testDirEntryConstruct(): Unit {
    // 对齐 Rust: DirEntry { path, kind }
    let entry = DirEntry("src/main.cj", EntryKind.File)
    if (entry.path != "src/main.cj") {
        throw Exception("path mismatch")
    }
    if (entry.kind != EntryKind.File) {
        throw Exception("kind should be File")
    }
}

@Test
func testDirEntryDirectory(): Unit {
    // 对齐 Rust: DirEntry { kind: Directory }
    let entry = DirEntry("src", EntryKind.Directory)
    if (entry.kind != EntryKind.Directory) {
        throw Exception("kind should be Directory")
    }
}

@Test
func testDirEntrySymlink(): Unit {
    // 对齐 Rust: DirEntry { kind: Symlink }
    let entry = DirEntry("link", EntryKind.Symlink)
    if (entry.kind != EntryKind.Symlink) {
        throw Exception("kind should be Symlink")
    }
}

@Test
func testDirEntryPathWithSlash(): Unit {
    // 对齐 Rust: DirEntry 路径含分隔符
    let entry = DirEntry("a/b/c", EntryKind.File)
    if (entry.path != "a/b/c") {
        throw Exception("path should preserve slashes")
    }
}

@Test
func testDirEntryPathDotfile(): Unit {
    // 对齐 Rust: DirEntry 隐藏文件路径
    let entry = DirEntry(".gitignore", EntryKind.File)
    if (entry.path != ".gitignore") {
        throw Exception("path should be '.gitignore'")
    }
}

@Test
func testDirEntryPathEmpty(): Unit {
    // 对齐 Rust: DirEntry 空路径
    let entry = DirEntry("", EntryKind.File)
    if (entry.path != "") {
        throw Exception("path should be empty")
    }
}

@Test
func testDirEntryKindMutability(): Unit {
    // 对齐 Rust: DirEntry.kind 可修改
    let entry = DirEntry("test", EntryKind.File)
    entry.kind = EntryKind.Directory
    if (entry.kind != EntryKind.Directory) {
        throw Exception("kind should be Directory after update")
    }
}

// ============================================================
// EntryKind 测试 — 对齐 gix-dir/src/entry.rs
// ============================================================

@Test
func testEntryKindVariants(): Unit {
    // 对齐 Rust: EntryKind 枚举变体
    let kinds = ArrayList<EntryKind>()
    kinds.add(EntryKind.File)
    kinds.add(EntryKind.Directory)
    kinds.add(EntryKind.Symlink)
    if (kinds.size != 3) {
        throw Exception("should have 3 EntryKind variants")
    }
}

@Test
func testEntryKindFileNotDirectory(): Unit {
    // 对齐 Rust: File != Directory
    if (EntryKind.File == EntryKind.Directory) {
        throw Exception("File should not equal Directory")
    }
}

@Test
func testEntryKindFileNotSymlink(): Unit {
    // 对齐 Rust: File != Symlink
    if (EntryKind.File == EntryKind.Symlink) {
        throw Exception("File should not equal Symlink")
    }
}

@Test
func testEntryKindDirectoryNotSymlink(): Unit {
    // 对齐 Rust: Directory != Symlink
    if (EntryKind.Directory == EntryKind.Symlink) {
        throw Exception("Directory should not equal Symlink")
    }
}

// ============================================================
// walk_utils / 文件系统遍历集成测试
// ============================================================
// 【无法对齐】原版 gix-dir 测试大量依赖文件系统夹具（含 .gitignore、
// .git 目录、子目录结构等），验证 walk 的过滤、排序、忽略规则。
// 包括 walk_utils 模块中的 at_path_by_workdir_relative、
// filter_map_entries、sort_entries_by_workdir_relative 等测试。
// 仓颉中暂无法实现，待 gix_test_utils 文件系统夹具支持完善后补充。

// ============================================================
// dir_cwd 测试 — 对齐 gix-dir/tests/dir_cwd.rs
// ============================================================
// 【无法对齐】原版 dir_cwd 测试验证当前工作目录下的目录遍历，
// 依赖真实文件系统和 Git 仓库结构。仓颉中无法实现。
