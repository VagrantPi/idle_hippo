import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/localization_service.dart';

class KtvDownloadDialog extends StatefulWidget {
  final String songId;
  final String url;
  final VoidCallback onClose;
  final VoidCallback onDownloaded;
  final AudioDownloadService? downloader;

  const KtvDownloadDialog({
    super.key,
    required this.songId,
    required this.url,
    required this.onClose,
    required this.onDownloaded,
    this.downloader,
  });

  @override
  State<KtvDownloadDialog> createState() => _KtvDownloadDialogState();
}

class _KtvDownloadDialogState extends State<KtvDownloadDialog> {
  late final AudioDownloadService _downloader;
  final _loc = LocalizationService();

  final CancelToken _cancelToken = CancelToken();
  StreamSubscription? _sub;

  double? _percent; // 0..100
  String? _error;

  @override
  void initState() {
    super.initState();
    _downloader = widget.downloader ?? AudioDownloadService();
    // 直接啟動下載：服務會立即回傳 stream 並在背景執行，不會丟失事件
    _start();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cancelToken.cancel();
    super.dispose();
  }

  void _start() {
    setState(() {
      _error = null;
      _percent = 0;
    });

    _sub = _downloader
        .download(widget.songId, widget.url, cancelToken: _cancelToken)
        .listen(
          (p) {
            setState(() {
              _percent = p.percent;
            });
          },
          onError: (e) {
            String msg = e.toString();
            try {
              if (e is DioException) {
                switch (e.type) {
                  case DioExceptionType.connectionTimeout:
                  case DioExceptionType.sendTimeout:
                  case DioExceptionType.receiveTimeout:
                  case DioExceptionType.connectionError:
                    msg = _loc.getString(
                      'ktv.network_unavailable',
                      defaultValue: 'Network unavailable',
                    );
                    break;
                  default:
                    msg = _loc.getString(
                      'ktv.download_failed',
                      defaultValue: 'Download failed',
                    );
                }
              }
            } catch (_) {}
            setState(() => _error = msg);
          },
          onDone: () {
            widget.onDownloaded();
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Material(
            color: Colors.black.withValues(alpha: 0.7),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    _loc.getString(
                      'ktv.downloading',
                      defaultValue: 'Downloading...',
                    ),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 16),
                  if (_error == null) ...[
                    LinearProgressIndicator(
                      value: (_percent != null)
                          ? (_percent! / 100.0).clamp(0.0, 1.0)
                          : null,
                      backgroundColor: Colors.white12,
                      color: Colors.lightBlueAccent,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _percent != null
                          ? '${_percent!.toStringAsFixed(0)}%'
                          : '—',
                      style: const TextStyle(color: Colors.white70),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _cancelToken.cancel('user_cancel');
                            widget.onClose();
                          },
                          child: Text(
                            _loc.getString(
                              'ktv.cancel',
                              defaultValue: 'Cancel',
                            ),
                          ),
                        ),
                      ],
                    ),
                  ] else ...[
                    Icon(
                      Icons.error_outline,
                      color: Colors.red.withValues(alpha: 0.9),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _loc.getString('ktv.error', defaultValue: 'Error'),
                      style: const TextStyle(color: Colors.redAccent),
                    ),
                    const SizedBox(height: 4),
                    Text(_error ?? '',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontSize: 12,
                        ),
                        textAlign: TextAlign.center),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: widget.onClose,
                          child: Text(
                            _loc.getString('ktv.back', defaultValue: 'Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: _start,
                          child: Text(
                            _loc.getString('ktv.retry', defaultValue: 'Retry'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
