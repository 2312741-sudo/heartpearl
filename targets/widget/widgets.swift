import WidgetKit
import SwiftUI

struct Provider: TimelineProvider {
    func placeholder(in context: Context) -> SimpleEntry {
        SimpleEntry(date: Date(), image: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (SimpleEntry) -> ()) {
        let entry = SimpleEntry(date: Date(), image: nil)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SimpleEntry>) -> ()) {
        // Đọc link ảnh từ UserDefaults chia sẻ qua App Group
        let sharedDefaults = UserDefaults(suiteName: "group.com.tamchau.app")
        let photoUrlString = sharedDefaults?.string(forKey: "latestPhotoUrl") ?? ""
        
        // Tải ảnh bất đồng bộ từ URL
        Task {
            var image: UIImage? = nil
            if !photoUrlString.isEmpty,
               let url = URL(string: photoUrlString) {
                do {
                    let (data, _) = try await URLSession.shared.data(from: url)
                    image = UIImage(data: data)
                } catch {
                    print("Failed to download widget image: \(error)")
                }
            }
            
            let entry = SimpleEntry(date: Date(), image: image)
            let timeline = Timeline(entries: [entry], policy: .never)
            completion(timeline)
        }
    }
}

struct SimpleEntry: TimelineEntry {
    let date: Date
    let image: UIImage?
}

struct widgetEntryView : View {
    var entry: Provider.Entry

    var body: some View {
        GeometryReader { geometry in
            if let image = entry.image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
            } else {
                VStack(spacing: 8) {
                    Text("Tâm Châu")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                    Text("Chưa có ảnh mới")
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(Color(red: 10/255, green: 10/255, blue: 15/255))
            }
        }
    }
}

struct widget: Widget {
    let kind: String = "widget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: Provider()) { entry in
            widgetEntryView(entry: entry)
                .containerBackground(Color(red: 10/255, green: 10/255, blue: 15/255), for: .widget)
        }
        .configurationDisplayName("Tâm Châu Widget")
        .description("Hiển thị ảnh mới nhất từ bạn bè.")
        .supportedFamilies([.systemSmall])
    }
}

#Preview(as: .systemSmall) {
    widget()
} timeline: {
    SimpleEntry(date: .now, image: nil)
}
