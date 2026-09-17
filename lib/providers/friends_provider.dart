import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';
import '../services/friend_service.dart';
import 'auth_provider.dart';

final friendServiceProvider = Provider<FriendService>((ref) {
  return FriendService();
});

final friendRequestsProvider =
    StreamProvider<List<FriendRequestModel>>((ref) {
  final user = ref.watch(authStateProvider).value;
  if (user == null) {
    return Stream.value([]);
  }

  final service = ref.watch(friendServiceProvider);
  return service.streamFriendRequests(user.uid);
});

final friendsListProvider = FutureProvider<List<UserModel>>((ref) async {
  final profile = ref.watch(userProfileProvider).value;
  if (profile == null || profile.friends.isEmpty) {
    return [];
  }

  final service = ref.watch(friendServiceProvider);
  return await service.getFriendsList(profile.friends);
});
