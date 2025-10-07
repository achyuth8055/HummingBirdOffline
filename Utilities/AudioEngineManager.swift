//
//  AudioEngineManager.swift
//  HummingBirdOffline
//
//  Manages AVAudioEngine with EQ for real-time audio processing

import Foundation
import AVFoundation
import Combine

@MainActor
final class AudioEngineManager: ObservableObject {
    static let shared = AudioEngineManager()
    
    // EQ Bands (5 bands covering frequency spectrum)
    enum EQBand: Int, CaseIterable {
        case bass = 0      // 60 Hz
        case lowMid = 1    // 250 Hz
        case mid = 2       // 1 kHz
        case highMid = 3   // 4 kHz
        case treble = 4    // 16 kHz
        
        var frequency: Float {
            switch self {
            case .bass: return 60
            case .lowMid: return 250
            case .mid: return 1000
            case .highMid: return 4000
            case .treble: return 16000
            }
        }
        
        var bandwidth: Float {
            switch self {
            case .bass: return 0.5
            case .lowMid: return 0.7
            case .mid: return 1.0
            case .highMid: return 1.0
            case .treble: return 0.5
            }
        }
        
        var label: String {
            switch self {
            case .bass: return "60Hz"
            case .lowMid: return "250Hz"
            case .mid: return "1kHz"
            case .highMid: return "4kHz"
            case .treble: return "16kHz"
            }
        }
    }
    
    @Published var isEnabled: Bool = false {
        didSet { persistState(); applyEQState() }
    }
    
    @Published var bandGains: [Float] = Array(repeating: 0.0, count: EQBand.allCases.count) {
        didSet { persistState(); if isEnabled { applyBandGains() } }
    }
    
    private let engine = AVAudioEngine()
    private let playerNode = AVAudioPlayerNode()
    private var eqUnits: [AVAudioUnitEQ] = []
    
    private let gainsKey = "HBAudioEQGains"
    private let enabledKey = "HBAudioEQEnabled"
    
    private init() {
        loadState()
        setupAudioEngine()
    }
    
    // MARK: - Setup
    
    private func setupAudioEngine() {
        // Attach player node
        engine.attach(playerNode)
        
        // Create EQ unit with 5 bands
        let eq = AVAudioUnitEQ(numberOfBands: EQBand.allCases.count)
        eqUnits = [eq]
        engine.attach(eq)
        
        // Configure each band
        for (index, band) in EQBand.allCases.enumerated() {
            let filterParams = eq.bands[index]
            filterParams.filterType = .parametric
            filterParams.frequency = band.frequency
            filterParams.bandwidth = band.bandwidth
            filterParams.gain = bandGains[index]
            filterParams.bypass = false
        }
        
        // Connect: playerNode -> EQ -> main mixer -> output
        let format = engine.mainMixerNode.outputFormat(forBus: 0)
        engine.connect(playerNode, to: eq, format: format)
        engine.connect(eq, to: engine.mainMixerNode, format: format)
        
        // Prepare engine
        engine.prepare()
    }
    
    // MARK: - Public API
    
    func setGain(_ gain: Float, for band: EQBand) {
        let clampedGain = max(-12, min(12, gain)) // Safe range: -12dB to +12dB
        bandGains[band.rawValue] = clampedGain
    }
    
    func resetAllBands() {
        bandGains = Array(repeating: 0.0, count: EQBand.allCases.count)
    }
    
    func applyPreset(_ preset: EQPreset) {
        bandGains = preset.gains
    }
    
    // MARK: - Private Methods
    
    private func applyEQState() {
        guard let eq = eqUnits.first else { return }
        eq.bypass = !isEnabled
    }
    
    private func applyBandGains() {
        guard let eq = eqUnits.first else { return }
        for (index, gain) in bandGains.enumerated() {
            eq.bands[index].gain = gain
        }
    }
    
    // MARK: - Persistence
    
    private func loadState() {
        isEnabled = UserDefaults.standard.bool(forKey: enabledKey)
        
        if let data = UserDefaults.standard.data(forKey: gainsKey),
           let gains = try? JSONDecoder().decode([Float].self, from: data),
           gains.count == EQBand.allCases.count {
            bandGains = gains
        }
    }
    
    private func persistState() {
        UserDefaults.standard.set(isEnabled, forKey: enabledKey)
        if let data = try? JSONEncoder().encode(bandGains) {
            UserDefaults.standard.set(data, forKey: gainsKey)
        }
    }
}

// MARK: - EQ Presets

enum EQPreset: String, CaseIterable, Identifiable {
    case flat = "Flat"
    case bassBoost = "Bass Boost"
    case trebleBoost = "Treble Boost"
    case vocal = "Vocal"
    case electronic = "Electronic"
    case rock = "Rock"
    case classical = "Classical"
    case jazz = "Jazz"
    
    var id: String { rawValue }
    
    // Gains for [bass, lowMid, mid, highMid, treble]
    var gains: [Float] {
        switch self {
        case .flat:
            return [0, 0, 0, 0, 0]
        case .bassBoost:
            return [6, 4, 0, -2, -2]
        case .trebleBoost:
            return [-2, -2, 0, 4, 6]
        case .vocal:
            return [-1, 2, 4, 3, 0]
        case .electronic:
            return [5, 0, -2, 2, 4]
        case .rock:
            return [5, 2, -1, 2, 4]
        case .classical:
            return [0, 0, 0, 0, 2]
        case .jazz:
            return [3, 2, 0, 2, 3]
        }
    }
}
