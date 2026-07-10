// 文件：encode.cj
// 所属包：gix.gix_object
// 用途：定义 Git 松散对象的头部编码函数
// 说明：松散对象头部格式为 "<kind> <size>\0"，如 "blob 123\0"

package gitoxide.gix_object

import std.collection.*

// 编码松散对象头部
// 将对象类型和数据大小编码为 "<kind> <size>\0" 格式的字节数组
// 参数 kind：对象类型
// 参数 size：对象体数据的字节大小
// 返回值：编码后的头部字节数组
public func looseHeader(kind: ObjectKind, size: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    let kindBytes = kindAsBytes(kind)
    for (b in kindBytes) {
        result.add(b)
    }
    result.add(UInt8(32))
    let sizeStr = size.toString()
    for (b in sizeStr.toArray()) {
        result.add(b)
    }
    result.add(UInt8(0))
    result.toArray()
}
