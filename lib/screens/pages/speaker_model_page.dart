import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../l10n/app_localizations.dart';
import '../../providers/settings_provider.dart';
import '../../services/log_service.dart';
import '../../services/three_d_speaker_model_service.dart';

class SpeakerModelPage extends StatefulWidget {
  const SpeakerModelPage({super.key});

  @override
  State<SpeakerModelPage> createState() => _SpeakerModelPageState();
}

class _SpeakerModelPageState extends State<SpeakerModelPage> {
  ColorScheme get _cs => Theme.of(context).colorScheme;

  bool _downloadingSpeakerModel = false;
  double _speakerModelDownloadProgress = 0.0;
  int _speakerModelDownloadedBytes = 0;
  int _speakerModelTotalBytes = 0;

  @override
  Widget build(BuildContext context) {
    final settings = context.watch<SettingsProvider>();
    final l10n = AppLocalizations.of(context)!;

    return Align(
      alignment: Alignment.topCenter,
      child: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 32),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l10n.speakerModelTitle,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w600,
                color: _cs.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              l10n.speakerModelDescription,
              style: TextStyle(fontSize: 14, color: _cs.onSurfaceVariant),
            ),
            const SizedBox(height: 16),
            _buildSpeaker3dSection(settings, l10n),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }

  Widget _buildSpeaker3dSection(
    SettingsProvider settings,
    AppLocalizations l10n,
  ) {
    const downloadSourceModes = ['auto', 'direct', 'mirror'];
    const maxOptions = [2, 3, 4, 5, 6, 8, 10, 12];
    final maxValue = maxOptions.contains(settings.speaker3dMaxSpeakers)
        ? settings.speaker3dMaxSpeakers
        : 6;
    final modelPath = settings.speaker3dModelPath.trim();
    final hasPath = modelPath.isNotEmpty;
    final modelExists = hasPath ? File(modelPath).existsSync() : false;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.record_voice_over_outlined,
                size: 20,
                color: _cs.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  l10n.speakerModelEnable,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: _cs.onSurface,
                  ),
                ),
              ),
              Switch(
                value: settings.speaker3dEnabled,
                onChanged: settings.setSpeaker3dEnabled,
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.speakerModelMaxSpeakers,
                  style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                ),
              ),
              DropdownButton<int>(
                value: maxValue,
                onChanged: settings.speaker3dEnabled
                    ? (value) {
                        if (value == null) return;
                        settings.setSpeaker3dMaxSpeakers(value);
                      }
                    : null,
                items: maxOptions
                    .map(
                      (value) => DropdownMenuItem<int>(
                        value: value,
                        child: Text('$value'),
                      ),
                    )
                    .toList(),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.speakerModelDownloadSource,
                  style: TextStyle(fontSize: 13, color: _cs.onSurfaceVariant),
                ),
              ),
              DropdownButton<String>(
                value:
                    downloadSourceModes.contains(
                      settings.speaker3dDownloadSourceMode,
                    )
                    ? settings.speaker3dDownloadSourceMode
                    : 'auto',
                onChanged:
                    settings.speaker3dEnabled && !_downloadingSpeakerModel
                    ? (value) {
                        if (value == null) return;
                        settings.setSpeaker3dDownloadSourceMode(value);
                      }
                    : null,
                items: [
                  DropdownMenuItem<String>(
                    value: 'auto',
                    child: Text(l10n.speakerModelDownloadSourceAuto),
                  ),
                  DropdownMenuItem<String>(
                    value: 'direct',
                    child: Text(l10n.speakerModelDownloadSourceDirect),
                  ),
                  DropdownMenuItem<String>(
                    value: 'mirror',
                    child: Text(l10n.speakerModelDownloadSourceMirror),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: Text(
                  hasPath ? modelPath : l10n.speakerModelPathNotSet,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13,
                    color: hasPath ? _cs.onSurface : _cs.onSurfaceVariant,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                onPressed: settings.speaker3dEnabled
                    ? () => _pickSpeakerModelFile(settings)
                    : null,
                child: Text(l10n.speakerModelPickModel),
              ),
              const SizedBox(width: 8),
              FilledButton.tonal(
                onPressed:
                    settings.speaker3dEnabled && !_downloadingSpeakerModel
                    ? () => _downloadSpeakerModel(settings)
                    : null,
                child: Text(
                  _downloadingSpeakerModel
                      ? l10n.speakerModelDownloading
                      : l10n.speakerModelDownloadDefault,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerLeft,
            child: OutlinedButton.icon(
              onPressed: () => _openModelDirectory(settings),
              icon: const Icon(Icons.folder_open_outlined, size: 18),
              label: Text(l10n.openModelDir),
            ),
          ),
          if (_downloadingSpeakerModel) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _speakerModelDownloadProgress),
            const SizedBox(height: 6),
            Text(
              _formatSpeakerDownloadStatus(),
              style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
            ),
          ],
          const SizedBox(height: 8),
          Text(
            hasPath
                ? (modelExists
                      ? l10n.speakerModelReady
                      : l10n.speakerModelMissing)
                : l10n.speakerModelDefaultLookup,
            style: TextStyle(
              fontSize: 12,
              color: modelExists || !hasPath
                  ? _cs.onSurfaceVariant
                  : Colors.red,
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _pickSpeakerModelFile(SettingsProvider settings) async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['onnx'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;
    await settings.setSpeaker3dModelPath(path);
  }

  Future<void> _downloadSpeakerModel(SettingsProvider settings) async {
    if (_downloadingSpeakerModel) return;

    setState(() {
      _downloadingSpeakerModel = true;
      _speakerModelDownloadProgress = 0.0;
      _speakerModelDownloadedBytes = 0;
      _speakerModelTotalBytes = 0;
    });

    final messenger = ScaffoldMessenger.of(context);
    try {
      final modelPath = await ThreeDSpeakerModelService.downloadDefaultModel(
        mode: _resolveDownloadSourceMode(settings.speaker3dDownloadSourceMode),
        onProgress: (progress) {
          if (!mounted) return;
          setState(() {
            _speakerModelDownloadProgress = progress.progress;
            _speakerModelDownloadedBytes = progress.downloadedBytes;
            _speakerModelTotalBytes = progress.totalBytes;
          });
        },
      );

      await settings.setSpeaker3dModelPath(modelPath);

      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.speakerModelDownloaded),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      final l10n = AppLocalizations.of(context)!;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.speakerModelDownloadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } finally {
      if (!mounted) return;
      setState(() {
        _downloadingSpeakerModel = false;
      });
    }
  }

  String _formatSpeakerDownloadStatus() {
    final l10n = AppLocalizations.of(context)!;
    final downloaded = LogService.formatFileSize(_speakerModelDownloadedBytes);
    final totalBytes = _speakerModelTotalBytes;
    final percent = (_speakerModelDownloadProgress * 100).clamp(0, 100);
    if (totalBytes > 0) {
      final total = LogService.formatFileSize(totalBytes);
      return l10n.speakerModelDownloadStatusKnown(
        downloaded,
        total,
        percent.toStringAsFixed(1),
      );
    }
    return l10n.speakerModelDownloadStatusUnknown(downloaded);
  }

  ThreeDSpeakerDownloadSourceMode _resolveDownloadSourceMode(String mode) {
    switch (mode.trim().toLowerCase()) {
      case 'direct':
        return ThreeDSpeakerDownloadSourceMode.directOnly;
      case 'mirror':
        return ThreeDSpeakerDownloadSourceMode.mirrorOnly;
      case 'auto':
      default:
        return ThreeDSpeakerDownloadSourceMode.auto;
    }
  }

  Future<void> _openModelDirectory(SettingsProvider settings) async {
    final l10n = AppLocalizations.of(context)!;
    final configuredPath = settings.speaker3dModelPath.trim();

    String targetDir;
    if (configuredPath.isNotEmpty) {
      final type = FileSystemEntity.typeSync(configuredPath);
      if (type == FileSystemEntityType.directory) {
        targetDir = configuredPath;
      } else {
        targetDir = File(configuredPath).parent.path;
      }
    } else {
      targetDir = await ThreeDSpeakerModelService.defaultModelDir();
    }

    try {
      final result = Platform.isWindows
          ? await Process.run('explorer', [targetDir])
          : await Process.run('open', [targetDir]);

      if (result.exitCode != 0 && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(l10n.openFolderFailed),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(l10n.openFolderFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }
}
