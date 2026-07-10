// 文件：hasher.cj
// 用途：定义增量式哈希计算器，支持分块写入数据并最终生成 ObjectId
// 所属包：gix.gix_hash
// 关键类型：Hasher

package gitoxide.gix_hash

import std.collection.*

// 增量式哈希计算器
// 支持通过多次 update 追加数据，最终调用 tryFinalize 生成 ObjectId
// 适用于流式或分块计算哈希的场景
public class GixHasher {
    // 哈希算法类型
    var kind: HashKind
    // 累积的待哈希数据
    var data: ArrayList<Byte>

    // 创建一个指定算法类型的 Hasher
    // 参数 kind：哈希算法类型（Sha1 或 Sha256）
    public init(kind: HashKind) {
        this.kind = kind
        this.data = ArrayList<Byte>()
    }

    // 追加数据到哈希计算器中
    // 参数 bytes：待追加的数据字节
    public func update(bytes: Array<Byte>): Unit {
        for (b in bytes) {
            data.add(b)
        }
    }

    // 完成哈希计算，返回 ObjectId
    // 返回值：基于累积数据计算出的 ObjectId
    public func tryFinalize(): ObjectId {
        let allBytes = data.toArray()
        let hexStr = computeHashHex(kind, allBytes)
        ObjectId.fromHex(hexStr)
    }
}

// 根据哈希算法类型计算数据的十六进制哈希值
func computeHashHex(kind: HashKind, data: Array<Byte>): String {
    match (kind) {
        case HashKind.Sha1 => sha1Hex(data)
        case HashKind.Sha256 => sha256Hex(data)
    }
}

// UInt32 溢出加法（取模 2^32）
func wadd(a: UInt32, b: UInt32): UInt32 {
    UInt32((UInt64(a) + UInt64(b)) % 0x100000000u64)
}

// SHA-1 纯仓颉实现
func sha1Hex(data: Array<Byte>): String {
    var a0: UInt32 = 0x67452301u32
    var b0: UInt32 = 0xEFCDAB89u32
    var c0: UInt32 = 0x98BADCFEu32
    var d0: UInt32 = 0x10325476u32
    var e0: UInt32 = 0xC3D2E1F0u32

    let msgLen = data.size
    let bitLen = msgLen * 8

    var padded = ArrayList<Byte>()
    for (b in data) {
        padded.add(b)
    }
    padded.add(0x80)

    while ((padded.size % 64) != 56) {
        padded.add(0x00)
    }

    for (i in 0..8) {
        let shift = (7 - i) * 8
        let byteVal = UInt8((UInt64(bitLen) >> UInt64(shift)) & 0xFFu64)
        padded.add(byteVal)
    }

    var off = 0
    while (off < padded.size) {
        let w = Array<UInt32>(80, repeat: 0u32)

        for (i in 0..16) {
            let idx = off + i * 4
            w[i] = (UInt32(padded[idx]) << 24) | (UInt32(padded[idx + 1]) << 16) | (UInt32(padded[idx + 2]) << 8) |
                UInt32(padded[idx + 3])
        }

        for (i in 16..80) {
            let val = w[i - 3] ^ w[i - 8] ^ w[i - 14] ^ w[i - 16]
            w[i] = leftRotate32(val, 1)
        }

        var a = a0
        var b = b0
        var c = c0
        var d = d0
        var e = e0

        for (i in 0..80) {
            var f: UInt32 = 0u32
            var k: UInt32 = 0u32
            if (i < 20) {
                f = (b & c) | ((b ^ 0xFFFFFFFFu32) & d)
                k = 0x5A827999u32
            } else if (i < 40) {
                f = b ^ c ^ d
                k = 0x6ED9EBA1u32
            } else if (i < 60) {
                f = (b & c) | (b & d) | (c & d)
                k = 0x8F1BBCDCu32
            } else {
                f = b ^ c ^ d
                k = 0xCA62C1D6u32
            }

            let temp = wadd(wadd(wadd(wadd(leftRotate32(a, 5), f), e), k), w[i])
            e = d
            d = c
            c = leftRotate32(b, 30)
            b = a
            a = temp
        }

        a0 = wadd(a0, a)
        b0 = wadd(b0, b)
        c0 = wadd(c0, c)
        d0 = wadd(d0, d)
        e0 = wadd(e0, e)

        off += 64
    }

    toHex(a0) + toHex(b0) + toHex(c0) + toHex(d0) + toHex(e0)
}

