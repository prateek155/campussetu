import 'dart:io';
import 'package:dio/dio.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:flutter/foundation.dart';

class UpdateInfo {
  final String currentVersion;
  final String latestVersion;
  final String? apkUrl;
  final String? releaseNotes;
  final bool isForceUpdate;
  const UpdateInfo({required this.currentVersion, required this.latestVersion, this.apkUrl, this.releaseNotes, this.isForceUpdate = false});
  bool get hasUpdate => _compare(latestVersion, currentVersion) > 0;
  static int _compare(String a, String b) {
    List<int> pa = a.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    List<int> pb = b.replaceAll(RegExp(r'[^0-9.]'), '').split('.').map((e) => int.tryParse(e) ?? 0).toList();
    for (int i = 0; i < 3; i++) {
      int av = i < pa.length ? pa[i] : 0;
      int bv = i < pb.length ? pb[i] : 0;
      if (av != bv) return av.compareTo(bv);
    }
    return 0;
  }
}

class UpdateService {
  static const String githubRepo = 'prateekagrawal589-create/campussetu';
  static const String githubApi = 'https://api.github.com/repos/prateekagrawal589-create/campussetu/releases/latest';
  static const String fallbackVersionUrl = 'https://campussetu-production.up.railway.app/api/v1/version';
  static const String rawPubspecUrl = 'https://raw.githubusercontent.com/prateekagrawal589-create/campussetu/main/pubspec.yaml';

  static final Dio _dio = Dio();

  static Future<String> getCurrentVersion() async {
    final info = await PackageInfo.fromPlatform();
    return '${info.version}+${info.buildNumber}';
  }

  static Future<UpdateInfo?> checkForUpdate() async {
    try {
      final current = await getCurrentVersion();
      final currentShort = current.split('+').first;

      // 1. Try Play Store InAppUpdate
      try {
        final info = await InAppUpdate.checkForUpdate();
        if (info.updateAvailability == UpdateAvailability.updateAvailable) {
          return UpdateInfo(currentVersion: currentShort, latestVersion: 'PlayStore', apkUrl: null, releaseNotes: 'Update available on Play Store');
        }
      } catch (_) {}

      // 2. Try GitHub releases
      try {
        final res = await _dio.get(githubApi, options: Options(headers: {'Accept': 'application/vnd.github.v3+json', 'User-Agent': 'CampusSetu-App'}));
        if (res.statusCode == 200 && res.data is Map) {
          final tag = (res.data['tag_name'] ?? '').toString().replaceAll('v', '');
          final notes = (res.data['body'] ?? '').toString();
          String? apkUrl;
          final assets = res.data['assets'] as List?;
          if (assets != null) {
            for (final a in assets) {
              final name = (a['name'] ?? '').toString();
              if (name.endsWith('.apk')) { apkUrl = a['browser_download_url']?.toString(); break; }
            }
            apkUrl ??= assets.isNotEmpty ? assets.first['browser_download_url']?.toString() : null;
          }
          apkUrl ??= 'https://github.com/$githubRepo/releases/latest/download/app-release.apk';
          final info = UpdateInfo(currentVersion: currentShort, latestVersion: tag.isEmpty ? currentShort : tag, apkUrl: apkUrl, releaseNotes: notes);
          if (info.hasUpdate) return info;
        }
      } catch (e) { if (kDebugMode) debugPrint('GH releases check failed $e'); }

      // 2b. Try raw pubspec.yaml (no Release needed — just push + version bump)
      try {
        final res = await _dio.get(rawPubspecUrl, options: Options(headers: {'Cache-Control': 'no-cache'}, responseType: ResponseType.plain));
        final body = res.data?.toString() ?? '';
        final match = RegExp(r'version:\s*([0-9]+\.[0-9]+\.[0-9]+)').firstMatch(body);
        if (match != null) {
          final tag = match.group(1)!;
          const apkUrl = 'https://github.com/$githubRepo/releases/latest/download/app-release.apk';
          final info = UpdateInfo(currentVersion: currentShort, latestVersion: tag, apkUrl: apkUrl, releaseNotes: 'New version $tag available — please update');
          if (info.hasUpdate) return info;
        }
      } catch (e) { if (kDebugMode) debugPrint('raw pubspec check failed $e'); }

      // 3. Fallback: backend version
      try {
        final res = await _dio.get(fallbackVersionUrl);
        if (res.statusCode == 200 && res.data is Map && res.data['version'] != null) {
          final tag = res.data['version'].toString().replaceAll('v', '');
          final apk = res.data['apkUrl']?.toString() ?? 'https://github.com/$githubRepo/releases/latest/download/app-release.apk';
          final info = UpdateInfo(currentVersion: currentShort, latestVersion: tag, apkUrl: apk, releaseNotes: res.data['notes']?.toString());
          if (info.hasUpdate) return info;
        }
      } catch (e) { if (kDebugMode) debugPrint('backend version check failed $e'); }

      return null;
    } catch (_) { return null; }
  }

