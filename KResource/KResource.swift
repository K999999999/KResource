import CommonCrypto
import CryptoKit
import UIKit

@dynamicMemberLookup
public struct KResource {
    public let fileURL: URL
    public subscript(dynamicMember member: String) -> KResource { KResource(fileURL: fileURL.appendingPathComponent(member)) }
    public subscript(key: String) -> KResource { KResource(fileURL: fileURL.appendingPathComponent(key)) }

    public static let resource = Resource()

    public class Resource {
        public lazy var encrypt: String = Bundle.main.bundleIdentifier ?? ""
        public lazy var output: String = "\(Bundle.main.infoDictionary?["CFBundleExecutable"] as? String ?? "").resource"

        private lazy var info: [String: Any]? = {
            guard let header = header,
                  let key = key,
                  let dataIn = try? read(8, header),
                  let dataOut = try? aes(dataIn, key) else { return nil }
            return try? JSONSerialization.jsonObject(with: dataOut) as? [String: Any]
        }()
    }
}

public extension KResource {
    static func resource(forResource name: String, withExtension ext: String?) -> KResource? {
        var fileURL = URL(fileURLWithPath: name)
        if let pathExtension = ext {
            fileURL.appendPathExtension(pathExtension)
        }
        guard resource.kind(fileURL) != .invalid else { return nil }
        return KResource(fileURL: fileURL)
    }

    func data(suffix: Suffix? = nil, pathExtension: PathExtension? = nil) throws -> Data {
        try Self.resource.data(KResource.fileURL(fileURL, suffix, pathExtension))
    }

    func contentsOfDirectory(suffix: Suffix? = nil, pathExtension: PathExtension? = nil) throws -> [URL] {
        try Self.resource.contentsOfDirectory(KResource.fileURL(fileURL, suffix, pathExtension))
    }

    func kind(suffix: Suffix? = nil, pathExtension: PathExtension? = nil) -> Kind {
        Self.resource.kind(KResource.fileURL(fileURL, suffix, pathExtension))
    }
}

public extension KResource {
    func image(suffix: Suffix? = .at3x, pathExtension: PathExtension? = .png, scale: CGFloat = 3) -> UIImage? {
        guard let data = try? data(suffix: suffix, pathExtension: pathExtension) else { return nil }
        return UIImage(data: data, scale: scale)
    }

    func registerAllFonts() throws {
        let contents = try contentsOfDirectory()
        for content in contents {
            if let data = try? KResource(fileURL: content).data() {
                KResource.registerFont(data)
            }
        }
    }

    func jsonObject(suffix: Suffix? = nil, pathExtension: PathExtension? = .json, options opt: JSONSerialization.ReadingOptions = []) throws -> Any {
        try JSONSerialization.jsonObject(with: data(suffix: suffix, pathExtension: pathExtension), options: opt)
    }

    func propertyList(suffix: Suffix? = nil, pathExtension: PathExtension? = .plist, options opt: PropertyListSerialization.ReadOptions = [], format: UnsafeMutablePointer<PropertyListSerialization.PropertyListFormat>? = nil) throws -> Any {
        try PropertyListSerialization.propertyList(from: data(suffix: suffix, pathExtension: pathExtension), options: opt, format: format)
    }

    func dataFileURL(suffix: Suffix? = nil, pathExtension: PathExtension? = nil, directory: String? = nil) throws -> URL {
        let fileURL = KResource.fileURL(fileURL, suffix, pathExtension)
        var url = try FileManager.default.url(for: .cachesDirectory, in: .userDomainMask, appropriateFor: nil, create: true)
        if let pathComponent = directory {
            url.appendPathComponent(pathComponent, isDirectory: true)
            var isDirectory: ObjCBool = .init(false)
            if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
                try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
            }
        }
        url.appendPathComponent(fileURL.lastPathComponent)
        var isDirectory: ObjCBool = .init(false)
        if !FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) || isDirectory.boolValue {
            try Self.resource.data(fileURL).write(to: url)
        }
        return url
    }

    func videoFileURL(suffix: Suffix? = nil, pathExtension: PathExtension? = .mp4, directory: String? = nil) throws -> URL {
        try dataFileURL(suffix: suffix, pathExtension: pathExtension, directory: directory)
    }
}

public extension KResource {
    enum Kind {
        case file
        case directory
        case invalid
    }

    enum Suffix {
        case at2x
        case at3x
        case custom(String)
    }

    enum PathExtension {
        case png
        case jpg
        case gif
        case webp
        case ttf
        case otf
        case json
        case plist
        case wav
        case mp3
        case mp4
        case html
        case custom(String)
    }
}

public extension KResource {
    static func fileURL(_ fileURL: URL, _ suffix: Suffix?, _ pathExtension: PathExtension?) -> URL {
        var url = fileURL
        if let suffix = suffix {
            switch suffix {
            case .at2x:
                url = URL(fileURLWithPath: url.path.appending("@2x"))
            case .at3x:
                url = URL(fileURLWithPath: url.path.appending("@3x"))
            case let .custom(aString):
                url = URL(fileURLWithPath: url.path.appending(aString))
            }
        }
        if let pathExtension = pathExtension {
            switch pathExtension {
            case .png:
                url.appendPathExtension("png")
            case .jpg:
                url.appendPathExtension("jpg")
            case .gif:
                url.appendPathExtension("gif")
            case .webp:
                url.appendPathExtension("webp")
            case .ttf:
                url.appendPathExtension("ttf")
            case .otf:
                url.appendPathExtension("otf")
            case .json:
                url.appendPathExtension("json")
            case .plist:
                url.appendPathExtension("plist")
            case .wav:
                url.appendPathExtension("wav")
            case .mp3:
                url.appendPathExtension("mp3")
            case .mp4:
                url.appendPathExtension("mp4")
            case .html:
                url.appendPathExtension("html")
            case let .custom(aString):
                url.appendPathExtension(aString)
            }
        }
        return url
    }

