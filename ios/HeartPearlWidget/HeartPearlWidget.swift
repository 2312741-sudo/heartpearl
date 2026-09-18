import WidgetKit
import SwiftUI

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Data Model
// ─────────────────────────────────────────────────────────────────────────────

struct HeartPearlEntry: TimelineEntry {
    let date: Date
    // Photo panel
    let photoImage: UIImage?
    let senderName: String
    let caption: String?
    let isMirrored: Bool
    let updatedAt: Date
    // Location panel
    let mapImage: UIImage?
    let locationFriend: String
    let locationSummary: String?
    let isLocation: Bool
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Timeline Provider
// ─────────────────────────────────────────────────────────────────────────────

struct HeartPearlTimelineProvider: TimelineProvider {
    let appGroupId = "group.com.tamchau.app"

    func placeholder(in context: Context) -> HeartPearlEntry {
        HeartPearlEntry(
            date: Date(), photoImage: nil,
            senderName: "Bạn bè", caption: "Khoảnh khắc mới",
            isMirrored: false, updatedAt: Date(),
            mapImage: nil, locationFriend: "Bạn bè",
            locationSummary: nil, isLocation: false
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HeartPearlEntry) -> Void) {
        completion(HeartPearlEntry(
            date: Date(), photoImage: nil,
            senderName: "HeartPearl", caption: "Chia sẻ khoảnh khắc",
            isMirrored: false, updatedAt: Date(),
            mapImage: nil, locationFriend: "Bạn bè",
            locationSummary: nil, isLocation: false
        ))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeartPearlEntry>) -> Void) {
        let defaults = UserDefaults(suiteName: appGroupId)

        // ── Photo fields ──────────────────────────────────────────────────────
        let localPath     = defaults?.string(forKey: "latestPhoto") ?? ""
        let photoUrl      = defaults?.string(forKey: "latestPhotoUrl") ?? ""
        let senderName    = defaults?.string(forKey: "senderName") ?? "HeartPearl"
        let caption       = defaults?.string(forKey: "caption")
        let isMirrored    = defaults?.bool(forKey: "isMirrored") ?? false
        let updatedMillis = defaults?.double(forKey: "updatedAt") ?? 0
        let updatedDate   = updatedMillis > 0
            ? Date(timeIntervalSince1970: updatedMillis / 1000) : Date()

        // ── Location fields ───────────────────────────────────────────────────
        let isLocation     = defaults?.string(forKey: "widgetMode") == "location"
        let locationMapPath = defaults?.string(forKey: "locationMap") ?? ""
        let locationFriend  = defaults?.string(forKey: "locationFriend") ?? "Bạn bè"
        let locationSummary = defaults?.string(forKey: "locationSummary")

        // Load images
        let photoImage: UIImage? = FileManager.default.fileExists(atPath: localPath)
            ? UIImage(contentsOfFile: localPath) : nil
        let mapImage: UIImage? = !locationMapPath.isEmpty
            && FileManager.default.fileExists(atPath: locationMapPath)
            ? UIImage(contentsOfFile: locationMapPath) : nil

        // For small/medium: if in location mode and map available, refresh often
        let nextRefresh = isLocation && mapImage != nil
            ? Date().addingTimeInterval(20 * 60)   // 20 min for location mode
            : Date().addingTimeInterval(15 * 60)   // 15 min for photo mode

        // If we have both photo and map → always load both for Large
        if photoImage != nil || mapImage != nil {
            let entry = HeartPearlEntry(
                date: Date(),
                photoImage: photoImage,
                senderName: senderName, caption: caption, isMirrored: isMirrored,
                updatedAt: updatedDate,
                mapImage: mapImage,
                locationFriend: locationFriend, locationSummary: locationSummary,
                isLocation: isLocation
            )
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
            return
        }

        // Download photo from URL if no local copy
        Task {
            var downloadedPhoto: UIImage? = nil
            if !photoUrl.isEmpty, let url = URL(string: photoUrl) {
                let config = URLSessionConfiguration.default
                config.timeoutIntervalForRequest = 10
                config.timeoutIntervalForResource = 15
                if let (data, _) = try? await URLSession(configuration: config).data(from: url) {
                    downloadedPhoto = UIImage(data: data)
                }
            }
            let entry = HeartPearlEntry(
                date: Date(),
                photoImage: downloadedPhoto,
                senderName: senderName, caption: caption, isMirrored: isMirrored,
                updatedAt: updatedDate,
                mapImage: mapImage,
                locationFriend: locationFriend, locationSummary: locationSummary,
                isLocation: isLocation
            )
            completion(Timeline(entries: [entry], policy: .after(nextRefresh)))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Shared Branding Pill
// ─────────────────────────────────────────────────────────────────────────────

private struct BrandingPill: View {
    let label: String
    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: "heart.fill")
                .font(.system(size: 9, weight: .bold))
                .foregroundColor(Color(red: 255/255, green: 74/255, blue: 110/255))
            Text(label)
                .font(.system(size: 10, weight: .bold, design: .rounded))
                .foregroundColor(.white)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color.black.opacity(0.45))
        .clipShape(Capsule())
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Empty State
// ─────────────────────────────────────────────────────────────────────────────

private struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [
                            Color(red: 255/255, green: 74/255, blue: 110/255),
                            Color(red: 200/255, green: 40/255, blue: 90/255)
                        ],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 44, height: 44)
                    .shadow(color: Color(red: 255/255, green: 74/255, blue: 110/255).opacity(0.5), radius: 10)
                Image(systemName: "heart.fill")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
            }
            Text("HeartPearl")
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text("Chưa có ảnh mới")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundColor(Color.white.opacity(0.6))
        }
        .padding()
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Single Panel (Photo or Map — used by Small & Medium)
// ─────────────────────────────────────────────────────────────────────────────

