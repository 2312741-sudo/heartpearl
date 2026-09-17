import WidgetKit
import SwiftUI

// Timeline Provider reading from App Group: group.com.tamchau.app
struct HeartPearlTimelineProvider: TimelineProvider {
    let appGroupId = "group.com.tamchau.app"

    func placeholder(in context: Context) -> HeartPearlEntry {
        HeartPearlEntry(
            date: Date(),
            image: nil,
            senderName: "Bạn bè",
            caption: "Khoảnh khắc mới",
            isMirrored: false,
            updatedAt: Date()
        )
    }

    func getSnapshot(in context: Context, completion: @escaping (HeartPearlEntry) -> Void) {
        let entry = HeartPearlEntry(
            date: Date(),
            image: nil,
            senderName: "HeartPearl",
            caption: "Chia sẻ khoảnh khắc",
            isMirrored: false,
            updatedAt: Date()
        )
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<HeartPearlEntry>) -> Void) {
        let sharedDefaults = UserDefaults(suiteName: appGroupId)
        let localPath = sharedDefaults?.string(forKey: "latestPhoto") ?? ""
        let photoUrlString = sharedDefaults?.string(forKey: "latestPhotoUrl") ?? ""
        let senderName = sharedDefaults?.string(forKey: "senderName") ?? "HeartPearl"
        let caption = sharedDefaults?.string(forKey: "caption")
        let isMirrored = sharedDefaults?.bool(forKey: "isMirrored") ?? false
        let updatedMillis = sharedDefaults?.double(forKey: "updatedAt") ?? 0
        let updatedDate = updatedMillis > 0 ? Date(timeIntervalSince1970: updatedMillis / 1000) : Date()

        // 1. Try loading from local App Group shared storage (Fastest & Zero Latency)
        if !photoUrlString.isEmpty && !localPath.isEmpty && FileManager.default.fileExists(atPath: localPath),
           let localImage = UIImage(contentsOfFile: localPath) {
            let entry = HeartPearlEntry(
                date: Date(),
                image: localImage,
                senderName: senderName,
                caption: caption,
                isMirrored: isMirrored,
                updatedAt: updatedDate
            )
            let timeline = Timeline(entries: [entry], policy: .atEnd)
            completion(timeline)
            return
        }

        // 2. Otherwise download from remote URL asynchronously
        Task {
            var loadedImage: UIImage? = nil
            if !photoUrlString.isEmpty, let url = URL(string: photoUrlString) {
                do {
                    let config = URLSessionConfiguration.default
                    config.timeoutIntervalForRequest = 10
                    config.timeoutIntervalForResource = 15
                    let session = URLSession(configuration: config)
                    let (data, _) = try await session.data(from: url)
                    loadedImage = UIImage(data: data)
                } catch {
                    print("[HeartPearlWidget] Image download error: \(error)")
                }
            }

            let entry = HeartPearlEntry(
                date: Date(),
                image: loadedImage,
                senderName: senderName,
                caption: caption,
                isMirrored: isMirrored,
                updatedAt: updatedDate
            )
            let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(15 * 60)))
            completion(timeline)
        }
    }
}

// Timeline Entry Data Model
struct HeartPearlEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
    let senderName: String
    let caption: String?
    let isMirrored: Bool
    let updatedAt: Date
}

// SwiftUI Widget View
struct HeartPearlWidgetEntryView: View {
    var entry: HeartPearlTimelineProvider.Entry
    @Environment(\.widgetFamily) var family

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Background Obsidian Layer
                Color(red: 18/255, green: 7/255, blue: 22/255)
                    .ignoresSafeArea()

                if let img = entry.image {
                    // Full bleed image with mirror support
                    Image(uiImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                        .scaleEffect(x: entry.isMirrored ? -1 : 1, y: 1, anchor: .center)
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()

                    // Subtle bottom vignette for readability
                    LinearGradient(
                        colors: [
                            Color.black.opacity(0.0),
                            Color.black.opacity(0.15),
                            Color.black.opacity(0.75)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )

                    // Top HeartPearl Branding Pill
                    VStack {
                        HStack {
                            HStack(spacing: 4) {
                                Image(systemName: "heart.fill")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundColor(Color(red: 255/255, green: 74/255, blue: 110/255))
                                Text("HeartPearl")
                                    .font(.system(size: 10, weight: .bold, design: .rounded))
                                    .foregroundColor(.white)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.black.opacity(0.45))
                            .clipShape(Capsule())

                            Spacer()
                        }
                        .padding(.top, 10)
                        .padding(.leading, 10)

                        Spacer()

                        // Caption & Sender Info (if available)
                        if let caption = entry.caption, !caption.isEmpty {
                            HStack {
                                Text(caption)
                                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                                    .foregroundColor(.white)
                                    .lineLimit(family == .systemMedium ? 2 : 1)
                                    .shadow(color: .black.opacity(0.8), radius: 3, x: 0, y: 1)
                                Spacer()
                            }
                            .padding(.horizontal, 12)
                            .padding(.bottom, 10)
                        }
                    }
                } else {
                    // Empty State: Gorgeous Brand Presentation
                    VStack(spacing: 8) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [
                                            Color(red: 255/255, green: 74/255, blue: 110/255),
                                            Color(red: 200/255, green: 40/255, blue: 90/255)
                                        ],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
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
        }
        .widgetURL(URL(string: "heartpearl://camera"))
    }
}

// Widget Definition
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
        .description("Xem ảnh và khoảnh khắc tức thì từ bạn bè ngay trên màn hình chính.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}
