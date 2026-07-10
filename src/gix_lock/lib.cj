// 文件：lib.cj
// 用途：提供 Git 文件锁机制，确保对文件的互斥访问
// 所属包：gix.gix_lock
// 关键类型：LockFile

package gitoxide.gix_lock

import std.sync.*
import std.fs.*

// 文件锁，通过 .lock 文件实现 Git 风格的互斥访问
// 获取锁后可写入 .lock 文件，提交时原子性地重命名为目标文件
public class LockFile {
    // 目标文件路径
    var path: String
    // 锁文件路径（目标路径 + ".lock"）
    var lockPath: String
    // 互斥锁
    var locked: Mutex
    // 是否已获取锁
    var acquired: Bool

    // 构造函数
    // 参数 path：目标文件路径
    public init(path: String) {
        this.path = path
        this.lockPath = path + ".lock"
        this.locked = Mutex()
        this.acquired = false
    }

    // 尝试获取文件锁（非阻塞）
    // 返回值：成功获取返回 true，锁已被占用返回 false
    public func tryAcquire(): Bool {
        if (locked.tryLock()) {
            acquired = true
            true
        } else {
            false
        }
    }

    // 获取文件锁（阻塞）
    public func acquire(): Unit {
        locked.lock()
        acquired = true
    }

    // 提交锁文件，将 .lock 文件原子性地重命名为目标文件
    public func commit(): Unit {
        if (acquired) {
            if (exists(lockPath)) {
                doRenameFile(lockPath, path)
            }
            release()
        }
    }

    // 释放文件锁，删除 .lock 文件并解锁互斥锁
    public func release(): Unit {
        if (acquired) {
            if (exists(lockPath)) {
                try {
                    remove(lockPath)
                } catch (_: Exception) {}
            }
            locked.unlock()
            acquired = false
        }
    }
}

// 重命名文件
// 参数 from：源文件路径
// 参数 to：目标文件路径
func doRenameFile(from: String, to: String): Unit {
    try {
        rename(from, to: to)
    } catch (_: Exception) {}
}

// 获取锁的失败模式
// 对齐 Rust: gix_lock::acquire::Fail
public enum Fail {
    // 立即失败
    | Immediately
    // 在指定时长后失败（带退避重试）
    | AfterDurationWithBackoff(Int64)
}

// 锁标记，仅持有锁但不打开文件进行写入
// 对齐 Rust: gix_lock::Marker
public class Marker {
    var resource: String
    var lock: String
    var isHeld: Bool
    // 标记是否为可写入的锁文件（Marker 不可写，File 可写）
    // 对齐 Rust: Marker::commit 对不可写标记应返回错误
    var wasOpenedForWriting: Bool

    public init(resource: String) {
        this.resource = resource
        this.lock = resource + ".lock"
        this.isHeld = false
        this.wasOpenedForWriting = false
    }

    // 获取锁标记
    // 对齐 Rust: Marker::acquire_to_hold_resource
    public func acquire(): Unit {
        isHeld = true
    }

    // 尝试获取锁标记（非阻塞）
    // 对齐 Rust: Marker::acquire_to_hold_resource with Fail::Immediately
    // 返回值: None 表示成功，Some(msg) 表示失败
    public func tryAcquire(failMode: Fail): ?String {
        if (isHeld) {
            match (failMode) {
                case Fail.Immediately => Some(
                    "the lock for '" + resource + "' could not be obtained immediately, lock file at '" + lock +
                        "' exists")
                case Fail.AfterDurationWithBackoff(_) => Some(
                    "the lock for '" + resource + "' could not be obtained after timeout, lock file at '" + lock +
                        "' exists")
            }
        } else {
            isHeld = true
            None
        }
    }

    // 提交锁标记
    // 对齐 Rust: Marker::commit — 不可写标记提交时应返回错误
    public func commit(): ?String {
        if (!isHeld) {
            return Some("marker is not held")
        }
        if (!wasOpenedForWriting) {
            isHeld = false
            return Some("refusing to commit marker that was never opened")
        }
        if (exists(lock)) {
            doRenameFile(lock, resource)
        }
        isHeld = false
        None
    }

    // 释放锁标记
    public func release(): Unit {
        if (isHeld && exists(lock)) {
            try {
                remove(lock)
            } catch (_: Exception) {}
        }
        isHeld = false
    }

    // 获取锁文件路径
    public func lockPath(): String {
        lock
    }

    // 获取资源路径
    public func resourcePath(): String {
        resource
    }

    // 标记为可写入（由 LockFile 使用）
    public func markAsWritable(): Unit {
        wasOpenedForWriting = true
    }
}

// 为文件路径添加 .lock 后缀
// 对齐 Rust: gix_lock::acquire::add_lock_suffix
// 参数 path：原始文件路径
// 返回值：添加 .lock 后缀的路径
public func addLockSuffix(path: String): String {
    path + ".lock"
}
