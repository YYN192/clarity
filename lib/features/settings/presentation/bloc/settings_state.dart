part of 'settings_bloc.dart';

class SettingsState extends Equatable {
  final AppSettings settings;

  const SettingsState({required this.settings});

  @override
  List<Object?> get props => [settings];
}
