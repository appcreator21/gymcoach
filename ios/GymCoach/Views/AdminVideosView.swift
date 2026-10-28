import PhotosUI
import SwiftUI
import UniformTypeIdentifiers

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
                            Text([clip.category, clip.exerciseName.map { "Demo: \($0)" }, clip.workoutName.map { "Workout: \($0)" }, clip.durationLabel].compactMap { $0 }.joined(separator: "  -  "))
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
    var workoutName = ""
    var durationText = ""
    var featured = false
    /// The link the video had when it was opened, to notice when it is replaced.
    var originalVideoUrl = ""
    var hadUpload = false

    init() {}

    init(clip: VideoClip) {
        existingId = clip.id
        title = clip.title
        details = clip.description ?? ""
        videoUrl = clip.videoUrl
        originalVideoUrl = clip.videoUrl
        thumbnailUrl = clip.thumbnailUrl ?? ""
        category = clip.category
        exerciseName = clip.exerciseName ?? ""
        workoutName = clip.workoutName ?? ""
        durationText = clip.durationSec.map(String.init) ?? ""
        featured = clip.featured
        hadUpload = clip.storageKey != nil
    }
}

struct VideoEditorSheet: View {
    @Environment(AppState.self) private var app
    @Environment(\.dismiss) private var dismiss
    @State var draft: VideoDraft
    @State private var uploader = VideoUploader()
    @State private var storage: StorageStatus?
    @State private var pickerItem: PhotosPickerItem?
    @State private var showFiles = false
    @State private var pickedFile: URL?
    @State private var pickedLabel = ""
    @State private var loadingPick = false
    @State private var busy = false
    @State private var error: String?
    @State private var preview: VideoClip?
    @State private var pickExercise = false

    init(draft: VideoDraft) { _draft = State(initialValue: draft) }

    private var workoutNames: [String] {
        var seen: [String] = []
        for name in (app.program?.workouts ?? []).map(\.name) where !seen.contains(name) { seen.append(name) }
        return seen
    }

