//
//  EqualizerView.swift
//  HummingBirdOffline
//
//  Functional equalizer with 5-band frequency control

import SwiftUI

struct EqualizerView: View {
    @Environment(\.dismiss) private var dismiss
    @StateObject private var audioEngine = AudioEngineManager.shared
    @State private var selectedPreset: EQPreset = .flat
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    enableToggle
                    
                    if audioEngine.isEnabled {
                        presetPicker
                        bandSliders
                        resetButton
                    }
                }
                .padding(.horizontal, 24)
                .padding(.vertical, 20)
            }
            .background(Color.primaryBackground.ignoresSafeArea())
            .navigationTitle("Equalizer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        Haptics.light()
                        dismiss()
                    }
                }
            }
        }
    }
    
    // MARK: - Components
    
    private var enableToggle: some View {
        Toggle(isOn: $audioEngine.isEnabled) {
            HStack(spacing: 12) {
                Image(systemName: "waveform")
                    .font(.title3)
                    .foregroundColor(.accentGreen)
                Text("Enable Equalizer")
                    .font(HBFont.body(16, weight: .medium))
            }
        }
        .tint(.accentGreen)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.secondaryBackground)
        )
    }
    
    private var presetPicker: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Presets")
                .font(HBFont.heading(18))
                .foregroundColor(.primaryText)
            
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(EQPreset.allCases) { preset in
                        presetChip(preset)
                    }
                }
            }
        }
        .animation(.snappy(duration: 0.3), value: selectedPreset)
    }
    
    private func presetChip(_ preset: EQPreset) -> some View {
        Button {
            Haptics.light()
            selectedPreset = preset
            audioEngine.applyPreset(preset)
        } label: {
            Text(preset.rawValue)
                .font(HBFont.body(14, weight: .medium))
                .foregroundColor(selectedPreset == preset ? .primaryBackground : .primaryText)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(
                    Capsule(style: .continuous)
                        .fill(selectedPreset == preset ? Color.accentGreen : Color.secondaryBackground)
                )
        }
        .buttonStyle(.plain)
    }
    
    private var bandSliders: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Frequency Bands")
                .font(HBFont.heading(18))
                .foregroundColor(.primaryText)
            
            VStack(spacing: 20) {
                ForEach(AudioEngineManager.EQBand.allCases, id: \.rawValue) { band in
                    bandSlider(for: band)
                }
            }
        }
    }
    
    private func bandSlider(for band: AudioEngineManager.EQBand) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(band.label)
                    .font(HBFont.body(14, weight: .medium))
                    .foregroundColor(.primaryText)
                Spacer()
                Text("\(audioEngine.bandGains[band.rawValue], specifier: "%+.1f") dB")
                    .font(HBFont.body(13, weight: .medium))
                    .foregroundColor(.accentGreen)
                    .monospacedDigit()
            }
            
            Slider(
                value: Binding(
                    get: { Double(audioEngine.bandGains[band.rawValue]) },
                    set: { audioEngine.setGain(Float($0), for: band) }
                ),
                in: -12...12,
                step: 0.5
            )
            .tint(.accentGreen)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.secondaryBackground.opacity(0.6))
        )
    }
    
    private var resetButton: some View {
        Button {
            Haptics.medium()
            withAnimation(.snappy(duration: 0.3)) {
                audioEngine.resetAllBands()
                selectedPreset = .flat
            }
        } label: {
            HStack {
                Image(systemName: "arrow.counterclockwise")
                Text("Reset All Bands")
                    .font(HBFont.body(15, weight: .semibold))
            }
            .foregroundColor(.primaryText)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color.secondaryBackground)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    EqualizerView()
}
