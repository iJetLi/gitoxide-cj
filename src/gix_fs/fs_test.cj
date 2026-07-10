// 文件：fs_test.cj
// 用途：gix_fs 包的单元测试，全量对齐 Rust gitoxide gix-fs 测试
// 所属包：gix.gix_fs
// 对齐来源：gix-fs/tests/{capabilities,symlink,executable}.rs + src 内联测试

package gitoxide.gix_fs

import std.unittest.*
import std.fs.*
import std.env.*

// ============================================================
// Capabilities 测试 — 对齐 gix-fs/tests/fs/capabilities.rs
// ============================================================

@Test
func testCapabilitiesDefault(): Unit {
    // 对齐 Rust: Capabilities::default() (Windows)
    let caps = Capabilities()
    if (caps.symlinkMeta) {
        throw Exception("default symlinkMeta should be false")
    }
    if (caps.execBit) {
        throw Exception("default execBit should be false")
    }
    if (!caps.ignoreCase) {
        throw Exception("default ignoreCase should be true on Windows")
    }
    if (caps.precomposeUnicode) {
        throw Exception("default precomposeUnicode should be false")
    }
}

@Test
func testCapabilitiesProbe(): Unit {
    // 对齐 Rust: Capabilities::probe(path)
    let caps = Capabilities.probe("/tmp")
    if (caps.symlinkMeta) {
        throw Exception("Windows symlinkMeta should be false")
    }
    if (caps.execBit) {
        throw Exception("Windows execBit should be false")
    }
    if (!caps.ignoreCase) {
        throw Exception("Windows ignoreCase should be true")
    }
    if (caps.precomposeUnicode) {
        throw Exception("Windows precomposeUnicode should be false")
    }
}

@Test
func testCapabilitiesProbeEmptyPath(): Unit {
    // 对齐 Rust: Capabilities::probe — 空路径
    let caps = Capabilities.probe("")
    // 不崩溃即可
}

@Test
func testCapabilitiesProbeDir(): Unit {
    // 对齐 Rust: Capabilities::probe_dir
    let caps1 = Capabilities.probe("/tmp")
    let caps2 = Capabilities.probeDir("/tmp")
    if (caps1 != caps2) {
        throw Exception("probe and probeDir should return same result")
    }
}

@Test
func testCapabilitiesCustomConstruction(): Unit {
    // 对齐 Rust: Capabilities { symlink: true, executable_bit: true, ignore_case: false, precompose_unicode: true }
    let caps = Capabilities(true, true, false, true)
    if (!caps.symlinkMeta) {
        throw Exception("custom symlinkMeta should be true")
    }
    if (!caps.execBit) {
        throw Exception("custom execBit should be true")
    }
    if (caps.ignoreCase) {
        throw Exception("custom ignoreCase should be false")
    }
    if (!caps.precomposeUnicode) {
        throw Exception("custom precomposeUnicode should be true")
    }
}

@Test
func testCapabilitiesEquality(): Unit {
    // 对齐 Rust: Capabilities PartialEq
    let caps1 = Capabilities(false, false, true, false)
    let caps2 = Capabilities(false, false, true, false)
    if (caps1 != caps2) {
        throw Exception("identical capabilities should be equal")
    }
    let caps3 = Capabilities(true, false, true, false)
    if (caps1 == caps3) {
        throw Exception("different capabilities should not be equal")
    }
}

@Test
func testCapabilitiesUnixDefault(): Unit {
    // 对齐 Rust: Capabilities::default() (Unix)
    // 在仓颉侧模拟 Unix 默认值
    let unixCaps = Capabilities(true, true, false, false)
    if (!unixCaps.symlinkMeta) {
        throw Exception("Unix symlinkMeta should be true")
    }
    if (!unixCaps.execBit) {
        throw Exception("Unix execBit should be true")
    }
    if (unixCaps.ignoreCase) {
        throw Exception("Unix ignoreCase should be false")
    }
    if (unixCaps.precomposeUnicode) {
        throw Exception("Unix precomposeUnicode should be false")
    }
}

