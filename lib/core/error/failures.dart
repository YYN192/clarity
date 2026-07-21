import 'package:equatable/equatable.dart';

abstract class Failure extends Equatable {
  final String message;
  const Failure(this.message);

  @override
  List<Object?> get props => [message];
}

class ServerFailure extends Failure {
  const ServerFailure([super.message = 'Server Failure']);
}

class CacheFailure extends Failure {
  const CacheFailure([super.message = 'Cache Failure']);
}

class NetworkFailure extends Failure {
  const NetworkFailure([super.message = 'No Internet Connection']);
}

class ApiKeyFailure extends Failure {
  const ApiKeyFailure([super.message = 'Invalid API Key']);
}

class NotFoundFailure extends Failure {
  const NotFoundFailure([super.message = 'City not found']);
}

class RateLimitFailure extends Failure {
  const RateLimitFailure([super.message = 'Rate limit exceeded']);
}

class AuthFailure extends Failure {
  const AuthFailure([super.message = 'Authentication failed']);
}

