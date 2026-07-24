import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/error/exceptions.dart';
import '../../domain/entities/saved_city.dart';
import '../models/saved_city_model.dart';

/// Firestore-backed saved cities at `users/{uid}/saved_cities/{cityId}`.
///
/// Scoping by uid keeps the security rule trivial (a user may only touch
/// documents under their own uid) and means no query needs an index.
abstract class SavedCitiesRemoteDataSource {
  Stream<List<SavedCityModel>> watch();
  Future<void> save(String cityName);
  Future<void> remove(String id);
}

class SavedCitiesRemoteDataSourceImpl implements SavedCitiesRemoteDataSource {
  final FirebaseFirestore firestore;
  final FirebaseAuth auth;

  SavedCitiesRemoteDataSourceImpl({required this.firestore, required this.auth});

  CollectionReference<Map<String, dynamic>> _collection() {
    final uid = auth.currentUser?.uid;
    if (uid == null) {
      throw const ServerException('Not signed in.');
    }
    return firestore.collection('users').doc(uid).collection('saved_cities');
  }

  @override
  Stream<List<SavedCityModel>> watch() {
    // Newest first. Documents written in the same batch may briefly have a null
    // serverTimestamp, which Firestore orders last — acceptable for a bookmark
    // list and avoids a second round trip.
    return _collection()
        .orderBy('savedAt', descending: true)
        .snapshots()
        .map((snap) => snap.docs.map(SavedCityModel.fromFirestore).toList());
  }

  @override
  Future<void> save(String cityName) {
    final name = cityName.trim();
    if (name.isEmpty) throw const ServerException('City name is empty.');
    final model = SavedCityModel(id: SavedCity.idFor(name), name: name);
    return _collection().doc(model.id).set(model.toFirestore());
  }

  @override
  Future<void> remove(String id) => _collection().doc(id).delete();
}