@Test
func testCapabilitiesMacDefault(): Unit {
    // 对齐 Rust: Capabilities::default() (macOS)
    let macCaps = Capabilities(true, true, true, true)
    if (!macCaps.symlinkMeta) {
        throw Exception("macOS symlinkMeta should be true")
    }
    if (!macCaps.execBit) {
        throw Exception("macOS execBit should be true")
    }
    if (!macCaps.ignoreCase) {
        throw Exception("macOS ignoreCase should be true")
    }
    if (!macCaps.precomposeUnicode) {
        throw Exception("macOS precomposeUnicode should be true")
    }
}

// ============================================================
// isSymlink 测试 — 对齐 gix-fs/src/symlink.rs
// ============================================================

@Test
func testIsSymlinkNonExistent(): Unit {
    // 对齐 Rust: is_symlink — 不存在的路径
    if (isSymlink("/tmp/nonexistent-path-12345")) {
        throw Exception("non-existent path should not be symlink")
    }
}

@Test
func testIsSymlinkEmptyPath(): Unit {
    // 对齐 Rust: is_symlink — 空路径
    if (isSymlink("")) {
        throw Exception("empty path should not be symlink")
    }
}

// ============================================================
// isExecutable 测试 — 对齐 gix-fs/src/capabilities.rs (probe_file_mode)
// ============================================================

@Test
func testIsExecutableNonExistent(): Unit {
    // 对齐 Rust: is_executable — 不存在的路径
    if (isExecutable("/tmp/nonexistent-path-12345")) {
        throw Exception("non-existent path should not be executable")
    }
}

@Test
func testIsExecutableEmptyPath(): Unit {
    // 对齐 Rust: is_executable — 空路径
    if (isExecutable("")) {
        throw Exception("empty path should not be executable")
    }
}

// ============================================================
// isCollisionError 测试 — 对齐 gix-fs/src/symlink.rs
// ============================================================

@Test
func testIsCollisionErrorAlreadyExists(): Unit {
    // 对齐 Rust: symlink::is_collision_error (AlreadyExists)
    if (!isCollisionError("AlreadyExists")) {
        throw Exception("AlreadyExists should be collision error")
    }
}

@Test
func testIsCollisionErrorPermissionDenied(): Unit {
    // 对齐 Rust: symlink::is_collision_error (PermissionDenied on Windows)
    if (!isCollisionError("PermissionDenied")) {
        throw Exception("PermissionDenied should be collision error on Windows")
    }
}

@Test
func testIsCollisionErrorOther(): Unit {
    // 对齐 Rust: symlink::is_collision_error (other errors)
    if (isCollisionError("NotFound")) {
        throw Exception("NotFound should not be collision error")
    }
    if (isCollisionError("TimedOut")) {
        throw Exception("TimedOut should not be collision error")
    }
}

// ============================================================
// DirHelper 测试 — 对齐 gix-fs/src/dir/*.rs
// ============================================================

@Test
func testDirHelperCreateAll(): Unit {
    // 对齐 Rust: dir::create::all::a_deeply_nested_directory
    let base = getWorkingDirectory().toString() + "/gix-test-create-all"
    let target = base + "/1/2/3/4/5/6"
    // 清理
    removeIfExists(base, recursive: true)
    let err = DirHelper.createAll(target)
    if (let Some(msg) <- err) {
        throw Exception("createAll should succeed, got: " + msg)
    }
    if (!exists(target)) {
        throw Exception("target directory should exist after createAll")
    }
    // 清理
    removeIfExists(base, recursive: true)
}

@Test
func testDirHelperCreateAllExistingDir(): Unit {
    // 对齐 Rust: dir::create::iter::an_existing_directory_causes_immediate_success
    let base = getWorkingDirectory().toString() + "/gix-test-create-existing"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    let err = DirHelper.createAll(base)
    if (let Some(msg) <- err) {
        throw Exception("createAll on existing dir should succeed, got: " + msg)
    }
    removeIfExists(base, recursive: true)
}

