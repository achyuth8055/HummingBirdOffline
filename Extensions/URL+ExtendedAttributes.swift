import Foundation

extension URL {
    /// Store arbitrary metadata alongside a file using extended attributes.
    func setExtendedAttribute(data: Data, forName name: String) throws {
        try data.withUnsafeBytes { bytes in
            let result = setxattr(path, name, bytes.bindMemory(to: UInt8.self).baseAddress, data.count, 0, 0)
            guard result >= 0 else {
                throw NSError(domain: POSIXError.errorDomain, code: Int(errno), userInfo: nil)
            }
        }
    }

    /// Read metadata previously stored with `setExtendedAttribute`.
    func getExtendedAttribute(forName name: String) throws -> Data {
        let length = getxattr(path, name, nil, 0, 0, 0)
        guard length >= 0 else {
            throw NSError(domain: POSIXError.errorDomain, code: Int(errno), userInfo: nil)
        }

        var data = Data(count: length)
        let result = data.withUnsafeMutableBytes { bytes in
            getxattr(path, name, bytes.bindMemory(to: UInt8.self).baseAddress, length, 0, 0)
        }

        guard result >= 0 else {
            throw NSError(domain: POSIXError.errorDomain, code: Int(errno), userInfo: nil)
        }

        return data
    }
}
