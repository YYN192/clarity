/// Data-layer exceptions. The optional [message] lets a data source explain a
/// specific failure; repositories map these to [Failure]s and never let them
/// cross a layer boundary.
class ServerException implements Exception {
  final String? message;
  const ServerException([this.message]);
}

class CacheException implements Exception {
  final String? message;
  const CacheException([this.message]);
}

class NetworkException implements Exception {
  final String? message;
  const NetworkException([this.message]);
}

class ApiKeyException implements Exception {
  final String? message;
  const ApiKeyException([this.message]);
}

class NotFoundException implements Exception {
  final String? message;
  const NotFoundException([this.message]);
}

class RateLimitException implements Exception {
  final String? message;
  const RateLimitException([this.message]);
}
