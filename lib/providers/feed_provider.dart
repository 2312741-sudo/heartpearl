import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/photo_model.dart';
import '../services/photo_service.dart';
import 'auth_provider.dart';

final photoServiceProvider = Provider<PhotoService>((ref) {
  return PhotoService();
});

final inboxPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  final photoService = ref.watch(photoServiceProvider);
  return photoService.streamInbox(user.uid);
});

final sentPhotosProvider = StreamProvider<List<PhotoModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  final photoService = ref.watch(photoServiceProvider);
  return photoService.streamSentPhotos(user.uid);
});

final unreadPhotosCountProvider = Provider<int>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) return 0;

  final inboxAsync = ref.watch(inboxPhotosProvider);
  return inboxAsync.maybeWhen(
    data: (photos) =>
        photos.where((p) => p.seen[user.uid] != true).length,
    orElse: () => 0,
  );
});
