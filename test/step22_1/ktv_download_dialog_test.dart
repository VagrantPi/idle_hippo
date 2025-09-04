import 'dart:async';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/ui/components/ktv_download_dialog.dart';

// Helper functions for creating test streams
Stream<DownloadProgress> _createSuccessStream() async* {
  yield DownloadProgress(received: 50, total: 100, percent: 50.0);
  await Future.delayed(const Duration(milliseconds: 100));
  yield DownloadProgress(received: 100, total: 100, percent: 100.0);
}

Stream<DownloadProgress> _createErrorStream() async* {
  await Future.delayed(const Duration(milliseconds: 100));
  throw DioException(
    requestOptions: RequestOptions(path: ''),
    error: 'Download failed',
  );
}

// Mock AudioDownloadService with configurable behavior
class MockAudioDownloadService extends Mock implements AudioDownloadService {
  final Future<bool> Function(String)? isCachedImpl;
  final Future<String> Function(String)? cachedFilePathImpl;
  final Stream<DownloadProgress> Function(
    String,
    String, {
    CancelToken? cancelToken,
  })?
  downloadStreamImpl;

  MockAudioDownloadService({
    this.isCachedImpl,
    this.cachedFilePathImpl,
    this.downloadStreamImpl,
  });

  @override
  Future<bool> isCached(String songId) =>
      isCachedImpl?.call(songId) ?? Future.value(false);

  @override
  Future<String> cachedFilePath(String songId) =>
      cachedFilePathImpl?.call(songId) ?? Future.value('path/to/cached/file');

  @override
  Stream<DownloadProgress> download(
    String songId,
    String url, {
    CancelToken? cancelToken,
  }) {
    if (downloadStreamImpl != null) {
      return downloadStreamImpl!(songId, url, cancelToken: cancelToken);
    }
    return _createSuccessStream();
  }
}

void main() {
  late MockAudioDownloadService mockDownloader;
  late Directory tempDir;
  final testSongId = 'test_song';
  final testUrl = 'https://example.com/test.mp3';

  setUp(() async {
    mockDownloader = MockAudioDownloadService(
      downloadStreamImpl: (_, __, {cancelToken}) => _createSuccessStream(),
    );
    tempDir = await Directory.systemTemp.createTemp('ktv_test_');
  });

  tearDown(() async {
    if (await tempDir.exists()) {
      await tempDir.delete(recursive: true);
    }
  });

  Future<void> pumpDialog(
    WidgetTester tester, {
    VoidCallback? onClose,
    VoidCallback? onDownloaded,
    AudioDownloadService? mockDownloader,
  }) async {
    final downloader =
        mockDownloader ??
        MockAudioDownloadService(
          downloadStreamImpl: (_, __, {cancelToken}) => _createSuccessStream(),
        );
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: KtvDownloadDialog(
            songId: testSongId,
            url: testUrl,
            downloader: downloader,
            onClose: onClose ?? () {},
            onDownloaded: onDownloaded ?? () {},
          ),
        ),
      ),
    );
    await tester.pump();
  }

  testWidgets('should show download progress and complete', (tester) async {
    bool downloaded = false;
    await pumpDialog(tester, onDownloaded: () => downloaded = true);

    // Verify initial state
    expect(find.text('Downloading...'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);

    // Wait for download to complete
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify completion
    expect(downloaded, isTrue);
  });

  testWidgets('should cancel download when dialog is closed', (tester) async {
    bool cancelTriggered = false;
    bool onCloseCalled = false;

    final controller = StreamController<DownloadProgress>();

    final customDownloader = MockAudioDownloadService(
      downloadStreamImpl: (songId, url, {cancelToken}) {
        if (cancelToken != null) {
          cancelToken.whenCancel.then((_) {
            cancelTriggered = true;
            controller.close();
          });
        }
        return controller.stream;
      },
    );

    await pumpDialog(
      tester,
      mockDownloader: customDownloader,
      onClose: () => onCloseCalled = true,
    );

    // Find and tap the Cancel button
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();

    // Verify cancel was triggered and onClose was called
    expect(cancelTriggered, isTrue);
    expect(onCloseCalled, isTrue);
  });

  testWidgets('should handle download error and retry', (tester) async {
    int downloadAttempts = 0;
    bool downloaded = false;

    final customDownloader = MockAudioDownloadService(
      downloadStreamImpl: (songId, url, {cancelToken}) {
        downloadAttempts++;
        if (downloadAttempts == 1) {
          return _createErrorStream();
        } else {
          return _createSuccessStream();
        }
      },
    );

    await pumpDialog(
      tester,
      mockDownloader: customDownloader,
      onDownloaded: () => downloaded = true,
    );

    // Wait for error
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify error state
    expect(find.text('Error'), findsOneWidget);
    expect(find.text('Retry'), findsOneWidget);

    // Retry the download
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    // Wait for retry to complete
    await tester.pumpAndSettle(const Duration(seconds: 1));

    // Verify completion after retry
    expect(downloaded, isTrue);
  });
}
