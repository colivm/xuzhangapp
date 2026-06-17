import Foundation
import Photos
import UIKit

enum PhotoLibrarySaveError: LocalizedError {
    case permissionDenied
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "无法保存到相册。请在系统设置中允许叙账访问相册。"
        case .saveFailed:
            return "暂时没保存成功。请检查相册权限后再试。"
        }
    }
}

final class PhotoLibrarySaveService {
    static let shared = PhotoLibrarySaveService()

    private init() {}

    func saveImageToLibrary(_ image: UIImage) async throws {
        let status = await requestAddOnlyAuthorizationIfNeeded()
        guard status == .authorized || status == .limited else {
            throw PhotoLibrarySaveError.permissionDenied
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges {
                PHAssetChangeRequest.creationRequestForAsset(from: image)
            } completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoLibrarySaveError.saveFailed)
                }
            }
        }
    }

    private func requestAddOnlyAuthorizationIfNeeded() async -> PHAuthorizationStatus {
        let current = PHPhotoLibrary.authorizationStatus(for: .addOnly)
        guard current == .notDetermined else { return current }
        return await PHPhotoLibrary.requestAuthorization(for: .addOnly)
    }
}
