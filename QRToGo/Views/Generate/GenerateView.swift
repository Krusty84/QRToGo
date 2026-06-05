//
//  GenerateView.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import SwiftUI

struct GenerateView: View {
    @Bindable var viewModel: GenerateViewModel
    let settingsViewModel: SettingsViewModel
    let favoritesViewModel: FavoritesViewModel
    @State private var isContactPickerPresented = false
    @State private var isFavoriteSheetPresented = false
    @FocusState private var focusedField: FocusedField?

    private let modeColumns = [
        GridItem(.adaptive(minimum: 60, maximum: 72), spacing: 8)
    ]

    var body: some View {
        NavigationStack {
            Form {
                Section("generate.section.type") {
                    LazyVGrid(columns: modeColumns, spacing: 8) {
                        ForEach(GenerateContentKind.allCases) { kind in
                            Button {
                                viewModel.setContentKind(kind)
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: kind.systemImage)
                                        .font(.body.weight(.semibold))
                                    Text(LocalizedStringKey(kind.titleKey))
                                        .font(.caption2.weight(.medium))
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .minimumScaleFactor(0.75)
                                }
                                .frame(maxWidth: .infinity, minHeight: 58)
                                .padding(.horizontal, 4)
                                .foregroundStyle(viewModel.contentDraft.kind == kind ? .white : .primary)
                                .background(
                                    viewModel.contentDraft.kind == kind
                                        ? Color.accentColor
                                        : Color(uiColor: .secondarySystemBackground),
                                    in: .rect(cornerRadius: 14)
                                )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                Section("generate.section.content") {
                    contentEditor

                    VStack(alignment: .leading, spacing: 8) {
                        TextField("generate.exportPurpose", text: $viewModel.exportPurposeDraft, axis: .vertical)
                            .lineLimit(3, reservesSpace: true)

                        Text("generate.exportPurposeFooter")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
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

                        if settingsViewModel.validationResults.isEmpty {
                            Text("settings.scannability.safe")
                                .font(.subheadline)
                                .foregroundStyle(.green)
                        } else {
                            ForEach(settingsViewModel.validationResults) { result in
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
                            await viewModel.savePreviewToPhotos(using: settingsViewModel.draftSettings)
                        }
                    } label: {
                        if viewModel.isSavingPreview {
                            ProgressView()
                        } else {
                            Label("settings.savePreview", systemImage: "photo.badge.plus")
                        }
                    }
                    .disabled(
                        viewModel.isSavingPreview
                            || viewModel.isGeneratingPreview
                            || settingsViewModel.hasBlockingValidation
                    )

                    Button {
                        isFavoriteSheetPresented = true
                    } label: {
                        Label("favorites.add.button", systemImage: "text.badge.star")
                    }
                    .disabled(isAddToFavoriteDisabled)
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
        .sheet(isPresented: $isFavoriteSheetPresented) {
            AddFavoriteSheet { name in
                addFavorite(named: name)
            }
        }
    }

    @ViewBuilder
    private var contentEditor: some View {
        switch viewModel.contentDraft.kind {
        case .website:
            websiteEditor
        case .contact:
            contactEditor
        case .wifi:
            wifiEditor
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

    private var websiteEditor: some View {
        TextField("generate.websiteURL", text: $viewModel.contentDraft.websiteURL)
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .keyboardType(.URL)
            .textContentType(.URL)
            .focused($focusedField, equals: .websiteURL)
    }

    private var wifiSecurityBinding: Binding<GenerateWiFiSecurity> {
        Binding(
            get: {
                viewModel.contentDraft.wifiSecurity
            },
            set: { newValue in
                viewModel.setWiFiSecurity(newValue)
            }
        )
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

            Picker("generate.wifiSecurity", selection: wifiSecurityBinding) {
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

    private var isAddToFavoriteDisabled: Bool {
        viewModel.isGeneratingPreview
            || settingsViewModel.hasBlockingValidation
            || viewModel.canMakeFavoriteQRCode(using: settingsViewModel.draftSettings) == false
    }

    private func addFavorite(named name: String) {
        guard settingsViewModel.hasBlockingValidation == false else {
            viewModel.statusMessage = AppLocalization.string("settings.fixErrorsFirst")
            return
        }

        do {
            let favorite = try viewModel.makeFavoriteQRCode(
                name: name,
                using: settingsViewModel.draftSettings
            )
            try favoritesViewModel.addFavorite(favorite)
            viewModel.statusMessage = AppLocalization.string("favorites.add.success")
        } catch let error as GenerateContentError {
            viewModel.statusMessage = error.localizedDescription
        } catch {
            viewModel.statusMessage = AppLocalization.string("favorites.add.error")
        }
    }
}

private struct AddFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    let onAdd: (String) -> Void

    var body: some View {
        NavigationStack {
            Form {
                Section("favorites.name") {
                    TextField("favorites.name.placeholder", text: $name)
                        .textInputAutocapitalization(.words)
                }

                Section("favorites.suggestions") {
                    suggestionButton("favorites.suggestion.myContact")
                    suggestionButton("favorites.suggestion.myEmergency")
                    suggestionButton("favorites.suggestion.myWebsite")
                }
            }
            .navigationTitle("favorites.add.title")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("share.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("favorites.add.confirm") {
                        onAdd(trimmedName)
                        dismiss()
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestionButton(_ titleKey: String) -> some View {
        Button(LocalizedStringKey(titleKey)) {
            name = AppLocalization.string(titleKey)
        }
    }
}

private enum FocusedField: Hashable {
    case websiteURL
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
    GenerateView(
        viewModel: GenerateViewModel(),
        settingsViewModel: SettingsViewModel(),
        favoritesViewModel: FavoritesViewModel()
    )
}