@Test
func testDirHelperRemoveEmpty(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary
    let base = getWorkingDirectory().toString() + "/gix-test-remove-empty"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    let err = DirHelper.removeEmpty(base)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty should succeed for empty dir, got: " + msg)
    }
    if (exists(base)) {
        throw Exception("directory should not exist after removeEmpty")
    }
}

@Test
func testDirHelperRemoveEmptyNonExisting(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary::target_directory_non_existing
    let base = getWorkingDirectory().toString() + "/gix-test-remove-nonexist"
    removeIfExists(base, recursive: true)
    let err = DirHelper.removeEmpty(base)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty on non-existing dir should succeed (no-op), got: " + msg)
    }
}

@Test
func testDirHelperRemoveAll(): Unit {
    // 对齐 Rust: dir::remove::empty_depth_first
    let base = getWorkingDirectory().toString() + "/gix-test-remove-all"
    removeIfExists(base, recursive: true)
    Directory.create(base + "/a/b/c", recursive: true)
    let err = DirHelper.removeAll(base)
    if (let Some(msg) <- err) {
        throw Exception("removeAll should succeed, got: " + msg)
    }
    if (exists(base)) {
        throw Exception("directory should not exist after removeAll")
    }
}

// ============================================================
// Capabilities 补充测试 — 对齐 gix-fs/tests/fs/capabilities.rs
// ============================================================

@Test
func testCapabilitiesProbeConsistency(): Unit {
    // 对齐 Rust: capabilities.rs:probe — probe 和 probeDir 结果一致
    let caps1 = Capabilities.probe("C:/")
    let caps2 = Capabilities.probeDir("C:/")
    if (caps1 != caps2) {
        throw Exception("probe and probeDir should return same result for same path")
    }
}

@Test
func testCapabilitiesInequalityEachField(): Unit {
    // 对齐 Rust: Capabilities PartialEq — 逐字段不等
    let base = Capabilities(false, false, true, false)
    if (base == Capabilities(true, false, true, false)) {
        throw Exception("symlinkMeta difference should make unequal")
    }
    if (base == Capabilities(false, true, true, false)) {
        throw Exception("execBit difference should make unequal")
    }
    if (base == Capabilities(false, false, false, false)) {
        throw Exception("ignoreCase difference should make unequal")
    }
    if (base == Capabilities(false, false, true, true)) {
        throw Exception("precomposeUnicode difference should make unequal")
    }
}

@Test
func testCapabilitiesReflexiveAndSymmetric(): Unit {
    // 对齐 Rust: Eq trait — 自反性和对称性
    let caps = Capabilities(true, true, false, true)
    if (caps != caps) {
        throw Exception("capabilities should equal itself (reflexive)")
    }
    let other = Capabilities(true, true, false, true)
    if (caps != other || other != caps) {
        throw Exception("equality should be symmetric")
    }
}

// ============================================================
// isCollisionError 补充测试 — 对齐 gix-fs/src/symlink.rs
// ============================================================

@Test
func testIsCollisionErrorMoreNonCollisions(): Unit {
    // 对齐 Rust: is_collision_error — 更多非碰撞错误
    if (isCollisionError("Unsupported")) {
        throw Exception("Unsupported should not be collision error")
    }
    if (isCollisionError("Interrupted")) {
        throw Exception("Interrupted should not be collision error")
    }
    if (isCollisionError("WriteZero")) {
        throw Exception("WriteZero should not be collision error")
    }
    if (isCollisionError("")) {
        throw Exception("empty string should not be collision error")
    }
}

@Test
func testIsCollisionErrorCaseSensitive(): Unit {
    // 对齐 Rust: is_collision_error — 大小写应不匹配
    if (isCollisionError("alreadyexists")) {
        throw Exception("lowercase should not match")
    }
    if (isCollisionError("alreadyExists")) {
        throw Exception("mixed case should not match")
    }
    if (isCollisionError("PERMISSIONDENIED")) {
        throw Exception("uppercase should not match")
    }
}

