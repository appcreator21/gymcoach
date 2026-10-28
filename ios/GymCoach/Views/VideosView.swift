import SwiftUI
import AVKit
import Combine

/// The coach's video library: a featured clip, categories, and a grid.
struct VideosView: View {
    @Environment(AppState.self) private var app
    @State private var category: String?
    @State private var playing: VideoClip?

    private var categories: [String] {
        var seen: [String] = []
        for c in app.videos.map(\.category) where !seen.contains(c) { seen.append(c) }
        return seen
    }

    private var visible: [VideoClip] {
        app.videos.filter { category == nil || $0.category == category }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if app.videos.isEmpty {
                    GlassCard {
                        VStack(alignment: .leading, spacing: 6) {
                            Label("Videos are coming", systemImage: "play.rectangle.fill").font(.system(.headline, design: .rounded))
                            Text("Surba's workouts, technique tips and routines will show up here.")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                } else {
                    if category == nil, let hero = app.featuredVideo {
                        Button { open(hero) } label: { HeroCard(clip: hero) }.buttonStyle(.plain)
                    }
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            chip("All", on: category == nil) { category = nil }
                            ForEach(categories, id: \.self) { c in chip(c, on: category == c) { category = c } }
                        }
                    }
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)], spacing: 14) {
                        ForEach(visible) { clip in
                            Button { open(clip) } label: { GridCard(clip: clip) }.buttonStyle(.plain)
                        }
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 30)
        }
        .background(Theme.background)
        .navigationTitle("Surba's videos")
        .navigationBarTitleDisplayMode(.inline)
        .refreshable { await app.reloadVideos() }
        .task { await app.reloadVideos() }
        .fullScreenCover(item: $playing) { VideoPlayerScreen(clip: $0) }
    }

    private func open(_ clip: VideoClip) {
        Haptics.select()
        playing = clip
    }

    private func chip(_ title: String, on: Bool, action: @escaping () -> Void) -> some View {
        Button { action(); Haptics.select() } label: {
            Text(title).font(.subheadline.weight(.semibold))
                .padding(.horizontal, 14).padding(.vertical, 9)
                .background(on ? Color.white : Theme.card, in: Capsule())
                .foregroundStyle(on ? Color.black : Color.white)
        }
        .buttonStyle(.plain)
    }
}

private struct HeroCard: View {
    let clip: VideoClip

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            VideoThumbnail(clip: clip).frame(height: 230).clipped()
            LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.featured ? "FEATURED" : "LATEST").font(.caption2.weight(.heavy)).foregroundStyle(Theme.accent)
                Text(clip.title).font(.system(.title3, design: .rounded, weight: .bold)).foregroundStyle(.white).lineLimit(2)
                if let d = clip.durationLabel { Text(d).font(.caption.monospacedDigit()).foregroundStyle(.white.opacity(0.8)) }
            }
            .padding(16)
            Image(systemName: "play.circle.fill").font(.system(size: 54)).foregroundStyle(.white.opacity(0.95))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(height: 230)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
    }
}

private struct GridCard: View {
    let clip: VideoClip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottomTrailing) {
                VideoThumbnail(clip: clip)
                    .aspectRatio(9 / 13, contentMode: .fill)
                    .frame(maxWidth: .infinity)
                    .clipped()
                Image(systemName: "play.fill").font(.caption.weight(.bold)).foregroundStyle(.white)
                    .padding(8).background(.black.opacity(0.55), in: Circle()).padding(8)
            }
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            Text(clip.title).font(.system(.subheadline, design: .rounded, weight: .semibold)).foregroundStyle(.white).lineLimit(2)
            Text([clip.category, clip.durationLabel].compactMap { $0 }.joined(separator: "  -  "))
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

/// The image for a clip: its thumbnail link, or the first frame of the video.
struct VideoThumbnail: View {
    let clip: VideoClip
    @State private var frame: UIImage?

    var body: some View {
        ZStack {
            Theme.card
            if let url = clip.thumbnail {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image): image.resizable().scaledToFill()
                    case .failure: placeholder
                    default: ProgressView()
                    }
                }
            } else if let frame {
                Image(uiImage: frame).resizable().scaledToFill()
            } else {
                placeholder
            }
        }
        .task(id: clip.id) {
            guard clip.thumbnail == nil, let url = clip.url else { return }
            frame = await FrameCache.shared.frame(for: url)
        }
    }

    private var placeholder: some View {
        Image(systemName: "play.rectangle.fill").font(.largeTitle).foregroundStyle(.secondary)
    }
}

