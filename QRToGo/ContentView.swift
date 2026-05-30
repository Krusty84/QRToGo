//
//  ContetView.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI

struct ContentView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var viewModel = SettingsViewModel()

    var body: some View {
        TabView {
            GenerateView(viewModel: viewModel)
                .tabItem {
                    Label("tab.generate", systemImage: "qrcode.viewfinder")
                }

            SettingsView(viewModel: viewModel)
                .tabItem {
                    Label("tab.settings", systemImage: "gearshape")
                }

            AboutView()
                .tabItem {
                    Label("tab.about", systemImage: "info.circle")
                }
        }
        .task {
            viewModel.loadIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else {
                return
            }
            viewModel.refreshSampleTextFromPasteboardIfNeeded()
        }
        .onChange(of: viewModel.sampleText) { _, _ in
            viewModel.refreshPreview()
        }
        .onChange(of: viewModel.draftSettings) { _, _ in
            viewModel.refreshPreview()
        }
    }
}

private struct GenerateView: View {
    @Bindable var viewModel: SettingsViewModel
    @FocusState private var isSampleTextFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("settings.section.preview") {
                    TextField("settings.sampleText", text: $viewModel.sampleText, axis: .vertical)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.done)
                        .focused($isSampleTextFocused)

                    QRPreviewView(
                        image: viewModel.previewImage,
                        isLoading: viewModel.isGeneratingPreview,
                        errorMessage: viewModel.previewErrorMessage
                    )

                    VStack(alignment: .leading, spacing: 10) {
                        Label("settings.scannability", systemImage: "checkmark.shield")
                            .font(.headline)

                        if viewModel.validationResults.isEmpty {
                            Text("settings.scannability.safe")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
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

                    Button {
                        Task {
                            await viewModel.savePreviewToPhotos()
                        }
                    } label: {
                        if viewModel.isSavingPreview {
                            ProgressView()
                        } else {
                            Label("settings.savePreview", systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(viewModel.isSavingPreview || viewModel.isGeneratingPreview || viewModel.hasBlockingValidation)
                }

                if let statusMessage = viewModel.statusMessage {
                    Section {
                        Text(verbatim: statusMessage)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("tab.generate")
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("share.done") {
                        isSampleTextFocused = false
                    }
                }
            }
        }
    }
}

private struct AboutView: View {
    var body: some View {
        NavigationStack {
            Color.clear
                .navigationTitle("tab.about")
        }
    }
}

#Preview {
    ContentView()
}
