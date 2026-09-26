import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../models/friend_request_model.dart';
import '../models/user_model.dart';

class FriendService {
  final FirebaseFirestore _db;
  final FirebaseAuth _auth;

  FriendService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _db = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  Future<void> blockUser(String targetUid) async {
    final currentUid = _requireCurrentUid();
    final cleanTargetUid = targetUid.trim();
    if (cleanTargetUid.isEmpty || cleanTargetUid == currentUid) {
      throw ArgumentError('Không thể chặn người dùng này.');
    }

    try {
      await _db.collection('users').doc(currentUid).set({
        'blockedUsers': FieldValue.arrayUnion([cleanTargetUid]),
      }, SetOptions(merge: true));

      // Apple Guideline 1.2: Blocking must automatically notify the developer
      await _db.collection('reports').add({
        'type': 'block_incident_report',
        'reporterUid': currentUid,
        'targetUid': cleanTargetUid,
        'reason': 'abusive_behavior_blocked',
        'note': 'Người dùng bị chặn do hành vi lạm dụng hoặc nội dung phản cảm. Đã gỡ khỏi bảng tin tức thì.',
        'developerNotified': true,
        'status': 'pending_24h_review',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw Exception('Không thể chặn người dùng: $error');
    }
  }

  Future<void> unblockUser(String targetUid) async {
    final currentUid = _requireCurrentUid();
    final cleanTargetUid = targetUid.trim();
    if (cleanTargetUid.isEmpty || cleanTargetUid == currentUid) {
      throw ArgumentError('Không thể bỏ chặn người dùng này.');
    }

    try {
      await _db.collection('users').doc(currentUid).set({
        'blockedUsers': FieldValue.arrayRemove([cleanTargetUid]),
      }, SetOptions(merge: true));
    } catch (error) {
      throw Exception('Không thể bỏ chặn người dùng: $error');
    }
  }

  Future<void> reportUser({
    required String targetUid,
    required String reason,
    String note = '',
  }) async {
    final reporterUid = _requireCurrentUid();
    final cleanTargetUid = targetUid.trim();
    final cleanReason = reason.trim();
    final cleanNote = note.trim();

    if (cleanTargetUid.isEmpty || cleanTargetUid == reporterUid) {
      throw ArgumentError('Không thể báo cáo người dùng này.');
    }
    if (cleanReason.isEmpty) {
      throw ArgumentError('Vui lòng chọn lý do báo cáo.');
    }
    if (cleanNote.length > 500) {
      throw ArgumentError('Mô tả báo cáo không được vượt quá 500 ký tự.');
    }

    try {
      await _db.collection('reports').add({
        'type': 'user_report',
        'reporterUid': reporterUid,
        'targetUid': cleanTargetUid,
        'reason': cleanReason,
        'note': cleanNote,
        'developerNotified': true,
        'status': 'pending_24h_review',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw Exception('Không thể gửi báo cáo: $error');
    }
  }

  Future<void> reportPhoto({
    required String photoId,
    required String targetUid,
    required String reason,
    String note = '',
  }) async {
    final reporterUid = _requireCurrentUid();
    final cleanPhotoId = photoId.trim();
    final cleanTargetUid = targetUid.trim();
    final cleanReason = reason.trim();
    final cleanNote = note.trim();

    if (cleanPhotoId.isEmpty ||
        cleanTargetUid.isEmpty ||
        cleanTargetUid == reporterUid) {
      throw ArgumentError('Thông tin báo cáo khoảnh khắc không hợp lệ.');
    }
    if (cleanReason.isEmpty) {
      throw ArgumentError('Vui lòng chọn lý do báo cáo.');
    }
    if (cleanNote.length > 500) {
      throw ArgumentError('Mô tả báo cáo không được vượt quá 500 ký tự.');
    }

    try {
      await _db.collection('reports').add({
        'type': 'photo_report',
        'photoId': cleanPhotoId,
        'targetUid': cleanTargetUid,
        'reporterUid': reporterUid,
        'reason': cleanReason,
        'note': cleanNote,
        'developerNotified': true,
        'status': 'pending_24h_review',
        'timestamp': FieldValue.serverTimestamp(),
      });
    } catch (error) {
      throw Exception('Không thể gửi báo cáo khoảnh khắc: $error');
    }
  }

  Future<bool> isInteractionBlocked(String firstUid, String secondUid) async {
    final cleanFirstUid = firstUid.trim();
    final cleanSecondUid = secondUid.trim();
    if (cleanFirstUid.isEmpty || cleanSecondUid.isEmpty) return true;
    if (cleanFirstUid == cleanSecondUid) return false;

    try {
      final documents = await Future.wait([
        _db.collection('users').doc(cleanFirstUid).get(),
        _db.collection('users').doc(cleanSecondUid).get(),
      ]);
      final firstBlocked = _blockedUsersFromData(documents[0].data());
      final secondBlocked = _blockedUsersFromData(documents[1].data());
      return firstBlocked.contains(cleanSecondUid) ||
          secondBlocked.contains(cleanFirstUid);
    } catch (error) {
      throw Exception('Không thể kiểm tra trạng thái chặn: $error');
    }
  }

  Future<List<String>> filterAllowedRecipients({
    required String senderUid,
    required Iterable<String> recipientUids,
  }) async {
    final allowed = <String>[];
    for (final recipientUid in recipientUids.toSet()) {
      if (!await isInteractionBlocked(senderUid, recipientUid)) {
        allowed.add(recipientUid);
      }
    }
    return allowed;
  }

  String _requireCurrentUid() {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để thực hiện thao tác này.');
    }
    return uid;
  }

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
    if (await isInteractionBlocked(fromUid, toUid)) {
      throw StateError('Không thể gửi lời mời do cài đặt chặn.');
    }

    // 1. Check if already friends
    final senderDoc = await _db.collection('users').doc(fromUid).get();
    final friends =
        (senderDoc.data()?['friends'] as List?)?.cast<String>() ?? [];
    if (friends.contains(toUid)) {
      throw StateError('Hai người đã là bạn bè.');
    }

    // 2. Check if request already exists in this direction
    final existing = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (existing.docs.isNotEmpty) return;

    // 3. Check inverse direction: if target already sent a request to fromUid, auto-accept
    final inverse = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: toUid)
        .where('to', isEqualTo: fromUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (inverse.docs.isNotEmpty) {
      final inverseReq = inverse.docs.first;
      await acceptFriendRequest(
        requestId: inverseReq.id,
        fromUid: toUid,
        toUid: fromUid,
      );
      return;
    }

    // 4. Create new pending friend request
    final reqRef = await _db.collection('friendRequests').add({
      'from': fromUid,
      'to': toUid,
      'status': 'pending',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // In-app notification
    try {
      final senderData = senderDoc.data();
      final senderName = senderDoc.exists
          ? (senderData?['displayName'] as String? ?? 'Ai đó')
          : 'Ai đó';
      final senderAvatar = senderData?['avatarUrl'] as String?;

      await _db.collection('notifications').add({
        'userId': toUid,
        'senderId': fromUid,
        'senderName': senderName,
        'senderAvatarUrl': ?senderAvatar,
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
    if (await isInteractionBlocked(fromUid, toUid)) {
      throw StateError('Không thể chấp nhận lời mời do cài đặt chặn.');
    }
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'accepted',
    });

    // Note: Mutually updating friends array is handled atomically
    // by Cloud Function onFriendRequestAccepted via Admin SDK.

    // In-app notification for accept
    try {
      final toDoc = await _db.collection('users').doc(toUid).get();
      final toData = toDoc.data();
      final toName = toDoc.exists
          ? (toData?['displayName'] as String? ?? 'Bạn bè')
          : 'Bạn bè';
      final toAvatar = toData?['avatarUrl'] as String?;

      await _db.collection('notifications').add({
        'userId': fromUid,
        'senderId': toUid,
        'senderName': toName,
        'senderAvatarUrl': ?toAvatar,
        'type': 'friend_accept',
        'title': 'HeartPearl',
        'body': '🎉 $toName đã đồng ý lời mời kết bạn của bạn!',
        'read': false,
        'requestId': requestId,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (_) {}
  }

  /// Checks pending friend request status between [currentUid] and [targetUid].
  /// Returns:
  /// - 'sent' if [currentUid] sent a pending request to [targetUid]
  /// - 'received' if [targetUid] sent a pending request to [currentUid]
  /// - null if no pending request exists
  Future<String?> getRequestStatusBetween(
    String currentUid,
    String targetUid,
  ) async {
    final cleanCurrent = currentUid.trim();
    final cleanTarget = targetUid.trim();
    if (cleanCurrent.isEmpty || cleanTarget.isEmpty) return null;

    final results = await Future.wait([
      _db
          .collection('friendRequests')
          .where('from', isEqualTo: cleanCurrent)
          .where('to', isEqualTo: cleanTarget)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get(),
      _db
          .collection('friendRequests')
          .where('from', isEqualTo: cleanTarget)
          .where('to', isEqualTo: cleanCurrent)
          .where('status', isEqualTo: 'pending')
          .limit(1)
          .get(),
    ]);

    if (results[0].docs.isNotEmpty) return 'sent';
    if (results[1].docs.isNotEmpty) return 'received';
    return null;
  }
  // Reject friend request
  Future<void> rejectFriendRequest(String requestId) async {
    await _db.collection('friendRequests').doc(requestId).update({
      'status': 'rejected',
    });
  }

  /// Accept a pending friend request from [fromUid] to [toUid] without needing requestId.
  Future<void> acceptPendingRequestFrom({
    required String fromUid,
    required String toUid,
  }) async {
    final snapshot = await _db
        .collection('friendRequests')
        .where('from', isEqualTo: fromUid)
        .where('to', isEqualTo: toUid)
        .where('status', isEqualTo: 'pending')
        .limit(1)
        .get();

    if (snapshot.docs.isNotEmpty) {
      await acceptFriendRequest(
        requestId: snapshot.docs.first.id,
        fromUid: fromUid,
        toUid: toUid,
      );
    }
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

  Future<List<UserModel>> getUsersByIds(Iterable<String> userIds) async {
    final users = <UserModel>[];
    for (final id in userIds.toSet()) {
      if (id.isEmpty) continue;
      try {
        final doc = await _db.collection('users').doc(id).get();
        if (doc.exists) {
          users.add(UserModel.fromFirestore(doc));
        } else {
          users.add(_missingUser(id));
        }
      } catch (_) {
        users.add(_missingUser(id));
      }
    }
    return users;
  }
}

UserModel _missingUser(String uid) {
  return UserModel(
    uid: uid,
    displayName: 'Người dùng không còn tồn tại',
    username: uid,
    createdAt: DateTime.fromMillisecondsSinceEpoch(0),
  );
}

Set<String> _blockedUsersFromData(Map<String, dynamic>? data) {
  final raw = data?['blockedUsers'];
  if (raw is! Iterable) return const {};
  return raw.whereType<String>().toSet();
}
