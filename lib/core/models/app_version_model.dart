class AppVersionModel {
  final String latestVersion;
  final int versionCode;
  final int minSupportedVersionCode;
  final String apkUrl;
  final String releaseNotes;
  final DateTime releasedAt;
  final bool forceUpdate;

  AppVersionModel({
    required this.latestVersion,
    required this.versionCode,
    this.minSupportedVersionCode = 1,
    required this.apkUrl,
    required this.releaseNotes,
    required this.releasedAt,
    this.forceUpdate = false,
  });

  Map<String, dynamic> toMap() {
    return {
      'latest_version': latestVersion,
      'version_code': versionCode,
      'min_supported_version_code': minSupportedVersionCode,
      'apk_url': apkUrl,
      'release_notes': releaseNotes,
      'released_at': releasedAt.toIso8601String(),
      'force_update': forceUpdate,
    };
  }

  factory AppVersionModel.fromMap(Map<String, dynamic> map) {
    return AppVersionModel(
      latestVersion: map['latest_version']?.toString() ?? '1.0.0',
      versionCode: int.tryParse(map['version_code']?.toString() ?? '1') ?? 1,
      minSupportedVersionCode:
          int.tryParse(map['min_supported_version_code']?.toString() ?? '1') ?? 1,
      apkUrl: map['apk_url']?.toString() ?? '',
      releaseNotes: map['release_notes']?.toString() ??
          'Peningkatan performa dan perbaikan sistem.',
      releasedAt: map['released_at'] != null
          ? DateTime.tryParse(map['released_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
      forceUpdate: map['force_update'] == true,
    );
  }
}

class AppUpdateCheckResult {
  final bool hasUpdate;
  final bool isForceUpdate;
  final String currentVersion;
  final int currentVersionCode;
  final AppVersionModel? serverVersion;

  AppUpdateCheckResult({
    required this.hasUpdate,
    required this.isForceUpdate,
    required this.currentVersion,
    required this.currentVersionCode,
    this.serverVersion,
  });
}
