import CryptoKit
import Foundation
import ImageIO
import UniformTypeIdentifiers

enum LedgerImageLoadVariant: String, Sendable {
    case thumbnail
    case original
}

enum LedgerImageStoreError: LocalizedError {
    case missingImageData(recordID: UUID, index: Int)
    case unsafeRelativePath(String)

    var errorDescription: String? {
        switch self {
        case .missingImageData(let recordID, let index):
            return "记录 \(recordID.uuidString) 的第 \(index + 1) 张图片既没有文件引用也没有图片数据。"
        case .unsafeRelativePath(let path):
            return "图片路径不在账本图片目录内：\(path)"
        }
    }
}

final class LedgerImageStore {
    private let fileManager: FileManager
    let storeRootURL: URL
    let imageRootURL: URL
    let thumbnailRootURL: URL

    init(storeRootURL: URL, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.storeRootURL = storeRootURL.standardizedFileURL
        self.imageRootURL = self.storeRootURL
            .appendingPathComponent(LedgerStorageSchema.imageDirectoryName, isDirectory: true)
            .standardizedFileURL
        self.thumbnailRootURL = self.storeRootURL
            .appendingPathComponent("thumbnails", isDirectory: true)
            .standardizedFileURL
    }

    func prepareForPersistence(_ items: [HomeItem]) throws -> [HomeItem] {
        try fileManager.createDirectory(at: imageRootURL, withIntermediateDirectories: true)
        return try items.map(externalizedItem)
    }

    func hydrate(_ items: [HomeItem]) -> [HomeItem] {
        items.map(hydratedItem)
    }

    func metadataOnly(_ items: [HomeItem]) -> [HomeItem] {
        items.map { source in
            guard !source.memoryImageReferences.isEmpty else { return source }
            var item = source
            item.setExternalMemoryImages(
                references: source.memoryImageReferences,
                data: Array(repeating: Data(), count: source.memoryImageReferences.count),
                byteCounts: source.memoryImageByteCounts,
                unavailableIndices: []
            )
            return item
        }
    }

    func loadData(reference: String, variant: LedgerImageLoadVariant) -> Data? {
        switch variant {
        case .original:
            guard let url = try? safeURL(for: reference),
                  let data = try? Data(contentsOf: url),
                  !data.isEmpty else { return nil }
            return data
        case .thumbnail:
            return loadThumbnailData(reference: reference)
        }
    }

    func referencedPaths(in items: [HomeItem]) -> Set<String> {
        Set(items.flatMap(\.memoryImageReferences).filter { !$0.isEmpty })
    }

    func cleanupOrphans(keeping referencedPaths: Set<String>) throws {
        try cleanupFiles(in: imageRootURL, keeping: referencedPaths)
        let thumbnailReferences = Set(referencedPaths.compactMap(thumbnailReference(for:)))
        try cleanupFiles(in: thumbnailRootURL, keeping: thumbnailReferences)
    }

    func cleanupRecordOrphans(recordID: UUID, keeping referencedPaths: Set<String>) throws {
        let component = recordID.uuidString.lowercased()
        let imageDirectory = imageRootURL.appendingPathComponent(component, isDirectory: true).standardizedFileURL
        let thumbnailDirectory = thumbnailRootURL.appendingPathComponent(component, isDirectory: true).standardizedFileURL
        try assertChild(imageDirectory, of: imageRootURL)
        try assertChild(thumbnailDirectory, of: thumbnailRootURL)
        try cleanupFiles(in: imageDirectory, keeping: referencedPaths)
        let thumbnailReferences = Set(referencedPaths.compactMap(thumbnailReference(for:)))
        try cleanupFiles(in: thumbnailDirectory, keeping: thumbnailReferences)
    }

    func removeRecordFiles(recordID: UUID) throws {
        let component = recordID.uuidString.lowercased()
        let directories = [
            imageRootURL.appendingPathComponent(component, isDirectory: true).standardizedFileURL,
            thumbnailRootURL.appendingPathComponent(component, isDirectory: true).standardizedFileURL,
        ]
        for (directory, root) in zip(directories, [imageRootURL, thumbnailRootURL]) {
            try assertChild(directory, of: root)
            if fileManager.fileExists(atPath: directory.path) {
                try fileManager.removeItem(at: directory)
            }
        }
    }

