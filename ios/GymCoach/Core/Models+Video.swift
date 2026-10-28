import Foundation

struct VideoClip: Codable, Identifiable, Hashable {
    let id: String
    let title: String
    let description: String?
    let videoUrl: String
    let thumbnailUrl: String?
    let category: String
    let exerciseName: String?
    let durationSec: Int?
    let featured: Bool
    let createdAt: Date

    var url: URL? { URL(string: videoUrl) }
    var thumbnail: URL? { thumbnailUrl.flatMap { URL(string: $0) } }
    var durationLabel: String? { durationSec.map { String(format: "%d:%02d", $0 / 60, $0 % 60) } }
}

enum VideoCategories {
    static let all = ["Workouts", "Technique", "Tips", "Mobility", "Nutrition", "Motivation"]
}

extension AppState {
    /// Lower-cased, punctuation-free, so "Barbell Back-Squat" matches "barbell back squat".
    static func normalizedName(_ name: String) -> String {
        name.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }.joined(separator: " ")
    }

    /// A demo video the coach linked to this exercise, if any.
    func demoVideo(for exerciseName: String) -> VideoClip? {
        let key = AppState.normalizedName(exerciseName)
        return videos.first { $0.exerciseName.map(AppState.normalizedName) == key }
    }

    var featuredVideo: VideoClip? { videos.first { $0.featured } ?? videos.first }

    func reloadVideos() async {
        if let fresh: [VideoClip] = try? await APIClient.shared.get("/api/videos") { videos = fresh }
    }
}
