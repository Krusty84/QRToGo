//
//  SharedInputReader.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import Foundation
import UniformTypeIdentifiers

struct SharedInputCandidate: Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case webURL
        case telegramLink
        case remoteFileURL
        case contact

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .webURL: "candidate.kind.webURL"
            case .telegramLink: "candidate.kind.telegramLink"
            case .remoteFileURL: "candidate.kind.remoteFileURL"
            case .contact: "candidate.kind.contact"
            }
        }

        var sortPriority: Int {
            switch self {
            case .webURL: 0
            case .telegramLink: 1
            case .remoteFileURL: 2
            case .contact: 3
            }
        }
    }

    let kind: Kind
    let sourceTitle: String?
    let content: String
    let previewValue: String

    var id: String {
        "\(kind.rawValue)|\(content)"
    }
}

enum SharedInputReaderError: LocalizedError {
    case noSupportedContent
    case localFileImport

    var errorDescription: String? {
        switch self {
        case .noSupportedContent:
            AppLocalization.string("error.noSupportedContent")
        case .localFileImport:
            AppLocalization.string("error.localFileImport")
        }
    }
}

struct SharedInputReader {
    func readCandidates(from extensionContext: NSExtensionContext?) async throws -> [SharedInputCandidate] {
        guard let extensionContext else {
            throw SharedInputReaderError.noSupportedContent
        }

        let items = extensionContext.inputItems.compactMap { $0 as? NSExtensionItem }
        let providers = items.flatMap { $0.attachments ?? [] }
        guard providers.isEmpty == false else {
            throw SharedInputReaderError.noSupportedContent
        }

        var candidates: [SharedInputCandidate] = []
        for provider in providers {
            candidates.append(contentsOf: await readCandidates(from: provider))
        }

        let uniqueCandidates = deduplicatedAndSorted(candidates)
        guard uniqueCandidates.isEmpty == false else {
            throw SharedInputReaderError.noSupportedContent
        }
        return uniqueCandidates
    }

    private func readCandidates(from provider: NSItemProvider) async -> [SharedInputCandidate] {
        if let vCardCandidate = try? await vCardCandidate(from: provider) {
            return [vCardCandidate]
        }

        var parsedCandidates: [SharedInputCandidate] = []

        if let directURL = try? await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
            parsedCandidates.append(contentsOf: urlCandidates(from: directURL))
        }

        if let fileURL = try? await loadURL(from: provider, typeIdentifier: UTType.fileURL.identifier) {
            if fileURL.isFileURL {
                if let contactCandidate = try? await contactCandidate(for: fileURL, preferredTypeIdentifier: UTType.vCard.identifier) {
                    return [contactCandidate]
                }
            } else {
                parsedCandidates.append(contentsOf: urlCandidates(from: fileURL))
            }
        }

        if let importedVCardCandidate = try? await importedVCardCandidate(from: provider) {
            return [importedVCardCandidate]
        }