    private func cleanupFiles(in rootURL: URL, keeping referencedPaths: Set<String>) throws {
        guard fileManager.fileExists(atPath: rootURL.path) else { return }
        let rootPath = rootURL.standardizedFileURL.path
        guard let enumerator = fileManager.enumerator(
            at: rootURL,
            includingPropertiesForKeys: [.isRegularFileKey, .isDirectoryKey],
            options: [.skipsHiddenFiles]
        ) else { return }

        var directories: [URL] = []
        for case let url as URL in enumerator {
            let standardized = url.standardizedFileURL
            guard standardized.path == rootPath || standardized.path.hasPrefix(rootPath + pathSeparator) else {
                throw LedgerImageStoreError.unsafeRelativePath(standardized.path)
            }
            let values = try standardized.resourceValues(forKeys: [.isRegularFileKey, .isDirectoryKey])
            if values.isDirectory == true {
                directories.append(standardized)
                continue
            }
            guard values.isRegularFile == true else { continue }
            let relative = relativePath(for: standardized)
            if !referencedPaths.contains(relative) {
                try fileManager.removeItem(at: standardized)
            }
        }

        for directory in directories.sorted(by: { $0.path.count > $1.path.count }) {
            let contents = try fileManager.contentsOfDirectory(atPath: directory.path)
            if contents.isEmpty {
                try fileManager.removeItem(at: directory)
            }
        }
        if rootURL != imageRootURL,
           rootURL != thumbnailRootURL,
           fileManager.fileExists(atPath: rootURL.path),
           (try fileManager.contentsOfDirectory(atPath: rootURL.path)).isEmpty {
            try fileManager.removeItem(at: rootURL)
        }
    }

    private func assertChild(_ url: URL, of root: URL) throws {
        let rootPath = root.standardizedFileURL.path
        guard url.standardizedFileURL.path.hasPrefix(rootPath + pathSeparator) else {
            throw LedgerImageStoreError.unsafeRelativePath(url.path)
        }
    }

