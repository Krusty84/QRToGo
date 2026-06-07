//
//  AboutView.swift
//  QRToGo
//
//  Created by Codex on 07/06/2026.
//

import SwiftUI

struct AboutView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                aboutHeader

                Spacer(minLength: 24)

                aboutText

                linksSection
            }
            .frame(maxWidth: .infinity)
            .padding(.horizontal, 24)
            .padding(.vertical, 32)
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("about.title")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var aboutHeader: some View {
        VStack(spacing: 14) {
            AppLogoView(size: 96)

            Text("QR2Go")
                .font(.title2.weight(.semibold))

            Text("about.subtitle")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    private var aboutText: some View {
        Text("about.description")
            .font(.footnote)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: 360)
    }

    private var linksSection: some View {
        VStack(spacing: 12) {
            linkRow(title: "about.link.home",
                    icon: "house",
                    url: "https://www.sedoykin.com")
            
            linkRow(title: "about.link.github",
                    icon: "chevron.left.forwardslash.chevron.right",
                    url: "https://github.com/Krusty84/QRToGo")
            
            linkRow(title: "about.link.privacy",
                    icon: "hand.raised",
                    url: "https://github.com/Krusty84/QRToGo")
        }
        .frame(maxWidth: 360, alignment: .leading)
    }

    private func linkRow(title: LocalizedStringKey, icon: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .frame(width: 28, alignment: .leading)
                    .foregroundStyle(.primary)
                
                Text(title)
                    .foregroundStyle(.primary)
                
                Spacer()
            }
            .contentShape(Rectangle())
        }
        .font(.body)
    }
}

#Preview {
    NavigationStack {
        AboutView()
    }
}
