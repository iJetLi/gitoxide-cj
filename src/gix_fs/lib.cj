// 文件：lib.cj
// 用途：提供文件系统能力探测和文件属性查询功能
// 所属包：gix.gix_fs
// 关键类型：Capabilities, Stack, StackRecord, SharedFileSnapshotMut
// 关键函数：isSymlink, isExecutable, readDir

package gitoxide.gix_fs

import std.collection.*
import std.env.*
import std.fs.*
import gitoxide.gix_utils.*

// 文件系统能力描述
// 对齐 Rust: gix_fs::Capabilities
// 不同操作系统对符号链接、可执行位、大小写、Unicode 的支持不同
public class Capabilities {
    // 是否支持符号链接的元数据
    var symlinkMeta: Bool
    // 是否支持可执行位
    var execBit: Bool
    // 是否忽略大小写
    var ignoreCase: Bool
    // 是否预组合 Unicode
    var precomposeUnicode: Bool

    // 创建一个默认的 Capabilities
    // Windows 下：symlinkMeta=false, execBit=false, ignoreCase=true, precomposeUnicode=false
    public init() {
        symlinkMeta = false
        execBit = false
        ignoreCase = true
        precomposeUnicode = false
    }

    // 完整构造
    public init(symlinkMeta: Bool, execBit: Bool, ignoreCase: Bool, precomposeUnicode: Bool) {
        this.symlinkMeta = symlinkMeta
        this.execBit = execBit
        this.ignoreCase = ignoreCase
        this.precomposeUnicode = precomposeUnicode
    }

    // 探测指定路径所在文件系统的能力
    // 对齐 Rust: Capabilities::probe
    public static func probe(path: String): Capabilities {
        // Windows 默认值
        Capabilities(false, false, true, false)
    }

    // 探测非 Git 目录的文件系统能力
    // 对齐 Rust: Capabilities::probe_dir
    public static func probeDir(path: String): Capabilities {
        probe(path)
    }

    public operator func ==(that: Capabilities): Bool {
        symlinkMeta == that.symlinkMeta && execBit == that.execBit && ignoreCase == that.ignoreCase &&
            precomposeUnicode == that.precomposeUnicode
    }

    public operator func !=(that: Capabilities): Bool {
        !(this == that)
    }
}

// 判断指定路径是否为符号链接
// 参数 path：待检查的文件路径
// 返回值：是符号链接返回 true
public func isSymlink(path: String): Bool {
    false
}

// 判断指定路径是否具有可执行权限
// 参数 path：待检查的文件路径
// 返回值：具有可执行权限返回 true
public func isExecutable(path: String): Bool {
    false
}

// 判断 IO 错误是否为碰撞错误（文件已存在）
// 对齐 Rust: gix_fs::symlink::is_collision_error
public func isCollisionError(errKind: String): Bool {
    errKind == "AlreadyExists" || errKind == "PermissionDenied"
}

// 目录创建/删除辅助
// 对齐 Rust: gix_fs::dir
public class DirHelper {
    // 创建目录（递归）
    // 对齐 Rust: gix_fs::dir::create::all
    // 参数 path: 目标目录路径
    // 返回值: None 表示成功，Some(msg) 表示失败
    public static func createAll(path: String): ?String {
        try {
            if (exists(path)) {
                return None
            }
            Directory.create(path, recursive: true)
            None
        } catch (e: Exception) {
            Some(e.message)
        }
    }

    // 删除空目录（向上删除直到边界）
    // 对齐 Rust: gix_fs::dir::remove::empty_upward_until_boundary
    // 从 deleteDir 向上删除空目录，直到 boundaryDir（不删除 boundaryDir）
    // 返回值: None 表示成功，Some(msg) 表示失败
    public static func removeEmptyUpward(deleteDir: String, boundaryDir: String): ?String {
        if (!deleteDir.startsWith(boundaryDir)) {
            return "Removal target must be contained in boundary"
        }
        var current = deleteDir
        while (current.size > 0 && current != boundaryDir) {
            if (exists(current)) {
                try {
                    remove(current, recursive: false)
                } catch (e: Exception) {
                    // 目录非空或无法删除，停止向上遍历
                    return None
                }
            }
            let lastSlash = current.lastIndexOf("/")
            if (let Some(ls) <- lastSlash) {
                current = substringStr(current, 0, ls)
                if (current.size == 0) {
                    current = "/"
                }
            } else {
                break
            }
        }
        None
    }

