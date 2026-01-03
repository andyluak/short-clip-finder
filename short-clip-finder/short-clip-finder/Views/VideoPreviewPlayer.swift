//
//  VideoPreviewPlayer.swift
//  short-clip-finder
//
//  Created by Alexandru Tirim on 03.01.2026.
//

import SwiftUI
import AVKit

struct VideoPreviewPlayer: View {
    let videoURL: URL
    let startTime: TimeInterval
    let endTime: TimeInterval

    @State private var player: AVPlayer?
    @State private var isPlaying = false
    @State private var thumbnail: NSImage?

    var body: some View {
        ZStack {
            if let player {
                VideoPlayer(player: player)
                    .disabled(true) // Disable default controls
                    .overlay {
                        playOverlay
                    }
            } else if let thumbnail {
                Image(nsImage: thumbnail)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .overlay {
                        playOverlay
                    }
            } else {
                Rectangle()
                    .fill(Color.black.opacity(0.8))
                    .overlay {
                        ProgressView()
                            .scaleEffect(0.8)
                    }
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .onAppear {
            loadThumbnail()
        }
        .onDisappear {
            player?.pause()
            player = nil
        }
        .onTapGesture {
            togglePlayback()
        }
    }

    private var playOverlay: some View {
        Group {
            if !isPlaying {
                ZStack {
                    Color.black.opacity(0.3)

                    Image(systemName: "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.white)
                        .shadow(radius: 4)
                }
            }
        }
    }

    private func loadThumbnail() {
        Task {
            let asset = AVAsset(url: videoURL)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            imageGenerator.maximumSize = CGSize(width: 400, height: 400)

            let time = CMTime(seconds: startTime, preferredTimescale: 600)

            do {
                let cgImage = try await imageGenerator.image(at: time).image
                await MainActor.run {
                    thumbnail = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                }
            } catch {
                // Fallback: no thumbnail
            }
        }
    }

    private func togglePlayback() {
        if player == nil {
            setupPlayer()
        }

        if isPlaying {
            player?.pause()
            isPlaying = false
        } else {
            player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
            player?.play()
            isPlaying = true
            scheduleEndStop()
        }
    }

    private func setupPlayer() {
        let playerItem = AVPlayerItem(url: videoURL)
        player = AVPlayer(playerItem: playerItem)
        player?.seek(to: CMTime(seconds: startTime, preferredTimescale: 600))
    }

    private func scheduleEndStop() {
        let duration = endTime - startTime
        Task {
            try? await Task.sleep(for: .seconds(duration))
            await MainActor.run {
                player?.pause()
                isPlaying = false
            }
        }
    }
}

#Preview {
    VideoPreviewPlayer(
        videoURL: URL(fileURLWithPath: "/tmp/test.mp4"),
        startTime: 10,
        endTime: 55
    )
    .frame(width: 200, height: 120)
}
