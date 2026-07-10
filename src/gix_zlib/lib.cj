// 文件：lib.cj
// 用途：提供 zlib 压缩与解压缩功能，用于 Git 对象的存储和读取
// 所属包：gix.gix_zlib
// 关键类型：InflateResult, DeflateResult, Stream
// 关键函数：inflate, deflate
// 对齐 Rust: gix-zlib 使用 miniz_oxide，仓颉使用 zlib4cj

package gitoxide.gix_zlib

import std.collection.*
import cangjie_tpc::zlib4cj.*

// 解压缩结果，包含解压后的数据和已消费的输入字节数
public class InflateResult {
    public var data: Array<Byte>
    public var consumed: Int64

    public init(data: Array<Byte>, consumed: Int64) {
        this.data = data
        this.consumed = consumed
    }
}

// 压缩结果，包含压缩后的数据
public class DeflateResult {
    public var data: Array<Byte>

    public init(data: Array<Byte>) {
        this.data = data
    }
}

// 对字节数组进行 zlib 解压缩
// 对齐 Rust: gix_zlib::Inflate::once() — 在 StreamEnd 时停止，返回 consumed 字节数
// 使用 zlib4cj 替换手写 DEFLATE 解码器，解决死循环和 consumed 不准确问题
public func inflate(input: Array<Byte>): InflateResult {
    if (input.size == 0) {
        return InflateResult([], 0)
    }
    let inf = Inflate(1)
    let out = ArrayList<Byte>()
    let buffer = Array<Byte>(4096, repeat: 0)
    var error: Int32 = Z_OK
    inf.setInBuf(input)
    while (!inf.isInbufEmpty() && error != Z_STREAM_END) {
        inf.setOutBuf(buffer)
        var loopSafety: Int64 = 0
        while (loopSafety < 1000000) {
            loopSafety += 1
            if (inf.isInbufEmpty()) {
                break
            }
            error = inf.inflate(Z_NO_FLUSH)
            if (error >= 0) {
                let len = inf.getOutDataLength()
                if (len > 0) {
                    for (i in 0..len) {
                        out.add(buffer[i])
                    }
                    inf.resetOutBuf()
                    inf.setOutBuf(buffer)
                }
                if (error == Z_STREAM_END) {
                    break
                }
            } else {
                throw Exception("zlib inflate error: ${error}")
            }
        }
    }
    let consumed = inf.getTotalIn()
    InflateResult(out.toArray(), consumed)
}

// 对字节数组进行 zlib 压缩
// 对齐 Rust: gix_zlib::Deflate — 使用 zlib4cj 真正压缩
public func deflate(input: Array<Byte>): DeflateResult {
    let compressed = Zlib.compress(input, wrap: ZlibType.ZLIB)
    DeflateResult(compressed)
}

// 流式压缩/解压缩处理器
public class Stream {
    var buffer: ArrayList<Byte>

    public init() {
        this.buffer = ArrayList<Byte>()
    }

    public func write(data: Array<Byte>): Unit {
        for (b in data) {
            buffer.add(b)
        }
    }

    public func finishInflate(): Array<Byte> {
        let result = inflate(buffer.toArray())
        result.data
    }

    public func finishDeflate(): Array<Byte> {
        let result = deflate(buffer.toArray())
        result.data
    }
}
