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
import std.io.*

// 对齐 Rust: gix_commitgraph::file::commit::GENERATION_NUMBER_INFINITY
public let GENERATION_NUMBER_INFINITY: UInt32 = 0xFFFFFFFF

// 对齐 Rust: gix_commitgraph::file::commit::GENERATION_NUMBER_MAX
public let GENERATION_NUMBER_MAX: UInt32 = 0x3FFFFFFF
public let NO_PARENT: UInt32 = 0x70000000

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

    public init(objectId: ObjectId, parentPositions: Array<Position>, generation: Generation, committerTimestamp: Int64,
        rootTreeId: ObjectId) {
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
        if (generation == GENERATION_NUMBER_INFINITY) {
            None
        } else {
            Some(generation)
        }
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
    public var gda2Offset: Int64
    public var hashLen: Int64
    public var numCommits: Int64
    public var path: String

    public init() {
        this.data = []
        this.fan = Array<UInt32>(256, repeat: UInt32(0))
        this.oidLookupOffset = 0
        this.commitDataOffset = 0
        this.extraEdgesOffset = 0
        this.gda2Offset = 0
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
        this.gda2Offset = 0
        this.hashLen = 20
        this.numCommits = 0
        this.path = path
    }

    // 对齐 Rust: file::File::open()
    public static func open(path: String): ?CommitGraphFile {
        if (path.size == 0 || !exists(path)) {
            return None
        }
        try {
            let f = File(path, OpenMode.Read)
            var buf = ArrayList<Byte>()
            let chunk = Array<UInt8>(4096, repeat: UInt8(0))
            while (true) {
                let n = f.read(chunk)
                if (n <= 0) {
                    break
                }
                var i: Int64 = 0
                while (i < n) {
                    buf.add(chunk[i])
                    i += 1
                }
            }
            f.close()
            let data = buf.toArray()
            let file = fromBytes(data)
            if (let Some(f) <- file) {
                f.path = path
                Some(f)
            } else {
                None
            }
        } catch (_: Exception) {
            None
        }
    }

    // 对齐 Rust: file::File::init()
    // 从字节数据解析 commit-graph 文件
    public static func fromBytes(data: Array<Byte>): ?CommitGraphFile {
        if (data.size < 12) {
            return None
        }
        // 检查签名 "CGPH"
        if (data[0] != UInt8(67) || data[1] != UInt8(71) || data[2] != UInt8(80) || data[3] != UInt8(72)) {
            return None
        }
        // 版本号
        let version = UInt32(data[4])
        if (version != 1 && version != 2) {
            return None
        }
        let hashVersion = UInt32(data[5])
        let hashLen: Int64 = if (hashVersion == 2) {
            32
        } else {
            20
        }

        let numChunks = UInt32(data[6]) | (UInt32(data[7]) << 8)
        let tocOffset: Int64 = 8

        let file = CommitGraphFile()
        file.data = data
        file.hashLen = hashLen

        let chunkFile = ChunkFile.parse(data, tocOffset, Int64(numChunks))
        if (chunkFile.isNone()) {
            return None
        }
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
            let entrySize = hashLen + 16
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

        let gda2Kind = makeChunkId(UInt8(71), UInt8(68), UInt8(65), UInt8(50))
        let gda2Chunk = cf.findChunk(gda2Kind)
        if (let Some(c) <- gda2Chunk) {
            file.gda2Offset = c.offset
        }

        // 解析 fanout 表 ("OIDF")
        let oidfKind = makeChunkId(UInt8(79), UInt8(73), UInt8(68), UInt8(70))
        let oidfChunk = cf.findChunk(oidfKind)
        if (let Some(c) <- oidfChunk) {
            var i: Int64 = 0
            while (i < 256) {
                let offset = c.offset + i * 4
                if (offset + 4 <= data.size) {
                    file.fan[i] = (UInt32(data[offset]) << 24) | (UInt32(data[offset + 1]) << 16) | (UInt32(data[offset +
                            2]) << 8) | UInt32(data[offset + 3])
                }
                i += 1
            }
            file.numCommits = Int64(file.fan[255])
        }

        Some(file)
    }

    // 对齐 Rust: file::File::lookup()
    public func lookup(id: ObjectId): ?Position {
        if (data.size == 0 || numCommits == 0) {
            return None
        }
        let firstByte = id.bytes[0]
        var lo: Int64 = if (firstByte == 0) {
            0
        } else {
            Int64(fan[Int64(firstByte) - 1])
        }
        var hi: Int64 = Int64(fan[Int64(firstByte)])
        while (lo < hi) {
            let mid = lo + (hi - lo) / 2
            let oidOffset = oidLookupOffset + mid * hashLen
            if (oidOffset + hashLen > data.size) {
                break
            }
            var cmp: Int64 = 0
            var k: Int64 = 0
            while (k < hashLen) {
                let a = data[oidOffset + k]
                let b = id.bytes[k]
                if (a < b) {
                    cmp = -1
                    break
                }
                if (a > b) {
                    cmp = 1
                    break
                }
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
        if (data.size == 0) {
            return None
        }
        let idx = Int64(pos.index)
        if (idx >= numCommits) {
            return None
        }
        let oidOffset = oidLookupOffset + idx * hashLen
        if (oidOffset + hashLen > data.size) {
            return None
        }
        var oidBytes = Array<Byte>(hashLen, repeat: UInt8(0))
        var k: Int64 = 0
        while (k < hashLen) {
            oidBytes[k] = data[oidOffset + k]
            k += 1
        }
        let hashKind = if (hashLen == 32) {
            HashKind.Sha256
        } else {
            HashKind.Sha1
        }
        let objectId = ObjectId(oidBytes, hashKind)
        let entrySize = hashLen + 16
        let commitOffset = commitDataOffset + idx * entrySize
        if (commitOffset + entrySize > data.size) {
            return None
        }
        let baseOffset = commitOffset + hashLen
        let parent1 = (UInt32(data[baseOffset]) << 24) | (UInt32(data[baseOffset + 1]) << 16) | (UInt32(data[baseOffset +
                2]) << 8) | UInt32(data[baseOffset + 3])
        let parent2 = (UInt32(data[baseOffset + 4]) << 24) | (UInt32(data[baseOffset + 5]) << 16) | (UInt32(data[baseOffset +
                6]) << 8) | UInt32(data[baseOffset + 7])
        var parentPositions = Array<Position>(0, repeat: Position(UInt32(0)))
        if (parent1 == NO_PARENT || parent1 == 0xFFFFFFFF) {
            parentPositions = Array<Position>(0, repeat: Position(UInt32(0)))
        } else {
            let p1Pos = parent1 & UInt32(0x3FFFFFFF)
            if (parent2 == NO_PARENT || parent2 == 0xFFFFFFFF) {
                parentPositions = Array<Position>(1, repeat: Position(p1Pos))
            } else if ((parent2 & UInt32(0x80000000)) != 0) {
                parentPositions = Array<Position>(1, repeat: Position(p1Pos))
            } else {
                let p2Pos = parent2 & UInt32(0x3FFFFFFF)
                parentPositions = Array<Position>(2, repeat: Position(UInt32(0)))
                parentPositions[0] = Position(p1Pos)
                parentPositions[1] = Position(p2Pos)
            }
        }
        let genAndTime = (UInt32(data[baseOffset + 8]) << 24) | (UInt32(data[baseOffset + 9]) << 16) | (UInt32(data[baseOffset +
                10]) << 8) | UInt32(data[baseOffset + 11])
        var generation = genAndTime >> 2
        if (gda2Offset > 0) {
            let gda2EntryOffset = gda2Offset + idx * 4
            if (gda2EntryOffset + 4 <= data.size) {
                let correctedGen = (UInt32(data[gda2EntryOffset]) << 24) | (UInt32(data[gda2EntryOffset + 1]) << 16) | (UInt32(data[gda2EntryOffset +
                        2]) << 8) | UInt32(data[gda2EntryOffset + 3])
                if (correctedGen != 0) {
                    generation = correctedGen
                }
            }
        }
        let commitTime = (Int64(data[baseOffset + 12]) << 24) | (Int64(data[baseOffset + 13]) << 16) | (Int64(data[baseOffset +
                14]) << 8) | Int64(data[baseOffset + 15])
        let treeOffset = commitOffset
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
        if (data.size == 0) {
            return false
        }
        if (data.size < 12) {
            return false
        }
        if (data[0] != UInt8(67) || data[1] != UInt8(71) || data[2] != UInt8(80) || data[3] != UInt8(72)) {
            return false
        }
        if (fan[255] != UInt32(numCommits)) {
            return false
        }
        true
    }
}
