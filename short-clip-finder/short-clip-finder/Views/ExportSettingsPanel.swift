//
//  ExportSettingsPanel.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct ExportSettingsPanel: View {
    @Binding var settings: ExportSettings
    @Binding var isPresented: Bool
    let clipCount: Int
    let onExport: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Export Settings")
                .font(.headline)

            // Format
            VStack(alignment: .leading, spacing: 6) {
                Text("Format")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Format", selection: $settings.format) {
                    ForEach(ExportFormat.allCases, id: \.self) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Quality
            VStack(alignment: .leading, spacing: 6) {
                Text("Quality")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Quality", selection: $settings.quality) {
                    ForEach(ExportQuality.allCases, id: \.self) { quality in
                        Text(quality.displayName).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Crop Mode
            VStack(alignment: .leading, spacing: 6) {
                Text("Crop Focus")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Picker("Crop Mode", selection: $settings.cropMode) {
                    ForEach(CropMode.allCases, id: \.self) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .labelsHidden()
            }

            // Output Directory
            VStack(alignment: .leading, spacing: 6) {
                Text("Save to")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                HStack {
                    Image(systemName: "folder.fill")
                        .foregroundStyle(.secondary)

                    Text(settings.outputDirectory.path)
                        .lineLimit(1)
                        .truncationMode(.middle)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button("Choose...") {
                        chooseOutputDirectory()
                    }
                }
                .padding(8)
                .background(.quaternary)
                .cornerRadius(6)
            }

            Divider()
                .padding(.vertical, 4)

            // Actions
            HStack {
                Button("Cancel") {
                    isPresented = false
                }
                .keyboardShortcut(.escape)

                Spacer()

                Button("Export \(clipCount) Clip\(clipCount == 1 ? "" : "s")") {
                    settings.save()
                    isPresented = false
                    onExport()
                }
                .keyboardShortcut(.return)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(20)
        .frame(width: 380)
    }

    private func chooseOutputDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseFiles = false
        panel.canChooseDirectories = true
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = true
        panel.prompt = "Choose"

        if panel.runModal() == .OK, let url = panel.url {
            settings.outputDirectory = url
        }
    }
}
