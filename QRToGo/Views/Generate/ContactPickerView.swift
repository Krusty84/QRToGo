//
//  ContactPickerView.swift
//  QRToGo
//
//  Created by Codex on 30/05/2026.
//

import ContactsUI
import SwiftUI

struct ContactPickerView: UIViewControllerRepresentable {
    let onSelect: (CNContact) -> Void
    let onCancel: () -> Void

    func makeCoordinator() -> ContactPickerCoordinator {
        ContactPickerCoordinator(onSelect: onSelect, onCancel: onCancel)
    }

    func makeUIViewController(context: Context) -> CNContactPickerViewController {
        let controller = CNContactPickerViewController()
        controller.delegate = context.coordinator
        return controller
    }

    func updateUIViewController(_ uiViewController: CNContactPickerViewController, context: Context) {}
}

final class ContactPickerCoordinator: NSObject, CNContactPickerDelegate {
    private let onSelect: (CNContact) -> Void
    private let onCancel: () -> Void

    init(onSelect: @escaping (CNContact) -> Void, onCancel: @escaping () -> Void) {
        self.onSelect = onSelect
        self.onCancel = onCancel
    }

    func contactPicker(_ picker: CNContactPickerViewController, didSelect contact: CNContact) {
        onSelect(contact)
    }

    func contactPickerDidCancel(_ picker: CNContactPickerViewController) {
        onCancel()
    }
}
