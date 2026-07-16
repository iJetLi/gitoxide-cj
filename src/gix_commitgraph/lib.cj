// 文件：lib.cj
// 用途：提供 commit-graph 文件读写功能，加速提交遍历
// 所属包：gix.gix_commitgraph
// 关键类型：CommitGraphFile, Commit, Position, Generation
// 对齐来源：gix-commitgraph/src/file/, gix-commitgraph/src/access.rs

package gitoxide.gix_commitgraph

import gitoxide.gix_hash.*
import gitoxide.gix_chunk.*
import std.collection.*
import std.fs.*

// 对齐 Rust: gix_commitgraph::file::commit::GENERATION_NUMBER_INFINITY
public let GENERATION_NUMBER_INFINITY: UInt32 = 0xFFFFFFFF

// 对齐 Rust: gix_commitgraph::file::commit::GENERATION_NUMBER_MAX
public let GENERATION_NUMBER_MAX: UInt32 = 0x3FFFFFFF

// 对齐 Rust: gix_commitgraph::Position
public struct Position {
    public let index: UInt32
    public init(index: UInt32) {
        this.index = index
    }
    public operator func ==(that: Position): Bool {
        this.index == that.index
    }
    public operator func !=(that: Position): Bool {
        this.index != that.index
    }
}

// 对齐 Rust: gix_commitgraph::Generation
public type Generation = UInt32

// 对齐 Rust: gix_commitgraph::file::Commit
public class Commit {
    public var objectId: ObjectId
    public var parentPositions: Array<Position>
    public var generation: Generation
    public var committerTimestamp: Int64
    public var rootTreeId: ObjectId

    public init(objectId: ObjectId, parentPositions: Array<Position>, generation: Generation, committerTimestamp: Int64, rootTreeId: ObjectId) {
        this.objectId = objectId
        this.parentPositions = parentPositions
        this.generation = generation
        this.committerTimestamp = committerTimestamp
        this.rootTreeId = rootTreeId
    }

    public func iterParents(): Array<Position> {
        parentPositions
    }

    public func generationOpt(): ?Generation {
        if (generation == GENERATION_NUMBER_INFINITY) { None } else { Some(generation) }
    }
}

// 对齐 Rust: gix_commitgraph::Graph
public class Graph {
    public var files: ArrayList<CommitGraphFile>

    public init() {
        this.files = ArrayList<CommitGraphFile>()
    }

    public func addFile(file: CommitGraphFile): Unit {
        files.add(file)
    }

    public func lookup(id: ObjectId): ?Position {
        for (file in files) {
            let pos = file.lookup(id)
            if (let Some(p) <- pos) {
                return Some(p)
            }
        }
        None
    }

    public func commitAt(pos: Position): ?Commit {
        for (file in files) {
            if (pos.index < UInt32(file.numCommits)) {
                return file.commitAt(pos)
            }
        }
        None
    }
}

// 对齐 Rust: gix_commitgraph::file::File
public class CommitGraphFile {
    public var data: Array<Byte>
    public var fan: Array<UInt32>
    public var oidLookupOffset: Int64
    public var commitDataOffset: Int64
    public var extraEdgesOffset: Int64
    public var hashLen: Int64
    public var numCommits: Int64
    public var path: String

    public init() {
        this.data = []
        this.fan = Array<UInt32>(256, repeat: UInt32(0))
        this.oidLookupOffset = 0
        this.commitDataOffset = 0
        this.extraEdgesOffset = 0
        this.hashLen = 20
        this.numCommits = 0
        this.path = ""
    }

    public init(path: String) {
        this.data = []
        this.fan = Array<UInt32>(256, repeat: UInt32(0))
        this.oidLookupOffset = 0
        this.commitDataOffset = 0
        this.extraEdgesOffset = 0
        this.hashLen = 20
        this.numCommits = 0
        this.path = path
    }

    // 对齐 Rust: file::File::open()
    public static func open(path: String): ?CommitGraphFile {
        if (path.size == 0 || !exists(path)) {
            return None
        }
        let file = CommitGraphFile(path)
        Some(file)
    }

    // 对齐 Rust: file::File::init()
    // 从字节数据解析 commit-graph 文件
    public static func fromBytes(data: Array<Byte>): ?CommitGraphFile {
        if (data.size < 12) { return None }
        // 检查签名 "CGPH"
        if (data[0] != UInt8(67) || data[1] != UInt8(71) || data[2] != UInt8(80) || data[3] != UInt8(72)) {
            return None
        }
        // 版本号
        let version = (UInt32(data[4]) << 24) | (UInt32(data[5]) << 16) | (UInt32(data[6]) << 8) | UInt32(data[7])
        if (version != 1 && version != 2) { return None }
        // hash 版本
        let hashVersion = (UInt32(data[8]) << 24) | (UInt32(data[9]) << 16) | (UInt32(data[10]) << 8) | UInt32(data[11])
        let hashLen: Int64 = if (hashVersion == 2) { 32 } else { 20 }

        let file = CommitGraphFile()
        file.data = data
        file.hashLen = hashLen

        // 使用 gix_chunk 解析 chunk table
        let chunkFile = ChunkFile.parse(data)
        if (chunkFile.isNone()) { return None }
        let cf = chunkFile.getOrThrow()

        // 查找 OID Lookup chunk ("OIDL")
        let oidlKind = makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(76))
        let oidlChunk = cf.findChunk(oidlKind)
        if (let Some(c) <- oidlChunk) {
            file.oidLookupOffset = c.offset
        }

