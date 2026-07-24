import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/entities/city_location.dart';
import '../../domain/usecases/search_cities.dart';

// Events

abstract class CitySearchEvent extends Equatable {
  const CitySearchEvent();

  @override
  List<Object?> get props => [];
}

/// The (already debounced) text currently in the search field.
class CitySearchQueryChanged extends CitySearchEvent {
  final String query;
  final String locale;
  const CitySearchQueryChanged(this.query, {this.locale = 'en'});

  @override
  List<Object?> get props => [query, locale];
}

// State

enum CitySearchStatus { idle, loading, loaded, error }

class CitySearchState extends Equatable {
  final CitySearchStatus status;
  final List<CityLocation> results;
  final String query;

  const CitySearchState({
    this.status = CitySearchStatus.idle,
    this.results = const [],
    this.query = '',
  });

  CitySearchState copyWith({
    CitySearchStatus? status,
    List<CityLocation>? results,
    String? query,
  }) {
    return CitySearchState(
      status: status ?? this.status,
      results: results ?? this.results,
      query: query ?? this.query,
    );
  }

  @override
  List<Object?> get props => [status, results, query];
}

// Bloc

class CitySearchBloc extends Bloc<CitySearchEvent, CitySearchState> {
  final SearchCities searchCities;

  /// Session cache: repeating a query (backspacing, re-typing) is free.
  final Map<String, List<CityLocation>> _cache = {};

  /// Guards against out-of-order responses — a slow reply for "sof" must not
  /// overwrite the results already shown for "sofia".
  int _requestSeq = 0;

  CitySearchBloc({required this.searchCities}) : super(const CitySearchState()) {
    on<CitySearchQueryChanged>(_onQueryChanged);
  }

  Future<void> _onQueryChanged(
    CitySearchQueryChanged event,
    Emitter<CitySearchState> emit,
  ) async {
    final query = event.query.trim();
    if (query.length < 2) {
      emit(const CitySearchState());
      return;
    }

    final cacheKey = '${event.locale}:${query.toLowerCase()}';
    final cached = _cache[cacheKey];
    if (cached != null) {
      emit(state.copyWith(
          status: CitySearchStatus.loaded, results: cached, query: query));
      return;
    }

    final seq = ++_requestSeq;
    emit(state.copyWith(status: CitySearchStatus.loading, query: query));

    final result = await searchCities(
      SearchCitiesParams(query: query, locale: event.locale),
    );
    if (seq != _requestSeq) return; // superseded by a newer query

    result.fold(
      (failure) => emit(state.copyWith(status: CitySearchStatus.error)),
      (cities) {
        _cache[cacheKey] = cities;
        emit(state.copyWith(status: CitySearchStatus.loaded, results: cities));
      },
    );
  }
}