    @discardableResult
    static func registerFont(_ data: Data) -> Bool {
        guard let provider = CGDataProvider(data: data as CFData),
              let font = CGFont(provider),
              CTFontManagerRegisterGraphicsFont(font, nil) else { return false }
        return true
    }
}

public extension KResource.Resource {
    func data(_ fileURL: URL) throws -> Data {
        guard let rangeString = try info(fileURL) as? String else { throw KError("\(fileURL.path) is not a file") }
        guard let range = NSRange(rangeString) else { throw KError("\(rangeString) is not a range") }
        guard let header = header else { throw KError("header invalid") }
        let dataIn = try read(8 + header + range.location, range.length)
        guard let key = self.key else { throw KError("key invalid") }
        return try aes(dataIn, key)
    }

    func contentsOfDirectory(_ fileURL: URL) throws -> [URL] {
        guard let directory = try info(fileURL) as? [String: Any] else { throw KError("\(fileURL.path) is not a directory") }
        var urls: [URL] = []
        for key in directory.keys {
            urls.append(fileURL.appendingPathComponent(key))
        }
        return urls
    }

    func kind(_ fileURL: URL) -> KResource.Kind {
        guard let value = try? info(fileURL) else { return .invalid }
        if let rangeString = value as? String {
            return NSRange(rangeString) != nil ? .file : .invalid
        } else if value is [String: Any] {
            return .directory
        }
        return .invalid
    }
}

private extension KResource.Resource {
    var header: Int? {
        guard let data = try? read(0, 8) else { return nil }
        return data.withUnsafeBytes { $0.baseAddress!.assumingMemoryBound(to: Int.self).pointee }
    }

    var key: Data? {
        guard let data = encrypt.data(using: .utf8) else { return nil }
        if #available(iOS 13.0, *) {
            return Insecure.MD5.hash(data: data).map { String(format: "%02hhx", $0) }.joined().data(using: .utf8)
        }
        var digestData = Data(count: Int(CC_MD5_DIGEST_LENGTH))
        _ = digestData.withUnsafeMutableBytes { digestBytes in
            data.withUnsafeBytes { dataBytes in
                CC_MD5(dataBytes.baseAddress, CC_LONG(data.count), digestBytes.bindMemory(to: UInt8.self).baseAddress)
            }
        }
        return digestData.map { String(format: "%02hhx", $0) }.joined().data(using: .utf8)
    }

    func read(_ offset: Int, _ count: Int) throws -> Data {
        guard let url = Bundle.main.url(forResource: output, withExtension: nil) else { throw KError("resource file not found") }
        let readingHandle = try FileHandle(forReadingFrom: url)
        if #available(iOS 13.4, *) {
            try readingHandle.seek(toOffset: UInt64(offset))
            let data = try readingHandle.read(upToCount: count)
            try readingHandle.close()
            guard let confirmData = data else { throw KError("failed to read data") }
            return confirmData
        }
        readingHandle.seek(toFileOffset: UInt64(offset))
        let data = readingHandle.readData(ofLength: count)
        readingHandle.closeFile()
        return data
    }

    func aes(_ dataIn: Data, _ key: Data) throws -> Data {
        let dataOutAvailable: Int = dataIn.count + kCCBlockSizeAES128
        var dataOut: Data = Data(count: dataOutAvailable)
        var dataOutMoved: Int = 0
        let status = dataOut.withUnsafeMutableBytes { dataOutBytes in
            dataIn.withUnsafeBytes { dataInBytes in
                key.withUnsafeBytes { keyBytes in
                    CCCrypt(CCOperation(kCCDecrypt), CCAlgorithm(kCCAlgorithmAES), CCOptions(kCCOptionPKCS7Padding + kCCOptionECBMode), keyBytes.baseAddress, kCCKeySizeAES256, nil, dataInBytes.baseAddress, dataIn.count, dataOutBytes.baseAddress, dataOutAvailable, &dataOutMoved)
                }
            }
        }
        guard status == CCCryptorStatus(kCCSuccess) else { throw KError("failed to decrypt") }
        dataOut.removeSubrange(dataOutMoved ..< dataOut.count)
        return dataOut
    }

    func info(_ fileURL: URL) throws -> Any {
        guard let info = info else { throw KError("info invalid") }
        var url = URL(fileURLWithPath: "/")
        var result: Any = info
        for pathComponent in fileURL.pathComponents {
            if pathComponent == "/" {
                continue
            }
            guard let info = result as? [String: Any] else { throw KError("\(url.path) is not a directory") }
            url.appendPathComponent(pathComponent)
            guard let next = info[pathComponent] else { throw KError("\(url.path) not found") }
            result = next
        }
        return result
    }
}

private struct KError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}
