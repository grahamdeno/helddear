import Foundation
import Compression

/// Unzips a plain zip file (stored or deflated entries, no zip64), like the one "Export my data" writes. Used only to
/// read an export back in ("Import my data"). Nothing here touches the network.
enum ZipReader {
    enum Failure: Error, Equatable { case notAZip, unsupported(String), damaged(String) }

    /// Writes every file in `zip` under `folder`, keeping the paths inside the zip. Paths that would leave the
    /// folder are refused.
    static func extract(_ zip: URL, to folder: URL) throws {
        let data = try Data(contentsOf: zip, options: .mappedIfSafe)
        let bytes = [UInt8](data)
        func u16(_ i: Int) -> Int { Int(bytes[i]) | Int(bytes[i + 1]) << 8 }
        func u32(_ i: Int) -> Int { u16(i) | u16(i + 2) << 16 }

        // End of central directory: the last "PK\u{5}\u{6}" within the final 64 KB.
        guard bytes.count >= 22 else { throw Failure.notAZip }
        var end = -1
        var i = bytes.count - 22
        let stop = max(0, bytes.count - 22 - 65_535)
        while i >= stop {
            if bytes[i] == 0x50, bytes[i + 1] == 0x4B, bytes[i + 2] == 0x05, bytes[i + 3] == 0x06 { end = i; break }
            i -= 1
        }
        guard end >= 0 else { throw Failure.notAZip }
        let entries = u16(end + 10)
        var p = u32(end + 16)
        let fm = FileManager.default
        let root = folder.standardizedFileURL

        for _ in 0..<entries {
            guard p + 46 <= bytes.count, u32(p) == 0x0201_4B50 else { throw Failure.damaged("central directory") }
            let flags = u16(p + 8)
            let method = u16(p + 10)
            let compressed = u32(p + 20)
            let size = u32(p + 24)
            let nameLength = u16(p + 28), extraLength = u16(p + 30), commentLength = u16(p + 32)
            let local = u32(p + 42)
            let nameBytes = Array(bytes[(p + 46)..<(p + 46 + nameLength)])
            let name = String(decoding: nameBytes, as: UTF8.self)
            p += 46 + nameLength + extraLength + commentLength
            if flags & 0x1 != 0 { throw Failure.unsupported("encrypted") }
            if compressed == 0xFFFF_FFFF || size == 0xFFFF_FFFF { throw Failure.unsupported("zip64") }
            if name.hasPrefix("__MACOSX/") { continue }

            let target = root.appendingPathComponent(name).standardizedFileURL
            guard target.path.hasPrefix(root.path + "/") else { throw Failure.damaged("path outside the folder") }
            if name.hasSuffix("/") {
                try fm.createDirectory(at: target, withIntermediateDirectories: true)
                continue
            }
            guard local + 30 <= bytes.count, u32(local) == 0x0403_4B50 else { throw Failure.damaged("local header") }
            let start = local + 30 + u16(local + 26) + u16(local + 28)
            guard start + compressed <= bytes.count else { throw Failure.damaged(name) }
            let raw = Array(bytes[start..<(start + compressed)])
            let out: [UInt8]
            switch method {
            case 0: out = raw
            case 8: out = try inflate(raw, size: size)
            default: throw Failure.unsupported("method \(method)")
            }
            try fm.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
            try Data(out).write(to: target)
        }
    }

    /// Raw deflate, as zip uses it (Apple's COMPRESSION_ZLIB is raw deflate).
    static func inflate(_ input: [UInt8], size: Int) throws -> [UInt8] {
        if size == 0 { return [] }
        var output = [UInt8](repeating: 0, count: size)
        let written = input.withUnsafeBufferPointer { src in
            output.withUnsafeMutableBufferPointer { dst in
                compression_decode_buffer(dst.baseAddress!, size, src.baseAddress!, input.count, nil, COMPRESSION_ZLIB)
            }
        }
        guard written == size else { throw Failure.damaged("inflate") }
        return output
    }
}
