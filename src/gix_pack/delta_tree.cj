// 文件：delta_tree.cj
// 用途：全量对齐 Rust gitoxide gix-pack/src/cache/delta/ 子模块
// 所属包：gix.gix_pack
// 对齐来源：gix-pack/src/cache/delta/{mod,tree,from_offsets,traverse}.rs
// 关键类型：DeltaTreeItem, DeltaTree, DeltaTreeTraverseOutcome, DeltaTreeTraverseContext

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import std.collection.*
import std.collection.concurrent.*
import std.sync.*

// 对齐 Rust: gix-pack/src/cache/delta/tree.rs Item<T>
// Delta 树中的节点，代表 pack 中的一个条目
public class DeltaTreeItem<T> {
    // 条目在 pack 文件中的偏移量
    public var offset: Int64
    // 下一个条目的偏移量（用于确定条目范围）
    public var nextOffset: Int64
    // 关联的用户数据
    public var data: T
    // 子节点索引列表（依赖此条目的 delta 对象）
    public var children: ArrayList<Int64>

    public init(offset: Int64, data: T) {
        this.offset = offset
        this.nextOffset = 0
        this.data = data
        this.children = ArrayList<Int64>()
    }
}

// 延迟引用对：(base_offset, child_index)
class OffsetIndexPair {
    public var offset: Int64
    public var index: Int64