        return deduplicatedAndSorted(parsedCandidates)
    }

    private func vCardCandidate(from provider: NSItemProvider) async throws -> SharedInputCandidate? {
        let identifiers = provider.registeredTypeIdentifiers.filter(isVCardTypeIdentifier)
        for typeIdentifier in identifiers {
            if let candidate = try? await vCardCandidate(from: provider, typeIdentifier: typeIdentifier) {
                return candidate
            }
        }
        if identifiers.isEmpty, provider.hasItemConformingToTypeIdentifier(UTType.vCard.identifier) {
            return try await vCardCandidate(from: provider, typeIdentifier: UTType.vCard.identifier)
        }
        return nil
    }

    private func urlCandidates(from url: URL, sourceTitle: String? = nil) -> [SharedInputCandidate] {
        guard let absoluteString = sanitizedURLString(url) else {
            return []
        }
        if isTelegramURL(absoluteString) {
            return [
                SharedInputCandidate(
                    kind: .telegramLink,
                    sourceTitle: sourceTitle,
                    content: absoluteString,
                    previewValue: absoluteString
                )
            ]
        }
        if isRemoteFileURL(url) {
            return [
                SharedInputCandidate(
                    kind: .remoteFileURL,
                    sourceTitle: sourceTitle,
                    content: absoluteString,
                    previewValue: absoluteString
                )
            ]
        }
        if url.isFileURL {
            return []
        }
        return [
            SharedInputCandidate(
                kind: .webURL,
                sourceTitle: sourceTitle,
                content: absoluteString,
                previewValue: absoluteString
            )
        ]
    }

    private func importedVCardCandidate(from provider: NSItemProvider) async throws -> SharedInputCandidate? {
        for typeIdentifier in provider.registeredTypeIdentifiers where isVCardTypeIdentifier(typeIdentifier) {
            if let importedFile = try? await loadCopiedFile(from: provider, typeIdentifier: typeIdentifier) {
                return try contactCandidate(for: importedFile.url, preferredTypeIdentifier: importedFile.typeIdentifier)
            }
        }
        return nil
    }

    private func vCardCandidate(from provider: NSItemProvider, typeIdentifier: String) async throws -> SharedInputCandidate? {
        if let data = try? await loadDataRepresentation(from: provider, typeIdentifier: typeIdentifier) {
            return try makeContactCandidate(from: data)
        }

        let item = try await loadItem(from: provider, typeIdentifier: typeIdentifier)
        if let url = item as? URL, url.isFileURL {
            return try contactCandidate(for: url, preferredTypeIdentifier: typeIdentifier)
        }
        if let nsURL = item as? NSURL, let url = nsURL as URL?, url.isFileURL {
            return try contactCandidate(for: url, preferredTypeIdentifier: typeIdentifier)
        }
        if let data = item as? Data {
            return try makeContactCandidate(from: data)
        }
        if let string = stringValue(item), let data = string.data(using: .utf8) {
            return try makeContactCandidate(from: data)
        }
        return nil
    }

    private func contactCandidate(for url: URL, preferredTypeIdentifier: String) throws -> SharedInputCandidate? {
        let values = try url.resourceValues(forKeys: [.contentTypeKey])
        let contentType = values.contentType?.identifier
            ?? UTType(filenameExtension: url.pathExtension)?.identifier
            ?? preferredTypeIdentifier

        guard isVCardTypeIdentifier(contentType) || url.pathExtension.lowercased() == "vcf" else {
            return nil
        }

        let data = try Data(contentsOf: url)
        return try makeContactCandidate(from: data)
    }

    private func makeContactCandidate(from data: Data) throws -> SharedInputCandidate? {
        #if DEBUG
        ContactQRPayloadDiagnostics.logVCardData(
            data,
            source: "ShareExtension.incomingVCard"
        )
        #endif

        let payload = try ContactVCardPayloadBuilder.makePayload(
            fromVCardData: data,
            fallbackNameKey: "share.contactFallback"
        )

        #if DEBUG
        ContactQRPayloadDiagnostics.logVCardText(
            payload.content,
            source: "ShareExtension.normalizedVCard"
        )
        #endif

        return SharedInputCandidate(
            kind: .contact,
            sourceTitle: payload.displayName,
            content: payload.content,
            previewValue: payload.previewValue
        )
    }
    
    private func loadURL(from provider: NSItemProvider, typeIdentifier: String) async throws -> URL? {
        guard provider.hasItemConformingToTypeIdentifier(typeIdentifier) else {
            return nil
        }
        let item = try await loadItem(from: provider, typeIdentifier: typeIdentifier)
        if let url = item as? URL {
            return url
        }
        if let nsURL = item as? NSURL {
            return nsURL as URL
        }
        if let data = item as? Data,
           let string = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
        {
            return URL(string: string)
        }
        if let string = stringValue(item) {
            return URL(string: string)
        }
        return nil
    }

    private func loadItem(from provider: NSItemProvider, typeIdentifier: String) async throws -> Any? {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: typeIdentifier, options: nil) { item, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: item)
                }
            }
        }
    }

    private func loadCopiedFile(from provider: NSItemProvider, typeIdentifier: String) async throws -> ImportedFile {
        try await withCheckedThrowingContinuation { continuation in
            // File representations from share extensions are temporary. Copy them before the completion returns.
            provider.loadFileRepresentation(forTypeIdentifier: typeIdentifier) { temporaryURL, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let temporaryURL else {
                    continuation.resume(throwing: SharedInputReaderError.localFileImport)
                    return
                }

                do {
                    let directoryURL = try AppGroupConfiguration.importedFilesDirectoryURL()
                    let destinationURL = directoryURL.appending(path: "\(UUID().uuidString)-\(temporaryURL.lastPathComponent)")
                    if FileManager.default.fileExists(atPath: destinationURL.path) {
                        try FileManager.default.removeItem(at: destinationURL)
                    }
                    try FileManager.default.copyItem(at: temporaryURL, to: destinationURL)
                    continuation.resume(returning: ImportedFile(url: destinationURL, typeIdentifier: typeIdentifier))
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    private func loadDataRepresentation(from provider: NSItemProvider, typeIdentifier: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: typeIdentifier) { data, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: SharedInputReaderError.localFileImport)
                }
            }
        }
    }

    private func isTelegramURL(_ value: String) -> Bool {
        guard let url = URL(string: value) else {
            return false
        }
        if url.scheme?.lowercased() == "tg" {
            return true
        }
        guard let host = url.host?.lowercased() else {
            return false
        }
        return host == "t.me" || host == "telegram.me" || host.hasSuffix(".t.me")
    }

    private func isRemoteFileURL(_ url: URL) -> Bool {
        guard url.isFileURL == false, let scheme = url.scheme?.lowercased(), scheme == "http" || scheme == "https" else {
            return false
        }
        let fileExtensions: Set<String> = [
            "7z", "apk", "csv", "doc", "docx", "dmg", "gif", "gz", "heic", "jpeg",
            "jpg", "json", "mov", "mp3", "mp4", "pdf", "pkg", "png", "ppt", "pptx",
            "rar", "svg", "tar", "txt", "webp", "xls", "xlsx", "xml", "zip"
        ]
        return fileExtensions.contains(url.pathExtension.lowercased())
    }

    private func sanitizedURLString(_ url: URL) -> String? {
        let absoluteString = url.absoluteString.trimmingCharacters(in: .whitespacesAndNewlines)
        return absoluteString.isEmpty ? nil : absoluteString
    }

    private func deduplicatedAndSorted(_ candidates: [SharedInputCandidate]) -> [SharedInputCandidate] {
        let unique = Dictionary(grouping: candidates, by: \.id).compactMap { $0.value.first }
        return unique.sorted { lhs, rhs in
            if lhs.kind.sortPriority == rhs.kind.sortPriority {
                return lhs.previewValue < rhs.previewValue
            }
            return lhs.kind.sortPriority < rhs.kind.sortPriority
        }
    }

    private func stringValue(_ value: Any?) -> String? {
        if let string = value as? String {
            return string
        }
        if let string = value as? NSString {
            return string as String
        }
        return nil
    }

    private func isVCardTypeIdentifier(_ typeIdentifier: String) -> Bool {
        if typeIdentifier == UTType.vCard.identifier {
            return true
        }
        if let contentType = UTType(typeIdentifier) {
            return contentType.conforms(to: .vCard)
        }
        return typeIdentifier.localizedCaseInsensitiveContains("vcard")
    }

}

private struct ImportedFile {
    let url: URL
    let typeIdentifier: String
}
