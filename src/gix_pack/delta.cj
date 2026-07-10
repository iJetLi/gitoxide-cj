// 文件：delta.cj
// 用途：实现 Git pack delta 指令的解析与应用，支持 OFS_DELTA 和 REF_DELTA
// 所属包：gix.gix_pack
// 关键类型：Delta
// 对齐来源：gix-pack/src/data/delta.rs

package gitoxide.gix_pack

import gitoxide.gix_hash.*
import gitoxide.gix_object.*
import gitoxide.gix_zlib.*
import std.collection.*

// Delta 指令，描述如何从基础对象数据生成目标对象数据
// 包含基础大小、目标大小和 delta 指令字节流
public class Delta {
    // 基础对象的字节大小
    public var baseSize: Int64
    // 目标对象的字节大小
    public var resultSize: Int64
    // delta 指令的字节流
    public var instructions: Array<Byte>

    // 构造函数
    // 参数 baseSize：基础对象大小
    // 参数 resultSize：目标对象大小
    // 参数 instructions：delta 指令字节流
    public init(baseSize: Int64, resultSize: Int64, instructions: Array<Byte>) {
        this.baseSize = baseSize
        this.resultSize = resultSize
        this.instructions = instructions
    }

    // 从字节数组解析 Delta
    // 依次读取变长编码的基础大小和目标大小，剩余部分为指令
    // 对齐 Rust: delta::decode_header_size() 用于解码头部大小
    // 参数 data：delta 数据的字节数组
    // 返回值：解析成功返回 Delta，数据不足返回 None
    public static func fromBytes(data: Array<Byte>): ?Delta {
        // 解码基础大小
        let baseSizeOpt = decodeDeltaHeaderSize(data)
        if (baseSizeOpt.isNone()) {
            return None
        }
        let (baseSize, baseConsumed) = baseSizeOpt.getOrThrow()
        // 解码目标大小
        var remaining = ArrayList<Byte>()
        var i = baseConsumed
        while (i < data.size) {
            remaining.add(data[i])
            i += 1
        }
        let resultSizeOpt = decodeDeltaHeaderSize(remaining.toArray())
        if (resultSizeOpt.isNone()) {
            return None
        }
        let (resultSize, resultConsumed) = resultSizeOpt.getOrThrow()
        // 剩余部分为指令
        var instructions = ArrayList<Byte>()
        var j = baseConsumed + resultConsumed
        while (j < data.size) {
            instructions.add(data[j])
            j += 1
        }
        Some(Delta(baseSize, resultSize, instructions.toArray()))
    }

    // 将 delta 指令应用到基础对象数据，生成目标对象数据
    // 支持两种指令：从基础对象复制（高位为1）和插入新数据（高位为0）
    // 对齐 Rust: delta::apply()
    // 参数 base：基础对象的字节数据
    // 返回值：应用成功返回目标数据，遇到无效指令返回 None
    public func apply(base: Array<Byte>): ?Array<Byte> {
        var result = ArrayList<Byte>()
        var pos: Int64 = 0
        while (pos < instructions.size) {
            let cmd = Int64(instructions[pos])
            pos += 1
            if ((cmd & 0x80) != 0) {
                // copy 指令：从基础对象复制数据
                var offset: Int64 = 0
                var size: Int64 = 0
                if ((cmd & 0x01) != 0) {
                    offset = Int64(instructions[pos])
                    pos += 1
                }
                if ((cmd & 0x02) != 0) {
                    offset |= Int64(instructions[pos]) << 8
                    pos += 1
                }
                if ((cmd & 0x04) != 0) {
                    offset |= Int64(instructions[pos]) << 16
                    pos += 1
                }
                if ((cmd & 0x08) != 0) {
                    offset |= Int64(instructions[pos]) << 24
                    pos += 1
                }
                if ((cmd & 0x10) != 0) {
                    size = Int64(instructions[pos])
                    pos += 1
                }
                if ((cmd & 0x20) != 0) {
                    size |= Int64(instructions[pos]) << 8
                    pos += 1
                }
                if ((cmd & 0x40) != 0) {
                    size |= Int64(instructions[pos]) << 16
                    pos += 1
                }
                // 对齐 Rust: size == 0 时使用 0x10000
                if (size == 0) {
                    size = 0x10000
                }
                // 边界检查：copy 范围不能超出 base
                if (offset < 0 || offset + size > base.size) {
                    return None
                }
                var i: Int64 = 0
                while (i < size) {
                    result.add(base[offset + i])
                    i += 1
                }
            } else if (cmd != 0) {
                // insert 指令：直接插入 cmd 字节的新数据
                // 边界检查：insert 数据不能截断
                if (pos + cmd > instructions.size) {
                    return None
                }
                var i: Int64 = 0
                while (i < cmd) {
                    result.add(instructions[pos])
                    pos += 1
                    i += 1
                }
            } else {
                // 对齐 Rust: 零命令是保留的无效指令
                return None
            }
        }
        // 对齐 Rust: 结果大小必须与声明的 resultSize 匹配
        if (result.size != resultSize) {
            return None
        }
        Some(result.toArray())
    }

