import 'package:cloud_firestore/cloud_firestore.dart';
import '../../domain/entities/saved_city.dart';

class SavedCityModel extends SavedCity {
  const SavedCityModel({required super.id, required super.name, super.savedAt});

  factory SavedCityModel.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data() ?? const {};
    return SavedCityModel(
      id: doc.id,
      // Fall back to the id so a malformed document still renders something
      // tappable rather than an empty row.
      name: (data['name'] as String?)?.trim().isNotEmpty == true
          ? data['name'] as String
          : doc.id,
      savedAt: (data['savedAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toFirestore() => {
        'name': name,
        'savedAt': FieldValue.serverTimestamp(),
      };
}