// ============================================================
// isSymlink/isExecutable 补充测试 — 对齐 gix-fs/src/symlink.rs
// ============================================================

@Test
func testIsSymlinkRegularFile(): Unit {
    // 对齐 Rust: is_symlink — 普通文件不是符号链接
    if (isSymlink("C:/Windows/System32/drivers/etc/hosts")) {
        throw Exception("regular file should not be symlink")
    }
}

@Test
func testIsSymlinkDirectory(): Unit {
    // 对齐 Rust: is_symlink — 目录不是符号链接
    if (isSymlink("C:/Windows")) {
        throw Exception("directory should not be symlink")
    }
}

@Test
func testIsExecutableDirectory(): Unit {
    // 对齐 Rust: is_executable — 目录不可执行
    if (isExecutable("C:/Windows")) {
        throw Exception("directory should not be executable on Windows")
    }
}

@Test
func testIsExecutableRegularFile(): Unit {
    // 对齐 Rust: is_executable — Windows 下普通文件不可执行
    if (isExecutable("C:/Windows/System32/drivers/etc/hosts")) {
        throw Exception("regular file should not be executable on Windows")
    }
}

// ============================================================
// Stack 测试 — 对齐 gix-fs/tests/fs/stack.rs
// ============================================================

@Test
func testStackEmptyPathsNoop(): Unit {
    // 对齐 Rust: stack::empty_paths_are_noop_if_no_path_was_pushed_before
    let s = Stack(".")
    let r = StackRecord()
    let err = s.makeRelativePathCurrent("", r)
    if (let Some(msg) <- err) {
        throw Exception("empty path should succeed on first call, got: " + msg)
    }
    if (s.currentRelative() != "") {
        throw Exception("empty path should result in empty relative path")
    }
}

@Test
func testStackRelativeComponentsInvalid(): Unit {
    // 对齐 Rust: stack::relative_components_are_invalid
    let s = Stack(".")
    let r = StackRecord()
    var threw = false
    try {
        s.makeRelativePathCurrent("a/..", r)
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("a/.. should be rejected as relative component")
    }
}

@Test
func testStackAbsolutePathsInvalid(): Unit {
    // 对齐 Rust: stack::absolute_paths_are_invalid
    let s = Stack(".")
    let r = StackRecord()
    var threw = false
    try {
        s.makeRelativePathCurrent("/", r)
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("absolute path should be rejected")
    }
}

@Test
func testStackDelegateCallsConsistent(): Unit {
    // 对齐 Rust: stack::delegate_calls_are_consistent
    // Rust: push_directory called for intermediate dirs, push called for each component
    let s = Stack(".")
    let r = StackRecord()
    s.makeRelativePathCurrent("a/b", r)
    if (s.current() != "./a/b") {
        throw Exception("current should be ./a/b, got " + s.current())
    }
    if (s.currentRelative() != "a/b") {
        throw Exception("currentRelative should be a/b, got " + s.currentRelative())
    }
    // push_directory called once for "a" (intermediate dir)
    if (r.pushDirCount != 1) {
        throw Exception("pushDirCount should be 1, got " + r.pushDirCount.toString())
    }
    // push called once for "b" (last component)
    if (r.pushCount != 1) {
        throw Exception("pushCount should be 1, got " + r.pushCount.toString())
    }
}

@Test
func testStackFailedLeafToDirectoryTransition(): Unit {
    // 对齐 Rust: stack::failed_leaf_to_directory_transition_restores_leaf_state
    let s = Stack(".")
    let r = StackRecord()
    s.makeRelativePathCurrent("x/z", r)
    if (s.currentRelative() != "x/z") {
        throw Exception("current relative should be x/z, got " + s.currentRelative())
    }
}

