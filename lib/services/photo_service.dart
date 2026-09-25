import 'dart:async';
import 'dart:io';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_storage/firebase_storage.dart';
import 'package:flutter/foundation.dart';
import '../core/utils/camera_filters.dart';
import '../core/utils/media_helper.dart';
import '../models/photo_model.dart';
import '../models/user_model.dart';
import 'camera_effects_service.dart';
import 'friend_service.dart';

class PhotoService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;
  final FirebaseStorage _storage = FirebaseStorage.instance;

  // Upload image to Firebase Storage with background isolate optimization and CDN caching
  Future<String> uploadPhoto({
    required File file,
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    // 1. Shrink high-res photo by 90-95% (to ~180-250KB) on separate isolate
    final File optimizedFile = await MediaHelper.optimizePhotoForUpload(file);

    final fileName = '${DateTime.now().millisecondsSinceEpoch}.jpg';
    final ref = _storage.ref().child('photos/$userId/$fileName');

    // 2. Set 1-year immutable cache header for instant edge CDN loading
    final uploadTask = ref.putFile(
      optimizedFile,
      SettableMetadata(
        contentType: 'image/jpeg',
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    final downloadUrl = await snapshot.ref.getDownloadURL();

    // Clean up temporary isolate file if different
    if (optimizedFile.path != file.path) {
      try {
        await optimizedFile.delete();
      } catch (_) {}
    }

    return downloadUrl;
  }

  // Upload video to Firebase Storage
  Future<String> uploadVideo({
    required File file,
    required String userId,
    void Function(double progress)? onProgress,
  }) async {
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.mp4';
    final ref = _storage.ref().child('videos/$userId/$fileName');

    final uploadTask = ref.putFile(
      file,
      SettableMetadata(
        contentType: 'video/mp4',
        cacheControl: 'public, max-age=31536000, immutable',
      ),
    );

    if (onProgress != null) {
      uploadTask.snapshotEvents.listen((event) {
        if (event.totalBytes > 0) {
          final progress = event.bytesTransferred / event.totalBytes;
          onProgress(progress);
        }
      });
    }

    final snapshot = await uploadTask;
    return await snapshot.ref.getDownloadURL();
  }

  // Send photo / video
  Future<String> sendPhoto({
    required String senderId,
    required List<String> recipientIds,
    required String imageUrl,
    String? videoUrl,
    String? caption,
    String mediaType = 'photo',
    bool isMirrored = false,
    bool filter = true,
  }) async {
    final docRef = await _db.collection('photos').add({
      'senderId': senderId,
      'recipientIds': recipientIds,
      'imageUrl': imageUrl,
      'videoUrl': videoUrl,
      'caption': caption,
      'mediaType': mediaType,
      'isMirrored': isMirrored,
      'filter': filter,
      'createdAt': FieldValue.serverTimestamp(),
      'reactions': {},
      'textReactions': {},
      'seen': {},
    });

    // Note: User's own sent photos are not synced to their own widget (widget only shows friends' photos)

    // Create in-app notifications for each recipient
    try {
      final senderDoc = await _db.collection('users').doc(senderId).get();
      final senderData = senderDoc.data();
      final senderName = senderDoc.exists
          ? (senderData?['displayName'] as String? ?? 'Bạn bè')
          : 'Bạn bè';
      final senderAvatar = senderData?['avatarUrl'] as String?;

      final batch = _db.batch();
      for (final recipientId in recipientIds) {
        final notifRef = _db.collection('notifications').doc();
        batch.set(notifRef, {
          'userId': recipientId,
          'senderId': senderId,
          'senderName': senderName,
          'senderAvatarUrl': ?senderAvatar,
          'type': 'photo',
          'title': 'HeartPearl',
          'body': '📸 $senderName vừa chia sẻ khoảnh khắc mới với bạn!',
          'read': false,
          'photoId': docRef.id,
          'createdAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (_) {}

    return docRef.id;
  }

  // Get a single photo by ID
  Future<PhotoModel?> getPhotoById(String photoId) async {
    try {
      final doc = await _db.collection('photos').doc(photoId).get();
      if (!doc.exists) return null;
      final senderId = doc.data()?['senderId'] as String?;
      UserModel? senderUser;
      if (senderId != null) {
        final userDoc = await _db.collection('users').doc(senderId).get();
        if (userDoc.exists) {
          senderUser = UserModel.fromFirestore(userDoc);
        }
      }
      return PhotoModel.fromFirestore(doc, senderUser: senderUser);
    } catch (_) {
      return null;
    }
  }

  // In-memory sender profile cache to avoid redundant Firestore reads
  // across multiple stream events. Keyed by userId, evicted when service is GC'd.
  final Map<String, UserModel> _senderCache = {};

  /// Clear the cached sender profiles to force a fresh fetch from Firestore
  void clearSenderCache() {
    _senderCache.clear();
  }

  /// Publish photo or video in the background without blocking the UI.
  /// Runs completely detached from any widget lifecycle.
  Future<String?> publishMediaInBackground({
    required String senderId,
    required Set<String> recipientUids,
    required String filePath,
    required bool isVideo,
    String? caption,
    BeautyFilter? filter,
    double filterIntensity = 0.65,
    BeautySettings beauty = const BeautySettings(),
    bool isMirrored = false,
  }) async {
    try {
      final activeFilter = filter ?? BeautyFilter.all.first;
      final allowedRecipientIds = await FriendService().filterAllowedRecipients(
        senderUid: senderId,
        recipientUids: recipientUids,
      );

      if (allowedRecipientIds.isEmpty) return null;

      String mediaUrl;
      String? videoUrl;

      if (isVideo) {
        // 1. Generate video thumbnail frame
        final thumbFile = await MediaHelper.generateVideoThumbnail(filePath);
        String? thumbUrl;
        if (thumbFile != null) {
          File thumbToUpload = thumbFile;
          File? renderedThumb;
          if (!activeFilter.isOriginal || beauty.hasEffect) {
            renderedThumb = await CameraEffectsService().renderPhoto(
              source: thumbFile,
              filter: activeFilter,
              filterIntensity: filterIntensity,
              beauty: beauty,
            );
            thumbToUpload = renderedThumb;
          }
          try {
            thumbUrl = await uploadPhoto(
              file: thumbToUpload,
              userId: senderId,
            );
            try {
              await thumbFile.delete();
              if (renderedThumb != null && renderedThumb.path != thumbFile.path) {
                await renderedThumb.delete();
              }
            } catch (_) {}
          } catch (e) {
            debugPrint('Background video thumb error: $e');
          }
        }

        // 2. Hardware Video Compression (reducing from 35MB to ~2MB with fast-start streaming)
        File uploadVideoFile = File(filePath);
        try {
          final compressedPath = await MediaHelper.compressVideo(filePath);
          if (compressedPath != null && compressedPath != filePath) {
            uploadVideoFile = File(compressedPath);
          }
        } catch (e) {
          debugPrint('Background video compression error: $e');
        }

        // 3. Upload video
        videoUrl = await uploadVideo(
          file: uploadVideoFile,
          userId: senderId,
        );

        if (uploadVideoFile.path != filePath) {
          try {
            await uploadVideoFile.delete();
          } catch (_) {}
        }

        mediaUrl = thumbUrl ?? videoUrl;
      } else {
        File photoToUpload = File(filePath);
        File? renderedPhoto;
        if (!activeFilter.isOriginal || beauty.hasEffect) {
          renderedPhoto = await CameraEffectsService().renderPhoto(
            source: photoToUpload,
            filter: activeFilter,
            filterIntensity: filterIntensity,
            beauty: beauty,
          );
          photoToUpload = renderedPhoto;
        }

        mediaUrl = await uploadPhoto(
          file: photoToUpload,
          userId: senderId,
        );

        if (renderedPhoto != null && renderedPhoto.path != filePath) {
          try {
            await renderedPhoto.delete();
          } catch (_) {}
        }
      }

      final docId = await sendPhoto(
        senderId: senderId,
        recipientIds: allowedRecipientIds,
        imageUrl: mediaUrl,
        videoUrl: videoUrl,
        caption: caption?.trim().isNotEmpty == true ? caption!.trim() : null,
        mediaType: isVideo ? 'video' : 'photo',
        isMirrored: isMirrored,
        filter: !activeFilter.isOriginal || beauty.hasEffect,
      );

      return docId;
    } catch (e) {
      debugPrint('PhotoService publishMediaInBackground error: $e');
      return null;
    }
  }

  // Stream Inbox Photos — optimized: parallel sender reads, no N+1 Firestore calls
  Stream<List<PhotoModel>> streamInbox(String userId) {
    return _db
        .collection('photos')
        .where('recipientIds', arrayContains: userId)
        .orderBy('createdAt', descending: true)
        .limit(50)
        .snapshots()
        .asyncMap((snapshot) async {
      // Collect unique sender IDs that are NOT already in the cache
      final uniqueSenderIds = snapshot.docs
          .map((d) => d.data()['senderId'] as String?)
          .whereType<String>()
          .toSet()
          .where((id) => !_senderCache.containsKey(id))
          .toList();

      // Fetch all unknown senders in parallel (one round-trip per unique sender)
      if (uniqueSenderIds.isNotEmpty) {
        final futures = uniqueSenderIds.map(
          (id) => _db.collection('users').doc(id).get(),
        );
        final results = await Future.wait(futures, eagerError: false);
        for (final doc in results) {
          if (doc.exists) {
            _senderCache[doc.id] = UserModel.fromFirestore(doc);
          }
        }
      }

      return snapshot.docs.map((doc) {
        final senderId = doc.data()['senderId'] as String?;
        final senderUser = senderId != null ? _senderCache[senderId] : null;
        return PhotoModel.fromFirestore(doc, senderUser: senderUser);
      }).toList();
    });
  }

  // Stream Sent Photos (Moments / History)
  Stream<List<PhotoModel>> streamSentPhotos(String userId) {
    return _db
        .collection('photos')
        .where('senderId', isEqualTo: userId)
        .orderBy('createdAt', descending: true)
        .limit(100)
        .snapshots()
        .asyncMap((snapshot) async {
      final userDoc = await _db.collection('users').doc(userId).get();
      final currentUser = userDoc.exists ? UserModel.fromFirestore(userDoc) : null;
      return snapshot.docs
          .map((doc) => PhotoModel.fromFirestore(doc, senderUser: currentUser))
          .toList();
    });
  }

  // Delete a single photo/moment
  Future<void> deletePhoto(String photoId) async {
    await _db.collection('photos').doc(photoId).delete();
  }

  // Mark photo as seen
  Future<void> markPhotoAsSeen(String photoId, String userId) async {
    await _db.collection('photos').doc(photoId).update({
      'seen.$userId': true,
    });
  }

  // React to photo with selfie
  Future<void> reactWithSelfie({
    required PhotoModel photo,
    required UserModel currentUser,
    required String selfieUrl,
  }) async {
    await _db.collection('photos').doc(photo.id).update({
      'reactions.${currentUser.uid}': selfieUrl,
    });

    // Notify photo owner
    if (photo.senderId != currentUser.uid) {
      await _db.collection('notifications').add({
        'userId': photo.senderId,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName,
        'senderAvatarUrl': ?currentUser.avatarUrl,
        'type': 'reaction',
        'title': 'HeartPearl',
        'body': '❤️ ${currentUser.displayName} vừa thả selfie vào ảnh của bạn!',
        'read': false,
        'photoId': photo.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync to 1-on-1 chat
      await _syncReactionToChat(
        photo: photo,
        currentUser: currentUser,
        text: 'Đã phản hồi bằng một ảnh selfie',
        photoUrl: selfieUrl,
      );
    }
  }

  // React to photo with text / emoji
  Future<void> reactWithText({
    required PhotoModel photo,
    required UserModel currentUser,
    required String message,
  }) async {
    final trimmed = message.trim();
    if (trimmed.isEmpty) return;

    await _db.collection('photos').doc(photo.id).update({
      'textReactions.${currentUser.uid}': trimmed,
    });

    // Notify photo owner
    if (photo.senderId != currentUser.uid) {
      await _db.collection('notifications').add({
        'userId': photo.senderId,
        'senderId': currentUser.uid,
        'senderName': currentUser.displayName,
        'senderAvatarUrl': ?currentUser.avatarUrl,
        'type': 'message',
        'title': 'HeartPearl',
        'body': '💬 ${currentUser.displayName}: $trimmed',
        'read': false,
        'photoId': photo.id,
        'createdAt': FieldValue.serverTimestamp(),
      });

      // Sync to 1-on-1 chat
      await _syncReactionToChat(
        photo: photo,
        currentUser: currentUser,
        text: trimmed,
      );
    }
  }

  // Helper to sync reaction into direct chat room
  Future<void> _syncReactionToChat({
    required PhotoModel photo,
    required UserModel currentUser,
    required String text,
    String? photoUrl, // selfie URL (for selfie reactions)
  }) async {
    final participants = [currentUser.uid, photo.senderId]..sort();
    final chatId = participants.join('_');

    // Determine the original photo URL to show as context in the bubble.
    // For video posts the imageUrl is the thumbnail; fall back to videoUrl only
    // if no thumbnail was stored.
    final originalPhotoUrl = photo.imageUrl.isNotEmpty
        ? photo.imageUrl
        : photo.videoUrl;

    // Add message — always type 'reaction' so the bubble can render context
    await _db.collection('chats').doc(chatId).collection('messages').add({
      'senderId': currentUser.uid,
      'text': text,
      'photoUrl': photoUrl,           // selfie image (may be null for text reactions)
      'reactedPhotoUrl': originalPhotoUrl, // original photo being reacted to
      'type': 'reaction',
      'status': 'sent',
      'createdAt': FieldValue.serverTimestamp(),
    });

    // Fetch friend doc for chat metadata
    final friendDoc = await _db.collection('users').doc(photo.senderId).get();
    final friendName = friendDoc.exists
        ? (friendDoc.data()?['displayName'] as String? ?? 'Bạn bè')
        : 'Bạn bè';
    final friendAvatar = friendDoc.exists
        ? (friendDoc.data()?['avatarUrl'] as String? ?? '')
        : '';

    await _db.collection('chats').doc(chatId).set({
      'participants': participants,
      'participantsInfo': {
        currentUser.uid: {
          'name': currentUser.displayName,
          'avatar': currentUser.avatarUrl ?? '',
        },
        photo.senderId: {
          'name': friendName,
          'avatar': friendAvatar,
        },
      },
      'lastMessage': photoUrl != null ? '📷 $text' : '💬 $text',
      'updatedAt': FieldValue.serverTimestamp(),
      'unreadCount.${photo.senderId}': FieldValue.increment(1),
    }, SetOptions(merge: true));
  }
}
