import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/place_model.dart';
import '../services/places_service.dart';

final placesServiceProvider = Provider<PlacesService>((ref) {
  return PlacesService();
});

final userPlacesProvider = StreamProvider<List<PlaceModel>>((ref) {
  final uid = FirebaseAuth.instance.currentUser?.uid ?? '';
  if (uid.isEmpty) return Stream.value(const []);
  final service = ref.watch(placesServiceProvider);
  return service.streamUserPlaces(uid);
});