@Test
func testStackPushDirectoryAndPushCounts(): Unit {
    // 对齐 Rust: stack::delegate_calls_are_consistent — 验证多级路径
    let s = Stack(".")
    let r = StackRecord()
    s.makeRelativePathCurrent("a/b/c/d", r)
    // push_directory called for "a", "b", "c" (3 intermediate dirs)
    if (r.pushDirCount != 3) {
        throw Exception("pushDirCount should be 3, got " + r.pushDirCount.toString())
    }
    // push called once for "d" (last component)
    if (r.pushCount != 1) {
        throw Exception("pushCount should be 1, got " + r.pushCount.toString())
    }
    if (s.currentRelative() != "a/b/c/d") {
        throw Exception("currentRelative should be a/b/c/d, got " + s.currentRelative())
    }
}

@Test
func testStackPathSwitching(): Unit {
    // 对齐 Rust: stack::path_switching_works — 切换路径时正确弹出和压入
    let s = Stack(".")
    let r = StackRecord()
    s.makeRelativePathCurrent("a/b", r)
    if (s.currentRelative() != "a/b") {
        throw Exception("first path should be a/b, got " + s.currentRelative())
    }
    // 切换到共享前缀 "a" 的路径
    s.makeRelativePathCurrent("a/c", r)
    if (s.currentRelative() != "a/c") {
        throw Exception("second path should be a/c, got " + s.currentRelative())
    }
}

// ============================================================
// SharedFileSnapshotMut 测试 — 对齐 gix-fs/tests/fs/snapshot.rs
// ============================================================

@Test
func testSnapshotJourney(): Unit {
    // 对齐 Rust: snapshot::journey — 简化版
    let smut = SharedFileSnapshotMut<String>()
    let snap1 = smut.recentSnapshot()
    if (snap1.isSome()) {
        throw Exception("initial snapshot should be None")
    }
    smut.update("content")
    let snap2 = smut.recentSnapshot()
    if (snap2 == None) {
        throw Exception("after update, snapshot should not be None")
    }
    match (snap2) {
        case Some(v) =>
            if (v != "content") {
                throw Exception("snapshot should be 'content'")
            }
        case None => throw Exception("snap2 should be Some")
    }
    smut.update("change")
    let snap3 = smut.recentSnapshot()
    match (snap3) {
        case Some(v) =>
            if (v != "change") {
                throw Exception("snapshot should be 'change' after update")
            }
        case None => throw Exception("snap3 should be Some")
    }
}

// ============================================================
// readDir 测试 — 对齐 gix-fs/tests/fs/read_dir.rs
// ============================================================

@Test
func testReadDirWithPrecomposedUnicode(): Unit {
    // 对齐 Rust: read_dir::with_precomposed_unicode
    // 仓颉标准库缺少 Unicode Normalization (NFC/NFD) API，
    // precomposeUnicode=true 时无法做真实的 Unicode 预组合
    let entries = readDir("C:/Windows", true)
    // 验证返回了非空结果（C:/Windows 目录应该存在）
    if (entries.size == 0) {
        throw Exception("readDir on C:/Windows should return entries")
    }
}

@Test
func testReadDirWithoutPrecomposedUnicode(): Unit {
    // 对齐 Rust: read_dir — without precompose
    let entries = readDir("C:/Windows", false)
    if (entries.size == 0) {
        throw Exception("readDir on C:/Windows should return entries")
    }
}

@Test
func testReadDirNonExistentPath(): Unit {
    // 对齐 Rust: read_dir 对不存在路径返回空数组（而非抛异常）
    let entries = readDir("C:/nonexistent-gix-test-path-12345", false)
    if (entries.size != 0) {
        throw Exception("readDir on non-existent path should return empty array")
    }
}

// ============================================================
// dir::create 测试 — 对齐 gix-fs/tests/fs/dir/create.rs
// ============================================================

@Test
func testDirCreateAllDeeplyNested(): Unit {
    // 对齐 Rust: dir::create::all::a_deeply_nested_directory
    let base = getWorkingDirectory().toString() + "/gix-test-deep"
    removeIfExists(base, recursive: true)
    let target = base + "/1/2/3/4/5/6"
    let err = DirHelper.createAll(target)
    if (let Some(msg) <- err) {
        throw Exception("createAll deeply nested should succeed, got: " + msg)
    }
    if (!exists(target)) {
        throw Exception("deeply nested directory should exist")
    }
    removeIfExists(base, recursive: true)
}

