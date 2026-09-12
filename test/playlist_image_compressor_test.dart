import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import '../lib/services/playlist_image_compressor.dart';
import '../lib/core/utils/error_sanitizer.dart';

void main() {
  test('large playlist images stay within pixel and byte limits', () async {
    final source = img.Image(width: 2400, height: 1800);
    final result = await compressPlaylistImage(Uint8List.fromList(img.encodeJpg(source)));
    final decoded = img.decodeJpg(result)!;
    expect(decoded.width, 1600);
    expect(decoded.height, 1200);
    expect(result.length, lessThan(500000));
  });
  test('errors never expose connection addresses', () {
    final message = ErrorSanitizer.getUserFriendlyMessage('ClientException connection reset http://myframe.ink:3001/private_db');
    expect(message, contains('Network connection interrupted'));
    expect(message, isNot(contains('myframe.ink')));
    expect(ErrorSanitizer.getUserFriendlyMessage('private_db'), isNot(contains('private_db')));
  });
}
