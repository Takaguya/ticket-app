import 'dart:convert';

import 'package:share_plus/share_plus.dart';

/// Hands a generated file to the phone, e.g. to save it or send it on.
abstract interface class FileSharer {
  Future<void> shareTextFile({
    required String name,
    required String content,
    required String mimeType,
  });
}

/// Opens the Android share sheet with the file attached.
class SharePlusFileSharer implements FileSharer {
  const SharePlusFileSharer();

  @override
  Future<void> shareTextFile({
    required String name,
    required String content,
    required String mimeType,
  }) async {
    final file = XFile.fromData(utf8.encode(content), mimeType: mimeType, name: name);
    await SharePlus.instance.share(
      ShareParams(files: [file], fileNameOverrides: [name], subject: name),
    );
  }
}
