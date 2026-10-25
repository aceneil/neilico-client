import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// 客户端接入控制面后需要持久化的少量状态。
///
/// 刻意不引入 shared_preferences：仓库已经依赖 path_provider，用它写一个小 JSON
/// 就够了，避免为两三个字段再加一个插件（并让 pubspec.lock 的 SDK 下限被抬高）。
class EnrollStore {
  static const _fileName = 'neilico_enroll.json';

  static Future<File> _file() async {
    final dir = await getApplicationSupportDirectory();
    return File('${dir.path}/$_fileName');
  }

  /// 读取已保存的接入信息；没有或解析失败时返回 null。
  static Future<({String serverBase, String apiToken})?> load() async {
    try {
      final file = await _file();
      if (!await file.exists()) return null;
      final raw = await file.readAsString();
      if (raw.trim().isEmpty) return null;
      final data = jsonDecode(raw);
      if (data is! Map<String, dynamic>) return null;
      final base = (data['server_base'] ?? '').toString().trim();
      final token = (data['api_token'] ?? '').toString().trim();
      if (base.isEmpty || token.isEmpty) return null;
      return (serverBase: base, apiToken: token);
    } catch (_) {
      return null;
    }
  }

  /// 写入（覆盖）接入信息。失败时抛出，由调用方决定如何提示。
  static Future<void> save({
    required String serverBase,
    required String apiToken,
  }) async {
    final file = await _file();
    await file.parent.create(recursive: true);
    await file.writeAsString(
      jsonEncode({'server_base': serverBase, 'api_token': apiToken}),
      flush: true,
    );
  }

  static Future<void> clear() async {
    try {
      final file = await _file();
      if (await file.exists()) await file.delete();
    } catch (_) {
      // 清理失败不影响主流程
    }
  }
}
