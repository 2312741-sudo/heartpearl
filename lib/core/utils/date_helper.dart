import 'package:intl/intl.dart';

class DateHelper {
  static String timeAgo(DateTime dateTime, {String lang = 'vi'}) {
    final now = DateTime.now();
    final difference = now.difference(dateTime);

    if (lang == 'vi') {
      if (difference.inSeconds < 45) {
        return 'vừa xong';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes} phút trước';
      } else if (difference.inHours < 24) {
        return '${difference.inHours} giờ trước';
      } else if (difference.inDays == 1) {
        return 'hôm qua';
      } else if (difference.inDays < 7) {
        return '${difference.inDays} ngày trước';
      } else {
        return DateFormat('dd/MM/yyyy').format(dateTime);
      }
    } else {
      if (difference.inSeconds < 45) {
        return 'just now';
      } else if (difference.inMinutes < 60) {
        return '${difference.inMinutes}m ago';
      } else if (difference.inHours < 24) {
        return '${difference.inHours}h ago';
      } else if (difference.inDays == 1) {
        return 'yesterday';
      } else if (difference.inDays < 7) {
        return '${difference.inDays}d ago';
      } else {
        return DateFormat('MMM d, yyyy').format(dateTime);
      }
    }
  }

  static String formatShortTime(DateTime dateTime) {
    return DateFormat('HH:mm').format(dateTime);
  }

  static String formatDateGroup(DateTime dateTime) {
    return DateFormat('dd/MM/yyyy').format(dateTime);
  }
}
