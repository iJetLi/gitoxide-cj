// 文件：lib.cj
// 用途：定义运行时特性检测和进度报告接口
// 所属包：gix.gix_features
// 关键类型：Threading, Progress, NoProgress, Pipe, TraceSpan, TraceLevel

package gitoxide.gix_features

import std.collection.*
import std.sync.*
import std.runtime.*

// 线程支持检测工具类
// 提供运行时对多线程能力的查询
public class Threading {
    // 检测当前运行环境是否支持多线程
    // 返回值：支持多线程返回 true
    public static func available(): Bool {
        true
    }
}

// 进度报告接口
// 用于在长时间操作中报告进度信息
public interface Progress {
    // 增加进度计数
    // 参数 amount：增加的数量
    func inc(amount: Int64): Unit
    // 设置当前操作的名称
    // 参数 name：操作名称
    func set(name: String): Unit
    // 获取当前进度计数
    // 返回值：当前的进度计数值
    func counter(): Int64
}

// 空操作进度报告器
// 实现了 Progress 接口但不产生任何输出，用于不需要进度报告的场景
public class NoProgress <: Progress {
    // 内部计数器
    var count: Int64
    public init() {
        count = 0
    }
    // 增加内部计数，不产生输出
    // 参数 amount：增加的数量
    public func inc(amount: Int64): Unit {
        count += amount
    }
    // 空操作，忽略名称设置
    // 参数 name：操作名称（被忽略）
    public func set(name: String): Unit {}
    // 返回当前内部计数值
    // 返回值：当前的进度计数值
    public func counter(): Int64 {
        count
    }
}

// 管道，用于线程间数据传输
// 对齐 Rust: gix_features::io::pipe
// 仓颉差异：当前 SDK 版本无 Channel，使用同步缓冲区模拟
// 待 Channel 可用后替换为 PipeWriter/PipeReader + Channel 实现
public class Pipe {
    var buffer: ArrayList<Byte>
    var closed: Bool
    var error: ?String
    var totalWritten: Int64

    public init() {
        buffer = ArrayList<Byte>()
        closed = false
        error = None
        totalWritten = 0
    }

    // 写入字符串到管道
    // 对齐 Rust: io::Write::write_all
    public func write(data: String): Unit {
        if (closed) {
            throw Exception("broken pipe")
        }
        if (let Some(_) <- error) {
            throw Exception("pipe has error")
        }
        let bytes = data.toArray()
        for (b in bytes) {
            buffer.add(b)
        }
        totalWritten += bytes.size
    }

    // 写入字节数组到管道
    // 对齐 Rust: io::Write::write
    public func writeBytes(data: Array<Byte>): Unit {
        if (closed) {
            throw Exception("broken pipe")
        }
        for (b in data) {
            buffer.add(b)
        }
        totalWritten += data.size
    }

    // 读取管道全部内容为字符串
    // 对齐 Rust: Read::read_to_string
    public func read(): String {
        if (let Some(err) <- error) {
            throw Exception(err)
        }
        let result = String.fromUtf8(buffer.toArray())
        buffer = ArrayList<Byte>()
        result
    }

    // 读取管道内容并按行分割
    // 对齐 Rust: BufRead::lines
    public func readLines(): Array<String> {
        let content = read()
        let lines = content.split("\n")
        var result = ArrayList<String>()
        for (line in lines) {
            if (line.size > 0) {
                result.add(line)
            }
        }
        result.toArray()
    }

    // 逐行读取
    // 对齐 Rust: BufRead::read_line
    public func readLine(): ?String {
        var newlineIdx: Int64 = -1
        for (i in 0..buffer.size) {
            if (buffer[i] == UInt8(10)) {
                newlineIdx = i
                break
            }
        }
        if (newlineIdx >= 0) {
            var line = ArrayList<Byte>()
            for (i in 0..newlineIdx) {
                line.add(buffer[i])
            }
            var remaining = ArrayList<Byte>()
            for (i in (newlineIdx + 1)..buffer.size) {
                remaining.add(buffer[i])
            }
            buffer = remaining
            String.fromUtf8(line.toArray())
        } else if (buffer.size > 0) {
            let result = String.fromUtf8(buffer.toArray())
            buffer = ArrayList<Byte>()
            result
        } else {
            None
        }
    }

    // 关闭读取端
    // 对齐 Rust: drop(reader)
    public func closeReader(): Unit {
        closed = true
    }

    // 注入错误
    // 对齐 Rust: Writer::channel.send(Err(io::Error))
    public func injectError(msg: String): Unit {
        error = msg
    }

