// 文件：lib.cj
// 用途：Git 协议协商，跟踪客户端已知的提交对象以优化 want/have 协商
// 所属包：gix.gix_negotiate
// 关键类型：Negotiator

package gitoxide.gix_negotiate

import gitoxide.gix_hash.*
import std.collection.*

// 协商器，跟踪客户端已拥有的提交对象，用于 fetch 协商中确定 common ancestor
public class Negotiator {
    // 已知提交的十六进制哈希集合
    public var known: HashSet<String>

    // 初始化空的协商器
    public init() {
        this.known = HashSet<String>()
    }

    // 添加一个已知提交到协商器
    // 参数 id: 已知的提交对象 ID
    public func addKnown(id: ObjectId): Unit {
        known.add(id.toHexString())
    }

    // 检查指定提交是否为已知提交
    // 参数 id: 待检查的对象 ID
    // 返回值: 已知返回 true，否则返回 false
    public func isKnown(id: ObjectId): Bool {
        known.contains(id.toHexString())
    }

    // 获取所有已知提交的对象 ID 列表
    // 返回值: 已知提交的 ObjectId 列表
    public func common(): ArrayList<ObjectId> {
        var result = ArrayList<ObjectId>()
        for (hex in known) {
            result.add(ObjectId.fromHex(hex))
        }
        result
    }
}

public func windowSize(stateless: Bool, prev: ?Int64): Int64 {
    if (prev.isNone()) {
        return 16
    }
    let current = prev.getOrThrow()
    let pipeSafeFlush: Int64 = 32
    let largeFlush: Int64 = 16384
    if (stateless) {
        if (current < largeFlush) {
            current * 2
        } else {
            current * 11 / 10
        }
    } else if (current < pipeSafeFlush) {
        current * 2
    } else {
        current + pipeSafeFlush
    }
}
