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
    return _placesCollection(uid)
        .orderBy('createdAt', descending: true)
        .snapshots()
        .map((snapshot) {
      final places = snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList(growable: false);
      if (uid == (_auth.currentUser?.uid ?? '')) {
        _cachedPlaces = places;
      } else {
        _cachedFriendsPlaces[uid] = places;
      }
      return places;
    }).handleError((Object e) {
      debugPrint('[PlacesService] streamUserPlaces error for $uid: $e');
      return <PlaceModel>[];
    });
  }

  /// Fetches places for a user once
  Future<List<PlaceModel>> getUserPlaces(String uid) async {
    if (uid.isEmpty) return const [];
    try {
      final snapshot = await _placesCollection(uid)
          .orderBy('createdAt', descending: true)
          .get();
      final places = snapshot.docs
          .map((doc) => PlaceModel.fromFirestore(doc))
          .toList(growable: false);
      if (uid == (_auth.currentUser?.uid ?? '')) {
        _cachedPlaces = places;
      } else {
        _cachedFriendsPlaces[uid] = places;
      }
      return places;
    } catch (e) {
      debugPrint('[PlacesService] getUserPlaces error for $uid: $e');
      return const [];
    }
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

    await collection.doc(placeId).set(
          modelToSave.toMap(),
          SetOptions(merge: true),
        );

    // Update in local cache
    _cachedPlaces = [
      modelToSave,
      ..._cachedPlaces.where((p) => p.id != placeId),
    ];
  }

  /// Deletes a place
  Future<void> deletePlace(String placeId) async {
    final uid = _auth.currentUser?.uid;
    if (uid == null || uid.isEmpty) return;
    try {
      await _placesCollection(uid).doc(placeId).delete();
      _cachedPlaces = _cachedPlaces.where((p) => p.id != placeId).toList();
    } catch (e) {
      debugPrint('[PlacesService] deletePlace error: $e');
      rethrow;
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