private struct SinglePanelView: View {
    let entry: HeartPearlEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 18/255, green: 7/255, blue: 22/255).ignoresSafeArea()

                // Choose which image to show
                let displayImage = entry.isLocation ? entry.mapImage : entry.photoImage
                let displayImage2 = entry.isLocation ? entry.mapImage : (entry.photoImage ?? entry.mapImage)
                let img = displayImage ?? displayImage2

                if let img = img {
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(x: (!entry.isLocation && entry.isMirrored) ? -1 : 1, y: 1, anchor: .center)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    LinearGradient(
                        colors: [.black.opacity(0.0), .black.opacity(0.15), .black.opacity(0.75)],
                        startPoint: .top, endPoint: .bottom
                    )

                    VStack {
                        HStack {
                            BrandingPill(label: entry.isLocation ? "HeartPearl Map" : "HeartPearl")
                            Spacer()
                        }
                        .padding(.top, 10).padding(.leading, 10)

                        Spacer()

                        if entry.isLocation {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(entry.locationFriend)
                                        .font(.system(size: 13, weight: .bold, design: .rounded))
                                        .foregroundColor(.white).lineLimit(1)
                                    if let s = entry.locationSummary {
                                        Text(s)
                                            .font(.system(size: 10, weight: .medium, design: .rounded))
                                            .foregroundColor(.white.opacity(0.85)).lineLimit(1)
                                    }
                                }
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.bottom, 10)
                        } else if let caption = entry.caption, !caption.isEmpty {
                            HStack {
                                Text(caption)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(family == .systemMedium ? 2 : 1)
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                                Spacer()
                            }
                            .padding(.horizontal, 12).padding(.bottom, 10)
                        }
                    }
                } else {
                    EmptyStateView()
                }
            }
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Large Dual-Panel View
// ─────────────────────────────────────────────────────────────────────────────

private struct LargeDualPanelView: View {
    let entry: HeartPearlEntry

    var body: some View {
        GeometryReader { geo in
            ZStack {
                Color(red: 18/255, green: 7/255, blue: 22/255).ignoresSafeArea()

                HStack(spacing: 0) {
                    // ── Left: Photo Panel ─────────────────────────────────────
                    ZStack {
                        Color(red: 12/255, green: 5/255, blue: 18/255)

                        if let photo = entry.photoImage {
                            Image(uiImage: photo)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .scaleEffect(x: entry.isMirrored ? -1 : 1, y: 1, anchor: .center)
                                .frame(width: geo.size.width / 2, height: geo.size.height)
                                .clipped()

                            LinearGradient(
                                colors: [.black.opacity(0), .black.opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            )

                            VStack {
                                HStack {
                                    BrandingPill(label: "HeartPearl")
                                    Spacer()
                                }
                                .padding(.top, 12).padding(.leading, 12)
                                Spacer()
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.senderName)
                                            .font(.system(size: 14, weight: .bold, design: .rounded))
                                            .foregroundColor(.white).lineLimit(1)
                                        if let caption = entry.caption, !caption.isEmpty {
                                            Text(caption)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.8)).lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.bottom, 14)
                            }
                        } else {
                            // No photo yet
                            VStack(spacing: 10) {
                                Image(systemName: "photo")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.25))
                                Text("Chưa có ảnh mới")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                            }
                        }
                    }
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .clipped()

