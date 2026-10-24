// SMCSensor.swift — AppleSMC 免 sudo 读取器
// SMCKeyData_t 80 字节布局（对照 recon/smc-base.c 实编，注意 vers 是 6 字节！勿再算错）：
//   key@0(4) | vers@4(6) | pLimit@12(16) | keyInfo@28(dataSize@28,dataType@32,attr@36)
//   result@40 | status@41 | data8@42 | data32@44 | bytes@48(32)
// 本机要点：温度/功率是 flt 浮点（非 Intel 时代 sp78）；键总数读 #KEY（此 CLI 未用到）

import Foundation
import IOKit

struct SMCValue {
    let type: String
    let size: Int
    let bytes: [UInt8]

    /// 按 SMC 数据类型解码为数值
    var double: Double? {
        switch type {
        case "flt " where size >= 4:
            return Double(bytes.withUnsafeBytes { $0.load(as: Float32.self) })
        case "ioft" where size >= 8:
            return bytes.withUnsafeBytes { $0.load(as: Double.self) }
        case "fpe2" where size >= 2:
            return Double(Int(bytes[0]) << 8 | Int(bytes[1])) / 4.0
        case "sp78" where size >= 2:
            return Double(Int16(bitPattern: UInt16(bytes[0]) << 8 | UInt16(bytes[1]))) / 256.0
        default:
            return nil
        }
    }
}

final class SMCSensor {
    enum SMCErr: Error { case openFailed, keyNotFound(String) }

    private var conn: io_connect_t = 0
    // KEYINFO 缓存（性能优化 P2）：dataSize/dataType 是键的 SMC 固有属性，进程内不变，
    // 命中即跳过 KEYINFO 调用。读写只发生在 Sampler 自有队列（串行约束），无需加锁；
    // open 失败重开是新实例、缓存随之重建，即便复用也不存在过期问题
    private var keyInfoCache: [UInt32: (size: UInt32, type: UInt32)] = [:]
    private static let structSize = 80
    private static let selector: UInt32 = 2 // KERNEL_INDEX_SMC
    private static let cmdReadBytes: UInt8 = 5
    private static let cmdReadKeyInfo: UInt8 = 9
    private static let oKeyInfo = 28
    private static let oData8 = 42
    private static let oBytes = 48

    func open() throws {
        var iterator: io_iterator_t = 0
        guard IOServiceGetMatchingServices(kIOMainPortDefault, IOServiceMatching("AppleSMC"), &iterator) == KERN_SUCCESS else {
            throw SMCErr.openFailed
        }
        let device = IOIteratorNext(iterator)
        IOObjectRelease(iterator)
        guard device != 0 else { throw SMCErr.openFailed }
        defer { IOObjectRelease(device) }
        guard IOServiceOpen(device, mach_task_self_, 0, &conn) == KERN_SUCCESS else {
            throw SMCErr.openFailed
        }
    }

    func close() {
        if conn != 0 { IOServiceClose(conn); conn = 0 }
    }

    func read(_ key: String) throws -> SMCValue {
        let keyU32 = Self.keyToUInt32(key)

        // 第一步：KEYINFO 拿 dataSize/dataType（P2：命中缓存则跳过本次内核调用）
        let dataSize: UInt32
        let dataTypeRaw: UInt32
        if let hit = keyInfoCache[keyU32] {
            dataSize = hit.size
            dataTypeRaw = hit.type
        } else {
            var input = Self.emptyInput(keyU32)
            input[Self.oData8] = Self.cmdReadKeyInfo
            guard let out = call(input) else { throw SMCErr.keyNotFound(key) }
            let size = out.withUnsafeBytes { $0.load(fromByteOffset: Self.oKeyInfo, as: UInt32.self) }
            // 无效键不缓存：下次仍走 KEYINFO 探测，保留失败可重试的原语义
            guard size > 0, size <= 32 else { throw SMCErr.keyNotFound(key) }
            dataSize = size
            dataTypeRaw = out.withUnsafeBytes { $0.load(fromByteOffset: Self.oKeyInfo + 4, as: UInt32.self) }
            keyInfoCache[keyU32] = (dataSize, dataTypeRaw)
        }

        // 第二步：READ_BYTES 读值
        var input2 = Self.emptyInput(keyU32)
        input2[Self.oKeyInfo] = UInt8(truncatingIfNeeded: dataSize)
        input2[Self.oData8] = Self.cmdReadBytes
        guard let out2 = call(input2) else { throw SMCErr.keyNotFound(key) }

        return SMCValue(type: Self.msbString(dataTypeRaw), size: Int(dataSize),
                        bytes: Array(out2[Self.oBytes..<(Self.oBytes + Int(dataSize))]))
    }

    func double(_ key: String) -> Double? {
        guard let v = try? read(key) else { return nil }
        return v.double
    }

    /// 一组键中的最大有效读数（如 Tg0x 系列取 GPU 最热核心）。
    /// ≤0 视为传感器无效（GPU 空闲时部分键回读 0.0），不计入
    func maxDouble(_ keys: [String]) -> Double? {
        keys.compactMap { key -> Double? in
            guard let v = double(key), v > 0 else { return nil }
            return v
        }.max()
    }

    // MARK: - 底层

    private func call(_ input: [UInt8]) -> [UInt8]? {
        var input = input
        var output = [UInt8](repeating: 0, count: Self.structSize)
        var outSize = Self.structSize
        let kr = input.withUnsafeMutableBufferPointer { ib in
            output.withUnsafeMutableBufferPointer { ob in
                IOConnectCallStructMethod(conn, Self.selector,
                                          ib.baseAddress, Self.structSize,
                                          ob.baseAddress, &outSize)
            }
        }
        return kr == KERN_SUCCESS ? output : nil
    }

    private static func emptyInput(_ key: UInt32) -> [UInt8] {
        var input = [UInt8](repeating: 0, count: structSize)
        input.withUnsafeMutableBytes { $0.storeBytes(of: key, as: UInt32.self) }
        return input
    }

    private static func keyToUInt32(_ key: String) -> UInt32 {
        var value: UInt32 = 0
        for ch in key.utf8.prefix(4) { value = (value << 8) | UInt32(ch) }
        return value
    }

    private static func msbString(_ value: UInt32) -> String {
        let chars = [UInt8((value >> 24) & 0xFF), UInt8((value >> 16) & 0xFF),
                     UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
        return String(bytes: chars, encoding: .ascii) ?? "????"
    }
}