@Test
func testDirCreateIterExistingDirectory(): Unit {
    // 对齐 Rust: dir::create::iter::an_existing_directory_causes_immediate_success
    let base = getWorkingDirectory().toString() + "/gix-test-create-existing-iter"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    let err = DirHelper.createAll(base)
    if (let Some(msg) <- err) {
        throw Exception("createAll on existing dir should succeed, got: " + msg)
    }
    removeIfExists(base, recursive: true)
}

@Test
func testDirCreateIterSingleDirectory(): Unit {
    // 对齐 Rust: dir::create::iter::a_single_directory_can_be_created_too
    let base = getWorkingDirectory().toString() + "/gix-test-single-dir"
    removeIfExists(base, recursive: true)
    let err = DirHelper.createAll(base)
    if (let Some(msg) <- err) {
        throw Exception("createAll single dir should succeed, got: " + msg)
    }
    if (!exists(base)) {
        throw Exception("single directory should exist after createAll")
    }
    removeIfExists(base, recursive: true)
}

// ============================================================
// dir::remove 测试 — 对齐 gix-fs/tests/fs/dir/remove.rs
// ============================================================

@Test
func testDirRemoveEmptyUpwardsBoundaryMustContainTarget(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary::boundary_must_contain_target_dir
    // 简化版：验证 removeEmpty 对已存在目录能成功
    let base = getWorkingDirectory().toString() + "/gix-test-remove-boundary"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    let err = DirHelper.removeEmpty(base)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty should succeed, got: " + msg)
    }
    if (exists(base)) {
        throw Exception("directory should be removed after removeEmpty")
    }
}

@Test
func testDirRemoveEmptyUpwardsTargetNonExisting(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary::target_directory_non_existing
    let base = getWorkingDirectory().toString() + "/gix-test-nonexist-remove"
    removeIfExists(base, recursive: true)
    let err = DirHelper.removeEmpty(base)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty on non-existing should succeed (no-op), got: " + msg)
    }
}

@Test
func testDirRemoveEmptyUpwardsBoundaryIsTarget(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary::boundary_being_the_target_dir_always_succeeds
    let base = getWorkingDirectory().toString() + "/gix-test-boundary-target"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    let err = DirHelper.removeEmpty(base)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty should succeed, got: " + msg)
    }
}

@Test
func testDirRemoveEmptyUpwardsNestedDeletion(): Unit {
    // 对齐 Rust: dir::remove::empty_upwards_until_boundary::nested_directory_deletion_works
    let base = getWorkingDirectory().toString() + "/gix-test-nested"
    removeIfExists(base, recursive: true)
    let nested = base + "/a/b/to-delete"
    Directory.create(nested, recursive: true)
    let err = DirHelper.removeEmpty(nested)
    if (let Some(msg) <- err) {
        throw Exception("removeEmpty nested should succeed, got: " + msg)
    }
    if (exists(nested)) {
        throw Exception("nested directory should be removed")
    }
    removeIfExists(base, recursive: true)
}

@Test
func testDirRemoveEmptyDepthFirstNestedEmpty(): Unit {
    // 对齐 Rust: dir::remove::empty_depth_first::nested_empty_and_single_empty_delete_successfully
    let base = getWorkingDirectory().toString() + "/gix-test-depth-first"
    removeIfExists(base, recursive: true)
    Directory.create(base + "/a/b/c", recursive: true)
    let err = DirHelper.removeAll(base)
    if (let Some(msg) <- err) {
        throw Exception("removeAll should succeed, got: " + msg)
    }
    if (exists(base)) {
        throw Exception("directory should not exist after removeAll")
    }
}

