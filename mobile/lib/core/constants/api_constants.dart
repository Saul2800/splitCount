class ApiConstants {
  static const String baseUrl = 'https://splitcount-backend.saularenasramirez.workers.dev';
  static const String downloadUrl = '$baseUrl/download';
  static const String syncPullEndpoint = '$baseUrl/api/v1/sync/pull';
  static const String syncPushEndpoint = '$baseUrl/api/v1/sync/push';
  static const String groupVerifyEndpoint = '$baseUrl/api/v1/groups/verify';
  
  static const Duration connectTimeout = Duration(seconds: 15);
  static const Duration receiveTimeout = Duration(seconds: 15);
}
