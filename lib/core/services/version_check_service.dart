import 'package:firebase_remote_config/firebase_remote_config.dart';
import 'package:package_info_plus/package_info_plus.dart';

class VersionCheckResult {
  final bool needsUpdate;
  final String currentVersion;
  final String minVersion;
  final String packageName;

  const VersionCheckResult({
    required this.needsUpdate,
    required this.currentVersion,
    required this.minVersion,
    required this.packageName,
  });
}

class VersionCheckService {
  static Future<VersionCheckResult> check() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version;
    final packageName = packageInfo.packageName;

    try {
      final remoteConfig = FirebaseRemoteConfig.instance;
      await remoteConfig.setConfigSettings(RemoteConfigSettings(
        fetchTimeout: const Duration(seconds: 10),
        minimumFetchInterval: const Duration(hours: 1),
        //minimumFetchInterval: const Duration(seconds: 0), // testing

      ));
      await remoteConfig.setDefaults({'min_version': '1.0.0'});
      await remoteConfig.fetchAndActivate();

      final minVersion = remoteConfig.getString('min_version');
      final needsUpdate = _isVersionLower(currentVersion, minVersion);

      return VersionCheckResult(
        needsUpdate: needsUpdate,
        currentVersion: currentVersion,
        minVersion: minVersion,
        packageName: packageName,
      );
    } catch (_) {
      // Si falla Remote Config, dejamos pasar al usuario
      return VersionCheckResult(
        needsUpdate: false,
        currentVersion: currentVersion,
        minVersion: '0.0.0',
        packageName: packageName,
      );
    }
  }

  /// Devuelve true si [current] es menor que [minimum]
  static bool _isVersionLower(String current, String minimum) {
    final currentParts = current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final minimumParts = minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    for (int i = 0; i < 3; i++) {
      final c = i < currentParts.length ? currentParts[i] : 0;
      final m = i < minimumParts.length ? minimumParts[i] : 0;
      if (c < m) return true;
      if (c > m) return false;
    }
    return false;
  }
}
