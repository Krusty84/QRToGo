//
//  ShareRootViewController.swift
//  QRToGo
//
//  Created by Sedoykin Alexey on 26/05/2026.
//

import SwiftUI
import UIKit

final class ShareRootViewController: UIViewController {
    private var hostingController: UIHostingController<ShareRootView>?
    private var shareViewModel: ShareViewModel?

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        // The share extension starts from a principal class and bridges into SwiftUI here.
        let shareViewModel = ShareViewModel(extensionContext: extensionContext)
        let hostingController = UIHostingController(rootView: ShareRootView(viewModel: shareViewModel))

        self.shareViewModel = shareViewModel
        self.hostingController = hostingController

        addChild(hostingController)
        hostingController.view.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(hostingController.view)

        NSLayoutConstraint.activate([
            hostingController.view.topAnchor.constraint(equalTo: view.topAnchor),
            hostingController.view.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            hostingController.view.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            hostingController.view.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        hostingController.didMove(toParent: self)
    }
}
