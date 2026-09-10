import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:image/image.dart' as img;
import 'package:myframe/services/frame_api_client.dart';
import 'package:myframe/services/gallery_image_normalizer.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('playlist multipart requests opt out of individual notifications only', () async {
    final bodies = <String>[];
    final api = FrameApiClient(httpClient: MockClient((request) async {
      bodies.add(request.body);
      return http.Response(jsonEncode({'ok': true, 'stored_path': 'test.bin'}), 200);
    }));
    for (final source in [UploadSource.playlist, UploadSource.directCast]) {
      await api.uploadPhoto(
        fileBytes: Uint8List.fromList([1, 2, 3]),
        filename: 'test.jpg',
        deviceId: 'D0CF13E03618',
        source: source,
        skipPlay: source == UploadSource.playlist,
      );
    }
    expect(bodies.first, contains('name="silent"'));
    expect(bodies.first, contains('name="skip_play"'));
    expect(bodies.last, isNot(contains('name="silent"')));
    api.close();
  });

  test('fallback image normalization runs in isolate and produces JPEG', () async {
    final raw = Uint8List.fromList(img.encodePng(img.Image(width: 16, height: 24)));
    final output = await GalleryImageNormalizer.toJpegBytes(raw);
    expect(output, isNotNull);
    expect(img.decodeJpg(output!)?.width, 16);
  });
}