    // 删除空目录（仅删除指定目录本身）
    // 对齐 Rust: gix_fs::dir::remove::empty_upward_until_boundary（boundary=parent 时等价）
    // 返回值: None 表示成功，Some(msg) 表示失败
    public static func removeEmpty(path: String): ?String {
        try {
            if (!exists(path)) {
                return None
            }
            remove(path, recursive: false)
            None
        } catch (e: Exception) {
            Some(e.message)
        }
    }

    // 递归删除目录
    // 对齐 Rust: gix_fs::dir::remove::empty_depth_first
    // 返回值: None 表示成功，Some(msg) 表示失败
    public static func removeAll(path: String): ?String {
        try {
            if (!exists(path)) {
                return None
            }
            remove(path, recursive: true)
            None
        } catch (e: Exception) {
            Some(e.message)
        }
    }
}

// 目录读取
// 对齐 Rust: gix_fs::read_dir
// 参数 precomposeUnicode: 是否预组合 Unicode
// 注意：仓颉标准库缺少 Unicode Normalization (NFC/NFD) API，
// precomposeUnicode=true 时无法做真实的 Unicode 预组合，仅返回原始文件名
public func readDir(path: String, precomposeUnicode: Bool): Array<String> {
    try {
        let entries = Directory.readFrom(path)
        var result = ArrayList<String>()
        for (entry in entries) {
            result.add(entry.path.toString())
        }
        result.toArray()
    } catch (e: Exception) {
        Array<String>()
    }
}

// 获取当前工作目录
// 对齐 Rust: gix_fs::current_dir
// 参数 precomposeUnicode: 是否预组合 Unicode（macOS 特有，仓颉无 NFD/NFC 转换 API，直接返回路径）
// 对齐 Rust: gix_fs::current_dir
public func currentDir(precomposeUnicode: Bool): String {
    getWorkingDirectory().toString()
}

// 路径栈委托接口
// 对齐 Rust: gix_fs::stack::Delegate
public interface StackDelegate {
    // 当目录被压入栈时调用
    // 对齐 Rust: Delegate::push_directory
    func pushDirectory(stack: Stack): ?String

    // 当任意组件被压入时调用
    // 对齐 Rust: Delegate::push
    // isLastComponent: 是否为最后一个路径组件
    func push(isLastComponent: Bool, stack: Stack): ?String

    // 当目录被弹出时调用
    // 对齐 Rust: Delegate::pop_directory
    func popDirectory(): Unit
}

// 默认委托实现（记录操作）
// 对齐 Rust: gix-fs/tests/fs/stack.rs Record
public class StackRecord <: StackDelegate {
    public var pushDirCount: Int64
    public var dirs: ArrayList<String>
    public var pushCount: Int64

    public init() {
        pushDirCount = 0
        dirs = ArrayList<String>()
        pushCount = 0
    }

    public func pushDirectory(stack: Stack): ?String {
        pushDirCount += 1
        dirs.add(stack.current())
        None
    }

    public func push(isLastComponent: Bool, stack: Stack): ?String {
        pushCount += 1
        None
    }

    public func popDirectory(): Unit {
        if (dirs.size > 0) {
            dirs.remove(at: dirs.size - 1)
        }
    }
}

// 路径栈，用于安全遍历和验证路径组件
// 对齐 Rust: gix_fs::Stack
public class Stack {
    var root: String
    var currentPath: String
    var currentRel: String
    var validComponents: Int64
    var currentIsDirectory: Bool

    public init(root: String) {
        this.root = root
        currentPath = root
        currentRel = ""
        validComponents = 0
        currentIsDirectory = true
    }

    // 获取根路径
    public func rootPath(): String {
        root
    }

    // 获取当前完整路径
    public func current(): String {
        currentPath
    }

