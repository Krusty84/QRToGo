//
//  PhotoAlbumSaver.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Foundation
import Photos

enum PhotoAlbumSaverError: LocalizedError {
    case permissionDenied
    case albumUnavailable
    case saveFailed

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            NSLocalizedString("error.photoPermissionDenied", comment: "Photos permission denied")
        case .albumUnavailable:
            NSLocalizedString("error.photoAlbum", comment: "Album unavailable")
        case .saveFailed:
            NSLocalizedString("error.photoSave", comment: "Photo save failed")
        }
    }
}

struct PhotoAlbumSaver {
    func savePNGData(_ data: Data, albumName: String) async throws {
        let albumName = resolvedAlbumName(from: albumName)
        let status = await requestAuthorizationStatus()
        guard status == .authorized || status == .limited else {
            throw PhotoAlbumSaverError.permissionDenied
        }

        let albumIdentifier = try await findOrCreateAlbumIdentifier(named: albumName)
        let assetIdentifier = try await createAssetIdentifier(with: data)
        try await addAsset(identifier: assetIdentifier, toAlbumIdentifier: albumIdentifier)
    }

    private func requestAuthorizationStatus() async -> PHAuthorizationStatus {
        await withCheckedContinuation { continuation in
            PHPhotoLibrary.requestAuthorization(for: .addOnly) { status in
                continuation.resume(returning: status)
            }
        }
    }

    private func findOrCreateAlbumIdentifier(named albumName: String) async throws -> String {
        if let existingAlbum = fetchAlbum(named: albumName) {
            return existingAlbum.localIdentifier
        }
        return try await withCheckedThrowingContinuation { continuation in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest.creationRequestForAssetCollection(withTitle: albumName)
                placeholder = request.placeholderForCreatedAssetCollection
            }, completionHandler: { success, error in
                if success, let identifier = placeholder?.localIdentifier {
                    continuation.resume(returning: identifier)
                } else {
                    continuation.resume(throwing: error ?? PhotoAlbumSaverError.albumUnavailable)
                }
            })
        }
    }

    private func createAssetIdentifier(with data: Data) async throws -> String {
        try await withCheckedThrowingContinuation { continuation in
            var placeholder: PHObjectPlaceholder?
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
                placeholder = request.placeholderForCreatedAsset
            }, completionHandler: { success, error in
                if success, let identifier = placeholder?.localIdentifier {
                    continuation.resume(returning: identifier)
                } else {
                    continuation.resume(throwing: error ?? PhotoAlbumSaverError.saveFailed)
                }
            })
        }
    }

    private func addAsset(identifier: String, toAlbumIdentifier albumIdentifier: String) async throws {
        let assets = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
        let albums = PHAssetCollection.fetchAssetCollections(withLocalIdentifiers: [albumIdentifier], options: nil)
        guard let album = albums.firstObject, assets.firstObject != nil else {
            throw PhotoAlbumSaverError.albumUnavailable
        }

        try await withCheckedThrowingContinuation { continuation in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCollectionChangeRequest(for: album)
                request?.addAssets(assets)
            }, completionHandler: { success, error in
                if success {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: error ?? PhotoAlbumSaverError.saveFailed)
                }
            })
        }
    }

    private func fetchAlbum(named albumName: String) -> PHAssetCollection? {
        let options = PHFetchOptions()
        options.predicate = NSPredicate(format: "title = %@", albumName)
        let collections = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .albumRegular, options: options)
        return collections.firstObject
    }

    private func resolvedAlbumName(from albumName: String) -> String {
        let trimmedName = albumName.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedName.isEmpty ? QRCodeSettings.defaultPhotoAlbumName : trimmedName
    }
}
