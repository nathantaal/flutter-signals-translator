import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

const String kHelloEn = '{"translations": {"hello": "Hello"}}';
const String kHelloNl = '{"translations": {"hello": "Hallo"}}';

/// Serves [assets] (path → JSON) to `rootBundle` in tests.
void mockTranslationAssets(Map<String, String> assets) {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', (message) async {
        final key = utf8.decode(message!.buffer.asUint8List());
        final asset = assets[key];
        if (asset == null) return null;
        return ByteData.view(Uint8List.fromList(utf8.encode(asset)).buffer);
      });
}

void clearTranslationAssets() {
  TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
      .setMockMessageHandler('flutter/assets', null);
}