/// First frames pulled from remote videos, kept so scrolling stays smooth.
final class FrameCache: @unchecked Sendable {
    static let shared = FrameCache()
    private let cache = NSCache<NSURL, UIImage>()

    func frame(for url: URL) async -> UIImage? {
        if let hit = cache.object(forKey: url as NSURL) { return hit }
        let generator = AVAssetImageGenerator(asset: AVURLAsset(url: url))
        generator.appliesPreferredTrackTransform = true
        generator.maximumSize = CGSize(width: 720, height: 1280)
        guard let result = try? await generator.image(at: CMTime(seconds: 0.5, preferredTimescale: 600)) else { return nil }
        let image = UIImage(cgImage: result.image)
        cache.setObject(image, forKey: url as NSURL)
        return image
    }
}

/// Full screen player. Plays with sound even when the silent switch is on,
/// and shows a clear message when the link does not play.
struct VideoPlayerScreen: View {
    @Environment(\.dismiss) private var dismiss
    let clip: VideoClip
    @State private var player: AVPlayer?
    @State private var failed = false

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.ignoresSafeArea()
            if let player, !failed {
                VideoPlayer(player: player).ignoresSafeArea()
            } else if failed {
                VStack(spacing: 12) {
                    Image(systemName: "exclamationmark.triangle.fill").font(.largeTitle).foregroundStyle(Theme.amber)
                    Text("This video could not be played.").foregroundStyle(.white)
                    Text("Check your connection and try again.").font(.footnote).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView().tint(.white).frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            Button { dismiss() } label: {
                Image(systemName: "xmark").font(.headline).foregroundStyle(.white)
                    .padding(12).background(.black.opacity(0.55), in: Circle())
            }
            .padding(16)
            .accessibilityLabel("Close video")
        }
        .overlay(alignment: .bottom) {
            VStack(alignment: .leading, spacing: 4) {
                Text(clip.title).font(.system(.headline, design: .rounded)).foregroundStyle(.white)
                if let d = clip.description, !d.isEmpty { Text(d).font(.caption).foregroundStyle(.white.opacity(0.8)).lineLimit(3) }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20).padding(.bottom, 70)
            .allowsHitTesting(false)
            .opacity(failed ? 0 : 1)
        }
        .task {
            guard let url = clip.url else { failed = true; return }
            try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .moviePlayback)
            try? AVAudioSession.sharedInstance().setActive(true)
            let item = AVPlayerItem(url: url)
            let p = AVPlayer(playerItem: item)
            player = p
            p.play()
            for await status in item.publisher(for: \.status).values where status == .failed {
                failed = true
                break
            }
        }
        .onDisappear {
            player?.pause()
            player = nil
            try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
        }
    }
}

/// A "From Surba" card for Today: the featured video, one tap to watch.
struct FromSurbaSection: View {
    @Environment(AppState.self) private var app
    @State private var playing: VideoClip?

    var body: some View {
        if let clip = app.featuredVideo {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    SectionTitle("From Surba")
                    Spacer()
                    NavigationLink { VideosView() } label: { Text("See all").font(.subheadline.weight(.semibold)) }
                }
                Button { Haptics.select(); playing = clip } label: {
                    ZStack(alignment: .bottomLeading) {
                        VideoThumbnail(clip: clip).frame(height: 190).clipped()
                        LinearGradient(colors: [.clear, .black.opacity(0.85)], startPoint: .center, endPoint: .bottom)
                        VStack(alignment: .leading, spacing: 3) {
                            Text(clip.title).font(.system(.headline, design: .rounded)).foregroundStyle(.white).lineLimit(2)
                            Text(clip.category).font(.caption).foregroundStyle(.white.opacity(0.8))
                        }
                        .padding(14)
                        Image(systemName: "play.circle.fill").font(.system(size: 46)).foregroundStyle(.white.opacity(0.95))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    .frame(height: 190)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                }
                .buttonStyle(.plain)
            }
            .fullScreenCover(item: $playing) { VideoPlayerScreen(clip: $0) }
        }
    }
}
