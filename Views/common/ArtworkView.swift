//
//  ArtworkView.swift
//  HummingBirdOffline
//
//  Created by Achyuth on 05/10/25.
//

import SwiftUI
import UIKit

/// Decodes song/podcast artwork lazily on a background queue and caches the bitmap.
/// Prevents SwiftUI from re-decoding `UIImage(data:)` every time a row re-renders.
struct ArtworkView: View {
    let data: Data?

    @State private var renderedImage: UIImage?
    @State private var loadTask: Task<Void, Never>? = nil

    var body: some View {
        ZStack {
            if let renderedImage {
                Image(uiImage: renderedImage)
                    .resizable()
                    .scaledToFill()
                    .transition(.opacity)
            } else {
                placeholder
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .onAppear(perform: loadImage)
        .onChange(of: data) { _, _ in loadImage() }
        .onDisappear { loadTask?.cancel() }
    }

    private var placeholder: some View {
        ZStack {
            Color.secondaryBackground
            Image(systemName: "music.note")
                .foregroundColor(.secondaryText)
                .font(.title3)
        }
    }

    private func loadImage() {
        loadTask?.cancel()

        guard let data else {
            renderedImage = nil
            return
        }

        if let cached = ArtworkImageCache.shared.image(for: data) {
            renderedImage = cached
            return
        }

        loadTask = Task.detached(priority: .userInitiated) {
            guard let decoded = UIImage(data: data, scale: UIScreen.main.scale) else { return }
            ArtworkImageCache.shared.store(decoded, for: data)
            await MainActor.run { renderedImage = decoded }
        }
    }
}

private final class ArtworkImageCache {
    static let shared = ArtworkImageCache()

    private let cache = NSCache<NSData, UIImage>()

    private init() {
        cache.countLimit = 250
        cache.totalCostLimit = 40 * 1_024 * 1_024 // ~40MB in-memory budget
    }

    func image(for data: Data) -> UIImage? {
        cache.object(forKey: data as NSData)
    }

    func store(_ image: UIImage, for data: Data) {
        cache.setObject(image, forKey: data as NSData, cost: imageCost(image))
    }

    private func imageCost(_ image: UIImage) -> Int {
        let pixels = Int(image.size.width * image.size.height * image.scale * image.scale)
        return pixels * 4 // 4 bytes per pixel (RGBA)
    }
}
