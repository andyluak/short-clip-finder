//
//  StorageManagementView.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI

struct StorageManagementView: View {
    @State private var storageInfo: StorageInfo?
    @State private var isLoading = true
    @State private var isClearing = false
    @State private var clearingType: StorageType?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Storage")
                .font(.headline)

            if isLoading {
                loadingView
            } else if let info = storageInfo {
                storageDetails(info)
            } else {
                errorView
            }
        }
        .task {
            await loadStorageInfo()
        }
    }

    private var loadingView: some View {
        HStack {
            ProgressView()
                .scaleEffect(0.8)
            Text("Calculating storage...")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    private var errorView: some View {
        HStack {
            Image(systemName: "exclamationmark.triangle")
                .foregroundStyle(.orange)
            Text("Could not calculate storage")
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding()
    }

    @ViewBuilder
    private func storageDetails(_ info: StorageInfo) -> some View {
        VStack(spacing: 10) {
            // Total usage bar
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Total Usage")
                        .font(.subheadline)
                    Spacer()
                    Text(formatBytes(info.totalSize))
                        .font(.system(.subheadline, design: .monospaced))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { geo in
                    HStack(spacing: 1) {
                        ForEach(info.categories, id: \.type) { category in
                            let width = info.totalSize > 0
                                ? CGFloat(category.size) / CGFloat(info.totalSize) * geo.size.width
                                : 0
                            Rectangle()
                                .fill(category.type.color)
                                .frame(width: max(width, category.size > 0 ? 2 : 0))
                        }
                    }
                }
                .frame(height: 8)
                .clipShape(RoundedRectangle(cornerRadius: 4))
                .background(Color.secondary.opacity(0.2), in: RoundedRectangle(cornerRadius: 4))
            }

            // Category breakdown
            VStack(spacing: 8) {
                ForEach(info.categories, id: \.type) { category in
                    storageRow(category)
                }
            }

            // Clear all button
            Divider()

            Button {
                Task {
                    await clearAllStorage()
                }
            } label: {
                if isClearing && clearingType == nil {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Text("Clear All Storage")
                }
            }
            .buttonStyle(.bordered)
            .disabled(isClearing || info.totalSize == 0)
        }
    }

    private func storageRow(_ category: StorageCategory) -> some View {
        HStack {
            Circle()
                .fill(category.type.color)
                .frame(width: 8, height: 8)

            Text(category.type.displayName)
                .font(.caption)

            Spacer()

            Text(formatBytes(category.size))
                .font(.system(.caption, design: .monospaced))
                .foregroundStyle(.secondary)

            Button {
                Task {
                    await clearStorage(type: category.type)
                }
            } label: {
                if isClearing && clearingType == category.type {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 16, height: 16)
                } else {
                    Image(systemName: "trash")
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.borderless)
            .disabled(isClearing || category.size == 0)
        }
    }

    private func loadStorageInfo() async {
        isLoading = true

        let projectsSize = (try? await ProjectManager.shared.totalStorageUsed()) ?? 0
        let cacheSize = calculateCacheSize()
        let downloadsSize = calculateDownloadsSize()

        storageInfo = StorageInfo(categories: [
            StorageCategory(type: .projects, size: projectsSize),
            StorageCategory(type: .downloads, size: downloadsSize),
            StorageCategory(type: .cache, size: cacheSize)
        ])

        isLoading = false
    }

    private func clearStorage(type: StorageType) async {
        isClearing = true
        clearingType = type

        switch type {
        case .projects:
            try? await ProjectManager.shared.deleteAllProjects()
        case .downloads:
            clearDownloads()
        case .cache:
            clearCache()
        }

        await loadStorageInfo()
        isClearing = false
        clearingType = nil
    }

    private func clearAllStorage() async {
        isClearing = true
        clearingType = nil

        try? await ProjectManager.shared.deleteAllProjects()
        clearDownloads()
        clearCache()

        await loadStorageInfo()
        isClearing = false
    }

    private func calculateCacheSize() -> Int64 {
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipFinder")
            .appendingPathComponent("yt-dlp-cache")

        return directorySize(at: cacheDir)
    }

    private func calculateDownloadsSize() -> Int64 {
        let tempDir = FileManager.default.temporaryDirectory

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey])
            let clipFinderDirs = contents.filter { $0.lastPathComponent.hasPrefix("ClipFinder-") }
            return clipFinderDirs.reduce(0) { $0 + directorySize(at: $1) }
        } catch {
            return 0
        }
    }

    private func clearDownloads() {
        let tempDir = FileManager.default.temporaryDirectory

        do {
            let contents = try FileManager.default.contentsOfDirectory(at: tempDir, includingPropertiesForKeys: [.isDirectoryKey])
            let clipFinderDirs = contents.filter { $0.lastPathComponent.hasPrefix("ClipFinder-") }
            for dir in clipFinderDirs {
                try? FileManager.default.removeItem(at: dir)
            }
        } catch {
            print("[Storage] Failed to clear downloads: \(error)")
        }
    }

    private func clearCache() {
        let cacheDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("ClipFinder")
            .appendingPathComponent("yt-dlp-cache")

        try? FileManager.default.removeItem(at: cacheDir)
        try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
    }

    private func directorySize(at url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.fileSizeKey],
            options: [.skipsHiddenFiles]
        ) else {
            return 0
        }

        var size: Int64 = 0
        for case let fileURL as URL in enumerator {
            if let fileSize = try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                size += Int64(fileSize)
            }
        }
        return size
    }

    private func formatBytes(_ bytes: Int64) -> String {
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }
}

// MARK: - Models

enum StorageType: CaseIterable {
    case projects
    case downloads
    case cache

    var displayName: String {
        switch self {
        case .projects: "Projects"
        case .downloads: "Downloads"
        case .cache: "Cache"
        }
    }

    var color: Color {
        switch self {
        case .projects: .blue
        case .downloads: .orange
        case .cache: .gray
        }
    }
}

struct StorageCategory {
    let type: StorageType
    let size: Int64
}

struct StorageInfo {
    let categories: [StorageCategory]

    var totalSize: Int64 {
        categories.reduce(0) { $0 + $1.size }
    }
}

#Preview {
    StorageManagementView()
        .frame(width: 400)
        .padding()
}