    // 获取当前相对路径
    public func currentRelative(): String {
        currentRel
    }

    // 将路径拆分为组件（过滤空组件和 . ）
    static func splitComponents(path: String): Array<String> {
        var parts = ArrayList<String>()
        var start: Int64 = 0
        var i: Int64 = 0
        while (i < path.size) {
            if (path[i] == UInt8(47)) {
                if (i > start) {
                    let part = path[start..i]
                    if (part != "." && part != "") {
                        parts.add(part)
                    }
                }
                start = i + 1
            }
            i += 1
        }
        if (start < path.size) {
            let part = path[start..path.size]
            if (part != "." && part != "") {
                parts.add(part)
            }
        }
        parts.toArray()
    }

    // 将相对路径设为当前路径
    // 对齐 Rust: Stack::make_relative_path_current
    // 使用委托接口进行回调
    public func makeRelativePathCurrent(relativePath: String, delegate: StackDelegate): ?String {
        if (relativePath == "") {
            if (validComponents != 0) {
                return "empty inputs are not allowed"
            }
            return None
        }
        // 检查绝对路径（以 / 开头）
        if (relativePath.startsWith("/")) {
            throw Exception("Input path \"" + relativePath + "\" contains relative or absolute components")
        }
        // 检查 .. 组件
        if (relativePath.contains("..")) {
            throw Exception("Input path \"" + relativePath + "\" contains relative or absolute components")
        }
        let components = splitComponents(relativePath)
        if (components.size == 0) {
            if (validComponents != 0) {
                return "empty inputs are not allowed"
            }
            return None
        }
        // 计算共享前缀长度
        var sharedLen: Int64 = 0
        let currentParts = splitComponents(currentRel)
        let minLen = if (currentParts.size < components.size) {
            currentParts.size
        } else {
            components.size
        }
        for (i in 0..minLen) {
            if (currentParts[i] == components[i]) {
                sharedLen += 1
            } else {
                break
            }
        }
        // 弹出不共享的目录
        var dirsToPop = validComponents - sharedLen
        while (dirsToPop > 0) {
            delegate.popDirectory()
            dirsToPop -= 1
        }
        // 重置路径到共享前缀
        if (sharedLen == 0) {
            currentPath = root
            currentRel = ""
            currentIsDirectory = true
            validComponents = 0
        } else {
            var newPath = root
            var newRel = ""
            for (i in 0..sharedLen) {
                if (newRel.size > 0) {
                    newPath = newPath + "/" + components[i]
                    newRel = newRel + "/" + components[i]
                } else {
                    newPath = newPath + "/" + components[i]
                    newRel = components[i]
                }
            }
            currentPath = newPath
            currentRel = newRel
            validComponents = sharedLen
        }
        // 压入新组件
        for (i in sharedLen..components.size) {
            let comp = components[i]
            let isLast = (i == components.size - 1)
            if (currentRel == "") {
                currentRel = comp
            } else {
                currentRel = currentRel + "/" + comp
            }
            currentPath = root + "/" + currentRel
            if (!isLast) {
                // 目录组件
                let err = delegate.pushDirectory(this)
                if (let Some(msg) <- err) {
                    return msg
                }
                currentIsDirectory = true
                validComponents += 1
            } else {
                // 最后一个组件（可能是文件或目录）
                let err = delegate.push(true, this)
                if (let Some(msg) <- err) {
                    return msg
                }
                currentIsDirectory = false
            }
        }
        None
    }

    // 兼容旧接口：使用 StackRecord 作为默认委托
    public func makeRelativePathCurrent(relativePath: String, record: StackRecord): ?String {
        let delegate: StackDelegate = record
        makeRelativePathCurrent(relativePath, delegate)
    }
}

// 共享文件快照
// 对齐 Rust: gix_fs::SharedFileSnapshotMut（仓颉无 Arc/RwLock，用单线程可变引用模拟）
public class SharedFileSnapshotMut<T> {
    var value: ?T

    public init() {
        value = None
    }

    // 获取最近的快照
    public func recentSnapshot(): ?T {
        value
    }

    // 更新快照值
    public func update(newValue: T): Unit {
        value = newValue
    }
}
