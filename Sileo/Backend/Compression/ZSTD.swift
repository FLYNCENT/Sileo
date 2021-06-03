//
//  ZSTD.swift
//  Sileo
//
//  Created by Andromeda on 31/05/2021.
//  Copyright © 2021 Sileo Team. All rights reserved.
//
#if !targetEnvironment(simulator) || !TARGET_SANDBOX
import Foundation

final class ZSTD {
    
    static var available: Bool {
        if let contents = try? URL(fileURLWithPath: "/usr/lib/").contents() {
            return contents.contains(where: { $0.absoluteString.contains("libzstd") })
        }
        return false
    }
    
    class func decompress(path: String) -> (String?, Data?) {
        AmyLogManager.log("[Sileo] Loading File")
        guard let fin = fopen(path, "rb") else { return (ZSTDError.fileLoad.rawValue, nil) }
        defer {
            fclose(fin)
        }

        AmyLogManager.log("[Sileo] Loading buffIn")
        let buffInSize = ZSTD_DStreamInSize()
        AmyLogManager.log("[Sileo] Loading buffOut")
        let buffOutSize = ZSTD_DStreamOutSize()
        AmyLogManager.log("[Sileo] malloc \(buffOutSize)")
        let inBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(buffInSize))
        let outBuf = UnsafeMutablePointer<UInt8>.allocate(capacity: Int(buffOutSize))
        AmyLogManager.log("[Sileo] Loading ZSTD_createDCTX")
        guard let dctx = ZSTD_createDCtx() else { return (ZSTDError.context.rawValue, nil) }
        defer {
            ZSTD_freeDCtx(dctx)
        }
        var read: size_t = 0
        var lastRet: size_t = 0
        var isEmpty = true
        let data = NSMutableData()
        while true {
            AmyLogManager.log("[Sileo] fread \(inBuf) \(1) \(buffInSize) \(fin)")
            read = fread(inBuf, 1, buffInSize, fin)
            if read == 0 { break }
            isEmpty = false
            AmyLogManager.log("[Sileo] ZSTD_in_buffer \(inBuf) \(read) \(0)")
            var input = ZSTD_inBuffer(src: inBuf, size: read, pos: 0)
            while input.pos < input.size {
                AmyLogManager.log("[Sileo] outBuffer \(outBuf) \(buffOutSize) \(0)")
                var output = ZSTD_outBuffer(dst: outBuf, size: buffOutSize, pos: 0)
                AmyLogManager.log("[Sileo] decompressStream \(dctx) \(output) \(input)")
                let ret = ZSTD_decompressStream(dctx, &output, &input)
                if ZSTD_isError(ret) != 0 {
                    if let error = ZSTD_getErrorName(ret) {
                        let string = String(cString: error)
                        return (string, nil)
                    } else {
                        return (ZSTDError.unknown.rawValue, nil)
                    }
                }
                AmyLogManager.log("[Sileo] Data Append \(outBuf) \(output.pos)")
                data.append(Data(bytes: outBuf, count: output.pos))
                lastRet = ret
            }
        }
        if isEmpty {
            return (ZSTDError.empty.rawValue, nil)
        }
        if lastRet != 0 {
            return (ZSTDError.midFrame.rawValue, nil)
        }
        
        return (nil, data as Data)
    }
}

enum ZSTDError: String {
    case fileLoad = "Failed to load file"
    case buffIn = "Failed to load buffin in memory"
    case buffOut = "Failed to load buffout in memory"
    case context = "Failed to create decompression context"
    case unknown = "Unknown Error"
    case empty = "Input File was Empty"
    case midFrame = "Data finished mid-frame"
}
#endif