    private var canSave: Bool {
        !busy && !draft.title.trimmingCharacters(in: .whitespaces).isEmpty && (pickedFile != nil || !draft.videoUrl.isEmpty)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Title") { TextField("Title", text: $draft.title) }
                uploadSection
                Section {
                    TextField("Or paste a video link (https, .mp4)", text: $draft.videoUrl)
                        .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                        .disabled(pickedFile != nil)
                    if pickedFile == nil {
                        TextField("Thumbnail link (optional)", text: $draft.thumbnailUrl)
                            .keyboardType(.URL).textInputAutocapitalization(.never).autocorrectionDisabled()
                    }
                    Button("Preview") { startPreview() }
                } header: { Text("Link") } footer: {
                    Text("Links work without any storage set up. An uploaded video fills these in for you.")
                }
                Section("Details") {
                    Picker("Category", selection: $draft.category) {
                        ForEach(VideoCategories.all, id: \.self) { Text($0).tag($0) }
                    }
                    TextField("Description (optional)", text: $draft.details, axis: .vertical).lineLimit(1...4)
                    if pickedFile == nil {
                        TextField("Length in seconds (optional)", text: $draft.durationText).keyboardType(.numberPad)
                    }
                    Toggle("Feature on Today", isOn: $draft.featured)
                }
                Section {
                    HStack {
                        TextField("Exercise name", text: $draft.exerciseName)
                        Button { pickExercise = true } label: { Image(systemName: "list.bullet") }.buttonStyle(.borderless)
                    }
                    HStack {
                        TextField("Workout name", text: $draft.workoutName)
                        if !workoutNames.isEmpty {
                            Menu {
                                ForEach(workoutNames, id: \.self) { name in Button(name) { draft.workoutName = name } }
                            } label: { Image(systemName: "list.bullet") }
                        }
                    }
                } header: { Text("Link it") } footer: {
                    Text("Exercise: a play button appears on that exercise during workouts. Workout: a walkthrough button appears on that workout. Names match without caring about capitals or punctuation.")
                }
                if let error { Text(error).foregroundStyle(.red).font(.footnote) }
            }
            .scrollContentBackground(.hidden)
            .background(Theme.background)
            .navigationTitle(draft.existingId == nil ? "New video" : "Edit video")
            .navigationBarTitleDisplayMode(.inline)
            .interactiveDismissDisabled(busy)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() }.disabled(busy) }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { Task { await save() } }.disabled(!canSave) }
            }
            .fullScreenCover(item: $preview) { VideoPlayerScreen(clip: $0) }
            .sheet(isPresented: $pickExercise) {
                ExercisePickerSheet(excluding: [], title: "Link to exercise") { draft.exerciseName = $0.name }
            }
            .fileImporter(isPresented: $showFiles, allowedContentTypes: [.movie, .mpeg4Movie, .quickTimeMovie]) { result in
                Task { await importFile(result) }
            }
            .onChange(of: pickerItem) { _, item in if let item { Task { await loadPhoto(item) } } }
            .task { storage = try? await APIClient.shared.get("/api/admin/storage") }
            .overlay { if busy { busyOverlay } }
        }
    }

    // MARK: Upload section

    @ViewBuilder
    private var uploadSection: some View {
        Section {
            if let storage, storage.configured {
                if let pickedFile {
                    HStack {
                        Image(systemName: "film.fill").foregroundStyle(Theme.accent)
                        VStack(alignment: .leading) {
                            Text(pickedLabel.isEmpty ? pickedFile.lastPathComponent : pickedLabel).lineLimit(1)
                            Text("Ready to upload").font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button("Remove") { clearPick() }.font(.footnote)
                    }
                } else {
                    PhotosPicker(selection: $pickerItem, matching: .videos) {
                        Label(draft.hadUpload ? "Replace video from Photos" : "Choose video from Photos", systemImage: "photo.on.rectangle")
                    }
                    Button { showFiles = true } label: { Label("Choose from Files", systemImage: "folder") }
                }
                if loadingPick { HStack { ProgressView(); Text("Loading the video...").font(.footnote).foregroundStyle(.secondary) } }
            } else if storage != nil {
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "externaldrive.badge.xmark").foregroundStyle(Theme.amber)
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Uploads are not connected yet").font(.subheadline.weight(.semibold))
                        Text("Add the Cloudflare R2 settings to the server to turn on uploading from your phone. Until then, paste a link below.")
                            .font(.footnote).foregroundStyle(.secondary)
                    }
                }
            } else {
                HStack { ProgressView(); Text("Checking storage...").font(.footnote).foregroundStyle(.secondary) }
            }
        } header: { Text("Upload") } footer: {
            if let storage, storage.configured {
                Text("The video is converted to an iPhone friendly MP4 and uploaded to your storage. Up to \(storage.maxMb) MB.")
            }
        }
    }

    private var busyOverlay: some View {
        ZStack {
            Color.black.opacity(0.55).ignoresSafeArea()
            VStack(spacing: 14) {
                if uploader.isWorking {
                    ProgressView(value: uploader.progress).tint(Theme.accent).frame(width: 220)
                    Text(uploader.stage).font(.subheadline.weight(.semibold))
                    if uploader.progress > 0 { Text("\(Int(uploader.progress * 100))%").font(.caption.monospacedDigit()).foregroundStyle(.secondary) }
                } else {
                    ProgressView()
                    Text("Saving").font(.subheadline.weight(.semibold))
                }
            }
            .padding(26)
            .background(Color(white: 0.14), in: RoundedRectangle(cornerRadius: 18, style: .continuous))
        }
    }

    // MARK: Picking

    private func clearPick() {
        if let pickedFile { try? FileManager.default.removeItem(at: pickedFile) }
        pickedFile = nil
        pickedLabel = ""
        pickerItem = nil
    }

    private func loadPhoto(_ item: PhotosPickerItem) async {
        loadingPick = true
        error = nil
        defer { loadingPick = false }
        do {
            guard let movie = try await item.loadTransferable(type: PickedMovie.self) else {
                error = "That video could not be loaded."
                return
            }
            setPicked(movie.url)
        } catch { self.error = error.localizedDescription }
    }

    private func importFile(_ result: Result<URL, Error>) async {
        switch result {
        case .failure(let failure):
            error = failure.localizedDescription
        case .success(let url):
            let scoped = url.startAccessingSecurityScopedResource()
            defer { if scoped { url.stopAccessingSecurityScopedResource() } }
            let ext = url.pathExtension.isEmpty ? "mov" : url.pathExtension
            let copy = FileManager.default.temporaryDirectory.appendingPathComponent("\(UUID().uuidString).\(ext)")
            do {
                try FileManager.default.copyItem(at: url, to: copy)
                pickedLabel = url.lastPathComponent
                setPicked(copy)
            } catch { self.error = error.localizedDescription }
        }
    }

    private func setPicked(_ url: URL) {
        if let pickedFile, pickedFile != url { try? FileManager.default.removeItem(at: pickedFile) }
        pickedFile = url
        if draft.title.trimmingCharacters(in: .whitespaces).isEmpty {
            draft.title = pickedLabel.isEmpty ? "" : (pickedLabel as NSString).deletingPathExtension
        }
    }

    private func startPreview() {
        let target: URL?
        if let pickedFile { target = pickedFile }
        else if let url = URL(string: draft.videoUrl.trimmingCharacters(in: .whitespaces)), url.scheme == "https" { target = url }
        else { target = nil }
        guard let target else { error = "Choose a video or enter a full https link first."; return }
        error = nil
        preview = VideoClip(id: "preview", title: draft.title.isEmpty ? "Preview" : draft.title, description: nil,
                            videoUrl: target.absoluteString, thumbnailUrl: nil, category: draft.category,
                            exerciseName: nil, durationSec: nil, featured: false, createdAt: Date())
    }

    // MARK: Save

    private func save() async {
        busy = true
        error = nil
        defer { busy = false }

        var body: [String: Any] = [
            "title": draft.title, "description": draft.details, "category": draft.category,
            "exerciseName": draft.exerciseName, "workoutName": draft.workoutName, "featured": draft.featured,
        ]

        if let pickedFile {
            guard let storage, storage.configured else { error = UploadError.notConfigured.localizedDescription; return }
            do {
                let result = try await uploader.upload(source: pickedFile, title: draft.title, maxMb: storage.maxMb)
                body["videoUrl"] = result.videoUrl
                body["thumbnailUrl"] = result.thumbnailUrl ?? draft.thumbnailUrl
                body["durationSec"] = result.durationSec
                body["storageKey"] = result.storageKey
                if let key = result.thumbnailKey { body["thumbnailKey"] = key }
            } catch {
                self.error = error.localizedDescription
                Haptics.warning()
                return
            }
        } else {
            body["videoUrl"] = draft.videoUrl.trimmingCharacters(in: .whitespaces)
            body["thumbnailUrl"] = draft.thumbnailUrl.trimmingCharacters(in: .whitespaces)
            body["durationSec"] = draft.durationText
            // A pasted link replaces an uploaded file, so the stored file is released.
            if draft.hadUpload, draft.videoUrl != draft.originalVideoUrl {
                body["storageKey"] = NSNull()
                body["thumbnailKey"] = NSNull()
            }
        }

        do {
            if let id = draft.existingId { _ = try await APIClient.shared.raw("PUT", "/api/admin/videos/\(id)", json: body) }
            else { _ = try await APIClient.shared.raw("POST", "/api/admin/videos", json: body) }
            if let pickedFile { try? FileManager.default.removeItem(at: pickedFile) }
            await app.reloadVideos()
            Haptics.success()
            dismiss()
        } catch { self.error = error.localizedDescription }
    }
}
