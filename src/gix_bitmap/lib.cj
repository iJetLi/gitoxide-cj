// 文件：lib.cj
// 所属包：gix.gix_bitmap
// 用途：提供位图（Bitmap）数据结构，用于高效存储和查询布尔位集合

package gitoxide.gix_bitmap

// 位图数据结构
// 使用字节数组按位存储布尔值，支持按索引读取、设置和清除位
public class Bitmap {
    // 底层字节数组，每个字节存储 8 个位
    var data: Array<Byte>

    // 创建一个指定位数的位图，所有位初始化为 0
    // 参数 size：位数
    public init(size: Int64) {
        let byteCount = (size + 7) / 8
        data = Array<Byte>(byteCount, repeat: 0)
    }

    // 创建一个空位图
    public init() {
        data = Array<Byte>()
    }

    // 读取指定位的值
    // 参数 idx：位索引
    // 返回值：该位为 1 返回 true，索引超出范围返回 false
    public func get(idx: Int64): Bool {
        let byteIdx = idx / 8
        let bitIdx = idx % 8
        if (byteIdx >= data.size) {
            return false
        }
        (Int64(data[byteIdx]) & (1 << bitIdx)) != 0
    }

    // 将指定位设为 1
    // 参数 idx：位索引
    public func set(idx: Int64): Unit {
        let byteIdx = idx / 8
        let bitIdx = idx % 8
        ensureCapacity(byteIdx + 1)
        let oldVal = Int64(data[byteIdx])
        let newVal = oldVal | (1 << bitIdx)
        data[byteIdx] = UInt8(newVal & 0xFF)
    }

    // 将指定位设为 0
    // 参数 idx：位索引
    public func clear(idx: Int64): Unit {
        let byteIdx = idx / 8
        let bitIdx = idx % 8
        if (byteIdx < data.size) {
            let oldVal = Int64(data[byteIdx])
            let mask = !(1 << bitIdx)
            data[byteIdx] = UInt8((oldVal & (mask & 0xFF)))
        }
    }

    // 返回位图可容纳的总位数
    // 返回值：总位数（字节数 * 8）
    public func size(): Int64 {
        data.size * 8
    }

    // 返回设置为 1 的位数（popcount）
    // 对齐 Rust: bitmap::count
    public func count(): Int64 {
        var c: Int64 = 0
        for (b in data) {
            // 计算 byte 中 1 的个数
            var v = Int64(b) & 0xFF
            while (v != 0) {
                c = c + 1
                v = v & (v - 1)
            }
        }
        c
    }

    // 确保底层字节数组至少能容纳 cap 个字节
    // 参数 cap：所需的最小字节数
    func ensureCapacity(cap: Int64): Unit {
        if (cap > data.size) {
            let newData = Array<Byte>(cap, repeat: 0)
            for (i in 0..data.size) {
                newData[i] = data[i]
            }
            data = newData
        }
    }
}
