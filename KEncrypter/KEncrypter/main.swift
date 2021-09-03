//
//  main.swift
//  KEncrypter
//
//  Created by K999999999 on 2021/9/2.
//

import ArgumentParser
import CommonCrypto
import CryptoKit
import Foundation

KEncrypter.main()

struct KEncrypter: ParsableCommand {
    @Argument() var resources: [String]
    @Option(name: [.short, .long]) var encrypt: String?
    @Option(name: [.short, .long]) var output: String?

    mutating func run() throws {
        guard let EXECUTABLE_NAME = ProcessInfo.processInfo.environment["EXECUTABLE_NAME"] else { throw KError("EXECUTABLE_NAME not found") }
        print("EXECUTABLE_NAME: \(EXECUTABLE_NAME)")
        guard let PRODUCT_BUNDLE_IDENTIFIER = ProcessInfo.processInfo.environment["PRODUCT_BUNDLE_IDENTIFIER"] else { throw KError("PRODUCT_BUNDLE_IDENTIFIER not found") }
        print("PRODUCT_BUNDLE_IDENTIFIER: \(PRODUCT_BUNDLE_IDENTIFIER)")
        guard let CODESIGNING_FOLDER_PATH = ProcessInfo.processInfo.environment["CODESIGNING_FOLDER_PATH"] else { throw KError("CODESIGNING_FOLDER_PATH not found") }
        print("CODESIGNING_FOLDER_PATH: \(CODESIGNING_FOLDER_PATH)")
        print("resources: \(resources)")
        let encryptKey = encrypt ?? PRODUCT_BUNDLE_IDENTIFIER
        print("encrypt key: \(encryptKey)")
        let outputFile = output ?? "\(EXECUTABLE_NAME).resource"
        print("output file name: \(outputFile)")
        guard let originalData = encryptKey.data(using: .utf8) else { throw KError("failed to encode encryptKey") }
        let MD5String = Insecure.MD5.hash(data: originalData).map { String(format: "%02hhx", $0) }.joined()
        guard let key = MD5String.data(using: .utf8) else { throw KError("failed to encode MD5String") }
        try Self.encrypt(resources, key, outputFile, CODESIGNING_FOLDER_PATH)
    }

    static func encrypt(_ resources: [String], _ key: Data, _ outputFile: String, _ CODESIGNING_FOLDER_PATH: String) throws {
        var info: [String: Any] = [:]
        var resourceData: Data = Data()
        for resource in resources {
            if let resourceInfo = try process(CODESIGNING_FOLDER_PATH, resource, key, &resourceData) {
                info.updateValue(resourceInfo, forKey: resource)
            }
            var url = URL(fileURLWithPath: CODESIGNING_FOLDER_PATH)
            url.appendPathComponent(resource)
            try FileManager.default.removeItem(at: url)
        }
        let infoData = try aes(JSONSerialization.data(withJSONObject: info), key)
        var infoCount = infoData.count
        let headerData = Data(bytes: &infoCount, count: 8)
        let finalData = headerData + infoData + resourceData
        var url = URL(fileURLWithPath: CODESIGNING_FOLDER_PATH)
        url.appendPathComponent(outputFile)
        try finalData.write(to: url)
        print("encrypt success: \(url.path)")
    }

    static func process(_ path: String, _ resource: String, _ key: Data, _ resourceData: inout Data) throws -> Any? {
        var url = URL(fileURLWithPath: path)
        url.appendPathComponent(resource)
        var isDirectory = ObjCBool(false)
        if FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) != true {
            return nil
        }
        if isDirectory.boolValue {
            let contents = try FileManager.default.contentsOfDirectory(atPath: url.path)
            var info: [String: Any] = [:]
            for content in contents {
                if let contentInfo = try process(url.path, content, key, &resourceData) {
                    info.updateValue(contentInfo, forKey: content)
                }
            }
            return info
        }
        let dataOut = try aes(Data(contentsOf: url), key)
        let range = NSRange(location: resourceData.count, length: dataOut.count)
        resourceData.append(dataOut)
        return NSStringFromRange(range)
    }

    static func aes(_ dataIn: Data, _ key: Data) throws -> Data {
        let dataOutAvailable: Int = dataIn.count + kCCBlockSizeAES128
        var dataOut: Data = Data(count: dataOutAvailable)
        var dataOutMoved: Int = 0
        let status = dataOut.withUnsafeMutableBytes { dataOutBytes in
            dataIn.withUnsafeBytes { dataInBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCEncrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding + kCCOptionECBMode), keyBytes.baseAddress, kCCKeySizeAES256, nil, dataInBytes.baseAddress, dataIn.count, dataOutBytes.baseAddress, dataOutAvailable, &dataOutMoved)
                }
            }
        }
        guard status == CCCryptorStatus(kCCSuccess) else { throw KError("failed to encrypt") }
        dataOut.removeSubrange(dataOutMoved ..< dataOut.count)
        return dataOut
    }
}

struct KError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