    // 对齐 Rust: gix-diff/src/lib.rs — 生成 delta 编码
    // 从基础数据和目标数据生成 delta 编码，包含 copy 和 insert 指令
    // 使用滑动窗口匹配算法：在 base 中查找与 target 当前位置匹配的子串，
    // 匹配到则生成 copy 指令，未匹配则生成 insert 指令
    // 对齐 Git 源码 diff-delta.c 的 delta 创建逻辑
    // 参数 base：基础对象数据
    // 参数 target：目标对象数据
    // 返回值：delta 编码后的字节数组
    public static func encode(base: Array<Byte>, target: Array<Byte>): Array<Byte> {
        var result = ArrayList<Byte>()
        // 编码基础大小（变长编码）
        var size = Int64(base.size)
        while (size > 0x7F) {
            result.add(UInt8(Int64(size & 0x7F) | 0x80))
            size = size >> 7
        }
        result.add(UInt8(Int64(size)))
        // 编码目标大小（变长编码）
        size = Int64(target.size)
        while (size > 0x7F) {
            result.add(UInt8(Int64(size & 0x7F) | 0x80))
            size = size >> 7
        }
        result.add(UInt8(Int64(size)))

        // 如果 base 为空，只能生成插入指令
        if (base.size == 0) {
            var pos = 0
            while (pos < target.size) {
                let remaining = Int64(target.size) - Int64(pos)
                let chunkSize = if (remaining > 127) {
                    127
                } else {
                    remaining
                }
                result.add(UInt8(chunkSize))
                var j = 0
                while (j < chunkSize) {
                    result.add(target[pos + j])
                    j += 1
                }
                pos += chunkSize
            }
            return result.toArray()
        }

        // 滑动窗口 delta 压缩
        // 策略：在 base 中查找与 target 当前位置匹配的最长子串
        // 匹配长度 >= 4 时生成 copy 指令，否则累积为 insert 指令
        var insertBuf = ArrayList<Byte>()
        var tPos: Int64 = 0
        while (tPos < target.size) {
            var bestOffset: Int64 = -1
            var bestLen: Int64 = 0
            // 在 base 中搜索最长匹配
            var bPos: Int64 = 0
            while (bPos < base.size) {
                var matchLen: Int64 = 0
                while (tPos + matchLen < target.size && bPos + matchLen < base.size && target[tPos + matchLen] == base[bPos +
                            matchLen]) {
                    matchLen += 1
                }
                if (matchLen > bestLen) {
                    bestLen = matchLen
                    bestOffset = bPos
                }
                bPos += 1
            }
            // 匹配长度 >= 4 时使用 copy 指令
            if (bestLen >= 4) {
                // 先刷新累积的 insert 指令
                flushInsert(result, insertBuf)
                // 生成 copy 指令
                emitCopy(result, bestOffset, bestLen)
                tPos += bestLen
            } else {
                // 累积 insert 数据
                insertBuf.add(target[tPos])
                // insert 最多 127 字节
                if (insertBuf.size == 127) {
                    flushInsert(result, insertBuf)
                }
                tPos += 1
            }
        }
        // 刷新剩余 insert
        flushInsert(result, insertBuf)
        result.toArray()
    }

    // 刷新累积的 insert 指令到结果缓冲区
    static func flushInsert(result: ArrayList<Byte>, insertBuf: ArrayList<Byte>): Unit {
        if (insertBuf.size == 0) {
            return
        }
        // insert 指令：高位为 0，低 7 位为长度
        result.add(UInt8(Int64(insertBuf.size)))
        for (b in insertBuf) {
            result.add(b)
        }
        insertBuf.clear()
    }

    // 生成 copy 指令
    // 对齐 Git 源码 diff-delta.c 的 encode 指令格式
    // copy 指令：高位为 1，后续字节按位标志编码 offset 和 size
    static func emitCopy(result: ArrayList<Byte>, offset: Int64, size: Int64): Unit {
        // copy 指令可能需要拆分（最大 size 为 0x10000）
        var remaining = size
        while (remaining > 0) {
            let chunkSize = if (remaining > 0x10000) {
                Int64(0x10000)
            } else {
                remaining
            }
            var cmd: Int64 = 0x80
            var data = ArrayList<Byte>()

            // 编码 offset（低 4 字节，按需编码）
            if ((offset & 0xFF) != 0) {
                cmd |= 0x01
                data.add(UInt8(offset & 0xFF))
            }
            if ((offset & 0xFF00) != 0) {
                cmd |= 0x02
                data.add(UInt8((offset >> 8) & 0xFF))
            }
            if ((offset & 0xFF0000) != 0) {
                cmd |= 0x04
                data.add(UInt8((offset >> 16) & 0xFF))
            }
            if ((offset & 0xFF000000) != 0) {
                cmd |= 0x08
                data.add(UInt8((offset >> 24) & 0xFF))
            }

            // 编码 size（低 3 字节，按需编码）
            // size == 0x10000 时编码为 0（按 Git 规范）
            let encodedSize = if (chunkSize == 0x10000) {
                Int64(0)
            } else {
                chunkSize
            }
            if ((encodedSize & 0xFF) != 0) {
                cmd |= 0x10
                data.add(UInt8(encodedSize & 0xFF))
            }
            if ((encodedSize & 0xFF00) != 0) {
                cmd |= 0x20
                data.add(UInt8((encodedSize >> 8) & 0xFF))
            }
            if ((encodedSize & 0xFF0000) != 0) {
                cmd |= 0x40
                data.add(UInt8((encodedSize >> 16) & 0xFF))
            }

            result.add(UInt8(cmd))
            for (b in data) {
                result.add(b)
            }
            remaining -= chunkSize
        }
    }
}
