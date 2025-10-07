//
//  EqualizerManager.swift
//  HummingBirdOffline
//

import Foundation
import AVFoundation
import Combine   // ← needed for ObservableObject / @Published

@MainActor
final class EqualizerManager: ObservableObject {
    static let shared = EqualizerManager()

    enum Preset: String, CaseIterable, Identifiable {
        case off = "Off"
        case bass = "Bass Boost"
        case treble = "Treble Boost"
        case vocal = "Vocal Boost"
        case rock = "Rock"
        case pop = "Pop"
        case jazz = "Jazz"
        case classical = "Classical"
        case electronic = "Electronic"

        var id: String { rawValue }

        /// Six-band gains (low → high). Values are in dB.
        var gains: [Float] {
            switch self {
            case .off:        return [ 0,  0,  0,  0,  0,  0]
            case .bass:       return [ 8,  6,  4,  0,  0,  0]
            case .treble:     return [ 0,  0,  0,  4,  6,  8]
            case .vocal:      return [ 0,  2,  4,  4,  2,  0]
            case .rock:       return [ 6,  4,  2, -1,  2,  4]
            case .pop:        return [ 2,  4,  4,  2,  0,  2]
            case .jazz:       return [ 4,  2,  0,  2,  4,  4]
            case .classical:  return [ 4,  2,  0,  0,  2,  4]
            case .electronic: return [ 6,  4,  0,  2,  4,  6]
            }
        }
    }

    @Published var currentPreset: Preset = .off

    private init() {}

    /// Apply a preset to a 6-band AVAudioUnitEQ.
    func applyPreset(_ preset: Preset, to eq: AVAudioUnitEQ) {
        currentPreset = preset
        let gains = preset.gains
        for (i, band) in eq.bands.enumerated() where i < gains.count {
            band.gain = gains[i]
            band.bypass = false
        }
    }
}
