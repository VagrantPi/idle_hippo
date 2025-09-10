import 'dart:async';

import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:idle_hippo/services/audio_download_service.dart';
import 'package:idle_hippo/services/localization_service.dart';

class KtvBatchSong {
  final String id;
  final String url;
  final String title;

  const KtvBatchSong({
    required this.id,
    required this.url,
    required this.title,
  });
}

class KtvBatchDownloadDialog extends StatefulWidget {
  final List<KtvBatchSong> songs;
  final VoidCallback onClose;
  final VoidCallback onCompleted;
  final AudioDownloadService? downloader;

  const KtvBatchDownloadDialog({
    super.key,
    required this.songs,
    required this.onClose,
    required this.onCompleted,
    this.downloader,
  });

  @override
  State<KtvBatchDownloadDialog> createState() => _KtvBatchDownloadDialogState();
}

class _KtvBatchDownloadDialogState extends State<KtvBatchDownloadDialog> {
  late final AudioDownloadService _downloader;
  final _loc = LocalizationService();

  int _currentIndex = 0;
  double? _percent; // 0..100
  Object? _error;
  bool _cancelled = false;

  CancelToken? _cancelToken;
  StreamSubscription? _sub;

  @override
  void initState() {
    super.initState();
    _downloader = widget.downloader ?? AudioDownloadService();
    _startCurrent();
  }

  @override
  void dispose() {
    _sub?.cancel();
    _cancelToken?.cancel();
    super.dispose();
  }

  void _startCurrent() {
    if (_currentIndex >= widget.songs.length) {
      widget.onCompleted();
      return;
    }
    setState(() {
      _error = null;
      _percent = 0;
    });
    _cancelToken?.cancel();
    _cancelToken = CancelToken();

    final s = widget.songs[_currentIndex];
    _sub?.cancel();
    _sub = _downloader
        .download(s.id, s.url, cancelToken: _cancelToken)
        .listen(
          (p) {
            setState(() => _percent = p.percent);
          },
          onError: (e) {
            setState(() => _error = e);
          },
          onDone: () {
            if (_cancelled) return; // 若已取消則忽略
            setState(() {
              _currentIndex++;
              _percent = null;
            });
            _startCurrent();
          },
        );
  }

  @override
  Widget build(BuildContext context) {
    final total = widget.songs.length;
    final idx = (_currentIndex < total) ? _currentIndex + 1 : total;
    final title = (_currentIndex < total)
        ? widget.songs[_currentIndex].title
        : '';

    return Container(
      color: Colors.black.withValues(alpha: 0.65),
      padding: const EdgeInsets.all(24),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460),
          child: Material(
            color: Colors.black.withValues(alpha: 0.75),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
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
                  const SizedBox(height: 8),
                  Text(
                    '$idx / $total  $title',
                    style: const TextStyle(color: Colors.white70),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 12),
                  if (_error == null) ...[
                    LinearProgressIndicator(
                      value: (_percent != null)
                          ? (_percent!.clamp(0, 100) / 100.0)
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
                      textAlign: TextAlign.right,
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _cancelled = true;
                            _cancelToken?.cancel('user_cancel');
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
                    Text(
                      '$_error',
                      style: const TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () {
                            _cancelled = true;
                            widget.onClose();
                          },
                          child: Text(
                            _loc.getString('ktv.back', defaultValue: 'Back'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            _error = null;
                            _cancelled = false;
                            _startCurrent();
                          },
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
