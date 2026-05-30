//
//  GenerateView.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

struct GenerateView: View {
    @Bindable var viewModel: SettingsViewModel
    @State private var isFileImporterPresented = false
    @State private var isContactPickerPresented = false
    @State private var selectedMediaItem: PhotosPickerItem?
    @FocusState private var focusedField: FocusedField?

    var body: some View {
        NavigationStack {
            Form {
                Section("generate.section.type") {
                    Picker("generate.contentType", selection: contentKindBinding) {
                        ForEach(GenerateContentKind.allCases) { kind in
                            Text(LocalizedStringKey(kind.titleKey)).tag(kind)
                        }
                    }
                }

                Section("generate.section.content") {
                    contentEditor
                }

                Section("settings.section.preview") {
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
                        focusedField = nil
                    }
                }
            }
        }
        .fileImporter(
            isPresented: $isFileImporterPresented,
            allowedContentTypes: [.item],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case let .success(urls):
                guard let url = urls.first else {
                    return
                }
                viewModel.importSelectedFile(at: url)
            case .failure:
                viewModel.statusMessage = NSLocalizedString("error.localFileImport", comment: "Local file import failed")
            }
        }
        .sheet(isPresented: $isContactPickerPresented) {
            ContactPickerView(
                onSelect: { contact in
                    viewModel.setSelectedContact(contact)
                    isContactPickerPresented = false
                },
                onCancel: {
                    isContactPickerPresented = false
                }
            )
        }
        .onChange(of: selectedMediaItem) { _, newItem in
            guard let newItem else {
                return
            }
            Task {
                await importMediaItem(newItem)
            }
        }
    }

    private var contentKindBinding: Binding<GenerateContentKind> {
        Binding(
            get: {
                viewModel.contentDraft.kind
            },
            set: { newValue in
                viewModel.setContentKind(newValue)
            }
        )
    }

    @ViewBuilder
    private var contentEditor: some View {
        switch viewModel.contentDraft.kind {
        case .website:
            placeholderCard("generate.websiteUnavailable", systemImage: "globe.badge.chevron.backward")
        case .localFile:
            localFileEditor
        case .contact:
            contactEditor
        case .wifi:
            wifiEditor
        case .text:
            textEditor
        case .clipboard:
            clipboardEditor
        case .email:
            emailEditor
        case .sms:
            smsEditor
        case .call:
            callEditor
        case .event:
            eventEditor
        case .location:
            locationEditor
        }
    }

    private var localFileEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("generate.filePicker", systemImage: "folder") {
                isFileImporterPresented = true
            }

            PhotosPicker(selection: $selectedMediaItem, matching: .any(of: [.images, .videos])) {
                Label("generate.mediaPicker", systemImage: "photo.stack")
            }

            if let localContent = viewModel.contentDraft.localContent {
                LabeledContent("generate.localFileName", value: localContent.fileName)
                LabeledContent("generate.localFileType", value: localContent.contentType)
                LabeledContent(
                    "generate.localFileSize",
                    value: ByteCountFormatter.string(fromByteCount: localContent.size, countStyle: .file)
                )
                Text("share.localMetadataNotice")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("generate.localFileRemove", role: .destructive) {
                    viewModel.removeSelectedLocalContent()
                }
            } else {
                placeholderCard("generate.localFilePlaceholder", systemImage: "doc.badge.plus")
            }
        }
    }

    private var contactEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("generate.contactPick", systemImage: "person.crop.circle.badge.plus") {
                isContactPickerPresented = true
            }

            if let contact = viewModel.contentDraft.contact {
                Label(contact.displayName, systemImage: "person.crop.circle")
                    .font(.headline)

                Button("generate.contactRemove", role: .destructive) {
                    viewModel.removeSelectedContact()
                }
            } else {
                placeholderCard("generate.contactPlaceholder", systemImage: "person.text.rectangle")
            }
        }
    }

    private var wifiEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.wifiSSID", text: $viewModel.contentDraft.wifiSSID)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .focused($focusedField, equals: .wifiSSID)

            Picker("generate.wifiSecurity", selection: $viewModel.contentDraft.wifiSecurity) {
                ForEach(GenerateWiFiSecurity.allCases) { security in
                    Text(LocalizedStringKey(security.titleKey)).tag(security)
                }
            }

            if viewModel.contentDraft.wifiSecurity != .none {
                SecureField("generate.wifiPassword", text: $viewModel.contentDraft.wifiPassword)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .focused($focusedField, equals: .wifiPassword)
            }

            Toggle("generate.wifiHidden", isOn: $viewModel.contentDraft.wifiIsHidden)
        }
    }

    private var textEditor: some View {
        TextField("settings.sampleText", text: $viewModel.sampleText, axis: .vertical)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .submitLabel(.done)
            .focused($focusedField, equals: .text)
    }

    private var clipboardEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("generate.clipboardReload", systemImage: "doc.on.clipboard") {
                viewModel.reloadClipboardContent()
            }

            if viewModel.contentDraft.clipboardText.isEmpty {
                placeholderCard("generate.clipboardPlaceholder", systemImage: "doc.on.clipboard")
            } else {
                Text(viewModel.contentDraft.clipboardText)
                    .font(.body)
                    .textSelection(.enabled)
                    .lineLimit(6)
            }
        }
    }

    private var emailEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.emailRecipient", text: $viewModel.contentDraft.emailTo)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.emailAddress)
                .focused($focusedField, equals: .emailRecipient)

            TextField("generate.emailSubject", text: $viewModel.contentDraft.emailSubject, axis: .vertical)
                .focused($focusedField, equals: .emailSubject)

            TextField("generate.emailBody", text: $viewModel.contentDraft.emailBody, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .emailBody)
        }
    }

    private var smsEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.smsNumber", text: $viewModel.contentDraft.smsNumber)
                .keyboardType(.phonePad)
                .focused($focusedField, equals: .smsNumber)

            TextField("generate.smsMessage", text: $viewModel.contentDraft.smsBody, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .smsBody)
        }
    }

    private var callEditor: some View {
        TextField("generate.callNumber", text: $viewModel.contentDraft.callNumber)
            .keyboardType(.phonePad)
            .focused($focusedField, equals: .callNumber)
    }

    private var eventEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.eventTitle", text: $viewModel.contentDraft.eventTitle)
                .focused($focusedField, equals: .eventTitle)

            TextField("generate.eventLocation", text: $viewModel.contentDraft.eventLocation)
                .focused($focusedField, equals: .eventLocation)

            TextField("generate.eventNotes", text: $viewModel.contentDraft.eventNotes, axis: .vertical)
                .lineLimit(4, reservesSpace: true)
                .focused($focusedField, equals: .eventNotes)

            DatePicker("generate.eventStart", selection: $viewModel.contentDraft.eventStartDate)
            DatePicker("generate.eventEnd", selection: $viewModel.contentDraft.eventEndDate)
        }
    }

    private var locationEditor: some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("generate.locationLatitude", text: $viewModel.contentDraft.locationLatitude)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .locationLatitude)

            TextField("generate.locationLongitude", text: $viewModel.contentDraft.locationLongitude)
                .keyboardType(.decimalPad)
                .focused($focusedField, equals: .locationLongitude)

            TextField("generate.locationLabel", text: $viewModel.contentDraft.locationLabel)
                .focused($focusedField, equals: .locationLabel)
        }
    }

    private func placeholderCard(_ titleKey: LocalizedStringKey, systemImage: String) -> some View {
        VStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.title2)
                .foregroundStyle(.secondary)

            Text(titleKey)
                .multilineTextAlignment(.center)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .background(Color(uiColor: .secondarySystemBackground), in: .rect(cornerRadius: 18))
    }

    @MainActor
    private func importMediaItem(_ item: PhotosPickerItem) async {
        do {
            guard let importedFile = try await item.loadTransferable(type: PickedMediaFile.self) else {
                return
            }
            viewModel.importSelectedMediaFile(
                at: importedFile.url,
                preferredTypeIdentifier: item.supportedContentTypes.first?.identifier
            )
        } catch {
            viewModel.statusMessage = error.localizedDescription
        }

        selectedMediaItem = nil
    }
}

private enum FocusedField: Hashable {
    case text
    case wifiSSID
    case wifiPassword
    case emailRecipient
    case emailSubject
    case emailBody
    case smsNumber
    case smsBody
    case callNumber
    case eventTitle
    case eventLocation
    case eventNotes
    case locationLatitude
    case locationLongitude
    case locationLabel
}

#Preview {
    GenerateView(viewModel: SettingsViewModel())
}
