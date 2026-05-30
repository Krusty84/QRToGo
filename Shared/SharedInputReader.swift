import Foundation
import UIKit
import UniformTypeIdentifiers

struct SharedInputCandidate: Identifiable, Hashable {
    enum Kind: String, Codable, CaseIterable, Identifiable {
        case webURL
        case telegramLink
        case remoteFileURL
        case text
        case localFileMetadata

        var id: String { rawValue }

        var titleKey: String {
            switch self {
            case .webURL: "candidate.kind.webURL"
            case .telegramLink: "candidate.kind.telegramLink"
            case .remoteFileURL: "candidate.kind.remoteFileURL"
            case .text: "candidate.kind.text"
            case .localFileMetadata: "candidate.kind.localFileMetadata"
            }
        }

        var sortPriority: Int {
            switch self {
            case .webURL: 0
            case .telegramLink: 1
            case .remoteFileURL: 2
            case .text: 3
            case .localFileMetadata: 4
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
            NSLocalizedString("error.noSupportedContent", comment: "No supported content")
        case .localFileImport:
            NSLocalizedString("error.localFileImport", comment: "Local file import failed")
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
        if let safariCandidates = try? await safariCandidates(from: provider) {
            let uniqueSafariCandidates = deduplicatedAndSorted(safariCandidates)
            if uniqueSafariCandidates.isEmpty == false {
                return uniqueSafariCandidates
            }
        }

        var parsedCandidates: [SharedInputCandidate] = []

        if let directURL = try? await loadURL(from: provider, typeIdentifier: UTType.url.identifier) {
            parsedCandidates.append(contentsOf: urlCandidates(from: directURL))
        }

        if let fileURL = try? await loadURL(from: provider, typeIdentifier: UTType.fileURL.identifier) {
            if fileURL.isFileURL, let localCandidate = try? await localFileCandidate(for: fileURL, typeIdentifier: UTType.fileURL.identifier) {
                parsedCandidates.append(localCandidate)
            } else {
                parsedCandidates.append(contentsOf: urlCandidates(from: fileURL))
            }
        }

        if let importedFileCandidate = try? await importedFileCandidate(from: provider) {
            parsedCandidates.append(importedFileCandidate)
        }

        if let plainText = try? await plainText(from: provider) {
            parsedCandidates.append(contentsOf: candidateList(fromText: plainText, sourceTitle: nil))
        }

        if let html = try? await htmlText(from: provider) {
            parsedCandidates.append(contentsOf: candidateList(fromHTML: html))
        }

        if parsedCandidates.isEmpty, let imageCandidate = try? await imageCandidate(from: provider) {
            parsedCandidates.append(imageCandidate)
        }

        return deduplicatedAndSorted(parsedCandidates)
    }

    private func safariCandidates(from provider: NSItemProvider) async throws -> [SharedInputCandidate] {
        guard provider.hasItemConformingToTypeIdentifier(UTType.propertyList.identifier) else {
            return []
        }

        let item = try await loadItem(from: provider, typeIdentifier: UTType.propertyList.identifier)
        let dictionary = unwrapDictionary(from: item)
        let resultsDictionary = unwrapDictionary(from: dictionary?["NSExtensionJavaScriptPreprocessingResultsKey"]) ?? dictionary

        guard let resultsDictionary else {
            return []
        }

        var candidates: [SharedInputCandidate] = []
        let pageURLString = stringValue(resultsDictionary["pageURL"]) ?? stringValue(resultsDictionary["URL"])
        let pageTitle = stringValue(resultsDictionary["pageTitle"]) ?? stringValue(resultsDictionary["title"])

        if let pageURLString, let pageURL = URL(string: pageURLString) {
            candidates.append(contentsOf: urlCandidates(from: pageURL, sourceTitle: pageTitle))
        }

        return candidates
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

    private func candidateList(fromText text: String, sourceTitle: String?) -> [SharedInputCandidate] {
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmedText.isEmpty == false else {
            return []
        }

        var candidates = extractedLinkStrings(from: trimmedText).compactMap { linkString -> SharedInputCandidate? in
            guard let url = URL(string: linkString) else {
                return nil
            }
            return urlCandidates(from: url).first
        }

        candidates.append(
            SharedInputCandidate(
                kind: .text,
                sourceTitle: sourceTitle,
                content: trimmedText,
                previewValue: trimmedText
            )
        )
        return candidates
    }

    private func candidateList(fromHTML html: String) -> [SharedInputCandidate] {
        var candidates: [SharedInputCandidate] = []
        let hrefPattern = #"href\s*=\s*"([^"]+)"|href\s*=\s*'([^']+)'"#
        if let regex = try? NSRegularExpression(pattern: hrefPattern, options: [.caseInsensitive]) {
            let range = NSRange(html.startIndex..<html.endIndex, in: html)
            regex.enumerateMatches(in: html, options: [], range: range) { match, _, _ in
                guard let match else { return }
                for index in 1..<match.numberOfRanges {
                    let matchRange = match.range(at: index)
                    guard matchRange.location != NSNotFound, let range = Range(matchRange, in: html) else { continue }
                    if let url = URL(string: String(html[range])) {
                        candidates.append(contentsOf: urlCandidates(from: url))
                    }
                }
            }
        }

        if let data = html.data(using: .utf8),
           let attributedText = try? NSAttributedString(
               data: data,
               options: [
                   .documentType: NSAttributedString.DocumentType.html,
                   .characterEncoding: String.Encoding.utf8.rawValue
               ],
               documentAttributes: nil
           )
        {
            candidates.append(contentsOf: candidateList(fromText: attributedText.string, sourceTitle: nil))
        } else {
            let strippedHTML = html.replacingOccurrences(of: "<[^>]+>", with: " ", options: .regularExpression)
            candidates.append(contentsOf: candidateList(fromText: strippedHTML, sourceTitle: nil))
        }

        return candidates
    }

    private func importedFileCandidate(from provider: NSItemProvider) async throws -> SharedInputCandidate? {
        for typeIdentifier in provider.registeredTypeIdentifiers where shouldTryFileRepresentation(for: typeIdentifier) {
            if let importedFile = try? await loadCopiedFile(from: provider, typeIdentifier: typeIdentifier) {
                return try makeLocalFileCandidate(for: importedFile.url, preferredTypeIdentifier: importedFile.typeIdentifier)
            }
        }
        return nil
    }

    private func imageCandidate(from provider: NSItemProvider) async throws -> SharedInputCandidate? {
        let preferredImageType = provider.registeredTypeIdentifiers.first { identifier in
            identifier == UTType.image.identifier
                || identifier.hasPrefix("public.image")
                || identifier.hasPrefix("public.png")
                || identifier.hasPrefix("public.jpeg")
        } ?? UTType.image.identifier

        guard provider.hasItemConformingToTypeIdentifier(preferredImageType) else {
            return nil
        }
        let data = try await loadDataRepresentation(from: provider, typeIdentifier: preferredImageType)
        guard let image = UIImage(data: data), let pngData = image.pngData() else {
            return nil
        }
        let importID = UUID().uuidString
        let directoryURL = try AppGroupConfiguration.importedFilesDirectoryURL()
        let destinationURL = directoryURL.appending(path: "\(importID).png")
        try pngData.write(to: destinationURL, options: .atomic)
        return try makeLocalFileCandidate(for: destinationURL, preferredTypeIdentifier: UTType.png.identifier)
    }

    private func localFileCandidate(for url: URL, typeIdentifier: String) async throws -> SharedInputCandidate {
        let directoryURL = try AppGroupConfiguration.importedFilesDirectoryURL()
        let importedURL = directoryURL.appending(path: "\(UUID().uuidString)-\(url.lastPathComponent)")
        if FileManager.default.fileExists(atPath: importedURL.path) {
            try FileManager.default.removeItem(at: importedURL)
        }
        try FileManager.default.copyItem(at: url, to: importedURL)
        return try makeLocalFileCandidate(for: importedURL, preferredTypeIdentifier: typeIdentifier)
    }

    private func makeLocalFileCandidate(for url: URL, preferredTypeIdentifier: String) throws -> SharedInputCandidate {
        let values = try url.resourceValues(forKeys: [.fileSizeKey, .contentTypeKey])
        let contentType = values.contentType?.identifier
            ?? UTType(filenameExtension: url.pathExtension)?.identifier
            ?? preferredTypeIdentifier

        let payload = LocalFilePayload(
            type: "local-file",
            fileName: url.lastPathComponent,
            contentType: contentType,
            size: Int64(values.fileSize ?? 0),
            importId: url.deletingPathExtension().lastPathComponent
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        let content = try String(decoding: encoder.encode(payload), as: UTF8.self)
        return SharedInputCandidate(
            kind: .localFileMetadata,
            sourceTitle: nil,
            content: content,
            previewValue: url.lastPathComponent
        )
    }

    private func plainText(from provider: NSItemProvider) async throws -> String? {
        for type in [UTType.plainText.identifier, UTType.text.identifier] {
            guard provider.hasItemConformingToTypeIdentifier(type) else { continue }
            let item = try await loadItem(from: provider, typeIdentifier: type)
            if let string = stringValue(item) {
                return string
            }
            if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
                return string
            }
        }
        return nil
    }

    private func htmlText(from provider: NSItemProvider) async throws -> String? {
        guard provider.hasItemConformingToTypeIdentifier(UTType.html.identifier) else {
            return nil
        }
        let item = try await loadItem(from: provider, typeIdentifier: UTType.html.identifier)
        if let string = stringValue(item) {
            return string
        }
        if let data = item as? Data, let string = String(data: data, encoding: .utf8) {
            return string
        }
        return nil
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

    private func shouldTryFileRepresentation(for typeIdentifier: String) -> Bool {
        let excludedTypes: Set<String> = [
            UTType.url.identifier,
            UTType.fileURL.identifier,
            UTType.text.identifier,
            UTType.plainText.identifier,
            UTType.html.identifier,
            UTType.propertyList.identifier
        ]
        return excludedTypes.contains(typeIdentifier) == false
    }

    private func extractedLinkStrings(from text: String) -> [String] {
        var links: [String] = []

        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(text.startIndex..<text.endIndex, in: text)
            detector.enumerateMatches(in: text, options: [], range: range) { result, _, _ in
                if let value = result?.url?.absoluteString {
                    links.append(value)
                }
            }
        }

        for pattern in [telegramSchemePattern, telegramHostPattern] {
            if let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) {
                let range = NSRange(text.startIndex..<text.endIndex, in: text)
                regex.enumerateMatches(in: text, options: [], range: range) { match, _, _ in
                    guard let match, let range = Range(match.range, in: text) else { return }
                    var value = String(text[range])
                    if value.hasPrefix("t.me") || value.hasPrefix("telegram.me") || value.contains(".t.me/") {
                        value = "https://" + value
                    }
                    links.append(value)
                }
            }
        }

        return Array(Set(links))
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

    private func unwrapDictionary(from value: Any?) -> [String: Any]? {
        if let dictionary = value as? [String: Any] {
            return dictionary
        }
        if let dictionary = value as? NSDictionary {
            var result: [String: Any] = [:]
            dictionary.forEach { key, value in
                if let key = key as? String {
                    result[key] = value
                }
            }
            return result
        }
        return nil
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

    private let telegramSchemePattern = #"tg://[^\s<>"']+"#
    private let telegramHostPattern = #"(?:https?://)?(?:(?:[A-Za-z0-9_]+\.)?t\.me|telegram\.me)/[A-Za-z0-9_/?=&.%+-]+"#
}

private struct LocalFilePayload: Codable {
    let type: String
    let fileName: String
    let contentType: String
    let size: Int64
    let importId: String
}

private struct ImportedFile {
    let url: URL
    let typeIdentifier: String
}
