//
//  FavoriteRenameSheet.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 07/06/2026.
//

import SwiftUI

struct FavoriteRenameSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State private var name: String

    let onRename: (String) -> Void

    init(initialName: String, onRename: @escaping (String) -> Void) {
        _name = State(initialValue: initialName)
        self.onRename = onRename
    }

    var body: some View {
        NavigationStack {
            Form {
                TextField("favorites.name.placeholder", text: $name)
                    .textInputAutocapitalization(.words)
            }
            .navigationTitle("favorites.rename")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("share.cancel") {
                        dismiss()
                    }
                }

                ToolbarItem(placement: .confirmationAction) {
                    Button("favorites.rename") {
                        onRename(trimmedName)
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
}
