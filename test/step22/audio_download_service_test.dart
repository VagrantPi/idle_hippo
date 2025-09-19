import 'dart:convert';
import 'dart:io';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:path/path.dart' as p;

void main() {
  group('AudioDownloadService', () {
    late Directory tempBase;
    late AudioDownloadService svc;

    setUp(() async {
      tempBase = await Directory.systemTemp.createTemp('ktv_test_');
      svc = AudioDownloadService();
      svc.baseDirProvider = () async => tempBase;
    });

    tearDown(() async {
      if (await tempBase.exists()) {
        await tempBase.delete(recursive: true);
      }
    });

    test('成功下載：進度回報且最終檔案存在', () async {
      final data = utf8.encode('hello world');
      svc.downloadImpl =
          (url, savePath, {onReceiveProgress, cancelToken}) async {
            final file = File(savePath);
            final sink = file.openWrite();
            // 模擬分段寫入與進度
            for (int i = 0; i < data.length; i++) {
              await Future<void>.delayed(const Duration(milliseconds: 5));
              sink.add([data[i]]);
              onReceiveProgress?.call(i + 1, data.length);
            }
            await sink.flush();
            await sink.close();
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
            );
          };

      final progresses = <DownloadProgress>[];
      await svc
          .download(
            'EchoesOfTheVoid',
            'https://github.com/VagrantPi/idle_hippo_music_resource/raw/refs/heads/main/EchoesOfTheVoid.mp3',
          )
          .listen(progresses.add)
          .asFuture<void>();

      // 檔案應存在且內容正確
      final songPath = p.join(tempBase.path, 'audio', 'EchoesOfTheVoid.mp3');
      final f = File(songPath);
      expect(await f.exists(), isTrue);
      expect(await f.readAsString(), 'hello world');

      // 進度至少回報 2 次，且最終百分比≈100
      expect(progresses.length, greaterThan(1));
      final last = progresses.last;
      expect((last.percent ?? 0) >= 99.0, isTrue);
    });

    test('取消下載：刪除半成品，不留下 .part 或最終檔', () async {
      final cancelToken = CancelToken();

      svc.downloadImpl =
          (url, savePath, {onReceiveProgress, cancelToken}) async {
            final file = File(savePath);
            final sink = file.openWrite();
            final total = 100;
            for (int i = 1; i <= total; i++) {
              if (cancelToken?.isCancelled ?? false) {
                await sink.close();
                throw DioException(
                  requestOptions: RequestOptions(path: url),
                  type: DioExceptionType.cancel,
                );
              }
              sink.add([i % 256]);
              onReceiveProgress?.call(i, total);
              await Future<void>.delayed(const Duration(milliseconds: 2));
              if (i == 20) {
                // 測試端在 20% 時取消
                cancelToken?.cancel('test cancel');
              }
            }
            await sink.flush();
            await sink.close();
            return Response(
              requestOptions: RequestOptions(path: url),
              statusCode: 200,
            );
          };

      // 監聽但忽略錯誤（預期為取消）
      try {
        await svc
            .download(
              'EchoesOfTheVoid',
              'https://github.com/VagrantPi/idle_hippo_music_resource/raw/refs/heads/main/EchoesOfTheVoid.mp3',
              cancelToken: cancelToken,
            )
            .drain<void>();
        fail('should throw cancel');
      } catch (_) {}

      final dir = Directory(p.join(tempBase.path, 'audio'));
      final finalFile = File(p.join(dir.path, 'EchoesOfTheVoid.mp3'));
      final partFile = File(p.join(dir.path, '.EchoesOfTheVoid.mp3.part'));
      expect(await finalFile.exists(), isFalse);
      expect(await partFile.exists(), isFalse);
    });

    test('錯誤時清理半成品', () async {
      svc.downloadImpl =
          (url, savePath, {onReceiveProgress, cancelToken}) async {
            final file = File(savePath);
            await file.writeAsBytes([0, 1, 2]); // 先寫一點點
            throw DioException(
              requestOptions: RequestOptions(path: url),
              type: DioExceptionType.badResponse,
            );
          };

      try {
        await svc
            .download(
              'EchoesOfTheVoid',
              'https://github.com/VagrantPi/idle_hippo_music_resource/raw/refs/heads/main/EchoesOfTheVoid.mp3',
            )
            .drain<void>();
        fail('should throw');
      } catch (_) {}

      final dir = Directory(p.join(tempBase.path, 'audio'));
      final finalFile = File(p.join(dir.path, 'EchoesOfTheVoid.mp3'));
      final partFile = File(p.join(dir.path, '.EchoesOfTheVoid.mp3.part'));
      expect(await finalFile.exists(), isFalse);
      expect(await partFile.exists(), isFalse);
    });
  });
}
