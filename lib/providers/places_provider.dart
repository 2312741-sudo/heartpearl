import 'dart:async';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/place_model.dart';
import '../models/user_model.dart';
import '../services/places_service.dart';
import 'friends_provider.dart';

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

final userPlacesProvider = StreamProvider<List<PlaceModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return Stream.value(const []);
  final service = ref.watch(placesServiceProvider);
  return service.streamUserPlaces(uid);
});

class FriendPlace {
  final UserModel friend;
  final PlaceModel place;

  const FriendPlace({
    required this.friend,
    required this.place,
  });
}

final friendsPlacesProvider = StreamProvider<List<FriendPlace>>((ref) {
  final friends = ref.watch(friendsListProvider).value ?? const [];
  if (friends.isEmpty) return Stream.value(const <FriendPlace>[]);

  final service = ref.watch(placesServiceProvider);
  final controller = StreamController<List<FriendPlace>>();
  final latestPlaces = <String, List<PlaceModel>>{};
  final subscriptions = <StreamSubscription>[];

  void emit() {
    if (controller.isClosed) return;
    final all = <FriendPlace>[
      for (final friend in friends)
        for (final place in (latestPlaces[friend.uid] ?? const <PlaceModel>[]))
          FriendPlace(friend: friend, place: place),
    ];
    controller.add(all);
  }

  controller.add(const <FriendPlace>[]);

  for (final friend in friends) {
    subscriptions.add(
      service.streamUserPlaces(friend.uid).listen(
        (places) {
          latestPlaces[friend.uid] = places;
          emit();
        },
        onError: (_) {},
      ),
    );
  }

  ref.onDispose(() {
    for (final s in subscriptions) {
      s.cancel();
    }
    controller.close();
  });

  return controller.stream;
});

