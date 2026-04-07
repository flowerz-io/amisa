//
//  VideoFramePickerView.swift
//  BalibuShareExtension
//

import AVFoundation
import SwiftUI

private struct VideoFrameCandidate: Identifiable {
    let id = UUID()
    let time: CMTime
    let image: UIImage
}

struct VideoFramePickerView: View {
    let videoURL: URL
    let onSelectFrame: (UIImage) -> Void
    let onCancel: () -> Void

    @State private var frames: [VideoFrameCandidate] = []
    @State private var selectedIndex: Int = 0
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var generationTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 14) {
            if let errorMessage {
                VStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.title2)
                        .foregroundStyle(.secondary)
                    Text(errorMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
            } else if isLoading {
                ProgressView(String(localized: "Extraction des frames vidéo…"))
                    .padding(.top, 20)
            } else if !frames.isEmpty {
                Image(uiImage: frames[selectedIndex].image)
                    .resizable()
                    .scaledToFit()
                    .frame(maxHeight: 260)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    .padding(.horizontal, 16)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 10) {
                        ForEach(Array(frames.enumerated()), id: \.element.id) { idx, frame in
                            Button {
                                selectedIndex = idx
                            } label: {
                                Image(uiImage: frame.image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(width: 72, height: 72)
                                    .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .stroke(idx == selectedIndex ? Color.accentColor : .clear, lineWidth: 2)
                                    }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, 16)
                }
            }

            Spacer(minLength: 8)

            if !isLoading, errorMessage == nil, !frames.isEmpty {
                ShareExtensionPrimaryActionButton(
                    title: String(localized: "Utiliser cette frame"),
                    action: { onSelectFrame(frames[selectedIndex].image) }
                )
                .padding(.horizontal, 16)
            }

            Button(String(localized: "Annuler"), action: onCancel)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.bottom, 12)
        }
        .background(Color(.systemGroupedBackground))
        .task {
            generationTask?.cancel()
            generationTask = Task { await generateFrames() }
        }
        .onDisappear {
            generationTask?.cancel()
            generationTask = nil
        }
    }

    private func generateFrames() async {
        isLoading = true
        errorMessage = nil
        frames = []
        selectedIndex = 0

        let asset = AVAsset(url: videoURL)
        let duration: CMTime
        do {
            duration = try await asset.load(.duration)
        } catch {
            isLoading = false
            errorMessage = String(localized: "Impossible de lire la vidéo.")
            return
        }
        let durationSeconds = CMTimeGetSeconds(duration)
        guard durationSeconds.isFinite, durationSeconds > 0 else {
            isLoading = false
            errorMessage = String(localized: "Impossible de lire la vidéo.")
            return
        }

        let generator = AVAssetImageGenerator(asset: asset)
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 720)

        var times: [NSValue] = []
        var second: Double = 0
        while second <= durationSeconds {
            let time = CMTime(seconds: second, preferredTimescale: 600)
            times.append(NSValue(time: time))
            second += 2
        }
        if times.isEmpty {
            times = [NSValue(time: .zero)]
        }

        var localFrames: [VideoFrameCandidate] = []
        await withTaskGroup(of: VideoFrameCandidate?.self) { group in
            for value in times {
                let time = value.timeValue
                group.addTask {
                    do {
                        let cg = try generator.copyCGImage(at: time, actualTime: nil)
                        return VideoFrameCandidate(time: time, image: UIImage(cgImage: cg))
                    } catch {
                        return nil
                    }
                }
            }
            for await frame in group {
                if Task.isCancelled { return }
                if let frame {
                    localFrames.append(frame)
                }
            }
        }

        localFrames.sort { CMTimeCompare($0.time, $1.time) < 0 }
        if localFrames.isEmpty {
            isLoading = false
            errorMessage = String(localized: "Aucune frame exploitable n’a été extraite.")
            return
        }

        if Task.isCancelled { return }
        frames = localFrames
        selectedIndex = 0
        isLoading = false
    }
}
