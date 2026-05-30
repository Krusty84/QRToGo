//
//  ShareRootView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ShareRootView: View {
    var viewModel: ShareViewModel

    var body: some View {
        @Bindable var viewModel = viewModel

        VStack(alignment: .leading, spacing: 16) {
            Text("share.title")
                .font(.headline)

            if viewModel.isLoading {
                Spacer()
                HStack {
                    Spacer()
                    ProgressView("share.loading")
                        .progressViewStyle(.circular)
                    Spacer()
                }
                Spacer()
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        if viewModel.candidates.count > 1 {
                            Picker("share.candidatePicker", selection: candidateSelection) {
                                ForEach(viewModel.candidates) { candidate in
                                    Text(verbatim: candidate.sourceTitle ?? candidate.previewValue)
                                        .tag(candidate.id)
                                }
                            }
                            .pickerStyle(.menu)
                        }

                        if let candidate = viewModel.selectedCandidate {
                            VStack(alignment: .leading, spacing: 8) {
                                Label {
                                    Text(LocalizedStringKey(candidate.kind.titleKey))
                                } icon: {
                                    Image(systemName: systemImage(for: candidate.kind))
                                }
                                .font(.caption)
                                .foregroundStyle(.secondary)

                                if let sourceTitle = candidate.sourceTitle {
                                    Text(verbatim: sourceTitle)
                                        .font(.headline)
                                }

                                Text(verbatim: candidate.previewValue)
                                    .font(.subheadline)
                                    .lineLimit(3)
                                    .truncationMode(.middle)

                                if candidate.kind == .localFileMetadata {
                                    Text("share.localMetadataNotice")
                                        .font(.footnote)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("share.preview")
                                .font(.headline)

                            QRPreviewView(
                                image: viewModel.previewImage,
                                isLoading: viewModel.isGeneratingPreview,
                                errorMessage: viewModel.previewErrorMessage
                            )
                        }

                        if viewModel.validationResults.isEmpty == false {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(viewModel.validationResults) { result in
                                    Label {
                                        Text(LocalizedStringKey(result.messageKey))
                                    } icon: {
                                        Image(systemName: result.severity == .error ? "exclamationmark.triangle.fill" : "exclamationmark.circle")
                                            .foregroundStyle(result.severity == .error ? .orange : .yellow)
                                    }
                                    .font(.subheadline)
                                }
                            }
                        }

                        if let statusMessage = viewModel.statusMessage {
                            Text(verbatim: statusMessage)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button("share.cancel", role: .cancel) {
                        viewModel.cancelRequest()
                    }
                    .buttonStyle(.bordered)

                    Button {
                        Task {
                            await viewModel.saveToPhotos()
                        }
                    } label: {
                        if viewModel.isSaving {
                            ProgressView()
                        } else {
                            Text("share.save")
                        }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(viewModel.isSaving || viewModel.previewImage == nil)

                    Button("share.done") {
                        viewModel.completeRequest()
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(uiColor: .systemBackground))
        .task {
            await viewModel.loadIfNeeded()
        }
    }

    private var candidateSelection: Binding<String> {
        Binding(
            get: { viewModel.selectedCandidateID ?? "" },
            set: { newValue in
                Task {
                    await viewModel.updateSelectedCandidate(id: newValue)
                }
            }
        )
    }

    private func systemImage(for kind: SharedInputCandidate.Kind) -> String {
        switch kind {
        case .webURL:
            "globe"
        case .telegramLink:
            "paperplane"
        case .remoteFileURL:
            "link"
        case .text:
            "text.alignleft"
        case .localFileMetadata:
            "doc.text"
        }
    }
}

#Preview {
    ShareRootView(viewModel: ShareViewModel(extensionContext: nil))
}
