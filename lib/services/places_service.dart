import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import '../models/place_model.dart';
import 'location_policy.dart';

class PlacesService {
  final FirebaseFirestore? firestore;
  final FirebaseAuth? auth;

  // Local cache for rapid geofence matching during GPS fixes
  List<PlaceModel> _cachedPlaces = [];
  final Map<String, List<PlaceModel>> _cachedFriendsPlaces = {};

  PlacesService({
    this.firestore,
    this.auth,
  });

  FirebaseFirestore get _db => firestore ?? FirebaseFirestore.instance;
  FirebaseAuth get _auth => auth ?? FirebaseAuth.instance;

  CollectionReference<Map<String, dynamic>> _placesCollection(String uid) =>
      _db.collection('users').doc(uid).collection('places');

  List<PlaceModel> get cachedPlaces => List.unmodifiable(_cachedPlaces);

  List<PlaceModel> getCachedFriendPlaces(String uid) =>
      List.unmodifiable(_cachedFriendsPlaces[uid] ?? const []);

  @visibleForTesting
  set cachedPlacesForTesting(List<PlaceModel> places) {
    _cachedPlaces = List.of(places);
  }

  /// Streams a user's pinned places (current user or friend)
  Stream<List<PlaceModel>> streamUserPlaces(String uid) {
    if (uid.isEmpty) return Stream.value(const []);

    final controller = StreamController<List<PlaceModel>>.broadcast();
    StreamSubscription? subColSub;
    StreamSubscription? userDocSub;

    void update(List<PlaceModel> places) {
      if (places.isNotEmpty || (_cachedPlaces.isEmpty && uid == (_auth.currentUser?.uid ?? ''))) {
        if (uid == (_auth.currentUser?.uid ?? '')) {
          _cachedPlaces = places;
        } else {
          _cachedFriendsPlaces[uid] = places;
        }
        if (!controller.isClosed) controller.add(places);
      }
    }

    // 1. Listen to subcollection
    subColSub = _placesCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .listen(
      (snapshot) {
        if (snapshot.docs.isNotEmpty) {
          final places = snapshot.docs
              .map((doc) => PlaceModel.fromFirestore(doc))
              .toList(growable: false);
          update(places);
        }
      },
      onError: (Object e) {
        debugPrint('[PlacesService] subcollection stream error for $uid: $e');
      },
    );

    // 2. Listen to user doc as resilient fallback / instant update
    userDocSub = _db.collection('users').doc(uid).snapshots().listen(
      (doc) {
        if (doc.exists) {
          final raw = doc.data()?['pinnedPlaces'];
          if (raw is List) {
            final places = raw
                .whereType<Map<String, dynamic>>()
                .map((m) => PlaceModel.fromMap(m, id: m['id']?.toString() ?? ''))
                .toList(growable: false);
            update(places);
          }
        }
      },
      onError: (Object e) {
        debugPrint('[PlacesService] user doc stream error for $uid: $e');
      },
    );

    controller.onCancel = () {
      subColSub?.cancel();
      userDocSub?.cancel();
    };

    return controller.stream;
  }

  /// Fetches places for a user once
  Future<List<PlaceModel>> getUserPlaces(String uid) async {
    if (uid.isEmpty) return const [];
    try {
      final snapshot = await _placesCollection(uid)
          .orderBy('createdAt', descending: true)
          .get();
      if (snapshot.docs.isNotEmpty) {
        final places = snapshot.docs
            .map((doc) => PlaceModel.fromFirestore(doc))
            .toList(growable: false);
        if (uid == (_auth.currentUser?.uid ?? '')) {
          _cachedPlaces = places;
        } else {
          _cachedFriendsPlaces[uid] = places;
        }
        return places;
      }
    } catch (e) {
      debugPrint('[PlacesService] getUserPlaces subcollection error for $uid: $e');
    }

    // Fallback: read from user doc
    try {
      final doc = await _db.collection('users').doc(uid).get();
      if (doc.exists) {
        final raw = doc.data()?['pinnedPlaces'];
        if (raw is List) {
          final places = raw
              .whereType<Map<String, dynamic>>()
              .map((m) => PlaceModel.fromMap(m, id: m['id']?.toString() ?? ''))
              .toList(growable: false);
          if (uid == (_auth.currentUser?.uid ?? '')) {
            _cachedPlaces = places;
          } else {
            _cachedFriendsPlaces[uid] = places;
          }
          return places;
        }
      }
    } catch (e) {
      debugPrint('[PlacesService] getUserPlaces user doc error for $uid: $e');
    }

    return const [];
  }

  /// Saves or updates a place
  Future<void> savePlace(PlaceModel place) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) {
      throw StateError('Bạn cần đăng nhập để lưu địa điểm.');
    }

    final collection = _placesCollection(uid);
    final placeId = place.id.isNotEmpty ? place.id : collection.doc().id;
    final modelToSave = place.copyWith(id: placeId, ownerUid: uid);

    // Update in local cache immediately
    _cachedPlaces = [
      modelToSave,
      ..._cachedPlaces.where((p) => p.id != placeId),
    ];

    // Dual-write:
    // 1. Write to user doc (guaranteed by firestore.rules even before rules redeployment)
    try {
      final userDocRef = _db.collection('users').doc(uid);
      await userDocRef.set({
        'pinnedPlaces': _cachedPlaces.map((p) => p.toMap()).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PlacesService] Failed to sync pinnedPlaces to user doc: $e');
    }

    // 2. Write to subcollection (when rules are active)
    try {
      await collection.doc(placeId).set(
            modelToSave.toMap(),
            SetOptions(merge: true),
          );
    } catch (e) {
      debugPrint('[PlacesService] Subcollection save error (likely pending rules deploy): $e');
    }
  }

  /// Deletes a place
  Future<void> deletePlace(String placeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;

    _cachedPlaces = _cachedPlaces.where((p) => p.id != placeId).toList();

    // 1. Delete from user doc
    try {
      final userDocRef = _db.collection('users').doc(uid);
      await userDocRef.set({
        'pinnedPlaces': _cachedPlaces.map((p) => p.toMap()).toList(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('[PlacesService] Failed to sync delete to user doc: $e');
    }

    // 2. Delete from subcollection
    try {
      await _placesCollection(uid).doc(placeId).delete();
    } catch (e) {
      debugPrint('[PlacesService] Subcollection delete error: $e');
    }
  }

  /// Matches coordinates against cached places. Returns the matching PlaceModel or null.
  /// Uses a Hysteresis factor:
  /// - To enter: distance <= place.radiusMetres (default 80m).
  /// - To stay if already at place: distance <= place.radiusMetres + 40m (default 120m).
  PlaceModel? findMatchingPlace({
    required double lat,
    required double lng,
    String? currentPlaceId,
    String? uid,
  }) {
    final places = (uid != null && uid != (_auth.currentUser?.uid ?? ''))
        ? (_cachedFriendsPlaces[uid] ?? const [])
        : _cachedPlaces;

    if (places.isEmpty) return null;

    for (final place in places) {
      final dist = LocationPolicy.distanceMetres(lat, lng, place.lat, place.lng);
      // Hysteresis boundary: wider margin if already inside this place
      final effectiveRadius = (currentPlaceId == place.id)
          ? place.radiusMetres + 40.0 // 120m
          : place.radiusMetres; // 80m

      if (dist <= effectiveRadius) {
        return place;
      }
    }
    return null;
  }
}