                    // ── Divider ───────────────────────────────────────────────
                    Rectangle()
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color(red: 255/255, green: 74/255, blue: 110/255).opacity(0.0),
                                    Color(red: 255/255, green: 74/255, blue: 110/255).opacity(0.55),
                                    Color(red: 255/255, green: 74/255, blue: 110/255).opacity(0.0),
                                ],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .frame(width: 1.5, height: geo.size.height)

                    // ── Right: Location Map Panel ─────────────────────────────
                    ZStack {
                        Color(red: 9/255, green: 4/255, blue: 13/255)

                        if let map = entry.mapImage {
                            Image(uiImage: map)
                                .resizable()
                                .aspectRatio(contentMode: .fill)
                                .frame(width: geo.size.width / 2, height: geo.size.height)
                                .clipped()

                            LinearGradient(
                                colors: [.black.opacity(0), .black.opacity(0.65)],
                                startPoint: .top, endPoint: .bottom
                            )

                            VStack {
                                HStack {
                                    BrandingPill(label: "Radar")
                                    Spacer()
                                }
                                .padding(.top, 12).padding(.leading, 12)
                                Spacer()
                                HStack {
                                    VStack(alignment: .leading, spacing: 2) {
                                        HStack(spacing: 5) {
                                            Image(systemName: "location.fill")
                                                .font(.system(size: 10))
                                                .foregroundColor(Color(red: 255/255, green: 74/255, blue: 110/255))
                                            Text(entry.locationFriend)
                                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                                .foregroundColor(.white).lineLimit(1)
                                        }
                                        if let s = entry.locationSummary {
                                            Text(s)
                                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                                .foregroundColor(.white.opacity(0.8)).lineLimit(1)
                                        }
                                    }
                                    Spacer()
                                }
                                .padding(.horizontal, 12).padding(.bottom, 14)
                            }
                        } else {
                            // No map yet — prompt user
                            VStack(spacing: 10) {
                                Image(systemName: "map")
                                    .font(.system(size: 32))
                                    .foregroundColor(.white.opacity(0.25))
                                Text("Ghim vị trí bạn bè\ntrong tab Bản đồ")
                                    .font(.system(size: 11, weight: .medium, design: .rounded))
                                    .foregroundColor(.white.opacity(0.35))
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                    .frame(width: geo.size.width / 2, height: geo.size.height)
                    .clipped()
                }
            }
        }
        .widgetURL(URL(string: entry.isLocation ? "heartpearl://map" : "heartpearl://camera"))
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Entry View (dispatches to correct layout by family)
// ─────────────────────────────────────────────────────────────────────────────

struct HeartPearlWidgetEntryView: View {
    var entry: HeartPearlTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        if family == .systemLarge {
            LargeDualPanelView(entry: entry)
        } else {
            SinglePanelView(entry: entry)
                .widgetURL(URL(string: entry.isLocation ? "heartpearl://map" : "heartpearl://camera"))
        }
    }
}

// ─────────────────────────────────────────────────────────────────────────────
// MARK: - Widget Definition
// ─────────────────────────────────────────────────────────────────────────────

struct HeartPearlWidget: Widget {
    let kind: String = "widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: HeartPearlTimelineProvider()) { entry in
            if #available(iOS 17.0, *) {
                HeartPearlWidgetEntryView(entry: entry)
                    .containerBackground(Color(red: 18/255, green: 7/255, blue: 22/255), for: .widget)
            } else {
                HeartPearlWidgetEntryView(entry: entry)
                    .background(Color(red: 18/255, green: 7/255, blue: 22/255))
            }
        }
        .configurationDisplayName("HeartPearl")
        .description("Xem khoảnh khắc và vị trí bạn bè ngay trên màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium, .systemLarge])
    }
}
