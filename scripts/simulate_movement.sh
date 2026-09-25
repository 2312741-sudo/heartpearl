#!/usr/bin/env bash
# ==============================================================================
# HeartPearl - Script giả lập di chuyển trên iOS Simulator
# ==============================================================================

set -e

ACTION="${1:-help}"

case "$ACTION" in
  walk)
    echo "🚶 Đang giả lập ĐI BỘ (Phố Đi Bộ Nguyễn Huệ -> Bến Bạch Đằng, TP.HCM)..."
    echo "   Vận tốc: ~4.3 km/h (1.2 m/s) | Chu kỳ: 2 giây/lần"
    echo "   (Nhấn Ctrl+C để dừng giả lập)"
    xcrun simctl location booted start --speed=1.2 --interval=2 \
      10.775320,106.701780 \
      10.774390,106.702520 \
      10.773480,106.703270 \
      10.772560,106.704010 \
      10.771650,106.704750
    ;;

  drive)
    echo "🚗 Đang giả lập LÁI XE (Bến Bạch Đằng -> Cầu Ba Son -> Thủ Thiêm, TP.HCM)..."
    echo "   Vận tốc: ~36 km/h (10 m/s) | Chu kỳ: 2 giây/lần"
    echo "   (Nhấn Ctrl+C để dừng giả lập)"
    xcrun simctl location booted start --speed=10.0 --interval=2 \
      10.771650,106.704750 \
      10.774500,106.706400 \
      10.777500,106.708100 \
      10.780600,106.710000 \
      10.783800,106.712500
    ;;

  city_run)
    echo "🏃 Đang chạy kịch bản chuẩn Apple: City Run (~5-8 km/h)..."
    echo "   (Chạy './scripts/simulate_movement.sh stop' để dừng)"
    xcrun simctl location booted run "City Run"
    ;;

  bike)
    echo "🚴 Đang chạy kịch bản chuẩn Apple: City Bicycle Ride (~15-20 km/h)..."
    echo "   (Chạy './scripts/simulate_movement.sh stop' để dừng)"
    xcrun simctl location booted run "City Bicycle Ride"
    ;;

  highway)
    echo "🏎️ Đang chạy kịch bản chuẩn Apple: Freeway Drive (~80-100 km/h)..."
    echo "   (Chạy './scripts/simulate_movement.sh stop' để dừng)"
    xcrun simctl location booted run "Freeway Drive"
    ;;

  set)
    LAT="${2:-10.7769}"
    LNG="${3:-106.7009}"
    echo "📍 Đang đặt vị trí cố định: $LAT, $LNG"
    xcrun simctl location booted set "$LAT,$LNG"
    echo "✅ Đã cập nhật tọa độ trên Simulator!"
    ;;

  stop)
    echo "⏹️ Đang dừng giả lập và xóa vị trí trên Simulator..."
    xcrun simctl location booted clear
    echo "✅ Đã dừng giả lập thành công!"
    ;;

  *)
    echo "=========================================================="
    echo " HeartPearl - Công cụ giả lập di chuyển trên iOS Simulator"
    echo "=========================================================="
    echo "Cách dùng: ./scripts/simulate_movement.sh [lệnh]"
    echo ""
    echo "Lệnh có sẵn:"
    echo "  walk      : Đi bộ Phố Đi Bộ Nguyễn Huệ, TP.HCM (~4 km/h)"
    echo "  drive     : Lái xe qua Cầu Ba Son, TP.HCM (~36 km/h)"
    echo "  city_run  : Kịch bản chạy bộ chuẩn của Apple"
    echo "  bike      : Kịch bản đạp xe chuẩn của Apple (~15 km/h)"
    echo "  highway   : Kịch bản xe hơi cao tốc của Apple (~90 km/h)"
    echo "  set <lat> <lng> : Đặt 1 tọa độ cố định"
    echo "  stop      : Dừng giả lập và đưa vị trí về bình thường"
    echo "=========================================================="
    ;;
esac