    // 获取已写入的总字节数
    public func totalBytesWritten(): Int64 {
        totalWritten
    }
}

// 追踪级别
// 对齐 Rust: gix_features::trace::Level
public enum TraceLevel {
    | Coarse
    | Detail
}

extend TraceLevel <: Equatable<TraceLevel> {
    public operator func ==(other: TraceLevel): Bool {
        match (this) {
            case TraceLevel.Coarse => match (other) {
                case TraceLevel.Coarse => true
                case _ => false
            }
            case TraceLevel.Detail => match (other) {
                case TraceLevel.Detail => true
                case _ => false
            }
        }
    }
    public operator func !=(other: TraceLevel): Bool {
        !(this == other)
    }
}

// 追踪范围
// 对齐 Rust: gix_features::trace::Span
public class TraceSpan {
    // 追踪名称
    public var name: String
    // 追踪级别
    public var level: TraceLevel
    // 是否已进入
    public var entered: Bool

    public init(name: String) {
        this.name = name
        this.level = TraceLevel.Coarse
        this.entered = false
    }

    public init(name: String, level: TraceLevel) {
        this.name = name
        this.level = level
        this.entered = false
    }

    // 进入追踪范围
    // 对齐 Rust: Span::enter()
    public func enter(): Unit {
        entered = true
    }

    // 退出追踪范围
    // 对齐 Rust: Span::exit()
    public func exit(): Unit {
        entered = false
    }
}

// 追踪范围创建
// 对齐 Rust: gix_features::trace::span!
// 创建一个带有级别和名称的追踪范围
public func traceSpan(level: TraceLevel, name: String): TraceSpan {
    TraceSpan(name, level)
}

// 序列号类型
// 对齐 Rust: gix_features::parallel::in_order::SequenceId
public type SequenceId = Int64

// 有序迭代器错误
// 对齐 Rust: InOrderIter 遇到 Err(e) 时的错误类型
public class InOrderError {
    public var message: String
    public init(message: String) {
        this.message = message
    }
}

// 有序迭代器输出
// 对齐 Rust: InOrderIter Iterator::Item = Result<T, E>
public enum InOrderOutput<T> {
    | Ok(T)
    | Err(InOrderError)
}

// 带序列号的输入项
// 对齐 Rust: Iterator<Item = Result<(SequenceId, T), E>>
public class SequencedItem<T> {
    public var seq: SequenceId
    public var output: InOrderOutput<T>
    public init(seq: SequenceId, output: InOrderOutput<T>) {
        this.seq = seq
        this.output = output
    }
}

// 有序迭代器
// 对齐 Rust: gix_features::parallel::InOrderIter<T, I>
// 将乱序到达的 Result<(SequenceId, T), E> 按 SequenceId 顺序输出
// 遇到错误时触发熔断（fuse），后续所有 next() 返回 None
// 内部使用 TreeMap 缓冲乱序项，等价于 Rust 的 BTreeMap
public class InOrderIter<T> {
    var inner: Array<SequencedItem<T>>
    var innerPos: Int64
    var store: TreeMap<SequenceId, T>
    var nextChunk: SequenceId
    var isDone: Bool

    public init(items: Array<SequencedItem<T>>) {
        inner = items
        innerPos = 0
        store = TreeMap<SequenceId, T>()
        nextChunk = 0
        isDone = false
    }

    // 从 Ok(seq, value) 对数组构造
    // 对齐 Rust: InOrderIter::from(vec![Ok((0, 'a')), Ok((1, 'b'))].into_iter())
    public static func fromOkPairs(pairs: Array<(SequenceId, T)>): InOrderIter<T> {
        var items = ArrayList<SequencedItem<T>>()
        for (pair in pairs) {
            items.add(SequencedItem<T>(pair[0], InOrderOutput.Ok(pair[1])))
        }
        InOrderIter<T>(items.toArray())
    }

    // 从混合 Ok/Err 项构造
    public static func fromMixed(items: Array<SequencedItem<T>>): InOrderIter<T> {
        InOrderIter<T>(items)
    }