        // 查找 Commit Data chunk ("CDAT")
        let cdatKind = makeChunkId(UInt8(67), UInt8(68), UInt8(65), UInt8(84))
        let cdatChunk = cf.findChunk(cdatKind)
        if (let Some(c) <- cdatChunk) {
            file.commitDataOffset = c.offset
            let commitDataSize = c.size
            let entrySize = hashLen * 2 + 16
            if (entrySize > 0) {
                file.numCommits = commitDataSize / entrySize
            }
        }

        // 查找 Extra Edge List chunk ("EDGE")
        let edgeKind = makeChunkId(UInt8(69), UInt8(68), UInt8(71), UInt8(69))
        let edgeChunk = cf.findChunk(edgeKind)
        if (let Some(c) <- edgeChunk) {
            file.extraEdgesOffset = c.offset
        }

        // 解析 fanout 表 ("OIDF")
        let oidfKind = makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70))
        let oidfChunk = cf.findChunk(oidfKind)
        if (let Some(c) <- oidfChunk) {
            var i: Int64 = 0
            while (i < 256) {
                let offset = c.offset + i * 4
                if (offset + 4 <= data.size) {
                    file.fan[i] = (UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16) | (UInt32(data[offset + 2]) << 8) | UInt32(data[offset + 3])
                }
                i += 1
            }
            file.numCommits = Int64(file.fan[255])
        }

        Some(file)
    }

    // 对齐 Rust: file::File::lookup()
    public func lookup(id: ObjectId): ?Position {
        if (data.size == 0 || numCommits == 0) { return None }
        let firstByte = id.bytes[0]
        var lo: Int64 = if (firstByte == 0) { 0 } else { Int64(fan[Int64(firstByte) - 1]) }
        var hi: Int64 = Int64(fan[Int64(firstByte)])
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            let oidOffset = oidLookupOffset + mid * hashLen
            if (oidOffset + hashLen > data.size) { break }
            var cmp: Int64 = 0
            var k: Int64 = 0
            while (k < hashLen) {
                let a = data[oidOffset + k]
                let b = id.bytes[k]
                if (a < b) { cmp = -1; break }
                if (a > b) { cmp = 1; break }
                k += 1
            }
            if (cmp == 0) {
                return Some(Position(UInt32(mid)))
            } else if (cmp < 0) {
                lo = mid + 1
            } else {
                hi = mid
            }
        }
        None
    }

    // 对齐 Rust: file::File::commit_at()
    public func commitAt(pos: Position): ?Commit {
        if (data.size == 0) { return None }
        let idx = Int64(pos.index)
        if (idx >= numCommits) { return None }
        let oidOffset = oidLookupOffset + idx * hashLen
        if (oidOffset + hashLen > data.size) { return None }
        var oidBytes = Array<Byte>(hashLen, repeat: UInt8(0))
        var k: Int64 = 0
        while (k < hashLen) {
            oidBytes[k] = data[oidOffset + k]
            k += 1
        }
        let hashKind = if (hashLen == 32) { HashKind.Sha256 } else { HashKind.Sha1 }
        let objectId = ObjectId(oidBytes, hashKind)
        let entrySize = hashLen * 2 + 16
        let commitOffset = commitDataOffset + idx * entrySize
        if (commitOffset + entrySize > data.size) { return None }
        let baseOffset = commitOffset + hashLen
        let parent1 = (UInt32(data[baseOffset]) << 24) | (UInt32(data[baseOffset + 1]) << 16) | (UInt32(data[baseOffset + 2]) << 8) | UInt32(data[baseOffset + 3])
        let parent2 = (UInt32(data[baseOffset + 4]) << 24) | (UInt32(data[baseOffset + 5]) << 16) | (UInt32(data[baseOffset + 6]) << 8) | UInt32(data[baseOffset + 7])
        var parentPositions = Array<Position>(0, repeat: Position(UInt32(0)))
        if (parent1 != 0xFFFFFFFF) {
            parentPositions = Array<Position>(1, repeat: Position(parent1))
            if (parent2 != 0xFFFFFFFF) {
                parentPositions = Array<Position>(2, repeat: Position(UInt32(0)))
                parentPositions[0] = Position(parent1)
                parentPositions[1] = Position(parent2)
            }
        }
        let genAndTime = (UInt32(data[baseOffset + 8]) << 24) | (UInt32(data[baseOffset + 9]) << 16) | (UInt32(data[baseOffset + 10]) << 8) | UInt32(data[baseOffset + 11])
        let generation = genAndTime >> 2
        let commitTime = (Int64(data[baseOffset + 12]) << 24) | (Int64(data[baseOffset + 13]) << 16) | (Int64(data[baseOffset + 14]) << 8) | Int64(data[baseOffset + 15])
        let treeOffset = baseOffset + 16
        var treeBytes = Array<Byte>(hashLen, repeat: UInt8(0))
        var t: Int64 = 0
        while (t < hashLen) {
            treeBytes[t] = data[treeOffset + t]
            t += 1
        }
        let rootTreeId = ObjectId(treeBytes, hashKind)
        Some(Commit(objectId, parentPositions, generation, commitTime, rootTreeId))
    }

    // 对齐 Rust: file::File::iter()
    public func iter(): ArrayList<Commit> {
        let result = ArrayList<Commit>()
        var i: Int64 = 0
        while (i < numCommits) {
            let commit = commitAt(Position(UInt32(i)))
            if (let Some(c) <- commit) {
                result.add(c)
            }
            i += 1
        }
        result
    }

    // 对齐 Rust: file::File::verify()
    public func verify(): Bool {
        if (data.size == 0) { return false }
        if (data.size < 12) { return false }
        if (data[0] != UInt8(67) || data[1] != UInt8(71) || data[2] != UInt8(80) || data[3] != UInt8(72)) {
            return false
        }
        if (fan[255] != UInt32(numCommits)) {
            return false
        }
        true
    }
}
