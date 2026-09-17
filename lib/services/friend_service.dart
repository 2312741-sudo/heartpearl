import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/friend_request_model.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  // Search users by username prefix
  Future<List<UserModel>> searchUserByUsername(String username) async {
    final clean = username.toLowerCase().trim();
    if (clean.isEmpty) return [];

    final snapshot = await _db
        .collection('users')
        .where('username', isGreaterThanOrEqualTo: clean)
        .where('username', isLessThanOrEqualTo: '$clean\uf8ff')
        .limit(20)
        .get();

    return snapshot.docs.map((doc) => UserModel.fromFirestore(doc)).toList();
  }

  // Send friend request
  Future<void> sendFriendRequest({
    required String fromUid,
    required String toUid,
  }) async {
    if (fromUid == toUid) return;

    // Check if request already exists
    final existing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .get();

    if (existing.docs.isNotEmpty) return;

    final reqRef = await _db.collection('friendRequests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // In-app notification
    try {
      final senderDoc = await _db.collection('users').doc(fromUid).get();
      final senderName = senderDoc.exists
          ? (senderDoc.data()?['displayName'] as String? ?? 'Ai đó')
          : 'Ai đó';

      await _db.collection('notifications').add({
        'userId': toUid,
        'senderId': fromUid,
        'type': 'friend_request',
        'title': 'HeartPearl',
        'body': '👋 $senderName đã gửi cho bạn lời mời kết bạn!',
        'read': false,
        'requestId': reqRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  // Accept friend request
  Future<void> acceptFriendRequest({
    required String requestId,
    required String fromUid,
    required String toUid,
  }) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'accepted',
    });

    // Add friends bidirectionally
    final batch = _db.batch();
    batch.set(
      _db.collection('users').doc(fromUid),
      {
        'friends': FieldValue.arrayUnion([toUid]),
      },
      SetOptions(merge: true),
    );

    batch.set(
      _db.collection('users').doc(toUid),
      {
        'friends': FieldValue.arrayUnion([fromUid]),
      },
      SetOptions(merge: true),
    );

    await batch.commit();
  }

  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  // Stream incoming friend requests
  Stream<List<FriendRequestModel>> streamFriendRequests(String uid) {
    return _db
        .collection('friendRequests')
        .where('to', isEqualTo: uid)
        .where('status', isEqualTo: 'pending')
        .snapshots()
        .asyncMap((snapshot) async {
      final list = <FriendRequestModel>[];
      for (final doc in snapshot.docs) {
        final fromId = doc.data()['from'] as String?;
        UserModel? fromUser;
        if (fromId != null) {
          final userDoc = await _db.collection('users').doc(fromId).get();
          if (userDoc.exists) {
            fromUser = UserModel.fromFirestore(userDoc);
          }
        }
        list.add(FriendRequestModel.fromFirestore(doc, fromUser: fromUser));
      }
      return list;
    });
  }

  // Fetch full list of friends
  Future<List<UserModel>> getFriendsList(List<String> friendIds) async {
    if (friendIds.isEmpty) return [];

    final friends = <UserModel>[];
    for (final id in friendIds) {
      try {
        final doc = await _db.collection('users').doc(id).get();
        if (doc.exists) {
          friends.add(UserModel.fromFirestore(doc));
        }
      } catch (_) {}
    }
    return friends;
  }
}
