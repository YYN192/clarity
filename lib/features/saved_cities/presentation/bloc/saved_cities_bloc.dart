import 'dart:async';

import 'package:flutter_bloc/flutter_bloc.dart';

import '../../domain/repositories/saved_cities_repository.dart';
import 'saved_cities_event.dart';
import 'saved_cities_state.dart';

class SavedCitiesBloc extends Bloc<SavedCitiesEvent, SavedCitiesState> {
  final SavedCitiesRepository repository;

  StreamSubscription<void>? _subscription;

  SavedCitiesBloc({required this.repository}) : super(const SavedCitiesState()) {
    on<SavedCitiesSubscribed>(_onSubscribed);
    on<SavedCitiesUpdated>(_onUpdated);
    on<SavedCityAdded>(_onAdded);
    on<SavedCityRemoved>(_onRemoved);
  }

  Future<void> _onSubscribed(
    SavedCitiesSubscribed event,
    Emitter<SavedCitiesState> emit,
  ) async {
    emit(state.copyWith(status: SavedCitiesStatus.loading));
    await _subscription?.cancel();
    // Forwarded through an event rather than emitted directly so the
    // subscription can outlive this handler.
    _subscription = repository.watch().listen((result) {
      result.fold(
        (failure) => add(SavedCitiesUpdated(error: failure.message)),
        (cities) => add(SavedCitiesUpdated(cities: cities)),
      );
    });
  }

  void _onUpdated(SavedCitiesUpdated event, Emitter<SavedCitiesState> emit) {
    if (event.error != null) {
      emit(state.copyWith(
        status: SavedCitiesStatus.error,
        message: event.error,
      ));
      return;
    }
    emit(state.copyWith(
      status: SavedCitiesStatus.loaded,
      cities: event.cities ?? const [],
    ));
  }

  Future<void> _onAdded(
    SavedCityAdded event,
    Emitter<SavedCitiesState> emit,
  ) async {
    // No optimistic update: the Firestore stream echoes the write back, and
    // its offline cache makes that immediate even without a connection.
    final result = await repository.save(event.cityName);
    result.fold(
      (failure) => emit(state.copyWith(
        status: SavedCitiesStatus.error,
        message: failure.message,
      )),
      (_) {},
    );
  }

  Future<void> _onRemoved(
    SavedCityRemoved event,
    Emitter<SavedCitiesState> emit,
  ) async {
    final result = await repository.remove(event.id);
    result.fold(
      (failure) => emit(state.copyWith(
        status: SavedCitiesStatus.error,
        message: failure.message,
      )),
      (_) {},
    );
  }

  @override
  Future<void> close() {
    _subscription?.cancel();
    return super.close();
  }
}
