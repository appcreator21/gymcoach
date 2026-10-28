import SwiftUI

/// Admin: add the coach's videos by link, edit them, mark one as featured,
/// link one to an exercise so it shows a "watch demo" button in workouts.
struct AdminVideosView: View {
    @State private var clips: [VideoClip] = []
    @State private var loading = true
    @State private var editing: VideoDraft?
    @State private var error: String?

    var body: some View {
        List {
            ForEach(clips) { clip in
                Button { editing = VideoDraft(clip: clip) } label: {
                    HStack(spacing: 12) {
                        VideoThumbnail(clip: clip).frame(width: 54, height: 72)
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                        VStack(alignment: .leading, spacing: 3) {
                            HStack(spacing: 6) {
                                Text(clip.title).font(.headline).foregroundStyle(.primary).lineLimit(2)
                                if clip.featured { Image(systemName: "star.fill").font(.caption).foregroundStyle(Theme.amber) }
                            }
                            Text([clip.category, clip.exerciseName.map { "Demo: \($0)" }, clip.durationLabel].compactMap { $0 }.joined(separator: "  -  "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .swipeActions { Button("Delete", role: .destructive) { Task { await delete(clip) } } }
            }
            if let error { Text(error).font(.footnote).foregroundStyle(.red) }
        }
        .scrollContentBackground(.hidden)
        .background(Theme.background)
        .overlay {
            if loading { ProgressView() }
            else if clips.isEmpty {
                Text("No videos yet. Tap + and paste a link to a video you uploaded.").multilineTextAlignment(.center)
                    .foregroundStyle(.secondary).padding()
            }
        }
        .navigationTitle("Videos")
        .toolbar { ToolbarItem(placement: .topBarTrailing) { Button { editing = VideoDraft() } label: { Image(systemName: "plus") } } }
        .sheet(item: $editing, onDismiss: { Task { await load() } }) { VideoEditorSheet(draft: $0) }
        .task { await load() }
        .refreshable { await load() }
    }

    private func load() async {
        do { clips = try await APIClient.shared.get("/api/admin/videos"); error = nil } catch { self.error = error.localizedDescription }
        loading = false
    }

    private func delete(_ clip: VideoClip) async {
        do {
            _ = try await APIClient.shared.raw("DELETE", "/api/admin/videos/\(clip.id)")
            clips.removeAll { $0.id == clip.id }
            Haptics.success()
        } catch { self.error = error.localizedDescription }
    }
}

struct VideoDraft: Identifiable {
    let id = UUID()
    var existingId: String?
    var title = ""
    var details = ""
    var videoUrl = ""
    var thumbnailUrl = ""
    var category = "Workouts"
    var exerciseName = ""
    var durationText = ""
    var featured = false

    init() {}

    init(clip: VideoClip) {
        existingId = clip.id
        title = clip.title
        details = clip.description ?? ""
        videoUrl = clip.videoUrl
        thumbnailUrl = clip.thumbnailUrl ?? ""
        category = clip.category
        exerciseName = clip.exerciseName ?? ""
        durationText = clip.durationSec.map(String.init) ?? ""
        featured = clip.featured
    }
}

struct VideoEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var draft: VideoDraft
    @State private var busy = false
    @State private var error: String?
    @State private var preview: VideoClip?

    init(draft: VideoDraft) { _draft = State(initialValue: draft) }

    var body: some View {
        NavigationStack {
            Form {
                Section("Video") {
                    TextField("Title", text: $draft.title)
                    TextField("Video link (https, .mp4)", text: $draft.videoUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    TextField("Thumbnail link (optional)", text: $draft.thumbnailUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    Button("Test the video link") {
                        if let url = URL(string: draft.videoUrl.trimmingCharacters(in: .whitespaces)), url.scheme == "https" {
                            preview = VideoClip(id: "preview", title: draft.title.isEmpty ? "Preview" : draft.title, description: nil,
                                                videoUrl: url.absoluteString, thumbnailUrl: nil, category: draft.category,
                                                exerciseName: nil, durationSec: nil, featured: false, createdAt: Date())
                        } else { error = "Enter a full https link first." }
                    }
                }
                Section("Details") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(VideoCategories.all, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Description (optional)", text: $draft.details, axis: .vertical).lineLimit(1...4)
                    TextField("Length in seconds (optional)", text: $draft.durationText).keyboardType(.numberPad)
                    Toggle("Feature on Today", isOn: $draft.featured)
                }
                Section {
                    TextField("Exercise name, e.g. Barbell Back Squat", text: $draft.exerciseName)
                } header: { Text("Demo for an exercise") } footer: {
                    Text("Match the exercise name in your library and this video appears as a play button inside that exercise during workouts.")
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(draft.existingId == nil ? "New video" : "Edit video")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { Task { await save() } }
                        .disabled(busy || draft.title.trimmingCharacters(in: .whitespaces).isEmpty || draft.videoUrl.isEmpty)
                }
            }
            .fullScreenCover(item: $preview) { VideoPlayerScreen(clip: $0) }
        }
    }

    private func save() async {
        busy = true
        defer { busy = false }
        let body: [String: Any] = [
            "title": draft.title, "description": draft.details, "videoUrl": draft.videoUrl.trimmingCharacters(in: .whitespaces),
            "thumbnailUrl": draft.thumbnailUrl.trimmingCharacters(in: .whitespaces), "category": draft.category,
            "exerciseName": draft.exerciseName, "durationSec": draft.durationText, "featured": draft.featured,
        ]
        do {
            if let id = draft.existingId { _ = try await APIClient.shared.raw("PUT", "/api/admin/videos/\(id)", json: body) }
            else { _ = try await APIClient.shared.raw("POST", "/api/admin/videos", json: body) }
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
