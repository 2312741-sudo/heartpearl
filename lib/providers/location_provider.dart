import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/location_model.dart';
import '../models/user_model.dart';
import '../services/location_service.dart';
import 'friends_provider.dart';

export '../services/location_service.dart' show LocationTrackingStatus;

class FriendLocation {
  final UserModel friend;
  final LocationModel location;

  const FriendLocation({required this.friend, required this.location});
}

final locationServiceProvider = Provider<LocationService>((ref) {
  final service = LocationService();
  ref.onDispose(() => unawaited(service.dispose()));
  return service;
});

final ownLocationProvider = StreamProvider<LocationModel?>((ref) {
  return ref.watch(locationServiceProvider).streamOwnLocation();
});

final locationTrackingStatusProvider = StreamProvider<LocationTrackingStatus>((
  ref,
) {
  final service = ref.watch(locationServiceProvider);
  return service.statusStream;
});

/// Keeps the single shared location stream aligned with the persisted sharing
/// setting. MainScaffold watches this provider for the signed-in app lifetime.
final locationTrackingBootstrapProvider = Provider<void>((ref) {
  final service = ref.watch(locationServiceProvider);
  final sharing = ref.watch(ownLocationProvider).value?.isSharing == true;
  if (sharing) {
    Future.microtask(() async {
      try {
        await service.startTracking();
      } catch (_) {}
    });
  } else {
    Future.microtask(() async {
      try {
        await service.stopTracking();
      } catch (_) {}
    });
  }
});

/// Direct per-document listeners are intentional. Firestore Rules are not
/// result filters, so a collection query cannot securely express a different
/// allowedViewers list for every friend location document.
final friendLocationsProvider = StreamProvider<List<FriendLocation>>((ref) {
  final friends = ref.watch(friendsListProvider).value ?? const <UserModel>[];
  if (friends.isEmpty) return Stream.value(const <FriendLocation>[]);

  final service = ref.watch(locationServiceProvider);
  final controller = StreamController<List<FriendLocation>>();
  final latest = <String, LocationModel>{};
  final subscriptions = <StreamSubscription<LocationModel?>>[];

  void emit() {
    if (controller.isClosed) return;
    final visible = <FriendLocation>[
      for (final friend in friends)
        if (latest[friend.uid] case final location?)
          FriendLocation(friend: friend, location: location),
    ]..sort(
      (first, second) =>
          second.location.timestamp.compareTo(first.location.timestamp),
    );
    controller.add(visible);
  }

  controller.onListen = () {
    controller.add(const <FriendLocation>[]);
    for (final friend in friends) {
      subscriptions.add(
        service.streamFriendLocation(friend.uid).listen(
          (location) {
            if (location == null) {
              latest.remove(friend.uid);
            } else {
              latest[friend.uid] = location;
            }
            emit();
          },
          onError: (Object _) {
            latest.remove(friend.uid);
            emit();
          },
        ),
      );
    }
  };
  controller.onCancel = () async {
    for (final subscription in subscriptions) {
      await subscription.cancel();
    }
    subscriptions.clear();
  };
  ref.onDispose(() {
    for (final subscription in subscriptions) {
      unawaited(subscription.cancel());
    }
    unawaited(controller.close());
  });
  return controller.stream;
});