    // 获取下一个有序输出
    // 对齐 Rust: InOrderIter::next() -> Option<Result<T, E>>
    public func next(): ?InOrderOutput<T> {
        if (isDone) {
            return None
        }
        var found: ?InOrderOutput<T> = None
        var keepGoing = true
        while (keepGoing) {
            keepGoing = false
            if (innerPos < inner.size) {
                let item = inner[innerPos]
                innerPos += 1
                match (item.output) {
                    case Ok(v) =>
                        let c = item.seq
                        if (c == nextChunk) {
                            nextChunk += 1
                            found = InOrderOutput.Ok(v)
                        } else if (c < nextChunk) {
                            throw Exception(
                                "in a correctly ordered sequence we can never see keys again, got " + c.toString())
                        } else {
                            let previous = store.add(c, v)
                            if (let Some(_) <- previous) {
                                throw Exception("Chunks are returned only once, input is an invalid sequence")
                            }
                            if (let Some(stored) <- store.remove(nextChunk)) {
                                nextChunk += 1
                                found = InOrderOutput.Ok(stored)
                            } else {
                                keepGoing = true
                            }
                        }
                    case Err(e) =>
                        isDone = true
                        store.clear()
                        found = InOrderOutput.Err(e)
                }
            } else {
                if (let Some(v) <- store.remove(nextChunk)) {
                    nextChunk += 1
                    found = InOrderOutput.Ok(v)
                } else {
                    found = None
                }
            }
        }
        found
    }

    // 收集所有剩余结果到数组
    public func collect(): Array<InOrderOutput<T>> {
        var result = ArrayList<InOrderOutput<T>>()
        while (true) {
            match (next()) {
                case Some(output) => result.add(output)
                case None => break
            }
        }
        result.toArray()
    }
}

// 优化分块大小和线程限制的结果
// 对齐 Rust: (usize, Option<usize>, usize)
public class ChunkSizeResult {
    public var chunkSize: Int64
    public var desiredThreads: ?Int64
    public var actualThreads: Int64

    public init(chunkSize: Int64, desiredThreads: ?Int64, actualThreads: Int64) {
        this.chunkSize = chunkSize
        this.desiredThreads = desiredThreads
        this.actualThreads = actualThreads
    }
}

// 获取系统可用并行度
// 对齐 Rust: std::thread::available_parallelism()
// 仓颉等价: std.runtime.getProcessorCount()
func availableParallelism(): Int64 {
    getProcessorCount()
}

// 获取线程数
// 对齐 Rust: gix_features::parallel::num_threads
public func numThreads(threadLimit: ?Int64): Int64 {
    var limit: Int64 = availableParallelism()
    if (let Some(l) <- threadLimit) {
        if (l > 0) {
            limit = l
        }
    }
    limit
}

// 优化分块大小和线程限制
// 对齐 Rust: gix_features::parallel::optimize_chunk_size_and_thread_limit (parallel 版本)
// 参数 desiredChunkSize: 期望的分块大小
// 参数 numItems: 总项目数（None 表示未知）
// 参数 threadLimit: 线程数上限（None 表示不限制）
// 参数 availableThreads: 可用线程数（None 表示自动检测）
// 返回值: ChunkSizeResult(chunkSize, desiredThreads, actualThreads)
public func optimizeChunkSizeAndThreadLimit(
    desiredChunkSize: Int64,
    numItems: ?Int64,
    threadLimit: ?Int64,
    availableThreads: ?Int64
): ChunkSizeResult {
    var at: Int64 = availableParallelism()
    if (let Some(v) <- availableThreads) {
        at = v
    }
    if (let Some(l) <- threadLimit) {
        if (l > 0) {
            at = l
        }
    }
    let lower: Int64 = 50
    let upper: Int64 = 1000
    var chunkSize: Int64 = 0
    var threadLimitResult: Int64 = 0
    if (let Some(ni) <- numItems) {
        let desiredChunksPerThreadAtLeast: Int64 = 2
        let items = ni
        chunkSize = items / (at * desiredChunksPerThreadAtLeast)
        if (chunkSize < 1) {
            chunkSize = 1
        }
        if (chunkSize > upper) {
            chunkSize = upper
        }
        let numChunks = items / chunkSize
        if (numChunks <= at) {
            threadLimitResult = numChunks / desiredChunksPerThreadAtLeast
            if (threadLimitResult < 1) {
                threadLimitResult = 1
            }
        } else {
            threadLimitResult = at
        }
    } else {
        if (at == 1) {
            chunkSize = desiredChunkSize
        } else if (desiredChunkSize < lower) {
            chunkSize = lower
        } else {
            chunkSize = desiredChunkSize
            if (chunkSize > upper) {
                chunkSize = upper
            }
        }
        threadLimitResult = at
    }
    ChunkSizeResult(chunkSize, Some(threadLimitResult), threadLimitResult)
}
