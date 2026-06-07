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
    @StateObject private var locationProvider = CurrentLocationProvider()
    @State private var isFullScreenLocationMapPresented = false
    @State private var saveToPhotosFeedback: ActionFeedback?
    @State private var addToFavoriteFeedback: ActionFeedback?
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
                    
                    if viewModel.contentDraft.kind != .location {
                        VStack(alignment: .leading, spacing: 8) {
                            TextField("generate.exportPurpose", text: $viewModel.exportPurposeDraft, axis: .vertical)
                                .lineLimit(3, reservesSpace: true)
                        }
                    }
                }

                Section("settings.section.preview") {
                    QRPreviewView(
                        image: viewModel.previewImage,
                        isLoading: viewModel.isGeneratingPreview,
                        errorMessage: viewModel.previewErrorMessage
                    )

                    if viewModel.hasGeneratedQRCode {
                        qrQualityView
                    }

                    Button {
                        guard isSaveToPhotosDisabled == false else {
                            return
                        }

                        Task {
                            let isSuccess = await viewModel.savePreviewToPhotos(
                                using: settingsViewModel.draftSettings
                            )

                            withAnimation(.snappy) {
                                saveToPhotosFeedback = isSuccess ? .success : .failure
                            }
                        }
                    } label: {
                        HStack {
                            if viewModel.isSavingPreview {
                                ProgressView()
                            } else {
                                Label("settings.savePreview", systemImage: "photo.badge.plus")
                                    .foregroundStyle(actionButtonForeground(isDisabled: isSaveToPhotosDisabled))
                            }

                            Spacer()

                            feedbackBadge(saveToPhotosFeedback)
                        }
                    }
                    .disabled(isSaveToPhotosDisabled)
                    .opacity(isSaveToPhotosDisabled ? 0.45 : 1.0)

                    Button {
                        guard isAddToFavoriteDisabled == false else {
                            return
                        }

                        isFavoriteSheetPresented = true
                    } label: {
                        HStack {
                            Label("favorites.add.button", systemImage: "text.badge.star")
                                .foregroundStyle(actionButtonForeground(isDisabled: isAddToFavoriteDisabled))

                            Spacer()

                            feedbackBadge(addToFavoriteFeedback)
                        }
                    }
                    .disabled(isAddToFavoriteDisabled)
                    .opacity(isAddToFavoriteDisabled ? 0.45 : 1.0)
                }
            }
            .scrollDismissesKeyboard(.interactively)
            .navigationTitle("tab.generate")
            .onChange(of: viewModel.contentDraft) { _, _ in
                resetActionFeedbackBadges()
            }
            .onChange(of: viewModel.contentDraft.kind) { _, newKind in
                if newKind == .location {
                    locationProvider.requestAuthorizationIfNeeded()
                }
            }
            .onChange(of: settingsViewModel.draftSettings) { _, _ in
                resetActionFeedbackBadges()
            }
            .onChange(of: viewModel.hasGeneratedQRCode) { _, hasGeneratedQRCode in
                if hasGeneratedQRCode == false {
                    resetActionFeedbackBadges()
                }
            }
            .onChange(of: viewModel.exportPurposeDraft) { _, _ in
                withAnimation(.snappy) {
                    saveToPhotosFeedback = nil
                }
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
        .sheet(isPresented: $isFavoriteSheetPresented) {
            AddFavoriteSheet(
                availableSuggestionNames: FavoriteDefaultNames.availableNames(
                    for: favoritesViewModel.favorites
                )
            ) { name in
                addFavorite(named: name)
            }
        }
        .fullScreenCover(isPresented: $isFullScreenLocationMapPresented) {
            LocationMapPickerView(
                initialSelection: viewModel.selectedLocation
            ) { selection in
                viewModel.setSelectedLocation(selection)
                isFullScreenLocationMapPresented = false
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
            HStack(spacing: 12) {
                TextField("generate.locationLatitude", text: $viewModel.contentDraft.locationLatitude)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .locationLatitude)

                TextField("generate.locationLongitude", text: $viewModel.contentDraft.locationLongitude)
                    .keyboardType(.numbersAndPunctuation)
                    .focused($focusedField, equals: .locationLongitude)
            }

            LocationInlineMapView(
                selection: viewModel.selectedLocation,
                currentLabel: viewModel.contentDraft.locationLabel,
                onSelect: { selection in
                    viewModel.setSelectedLocation(selection)
                },
                onOpenFullScreen: {
                    isFullScreenLocationMapPresented = true
                }
            )

            TextField("generate.locationLabel", text: $viewModel.contentDraft.locationLabel)
                .focused($focusedField, equals: .locationLabel)
        }
    }
    
    private var qrQualityView: some View {
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
    }
    
    private func actionButtonForeground(isDisabled: Bool) -> Color {
        isDisabled ? Color.secondary : Color.accentColor
    }
    
    private func resetActionFeedbackBadges() {
        withAnimation(.snappy) {
            saveToPhotosFeedback = nil
            addToFavoriteFeedback = nil
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

    private var isSaveToPhotosDisabled: Bool {
        viewModel.isSavingPreview
            || viewModel.hasGeneratedQRCode == false
            || settingsViewModel.hasBlockingValidation
    }

    private var isAddToFavoriteDisabled: Bool {
        viewModel.hasGeneratedQRCode == false
            || settingsViewModel.hasBlockingValidation
            || viewModel.canMakeFavoriteQRCode(using: settingsViewModel.draftSettings) == false
    }

    private func addFavorite(named name: String) -> Bool {
        guard viewModel.hasGeneratedQRCode, viewModel.previewImage != nil else {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }

        guard settingsViewModel.hasBlockingValidation == false else {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }

        do {
            let favorite = try viewModel.makeFavoriteQRCode(
                name: name,
                using: settingsViewModel.draftSettings
            )
            try favoritesViewModel.addFavorite(favorite)

            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .success
            }

            return true
        } catch {
            viewModel.statusMessage = nil

            withAnimation(.snappy) {
                addToFavoriteFeedback = .failure
            }

            return false
        }
    }
    
    private func feedbackBadge(_ feedback: ActionFeedback?) -> some View {
        Group {
            if let feedback {
                Image(systemName: feedback.systemImage)
                    .foregroundStyle(feedback.color)
                    .font(.headline)
                    .accessibilityHidden(true)
            }
        }
    }
}

private struct AddFavoriteSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""

    let availableSuggestionNames: [String]
    let onAdd: (String) -> Bool

    var body: some View {
        NavigationStack {
            Form {
                Section("favorites.name") {
                    TextField("favorites.name.placeholder", text: $name)
                        .textInputAutocapitalization(.words)
                }

                if availableSuggestionNames.isEmpty == false {
                    Section("favorites.suggestions") {
                        ForEach(availableSuggestionNames, id: \.self) { suggestionName in
                            suggestionButton(suggestionName)
                        }
                    }
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
                        if onAdd(trimmedName) {
                            dismiss()
                        }
                    }
                    .disabled(trimmedName.isEmpty)
                }
            }
        }
    }

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func suggestionButton(_ suggestionName: String) -> some View {
        Button(suggestionName) {
            name = suggestionName
        }
    }
}

private enum ActionFeedback: Equatable {
    case success
    case failure

    var systemImage: String {
        switch self {
        case .success:
            "checkmark.circle.fill"
        case .failure:
            "xmark.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .success:
            .green
        case .failure:
            .red
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
