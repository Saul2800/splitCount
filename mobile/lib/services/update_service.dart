import 'package:dio/dio.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';
import '../core/constants/api_constants.dart';

class UpdateInfo {
  final bool hasUpdate;
  final String latestVersion;
  final String currentVersion;
  final String downloadUrl;

  UpdateInfo({
    required this.hasUpdate,
    required this.latestVersion,
    required this.currentVersion,
    required this.downloadUrl,
  });
}

class UpdateService {
  static Future<UpdateInfo> checkForUpdate({String? githubRepo}) async {
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      if (githubRepo == null || githubRepo.isEmpty) {
        return UpdateInfo(
          hasUpdate: false,
          latestVersion: currentVersion,
          currentVersion: currentVersion,
          downloadUrl: ApiConstants.downloadUrl,
        );
      }

      final dio = Dio();
      final response = await dio.get(
        'https://api.github.com/repos/$githubRepo/releases/latest',
        options: Options(
          headers: {'Accept': 'application/vnd.github.v3+json'},
        ),
      );

      if (response.statusCode == 200 && response.data != null) {
        final tagName = (response.data['tag_name'] as String).replaceAll('v', '').trim();
        final assets = response.data['assets'] as List<dynamic>?;
        String apkUrl = ApiConstants.downloadUrl;

        if (assets != null && assets.isNotEmpty) {
          final apkAsset = assets.firstWhere(
            (a) => (a['name'] as String).endsWith('.apk'),
            orElse: () => null,
          );
          if (apkAsset != null) {
            apkUrl = apkAsset['browser_download_url'] ?? ApiConstants.downloadUrl;
          }
        }

        final hasUpdate = _isVersionNewer(tagName, currentVersion);
        return UpdateInfo(
          hasUpdate: hasUpdate,
          latestVersion: tagName,
          currentVersion: currentVersion,
          downloadUrl: apkUrl,
        );
      }
    } catch (_) {
      // Offline or network error
    }

    return UpdateInfo(
      hasUpdate: false,
      latestVersion: '1.0.0',
      currentVersion: '1.0.0',
      downloadUrl: ApiConstants.downloadUrl,
    );
  }

  static bool _isVersionNewer(String latest, String current) {
    try {
      final lParts = latest.split('.').map(int.parse).toList();
      final cParts = current.split('.').map(int.parse).toList();
      for (int i = 0; i < lParts.length && i < cParts.length; i++) {
        if (lParts[i] > cParts[i]) return true;
        if (lParts[i] < cParts[i]) return false;
      }
      return lParts.length > cParts.length;
    } catch (_) {
      return latest != current;
    }
  }

  static Future<void> launchDownload(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
