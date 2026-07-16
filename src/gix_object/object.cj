// 文件：object.cj
// 所属包：gix.gix_object
// 用途：定义 Git 对象的统一枚举类型（引用和拥有），以及对象解析、转换和哈希计算等核心操作
// 关键类型：ObjectRef - 对象引用的统一枚举
//           Object - 对象拥有类型的统一枚举

package gitoxide.gix_object

import std.collection.*
import gitoxide.gix_hash.*
import gitoxide.gix_hash.*

// 对象引用的统一枚举
// 将四种 Git 对象的引用类型统一为一个枚举，便于在不确定具体类型时统一处理
public enum ObjectRef {
    | Tree(TreeRef) // 树对象引用
    | Blob(BlobRef) // 文件对象引用
    | Commit(CommitRef) // 提交对象引用
    | Tag(TagRef) // 标签对象引用
}

// 对象拥有类型的统一枚举
// 将四种 Git 对象的拥有类型统一为一个枚举，便于在不确定具体类型时统一处理
public enum Object {
    | TreeObj(Tree) // 树对象
    | BlobObj(Blob) // 文件对象
    | CommitObj(Commit) // 提交对象
    | TagObj(Tag) // 标签对象
}

// 从松散对象数据解析 ObjectRef
// 先解码松散对象头部获取类型和大小，再根据类型解析对象体
// 参数 data：松散对象的完整字节数据（含头部）
// 参数 hashKind：哈希算法类型
// 返回值：解析成功返回 ObjectRef，失败返回 None
public func objectRefFromLoose(data: Array<Byte>, hashKind: HashKind): ?ObjectRef {
    let header = decodeLooseHeader(data)
    if (let Some(h) <- header) {
        let (kind, size, offset) = h
        if (offset + size > data.size) {
            return None
        }
        let body = sliceBytes2(data, offset, offset + size)
        objectRefFromBytes(body, kind, hashKind)
    } else {
        None
    }
}

// 根据对象类型从字节数据解析 ObjectRef
// 参数 data：对象体的字节数据（不含头部）
// 参数 kind：对象类型
// 参数 hashKind：哈希算法类型
// 返回值：解析成功返回对应类型的 ObjectRef，失败返回 None
public func objectRefFromBytes(data: Array<Byte>, kind: ObjectKind, hashKind: HashKind): ?ObjectRef {
    match (kind) {
        case ObjectKind.Tree => parseTreeRef(data, hashKind)
        case ObjectKind.Blob => Some(ObjectRef.Blob(BlobRef(data)))
        case ObjectKind.Commit => parseCommitRef(data, hashKind)
        case ObjectKind.Tag => parseTagRef(data, hashKind)
    }
}

// 解析 TreeRef
func parseTreeRef(data: Array<Byte>, hashKind: HashKind): ?ObjectRef {
    let tree = TreeRef.fromBytes(data, hashKind)
    if (let Some(t) <- tree) {
        Some(ObjectRef.Tree(t))
    } else {
        None
    }
}

// 解析 CommitRef
func parseCommitRef(data: Array<Byte>, hashKind: HashKind): ?ObjectRef {
    let commit = CommitRef.fromBytes(data, hashKind)
    if (let Some(c) <- commit) {
        Some(ObjectRef.Commit(c))
    } else {
        None
    }
}

// 解析 TagRef
func parseTagRef(data: Array<Byte>, hashKind: HashKind): ?ObjectRef {
    let tag = TagRef.fromBytes(data, hashKind)
    if (let Some(t) <- tag) {
        Some(ObjectRef.Tag(t))
    } else {
        None
    }
}

// 将 ObjectRef 转换为拥有类型的 Object
// 参数 objRef：对象引用枚举值
// 返回值：转换成功返回 Object，Commit/Tag 转换失败时返回 None
public func objectRefIntoOwned(objRef: ObjectRef): ?Object {
    match (objRef) {
        case ObjectRef.Tree(t) => Some(Object.TreeObj(t.intoOwned()))
        case ObjectRef.Blob(b) => Some(Object.BlobObj(b.intoOwned()))
        case ObjectRef.Commit(c) => convertCommit(c)
        case ObjectRef.Tag(t) => convertTag(t)
    }
}

// 转换 CommitRef 为 owned
func convertCommit(c: CommitRef): ?Object {
    let owned = c.intoOwned()
    if (let Some(co) <- owned) {
        Some(Object.CommitObj(co))
    } else {
        None
    }
}

// 转换 TagRef 为 owned
func convertTag(t: TagRef): ?Object {
    let owned = t.intoOwned()
    if (let Some(to) <- owned) {
        Some(Object.TagObj(to))
    } else {
        None
    }
}

// 获取 Object 的对象类型
// 参数 obj：对象拥有类型枚举值
// 返回值：对应的 ObjectKind 枚举值
public func objectKind(obj: Object): ObjectKind {
    match (obj) {
        case Object.TreeObj(_) => ObjectKind.Tree
        case Object.BlobObj(_) => ObjectKind.Blob
        case Object.CommitObj(_) => ObjectKind.Commit
        case Object.TagObj(_) => ObjectKind.Tag
    }
}

// 获取 ObjectRef 的对象类型
// 参数 objRef：对象引用枚举值
// 返回值：对应的 ObjectKind 枚举值
public func objectRefKind(objRef: ObjectRef): ObjectKind {
    match (objRef) {
        case ObjectRef.Tree(_) => ObjectKind.Tree
        case ObjectRef.Blob(_) => ObjectKind.Blob
        case ObjectRef.Commit(_) => ObjectKind.Commit
        case ObjectRef.Tag(_) => ObjectKind.Tag
    }
}

// 计算 Git 对象的哈希 ID
// 按照松散对象格式拼接头部和数据，然后计算哈希
// 参数 hashKind：哈希算法类型
// 参数 objectKind：对象类型
// 参数 data：对象体的字节数据
// 返回值：计算得到的 ObjectId
public func computeHash(hashKind: HashKind, objectKind: ObjectKind, data: Array<Byte>): ObjectId {
    let header = looseHeader(objectKind, data.size)
    let fullData = concatArrays(header, data)
    let hasher = GixHasher(hashKind)
    hasher.update(fullData)
    hasher.tryFinalize()
}

// 截取字节数组的指定范围（带边界检查）
// 参数 data：原始字节数组
// 参数 start：起始位置（含）
// 参数 end：结束位置（不含）
// 返回值：截取得到的新字节数组
public func sliceBytes2(data: Array<Byte>, start: Int64, end: Int64): Array<Byte> {
    var result = ArrayList<Byte>()
    var i = start
    while (i < end && i < data.size) {
        result.add(data[i])
        i += 1
    }
    result.toArray()
}

// 拼接两个字节数组
// 参数 a：第一个字节数组
// 参数 b：第二个字节数组
// 返回值：拼接后的新字节数组
func concatArrays(a: Array<Byte>, b: Array<Byte>): Array<Byte> {
    var result = ArrayList<Byte>()
    for (x in a) {
        result.add(x)
    }
    for (x in b) {
        result.add(x)
    }
    result.toArray()
}
