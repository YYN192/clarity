import 'package:equatable/equatable.dart';

/// A city the user has bookmarked, synced to their account.
class SavedCity extends Equatable {
  /// Firestore document id — the normalised name, so saving the same city
  /// twice overwrites rather than duplicating.
  final String id;

  /// The name as it should be displayed and sent to the weather API.
  final String name;

  final DateTime? savedAt;

  const SavedCity({required this.id, required this.name, this.savedAt});

  /// Document id for [name]: case- and whitespace-insensitive.
  static String idFor(String name) =>
      name.trim().toLowerCase().replaceAll(RegExp(r'\s+'), '-');

  @override
  List<Object?> get props => [id, name, savedAt];
}