  static Future<bool> performPlayStoreUpdate() async {
    try {
      final info = await InAppUpdate.checkForUpdate();
      if (info.updateAvailability == UpdateAvailability.updateAvailable) {
        if (info.immediateUpdateAllowed) {
          await InAppUpdate.performImmediateUpdate();
          return true;
        } else if (info.flexibleUpdateAllowed) {
          await InAppUpdate.startFlexibleUpdate();
          await InAppUpdate.completeFlexibleUpdate();
          return true;
        }
      }
    } catch (e) { if (kDebugMode) debugPrint('Play update failed $e'); }
    return false;
  }

  static Future<String> downloadApk(String apkUrl, {void Function(int received, int total)? onProgress}) async {
    if (Platform.isIOS) throw Exception('iOS sideload not supported');
    var status = await Permission.requestInstallPackages.status;
    if (status.isDenied) status = await Permission.requestInstallPackages.request();
    if (status.isPermanentlyDenied || status.isRestricted) {
      await openAppSettings();
      throw Exception('Please enable "Install unknown apps" for CampusSetu in Settings, then tap Update again');
    }
    if (!status.isGranted && !status.isLimited) {
      throw Exception('Install permission denied — enable "Install unknown apps"');
    }
    final dir = await getExternalStorageDirectory() ?? await getTemporaryDirectory();
    final savePath = '${dir.path}/campussetu_update.apk';
    final file = File(savePath);
    if (await file.exists()) await file.delete();
    if (kDebugMode) debugPrint('Downloading $apkUrl -> $savePath');
    final response = await _dio.download(apkUrl, savePath, onReceiveProgress: onProgress, options: Options(followRedirects: true, validateStatus: (s) => s != null && s < 400, headers: {'User-Agent': 'CampusSetu-App'}));
    if (response.statusCode != null && response.statusCode! >= 400) throw Exception('Download failed: ${response.statusCode}');
    final f = File(savePath);
    if (!await f.exists() || await f.length() < 1024 * 1024) throw Exception('Downloaded file invalid (maybe 404). Check release has app-release.apk');
    return savePath;
  }

  static Future<void> installApk(String path) async {
    final file = File(path);
    if (!await file.exists()) throw Exception('APK not found at $path');
    final result = await OpenFilex.open(path);
    if (kDebugMode) debugPrint('OpenFile result $result type=${result.type} message=${result.message}');
    if (result.type != ResultType.done) {
      if (result.message.contains('No APP found') || result.message.contains('Activity not found')) {
        throw Exception('No installer found — please enable "Install unknown apps" or open file manually: $path');
      }
      throw Exception('Install failed: ${result.message} — try opening $path manually or allow Install unknown apps');
    }
  }

  static Future<bool> updateViaGithub(UpdateInfo info, {void Function(int, int)? onProgress}) async {
    if (info.apkUrl == null) throw Exception('No APK url');
    final path = await downloadApk(info.apkUrl!, onProgress: onProgress);
    await installApk(path);
    return true;
  }
}