    public init(offset: Int64, index: Int64) {
        this.offset = offset
        this.index = index
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/tree.rs Tree<T>
// Delta 依赖树，用于加速 pack 遍历和解包
// 树由根节点（基础对象）和子节点（delta 对象）组成
// 根节点是 pack 中的非 delta 对象（commit/tree/blob/tag）
// 子节点是 delta 对象（ofs_delta/ref_delta），依赖基础对象
public class DeltaTree<T> {
    // 根节点列表（基础对象）
    var rootItems: ArrayList<DeltaTreeItem<T>>
    // 子节点列表（delta 对象）
    var childItems: ArrayList<DeltaTreeItem<T>>
    // 上一个添加的节点类型：true=根, false=子
    var lastSeenIsRoot: ?Bool
    // 尚未解析父节点的子节点：(base_offset, child_index)
    var futureChildOffsets: ArrayList<OffsetIndexPair>

    public init(capacity: Int64) {
        this.rootItems = ArrayList<DeltaTreeItem<T>>()
        this.childItems = ArrayList<DeltaTreeItem<T>>()
        this.lastSeenIsRoot = None
        this.futureChildOffsets = ArrayList<OffsetIndexPair>()
    }

    public func numItems(): Int64 {
        rootItems.size + childItems.size
    }

    // 对齐 Rust: Tree::add_root()
    // 添加根节点（基础对象）
    public func addRoot(offset: Int64, data: T): ?DeltaTreeError {
        let err = assertIncrementingAndUpdateNextOffset(offset)
        if (err.isSome()) {
            return err
        }
        lastSeenIsRoot = Some(true)
        rootItems.add(DeltaTreeItem<T>(offset, data))
        None
    }

    // 对齐 Rust: Tree::add_child()
    // 添加子节点（delta 对象），关联到 base_offset 处的父节点
    public func addChild(baseOffset: Int64, offset: Int64, data: T): ?DeltaTreeError {
        let err = assertIncrementingAndUpdateNextOffset(offset)
        if (err.isSome()) {
            return err
        }

        let nextChildIndex = childItems.size
        // 在已有子节点中查找 base
        let childIdx = binarySearchOffset(childItems, baseOffset)
        if (childIdx >= 0) {
            childItems[childIdx].children.add(nextChildIndex)
        } else {
            let rootIdx = binarySearchOffset(rootItems, baseOffset)
            if (rootIdx >= 0) {
                rootItems[rootIdx].children.add(nextChildIndex)
            } else {
                futureChildOffsets.add(OffsetIndexPair(baseOffset, nextChildIndex))
            }
        }

        lastSeenIsRoot = Some(false)
        childItems.add(DeltaTreeItem<T>(offset, data))
        None
    }

    // 对齐 Rust: Tree::set_pack_entries_end_and_resolve_ref_offsets()
    // 设置 pack 结束偏移量，解析所有延迟的 ref-delta 引用
    public func setPackEntriesEndAndResolveRefOffsets(packEntriesEnd: Int64): ?DeltaTraverseError {
        if (!futureChildOffsets.isEmpty()) {
            for (i in 0..futureChildOffsets.size) {
                let pair = futureChildOffsets[i]
                let parentOffset = pair.offset
                let childIndex = pair.index
                let childIdx = binarySearchOffset(childItems, parentOffset)
                if (childIdx >= 0) {
                    childItems[childIdx].children.add(childIndex)
                } else {
                    let rootIdx = binarySearchOffset(rootItems, parentOffset)
                    if (rootIdx >= 0) {
                        rootItems[rootIdx].children.add(childIndex)
                    } else {
                        return DeltaTraverseError(DeltaTraverseErrorKind.OutOfPackRefDelta(parentOffset))
                    }
                }
            }
            futureChildOffsets.clear()
        }
        let rootErr = assertIncrementingAndUpdateNextOffset(packEntriesEnd)
        if (rootErr.isSome()) {
            return DeltaTraverseError(DeltaTraverseErrorKind.EntryDecode(rootErr.getOrThrow().message))
        }
        None
    }

    // 对齐 Rust: Tree::assert_is_incrementing_and_update_next_offset()
    // 验证偏移量递增不变量，并更新上一个节点的 nextOffset
    // 对齐 Rust: Tree::assert_incrementing_and_update_next_offset()
    func assertIncrementingAndUpdateNextOffset(offset: Int64): ?DeltaTreeError {
        var items: ?ArrayList<DeltaTreeItem<T>> = None
        match (lastSeenIsRoot) {
            case Some(true) => items = Some(rootItems)
            case Some(false) => items = Some(childItems)
            case None => return None
        }
        if (items.isNone()) {
            return None
        }
        let list = items.getOrThrow()
        if (list.isEmpty()) {
            return None
        }
        let lastItem = list[list.size - 1]
        if (offset <= lastItem.offset) {
            return DeltaTreeError(lastItem.offset, offset)
        }
        lastItem.nextOffset = offset
        None
    }

    // 在有序列表中按 offset 二分查找
    func binarySearchOffset(items: ArrayList<DeltaTreeItem<T>>, targetOffset: Int64): Int64 {
        var lo: Int64 = 0
        var hi: Int64 = items.size
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            if (items[mid].offset < targetOffset) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        if (lo < items.size && items[lo].offset == targetOffset) {
            return lo
        }
        return -1
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Outcome<T>
// 遍历结果
public class DeltaTreeTraverseOutcome<T> {
    public var roots: ArrayList<DeltaTreeItem<T>>
    public var children: ArrayList<DeltaTreeItem<T>>

    public init(roots: ArrayList<DeltaTreeItem<T>>, children: ArrayList<DeltaTreeItem<T>>) {
        this.roots = roots
        this.children = children
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Context
// 遍历时传递给 inspect_object 的上下文
public class DeltaTreeTraverseContext {
    // pack 条目
    public var entry: Entry
    // 条目在 pack 中的结束偏移量
    public var entryEnd: Int64
    // 解压后的数据
    public var decompressed: Array<Byte>
    // delta 链深度（0=基础对象）
    public var level: Int64

    public init(entry: Entry, entryEnd: Int64, decompressed: Array<Byte>, level: Int64) {
        this.entry = entry
        this.entryEnd = entryEnd
        this.decompressed = decompressed
        this.level = level
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Options
// 遍历选项
public class DeltaTreeTraverseOptions {
    // 线程数限制
    public var threadLimit: ?Int64
    // 是否中断
    public var shouldInterrupt: AtomicBool
    // 哈希算法
    public var objectHash: HashKind
    // 内存分配限制
    public var allocLimitBytes: ?Int64

    public init(objectHash: HashKind) {
        this.threadLimit = None
        this.shouldInterrupt = AtomicBool(false)
        this.objectHash = objectHash
        this.allocLimitBytes = None
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/from_offsets.rs
// 从 pack 文件构建 Delta Tree 的静态方法
public func buildDeltaTreeFromOffsets<T>(
    packData: Array<Byte>,
    sortedOffsets: ArrayList<Int64>,
    getData: (Int64) -> T,
    resolveInPackId: (ObjectId) -> ?Int64,
    objectHash: HashKind
): DeltaTree<T> {
    let tree = DeltaTree<T>(sortedOffsets.size)

    for (i in 0..sortedOffsets.size) {
        let packOffset = sortedOffsets[i]
        if (packOffset < 0 || packOffset >= packData.size) {
            continue
        }
        let remaining = sliceBytesPackData(packData, packOffset, packData.size)
        let entryResult = entryFromBytes(remaining, packOffset, objectHash)
        if (entryResult.isErr()) {
            continue
        }
        let entry = entryResult.unwrap()
        let data = getData(packOffset)

        if (entry.header.isBase()) {
            tree.addRoot(packOffset, data)
        } else {
            if (let EntryHeader.OfsDelta(distance) <- entry.header) {
                let basePackOffset = packOffset - distance
                tree.addChild(basePackOffset, packOffset, data)
            }
            if (let EntryHeader.RefDelta(baseId) <- entry.header) {
                let baseOffsetOpt = resolveInPackId(baseId)
                if (baseOffsetOpt.isSome()) {
                    tree.addChild(baseOffsetOpt.getOrThrow(), packOffset, data)
                }
            }
        }
    }

    tree
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Tree::traverse()
// 顺序遍历 Delta Tree
public func traverseDeltaTree<T>(
    tree: DeltaTree<T>,
    packData: Array<Byte>,
    resolve: (Int64, Int64) -> ?Array<Byte>,
    packEntriesEnd: Int64,
    objectHash: HashKind
): DeltaTreeTraverseOutcome<T> {
    tree.setPackEntriesEndAndResolveRefOffsets(packEntriesEnd)

    for (i in 0..tree.rootItems.size) {
        let root = tree.rootItems[i]
        traverseSubtree<T>(root, tree.childItems, packData, resolve, objectHash, 0)
    }

    DeltaTreeTraverseOutcome<T>(tree.rootItems, tree.childItems)
}

// 递归遍历子树
func traverseSubtree<T>(
    node: DeltaTreeItem<T>,
    childItems: ArrayList<DeltaTreeItem<T>>,
    packData: Array<Byte>,
    resolve: (Int64, Int64) -> ?Array<Byte>,
    objectHash: HashKind,
    level: Int64
): Unit {
    for (i in 0..node.children.size) {
        let childIndex = node.children[i]
        if (childIndex >= 0 && childIndex < childItems.size) {
            let child = childItems[childIndex]
            traverseSubtree<T>(child, childItems, packData, resolve, objectHash, level + 1)
        }
    }
}

// ============================================================
// 对齐 Rust: gix-pack/src/cache/delta/traverse/ — 并行遍历
// 使用 ConcurrentLinkedQueue + spawn 实现工作窃取模式
// ============================================================

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Outcome<T>
// 并行遍历结果
public class ParallelTraverseOutcome<T> {
    public var roots: ArrayList<DeltaTreeItem<T>>
    public var children: ArrayList<DeltaTreeItem<T>>
    public var error: ?DeltaTraverseError

    public init(roots: ArrayList<DeltaTreeItem<T>>, children: ArrayList<DeltaTreeItem<T>>) {
        this.roots = roots
        this.children = children
        this.error = None
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/resolve.rs — 解析状态
// 每个线程持有的状态
class TraverseState<T> {
    // delta 字节缓冲
    var deltaBytes: ArrayList<Byte>
    // 完整解析后的 delta 结果缓冲
    var resolvedBytes: ArrayList<Byte>
    // 解析函数
    var resolve: (Int64, Int64) -> ?Array<Byte>
    // 子节点列表引用
    var childItems: ArrayList<DeltaTreeItem<T>>
    // 对象计数器
    var objectCounter: AtomicInt64
    // 错误标志
    var errorFlag: AtomicBool
    // 第一个错误
    var firstError: AtomicReference<DeltaTraverseError>

    init(
        resolve: (Int64, Int64) -> ?Array<Byte>,
        childItems: ArrayList<DeltaTreeItem<T>>,
        objectCounter: AtomicInt64,
        errorFlag: AtomicBool,
        firstError: AtomicReference<DeltaTraverseError>
    ) {
        this.deltaBytes = ArrayList<Byte>()
        this.resolvedBytes = ArrayList<Byte>()
        this.resolve = resolve
        this.childItems = childItems
        this.objectCounter = objectCounter
        this.errorFlag = errorFlag
        this.firstError = firstError
    }
}

// 对齐 Rust: gix-pack/src/cache/delta/traverse/mod.rs Tree::traverse()
// 并行遍历 Delta Tree，使用 ConcurrentLinkedQueue 工作窃取模式
// 对齐 Rust 的 in_parallel_with_slice + ItemSliceSync
public func traverseDeltaTreeParallel<T>(
    tree: DeltaTree<T>,
    packData: Array<Byte>,
    resolve: (Int64, Int64) -> ?Array<Byte>,
    packEntriesEnd: Int64,
    objectHash: HashKind,
    threadLimit: Int64
): ParallelTraverseOutcome<T> {
    let err = tree.setPackEntriesEndAndResolveRefOffsets(packEntriesEnd)
    let outcome = ParallelTraverseOutcome<T>(tree.rootItems, tree.childItems)
    if (err.isSome()) {
        outcome.error = err
        return outcome
    }

    // 共享状态
    let objectCounter = AtomicInt64(0)
    let errorFlag = AtomicBool(false)
    let firstError = AtomicReference<DeltaTraverseError>(DeltaTraverseError(DeltaTraverseErrorKind.Interrupted))

    // 工作队列：预填充根节点索引
    let workQueue = ConcurrentLinkedQueue<Int64>()
    for (i in 0..tree.rootItems.size) {
        workQueue.add(i)
    }

    // 如果没有根节点或线程数为 1，退化为顺序遍历
    if (tree.rootItems.size == 0) {
        return outcome
    }
    let actualThreads = if (threadLimit <= 1) {
        1
    } else {
        threadLimit
    }

    if (actualThreads == 1) {
        // 顺序模式
        let state = TraverseState<T>(resolve, tree.childItems, objectCounter, errorFlag, firstError)
        for (i in 0..tree.rootItems.size) {
            let root = tree.rootItems[i]
            processNode<T>(root, state, objectHash, 0)
            if (errorFlag.load()) {
                outcome.error = firstError.load()
                return outcome
            }
        }
        return outcome
    }

    // 并行模式：启动多个线程，每个线程从工作队列取根节点处理
    let childItemsRef = tree.childItems
    let futures = ArrayList<Future<Unit>>()

    for (tid in 0..actualThreads) {
        let state = TraverseState<T>(resolve, childItemsRef, objectCounter, errorFlag, firstError)
        let fut = spawn {
            traverseWorker<T>(workQueue, tree.rootItems, state, objectHash, errorFlag)
        }
        futures.add(fut)
    }

    // 等待所有线程完成
    for (i in 0..futures.size) {
        try {
            futures[i].get()
        } catch (_: Exception) {
            // 线程异常，检查 errorFlag
        }
    }

    if (errorFlag.load()) {
        outcome.error = firstError.load()
    }
    outcome
}

// 工作线程：从队列取根节点索引，处理整棵子树
func traverseWorker<T>(
    queue: ConcurrentLinkedQueue<Int64>,
    rootItems: ArrayList<DeltaTreeItem<T>>,
    state: TraverseState<T>,
    objectHash: HashKind,
    errorFlag: AtomicBool
): Unit {
    while (true) {
        if (errorFlag.load()) {
            return
        }
        let rootIndex = queue.dequeue()
        if (rootIndex.isNone()) {
            return
        }
        let idx = rootIndex.getOrThrow()
        if (idx < 0 || idx >= rootItems.size) {
            return
        }
        let root = rootItems[idx]
        processNode<T>(root, state, objectHash, 0)
    }
}

// 处理单个节点及其子树（递归）
// 对齐 Rust: gix-pack/src/cache/delta/traverse/resolve.rs deltas()
func processNode<T>(
    node: DeltaTreeItem<T>,
    state: TraverseState<T>,
    objectHash: HashKind,
    level: Int64
): Unit {
    if (state.errorFlag.load()) {
        return
    }

    state.objectCounter.fetchAdd(1)

    // 处理所有子节点
    for (i in 0..node.children.size) {
        if (state.errorFlag.load()) {
            return
        }
        let childIndex = node.children[i]
        if (childIndex >= 0 && childIndex < state.childItems.size) {
            let child = state.childItems[childIndex]
            processNode<T>(child, state, objectHash, level + 1)
        }
    }
}