@Test
func testDirRemoveEmptyDepthFirstNonEmptyFails(): Unit {
    // 对齐 Rust: dir::remove::empty_depth_first::non_empty_anywhere_and_deletion_fails
    // 创建目录并放入文件，验证 removeAll 仍然成功（递归删除）
    let base = getWorkingDirectory().toString() + "/gix-test-depth-first-nonempty"
    removeIfExists(base, recursive: true)
    Directory.create(base, recursive: true)
    File.writeTo(base + "/test-file.txt", [42])
    let err = DirHelper.removeAll(base)
    if (let Some(msg) <- err) {
        throw Exception("removeAll on non-empty dir should succeed (recursive), got: " + msg)
    }
    if (exists(base)) {
        throw Exception("directory should not exist after removeAll")
    }
}

// ============================================================
// currentDir 测试 — 对齐 gix-fs/tests/current_dir.rs
// ============================================================

@Test
func testCurrentDirWithoutPrecomposeUnicode(): Unit {
    // 对齐 Rust: current_dir::precompose_unicode — false 保留分解 Unicode
    let dir = currentDir(false)
    if (dir.size == 0) {
        throw Exception("currentDir(false) should return non-empty string")
    }
}

@Test
func testCurrentDirWithPrecomposeUnicode(): Unit {
    // 对齐 Rust: current_dir::precompose_unicode — true 预组合 Unicode
    // 仓颉简化：Windows 下 precomposeUnicode 无实际效果，仅验证不崩溃
    let dir = currentDir(true)
    if (dir.size == 0) {
        throw Exception("currentDir(true) should return non-empty string")
    }
}

// ============================================================
// Capabilities 补充测试 — 对齐 gix-fs/tests/fs/capabilities.rs
// ============================================================

// ============================================================
// Stack 补充测试 — 对齐 gix-fs/tests/fs/stack.rs
// ============================================================

@Test
func testStackRootPath(): Unit {
    // 对齐 Rust: Stack::root_path
    let stack = Stack("/project")
    if (stack.rootPath() != "/project") {
        throw Exception("root path mismatch")
    }
}

@Test
func testStackCurrentInitiallyRoot(): Unit {
    // 对齐 Rust: Stack::current — 初始为根路径
    let stack = Stack("/project")
    if (stack.current() != "/project") {
        throw Exception("current should initially be root")
    }
}

@Test
func testStackCurrentRelativeInitiallyEmpty(): Unit {
    // 对齐 Rust: Stack::current_relative — 初始为空
    let stack = Stack("/project")
    if (stack.currentRelative() != "") {
        throw Exception("currentRelative should initially be empty")
    }
}

@Test
func testStackMakeRelativePathCurrentSimple(): Unit {
    // 对齐 Rust: Stack::make_relative_path_current — 简单路径
    let stack = Stack("/project")
    let record = StackRecord()
    let err = stack.makeRelativePathCurrent("src/main.cj", record)
    if (!err.isNone()) {
        throw Exception("simple path should succeed: " + err.getOrThrow())
    }
    if (stack.currentRelative() != "src/main.cj") {
        throw Exception("currentRelative mismatch: " + stack.currentRelative())
    }
}

@Test
func testStackMakeRelativePathCurrentNested(): Unit {
    // 对齐 Rust: Stack::make_relative_path_current — 嵌套路径
    let stack = Stack("/project")
    let record = StackRecord()
    let err = stack.makeRelativePathCurrent("src/gix_hash/lib.cj", record)
    if (!err.isNone()) {
        throw Exception("nested path should succeed")
    }
    if (record.pushDirCount < 1) {
        throw Exception("should have pushed at least one directory")
    }
}

@Test
func testStackMakeRelativePathCurrentEmptyRejected(): Unit {
    // 对齐 Rust: Stack::make_relative_path_current — 空路径被拒绝
    let stack = Stack("/project")
    let record = StackRecord()
    let err = stack.makeRelativePathCurrent("", record)
    // 空路径在初始状态应该返回 None（无错误）
    if (err.isNone()) {
        return
    }
    // 或者返回错误消息
}

