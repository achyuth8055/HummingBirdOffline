//
//  CompactSongRow.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//


import SwiftUI

/// Consistent compact song row: 40x40 artwork + title only.
struct CompactSongRow: View {
    let artworkData: Data?
    let title: String

    var body: some View {
        HStack(spacing: 12) {
            ArtworkView(data: artworkData)
                .frame(width: 40, height: 40)
            Text(title)
                .lineLimit(1)
            Spacer()
        }
    }
}
