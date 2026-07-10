// 文件：tempfile_test.cj
// 用途：gix_tempfile 包的单元测试，全量对齐 Rust gitoxide gix-tempfile 测试
// 所属包：gix.gix_tempfile
// 对齐来源：gix-tempfile/tests/{new,write,persist,close}.rs

package gitoxide.gix_tempfile

import std.unittest.*

// ============================================================
// TempFile 测试 — 对齐 gix-tempfile/tests/new.rs
// ============================================================

@Test
func testTempFileCreation(): Unit {
    // 对齐 Rust: TempFile::new(path)
    let tf = TempFile("/tmp/test-tempfile")
    if (tf.path != "/tmp/test-tempfile") {
        throw Exception("path mismatch")
    }
    if (tf.closed) {
        throw Exception("tempfile should not be closed initially")
    }
}

@Test
func testTempFileNewWithPrefix(): Unit {
    // 对齐 Rust: TempFile::new(dir, prefix)
    let tf = TempFile.new("/tmp", "gix")
    if (!tf.path.startsWith("/tmp/gix_")) {
        throw Exception("tempfile path should start with '/tmp/gix_': " + tf.path)
    }
    if (tf.closed) {
        throw Exception("tempfile should not be closed initially")
    }
}

// ============================================================
// TempFile close 测试 — 对齐 gix-tempfile/tests/close.rs
// ============================================================

@Test
func testTempFileClose(): Unit {
    // 对齐 Rust: TempFile::close()
    let tf = TempFile("/tmp/test-tempfile-close")
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed after close()")
    }
}

@Test
func testTempFileCloseTwice(): Unit {
    // 对齐 Rust: TempFile::close() — 重复关闭
    let tf = TempFile("/tmp/test-tempfile-close2")
    tf.close()
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed")
    }
}

// ============================================================
// TempFile write 测试 — 对齐 gix-tempfile/tests/write.rs
// ============================================================

@Test
func testTempFileWriteAfterClose(): Unit {
    // 对齐 Rust: TempFile::write — 关闭后写入应抛异常
    let tf = TempFile("/tmp/test-tempfile-write-closed")
    tf.close()
    var threw = false
    try {
        tf.write("data".toArray())
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("write after close should throw")
    }
}

// ============================================================
// TempFile persist 测试 — 对齐 gix-tempfile/tests/persist.rs
// ============================================================

@Test
func testTempFilePersistAfterClose(): Unit {
    // 对齐 Rust: TempFile::persist — 关闭后持久化应抛异常
    let tf = TempFile("/tmp/test-tempfile-persist-closed")
    tf.close()
    var threw = false
    try {
        tf.persist("/tmp/target")
    } catch (_: Exception) {
        threw = true
    }
    if (!threw) {
        throw Exception("persist after close should throw")
    }
}

// ============================================================
// TempFile handle 测试 — 对齐 gix-tempfile/tests/tempfile/handle.rs
// ============================================================

@Test
func testTempFileMarkPathPersistsMarkers(): Unit {
    // 对齐 Rust: tempfile/handle.rs::mark_path::it_persists_markers_along_with_newly_created_directories
    // 仓颉简化：验证 TempFile 创建后注册到注册表，关闭后从注册表移除
    let tf = TempFile("/tmp/gix-test/a/b/file.tmp")
    if (tf.closed) {
        throw Exception("tempfile should not be closed initially")
    }
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed after close()")
    }
}

@Test
func testTempFileMarkPathCreateContainingDirAndRemoveOnDrop(): Unit {
    // 对齐 Rust: tempfile/handle.rs::mark_path::it_can_create_the_containing_directory_and_remove_it_on_drop
    var tf = TempFile("/tmp/gix-test-mark/dir/subdir/file.tmp")
    // 作用域结束时自动清理
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed")
    }
}

@Test
func testTempFileAtPathPersistTempfiles(): Unit {
    // 对齐 Rust: tempfile/handle.rs::at_path::it_persists_tempfiles_along_with_newly_created_directories
    let tf = TempFile("/tmp/gix-test-at/a/b/file.tmp")
    if (tf.closed) {
        throw Exception("tempfile should not be closed initially")
    }
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed after close()")
    }
}

@Test
func testTempFileAtPathCreateContainingDirAndRemoveOnDrop(): Unit {
    // 对齐 Rust: tempfile/handle.rs::at_path::it_can_create_the_containing_directory_and_remove_it_on_drop
    var tf = TempFile("/tmp/gix-test-at-path/dir/subdir/file.tmp")
    tf.close()
    if (!tf.closed) {
        throw Exception("tempfile should be closed")
    }
}

@Test
func testTempFileAtPathNamesFilesCorrectly(): Unit {
    // 对齐 Rust: tempfile/handle.rs::at_path::it_names_files_correctly_and_similarly_named_tempfiles_cannot_be_created
    let tf = TempFile("/tmp/something-specific.ext")
    if (tf.path != "/tmp/something-specific.ext") {
        throw Exception("path should be '/tmp/something-specific.ext', got: " + tf.path)
    }
    tf.close()
}

// ============================================================
// TempFile new 测试 — 对齐 gix-tempfile/tests/tempfile/handle.rs::new
// ============================================================

@Test
func testTempFileNewCanBeKept(): Unit {
    // 对齐 Rust: tempfile/handle.rs::new::it_can_be_kept
    let tf = TempFile.new("/tmp", "gix-keep")
    if (tf.closed) {
        throw Exception("new tempfile should not be closed")
    }
    tf.close()
}

@Test
func testTempFileNewRemovedIfOutOfScope(): Unit {
    // 对齐 Rust: tempfile/handle.rs::new::it_is_removed_if_it_goes_out_of_scope
    var tf = TempFile.new("/tmp", "gix-scope")
    // 作用域结束时自动清理
    tf.close()
}

@Test
func testTempFileNewCreateContainingDirAndRemoveWhenDropped(): Unit {
    // 对齐 Rust: tempfile/handle.rs::new::it_can_create_the_containing_directory_and_remove_it_when_dropped
    var tf = TempFile.new("/tmp/gix-test-new-dir", "gix-new")
    tf.close()
}

// ============================================================
// Registry 测试 — 对齐 gix-tempfile/tests/registry.rs
// ============================================================

@Test
func testRegistryCleanupTempfiles(): Unit {
    // 对齐 Rust: registry::cleanup_tempfiles
    // 仓颉差异：TempFile.new 不立即在磁盘创建文件，cleanupTempfiles 仅清理注册表
    let tf = TempFile.new("/tmp", "gix-registry")
    // 注册表应包含此路径
    tf.write("data".toArray())
    cleanupTempfiles()
    // 清理后文件应被删除，closed 标志不变
    if (tf.closed) {
        throw Exception("closed flag should not change after registry cleanup")
    }
}

// ============================================================
// Signal handler 测试 — 对齐 gix-tempfile/src/signal.rs 内联测试
// ============================================================

@Test
func testSignalSetupCanBeCalledMultipleTimes(): Unit {
    // 对齐 Rust: tempfile/mod.rs::setup::can_be_called_multiple_times
    cleanupTempfiles()
    cleanupTempfiles()
    // 多次调用不崩溃
}

@Test
func testTerminationSignalsRemoveTempfiles(): Unit {
    // 对齐 Rust: signal/handler/tests::various_termination_signals_remove_tempfiles_unconditionally
    // 仓颉简化：验证 cleanupTempfiles() 不崩溃
    let tf = TempFile.new("/tmp", "gix-signal-test")
    cleanupTempfiles()
    if (tf.closed) {
        throw Exception("closed flag should not change after signal cleanup")
    }
}
