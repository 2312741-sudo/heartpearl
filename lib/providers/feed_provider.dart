import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'auth_provider.dart';

import '../services/widget_service.dart';

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});

final inboxPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final profile = ref.watch(userProfileProvider).value;
  if (user == null || profile == null) {
    return Stream.value([]);
  }

  final photoService = ref.watch(photoServiceProvider);

  // Auto-sync friend photos to iOS Widget whenever new photo arrives in stream
  final blockedUsers = profile.blockedUsers.toSet();
  return photoService.streamInbox(user.uid).map((photos) {
    final visiblePhotos = photos
        .where((photo) => !blockedUsers.contains(photo.senderId))
        .toList();
    final friendPhotos = visiblePhotos
        .where((p) => p.senderId != user.uid)
        .toList();
    if (friendPhotos.isNotEmpty) {
      final latest = friendPhotos.first;
      WidgetService.updateLatestPhoto(
        latest.imageUrl,
        caption: latest.caption,
        senderName:
            latest.senderUser?.displayName ??
            latest.senderUser?.username ??
            'Bạn bè',
        isMirrored: latest.isMirrored,
      );
    } else {
      WidgetService.clearWidget();
    }
    return visiblePhotos;
  });
});

final sentPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final profile = ref.watch(userProfileProvider).value;
  if (user == null || profile == null) {
    return Stream.value([]);
  }

  final photoService = ref.watch(photoServiceProvider);
  final blockedUsers = profile.blockedUsers.toSet();
  return photoService
      .streamSentPhotos(user.uid)
      .map(
        (photos) => photos
            .map(
              (photo) => photo.copyWith(
                reactions: Map.fromEntries(
                  photo.reactions.entries.where(
                    (entry) => !blockedUsers.contains(entry.key),
                  ),
                ),
                textReactions: Map.fromEntries(
                  photo.textReactions.entries.where(
                    (entry) => !blockedUsers.contains(entry.key),
                  ),
                ),
              ),
            )
            .toList(),
      );
});

final unreadPhotosCountProvider = Provider<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 0;

  final inboxAsync = ref.watch(inboxPhotosProvider);
  return inboxAsync.maybeWhen(
    data: (photos) => photos.where((p) => p.seen[user.uid] != true).length,
    orElse: () => 0,
  );
});
