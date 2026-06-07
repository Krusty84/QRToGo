//
//  AddFavoriteSheet.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct AddFavoriteSheet: View {
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