// SHA-256 纯仓颉实现
func sha256Hex(data: Array<Byte>): String {
    let k = [
        0x428a2f98u32,
        0x71374491u32,
        0xb5c0fbcfu32,
        0xe9b5dba5u32,
        0x3956c25bu32,
        0x59f111f1u32,
        0x923f82a4u32,
        0xab1c5ed5u32,
        0xd807aa98u32,
        0x12835b01u32,
        0x243185beu32,
        0x550c7dc3u32,
        0x72be5d74u32,
        0x80deb1feu32,
        0x9bdc06a7u32,
        0xc19bf174u32,
        0xe49b69c1u32,
        0xefbe4786u32,
        0x0fc19dc6u32,
        0x240ca1ccu32,
        0x2de92c6fu32,
        0x4a7484aau32,
        0x5cb0a9dcu32,
        0x76f988dau32,
        0x983e5152u32,
        0xa831c66du32,
        0xb00327c8u32,
        0xbf597fc7u32,
        0xc6e00bf3u32,
        0xd5a79147u32,
        0x06ca6351u32,
        0x14292967u32,
        0x27b70a85u32,
        0x2e1b2138u32,
        0x4d2c6dfcu32,
        0x53380d13u32,
        0x650a7354u32,
        0x766a0abbu32,
        0x81c2c92eu32,
        0x92722c85u32,
        0xa2bfe8a1u32,
        0xa81a664bu32,
        0xc24b8b70u32,
        0xc76c51a3u32,
        0xd192e819u32,
        0xd6990624u32,
        0xf40e3585u32,
        0x106aa070u32,
        0x19a4c116u32,
        0x1e376c08u32,
        0x2748774cu32,
        0x34b0bcb5u32,
        0x391c0cb3u32,
        0x4ed8aa4au32,
        0x5b9cca4fu32,
        0x682e6ff3u32,
        0x748f82eeu32,
        0x78a5636fu32,
        0x84c87814u32,
        0x8cc70208u32,
        0x90befffau32,
        0xa4506cebu32,
        0xbef9a3f7u32,
        0xc67178f2u32
    ]

    var h0: UInt32 = 0x6a09e667u32
    var h1: UInt32 = 0xbb67ae85u32
    var h2: UInt32 = 0x3c6ef372u32
    var h3: UInt32 = 0xa54ff53au32
    var h4: UInt32 = 0x510e527fu32
    var h5: UInt32 = 0x9b05688cu32
    var h6: UInt32 = 0x1f83d9abu32
    var h7: UInt32 = 0x5be0cd19u32

    let msgLen = data.size
    let bitLen = msgLen * 8

    var padded = ArrayList<Byte>()
    for (b in data) {
        padded.add(b)
    }
    padded.add(0x80)

    while ((padded.size % 64) != 56) {
        padded.add(0x00)
    }

    for (i in 0..8) {
        let shift = (7 - i) * 8
        let byteVal = UInt8((UInt64(bitLen) >> UInt64(shift)) & 0xFFu64)
        padded.add(byteVal)
    }

    var off = 0
    while (off < padded.size) {
        let w = Array<UInt32>(64, repeat: 0u32)

        for (i in 0..16) {
            let idx = off + i * 4
            w[i] = (UInt32(padded[idx]) << 24) | (UInt32(padded[idx + 1]) << 16) | (UInt32(padded[idx + 2]) << 8) |
                UInt32(padded[idx + 3])
        }

        for (i in 16..64) {
            let s0 = rightRotate32(w[i - 15], 7) ^ rightRotate32(w[i - 15], 18) ^ (w[i - 15] >> 3)
            let s1 = rightRotate32(w[i - 2], 17) ^ rightRotate32(w[i - 2], 19) ^ (w[i - 2] >> 10)
            w[i] = wadd(wadd(wadd(w[i - 16], s0), w[i - 7]), s1)
        }

        var a = h0
        var b = h1
        var c = h2
        var d = h3
        var e = h4
        var f = h5
        var g = h6
        var hh = h7

        for (i in 0..64) {
            let S1 = rightRotate32(e, 6) ^ rightRotate32(e, 11) ^ rightRotate32(e, 25)
            let ch = (e & f) ^ ((e ^ 0xFFFFFFFFu32) & g)
            let temp1 = wadd(wadd(wadd(wadd(wadd(hh, S1), ch), k[i]), w[i]), UInt32(0))
            let S0 = rightRotate32(a, 2) ^ rightRotate32(a, 13) ^ rightRotate32(a, 22)
            let maj = (a & b) ^ (a & c) ^ (b & c)
            let temp2 = wadd(S0, maj)

            hh = g
            g = f
            f = e
            e = wadd(d, temp1)
            d = c
            c = b
            b = a
            a = wadd(temp1, temp2)
        }

        h0 = wadd(h0, a)
        h1 = wadd(h1, b)
        h2 = wadd(h2, c)
        h3 = wadd(h3, d)
        h4 = wadd(h4, e)
        h5 = wadd(h5, f)
        h6 = wadd(h6, g)
        h7 = wadd(h7, hh)

        off += 64
    }

    toHex(h0) + toHex(h1) + toHex(h2) + toHex(h3) + toHex(h4) + toHex(h5) + toHex(h6) + toHex(h7)
}

// 32 位左旋转
func leftRotate32(x: UInt32, n: UInt32): UInt32 {
    (x << n) | (x >> (32u32 - n))
}

// 32 位右旋转
func rightRotate32(x: UInt32, n: UInt32): UInt32 {
    (x >> n) | (x << (32u32 - n))
}

// 将 UInt32 转为 8 字符十六进制字符串
func toHex(v: UInt32): String {
    let hexChars = "0123456789abcdef"
    var result = ""
    for (i in 0..8) {
        let shift = UInt32((7 - i) * 4)
        let nibble = Int64((v >> shift) & 0xFu32)
        result = result + hexChars[nibble..nibble + 1]
    }
    result
}
