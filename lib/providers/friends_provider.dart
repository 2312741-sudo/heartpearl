import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'auth_provider.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

final friendRequestsProvider = StreamProvider<List<FriendRequestModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  final profile = ref.watch(userProfileProvider).value;
  if (user == null || profile == null) {
    return Stream.value([]);
  }

  final service = ref.watch(friendServiceProvider);
  final blockedUsers = profile.blockedUsers.toSet();
  return service
      .streamFriendRequests(user.uid)
      .map(
        (requests) => requests
            .where((request) => !blockedUsers.contains(request.from))
            .toList(),
      );
});

final friendsListProvider = FutureProvider<List<UserModel>>((ref) async {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null || profile.friends.isEmpty) {
    return [];
  }

  final service = ref.watch(friendServiceProvider);
  final visibleFriendIds = profile.friends
      .where((uid) => !profile.blockedUsers.contains(uid))
      .toList();
  return service.getFriendsList(visibleFriendIds);
});

final blockedUsersProvider = FutureProvider<List<UserModel>>((ref) async {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null || profile.blockedUsers.isEmpty) return [];

  final service = ref.watch(friendServiceProvider);
  return service.getUsersByIds(profile.blockedUsers);
});