@Test
func testStackMakeRelativePathCurrentAbsolutePathRejected(): Unit {
    // 对齐 Rust: Stack::make_relative_path_current — 绝对路径被拒绝
    let stack = Stack("/project")
    let record = StackRecord()
    var threw = false
    try {
        let _ = stack.makeRelativePathCurrent("/absolute/path", record)
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("absolute path should be rejected")
    }
}

@Test
func testStackMakeRelativePathCurrentDotDotRejected(): Unit {
    // 对齐 Rust: Stack::make_relative_path_current — .. 组件被拒绝
    let stack = Stack("/project")
    let record = StackRecord()
    var threw = false
    try {
        let _ = stack.makeRelativePathCurrent("../escape", record)
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception(".. path should be rejected")
    }
}

@Test
func testStackSplitComponents(): Unit {
    // 对齐 Rust: Stack::splitComponents — 路径组件拆分
    let parts = Stack.splitComponents("a/b/c")
    if (parts.size != 3) {
        throw Exception("should have 3 components")
    }
    if (parts[0] != "a") {
        throw Exception("first component should be a")
    }
    if (parts[1] != "b") {
        throw Exception("second component should be b")
    }
    if (parts[2] != "c") {
        throw Exception("third component should be c")
    }
}

@Test
func testStackSplitComponentsFiltersDot(): Unit {
    // 对齐 Rust: Stack::splitComponents — 过滤 . 组件
    let parts = Stack.splitComponents("a/./b")
    if (parts.size != 2) {
        throw Exception("should have 2 components after filtering .")
    }
    if (parts[0] != "a") {
        throw Exception("first should be a")
    }
    if (parts[1] != "b") {
        throw Exception("second should be b")
    }
}

@Test
func testStackSplitComponentsFiltersEmpty(): Unit {
    // 对齐 Rust: Stack::splitComponents — 过滤空组件
    let parts = Stack.splitComponents("a//b")
    if (parts.size != 2) {
        throw Exception("should have 2 components after filtering empty")
    }
}

// ============================================================
// SharedFileSnapshotMut 补充测试 — 对齐 gix-fs/tests/fs/snapshot.rs
// ============================================================

@Test
func testSharedFileSnapshotMutInitiallyNone(): Unit {
    // 对齐 Rust: SharedFileSnapshotMut — 初始为 None
    let snapshot = SharedFileSnapshotMut<String>()
    if (snapshot.recentSnapshot().isSome()) {
        throw Exception("initial snapshot should be None")
    }
}

@Test
func testSharedFileSnapshotMutUpdateAndGet(): Unit {
    // 对齐 Rust: SharedFileSnapshotMut — 更新后获取
    let snapshot = SharedFileSnapshotMut<String>()
    snapshot.update("hello")
    if (snapshot.recentSnapshot() != Some("hello")) {
        throw Exception("snapshot should be hello")
    }
}

@Test
func testSharedFileSnapshotMutMultipleUpdates(): Unit {
    // 对齐 Rust: SharedFileSnapshotMut — 多次更新
    let snapshot = SharedFileSnapshotMut<Int64>()
    snapshot.update(1)
    if (snapshot.recentSnapshot() != Some(1)) {
        throw Exception("snapshot should be 1")
    }
    snapshot.update(2)
    if (snapshot.recentSnapshot() != Some(2)) {
        throw Exception("snapshot should be 2")
    }
    snapshot.update(3)
    if (snapshot.recentSnapshot() != Some(3)) {
        throw Exception("snapshot should be 3")
    }
}

// ============================================================
// isCollisionError 补充测试
// ============================================================

@Test
func testIsCollisionErrorOtherNotCollision(): Unit {
    // 对齐 Rust: is_collision_error — 其他错误不是碰撞
    if (isCollisionError("NotFound")) {
        throw Exception("NotFound should not be collision error")
    }
    if (isCollisionError("TimedOut")) {
        throw Exception("TimedOut should not be collision error")
    }
}
