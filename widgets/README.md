# Hướng dẫn tích hợp Widget (iOS & Android) cho Locket Clone

Tâm Châu (Locket Clone) được xây dựng bằng **Expo Go** (Managed Workflow). Để có thể tạo và chạy Native Widgets trên màn hình chính của điện thoại (Home Screen), bạn sẽ cần chuyển dự án sang **Custom Dev Client (Prebuild)** vì tính năng này yêu cầu mã Swift (iOS) và Kotlin (Android).

## 1. Cài đặt các thư viện cần thiết

Bạn hãy mở Terminal và chạy lệnh sau để cài plugin hỗ trợ Widget:

```bash
npx expo install react-native-android-widget
npx expo install @bacons/apple-targets
```

## 2. Cấu hình `app.json`

Thêm cấu hình `@bacons/apple-targets` vào file `app.json` (trong phần `plugins`) để Expo tự động tạo Extension Target cho iOS:

```json
"plugins": [
  [
    "@bacons/apple-targets",
    {
      "appleTeamId": "YOUR_APPLE_TEAM_ID",
      "targets": [
        {
          "type": "widget",
          "name": "TamChauWidget",
          "colors": {
            "$AccentColor": "#E6F4FE",
            "$WidgetBackground": "#0A0A0F"
          }
        }
      ]
    }
  ],
  "react-native-android-widget"
]
```

## 3. Tạo mã Swift cho iOS (Tùy chọn)

Sau khi chạy lệnh `npx expo prebuild`, Expo sẽ tạo ra thư mục `targets/TamChauWidget/`. Bạn có thể chỉnh sửa file `TamChauWidget.swift` để thiết kế giao diện Widget bằng **SwiftUI**. 

- Để tải ảnh mới nhất từ Firebase Storage lên Widget, hãy sử dụng `URLSession` trong Swift để gọi API tải hình ảnh và hiển thị bằng `Image(uiImage:)`.

## 4. Tạo mã React Native cho Android Widget

Thư viện `react-native-android-widget` cho phép bạn viết UI cho Android Widget trực tiếp bằng React Native!

Bạn có thể tạo một component như sau:

```tsx
import React from 'react';
import { FlexWidget, TextWidget, ImageWidget } from 'react-native-android-widget';

export function TamChauWidgetPreview({ imageUrl }) {
  return (
    <FlexWidget style={{ height: 'match_parent', width: 'match_parent', borderRadius: 16 }}>
      <ImageWidget
        image={imageUrl}
        imageWidth="match_parent"
        imageHeight="match_parent"
      />
    </FlexWidget>
  );
}
```

## 5. Build ứng dụng

Cuối cùng, chạy các lệnh sau để compile mã nguồn Native:

- **Cho iOS:** `npx expo run:ios`
- **Cho Android:** `npx expo run:android`

*Chú ý: Bạn sẽ cần máy tính Mac để build iOS Widget, và cài đặt Android Studio để build Android Widget.*