    private func externalizedItem(_ source: HomeItem) throws -> HomeItem {
        var item = source
        let images = item.memoryImages
        guard !images.isEmpty else {
            item.setExternalMemoryImages(references: [], data: [])
            return item
        }
        if item.memoryImageReferences.count == images.count,
           item.memoryImageReferences.allSatisfy({ !$0.isEmpty }) {
            // Already externalized records do not touch or re-hash photo files on metadata-only saves.
            return item
        }

        var references: [String] = []
        var persistedData: [Data] = []
        var unavailable = Set<Int>()
        references.reserveCapacity(images.count)
        persistedData.reserveCapacity(images.count)

        for (index, data) in images.enumerated() {
            if data.isEmpty {
                guard item.memoryImageReferences.indices.contains(index),
                      !item.memoryImageReferences[index].isEmpty else {
                    throw LedgerImageStoreError.missingImageData(recordID: item.id, index: index)
                }
                references.append(item.memoryImageReferences[index])
                persistedData.append(data)
                unavailable.insert(index)
                continue
            }

            if item.memoryImageReferences.indices.contains(index) {
                let existingReference = item.memoryImageReferences[index]
                if !existingReference.isEmpty {
                    let existingURL = try safeURL(for: existingReference)
                    if fileManager.fileExists(atPath: existingURL.path) {
                        references.append(existingReference)
                        persistedData.append(data)
                        continue
                    }
                }
            }

            let digest = sha256Hex(data)
            let reference = imageReference(recordID: item.id, digest: digest)
            let targetURL = try safeURL(for: reference)
            try fileManager.createDirectory(
                at: targetURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            if let attributes = try? fileManager.attributesOfItem(atPath: targetURL.path),
               let size = attributes[.size] as? NSNumber,
               size.intValue == data.count {
                // Content-addressed path plus matching byte count makes retries idempotent.
            } else {
                try data.write(to: targetURL, options: .atomic)
            }
            references.append(reference)
            persistedData.append(data)
        }

        item.setExternalMemoryImages(
            references: references,
            data: persistedData,
            byteCounts: persistedData.enumerated().map { index, imageData in
                imageData.isEmpty ? source.memoryImageByteCount(at: index) : imageData.count
            },
            unavailableIndices: unavailable
        )
        return item
    }

    private func hydratedItem(_ source: HomeItem) -> HomeItem {
        guard !source.memoryImageReferences.isEmpty else { return source }
        var item = source
        var data: [Data] = []
        var unavailable = Set<Int>()
        data.reserveCapacity(source.memoryImageReferences.count)

        for (index, reference) in source.memoryImageReferences.enumerated() {
            guard let url = try? safeURL(for: reference),
                  let imageData = try? Data(contentsOf: url),
                  !imageData.isEmpty else {
                data.append(Data())
                unavailable.insert(index)
                continue
            }
            data.append(imageData)
        }

        item.setExternalMemoryImages(
            references: source.memoryImageReferences,
            data: data,
            byteCounts: data.enumerated().map { index, imageData in
                imageData.isEmpty ? source.memoryImageByteCount(at: index) : imageData.count
            },
            unavailableIndices: unavailable
        )
        return item
    }

    private func loadThumbnailData(reference: String) -> Data? {
        guard let originalURL = try? safeURL(for: reference),
              fileManager.fileExists(atPath: originalURL.path),
              let thumbnailReference = thumbnailReference(for: reference),
              let thumbnailURL = try? safeThumbnailURL(for: thumbnailReference) else {
            return nil
        }
        if let cached = try? Data(contentsOf: thumbnailURL), !cached.isEmpty {
            return cached
        }
        guard let generated = createThumbnailData(from: originalURL, maxPixelSize: 720),
              !generated.isEmpty else {
            return try? Data(contentsOf: originalURL)
        }
        do {
            try fileManager.createDirectory(
                at: thumbnailURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try generated.write(to: thumbnailURL, options: .atomic)
        } catch {
            return generated
        }
        return generated
    }

    private func createThumbnailData(from url: URL, maxPixelSize: Int) -> Data? {
        let sourceOptions: [CFString: Any] = [kCGImageSourceShouldCache: false]
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions as CFDictionary) else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixelSize,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(source, 0, options as CFDictionary) else { return nil }
        let output = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            output,
            UTType.jpeg.identifier as CFString,
            1,
            nil
        ) else { return nil }
        CGImageDestinationAddImage(
            destination,
            image,
            [kCGImageDestinationLossyCompressionQuality: 0.82] as CFDictionary
        )
        guard CGImageDestinationFinalize(destination) else { return nil }
        return output as Data
    }

    private func thumbnailReference(for imageReference: String) -> String? {
        let components = imageReference.split(separator: "/", omittingEmptySubsequences: true)
        guard components.count >= 3,
              components.first.map(String.init) == LedgerStorageSchema.imageDirectoryName,
              !components.dropFirst().contains(where: { $0 == ".." }) else { return nil }
        return (["thumbnails"] + components.dropFirst().map(String.init)).joined(separator: "/")
    }

    private func safeThumbnailURL(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.contains("..") else {
            throw LedgerImageStoreError.unsafeRelativePath(relativePath)
        }
        let url = storeRootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = thumbnailRootURL.path
        guard url.path.hasPrefix(rootPath + pathSeparator) else {
            throw LedgerImageStoreError.unsafeRelativePath(relativePath)
        }
        return url
    }

    private func imageReference(recordID: UUID, digest: String) -> String {
        "\(LedgerStorageSchema.imageDirectoryName)/\(recordID.uuidString.lowercased())/\(digest).jpg"
    }

    private func safeURL(for relativePath: String) throws -> URL {
        guard !relativePath.isEmpty, !relativePath.contains("..") else {
            throw LedgerImageStoreError.unsafeRelativePath(relativePath)
        }
        let url = storeRootURL.appendingPathComponent(relativePath).standardizedFileURL
        let rootPath = imageRootURL.path
        guard url.path.hasPrefix(rootPath + pathSeparator) else {
            throw LedgerImageStoreError.unsafeRelativePath(relativePath)
        }
        return url
    }

    private func relativePath(for url: URL) -> String {
        let rootPath = storeRootURL.path
        let prefix = rootPath.hasSuffix(pathSeparator) ? rootPath : rootPath + pathSeparator
        return url.path.replacingOccurrences(of: prefix, with: "").replacingOccurrences(of: "\\", with: "/")
    }

    private var pathSeparator: String {
        "/"
    }

    private func sha256Hex(_ data: Data) -> String {
        SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }
}
