import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
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
    const maxOptions = [1, 2, 3, 4, 5, 6, 8, 10, 12];
    final maxValue = maxOptions.contains(settings.speaker3dMaxSpeakers)
        ? settings.speaker3dMaxSpeakers
        : 6;
    final modelPaths = settings.speaker3dModelPaths;
    final modelPath = settings.speaker3dModelPath.trim();
    final enabled = settings.speaker3dEnabled;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: _cs.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: _cs.outlineVariant.withValues(alpha: 0.28)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // ── Header: icon + title/subtitle + toggle ──
          Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: _cs.primaryContainer.withValues(alpha: 0.5),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.record_voice_over_outlined,
                  size: 22,
                  color: _cs.primary,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.speakerModelHeaderTitle,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: _cs.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      l10n.speakerModelHeaderSubtitle,
                      style: TextStyle(
                        fontSize: 12,
                        color: _cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: settings.speaker3dEnabled,
                onChanged: settings.setSpeaker3dEnabled,
              ),
            ],
          ),
          const SizedBox(height: 24),
          // ── 基础设置 ──
          Text(
            l10n.speakerModelBasicSettings,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: _cs.onSurface,
            ),
          ),
          const SizedBox(height: 16),
          // 最大说话人数
          Row(
            children: [
              Text(
                l10n.speakerModelMaxSpeakers,
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                  color: _cs.onSurface,
                ),
              ),
              const SizedBox(width: 4),
              Tooltip(
                message: l10n.speakerModelMaxSpeakersDesc,
                child: Icon(
                  Icons.info_outline,
                  size: 16,
                  color: _cs.onSurfaceVariant,
                ),
              ),
              const Spacer(),
              DropdownButton<int>(
                value: maxValue,
                onChanged: enabled
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
          const SizedBox(height: 24),
          // ── 算法参数 ──
          Row(
            children: [
              Text(
                l10n.speakerModelAlgorithmParams,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              _buildPresetButton(
                label: l10n.speakerModelPresetConsistency,
                preset: SettingsProvider.speaker3dPresetConsistency,
                settings: settings,
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                label: l10n.speakerModelPresetBalanced,
                preset: SettingsProvider.speaker3dPresetBalanced,
                settings: settings,
              ),
              const SizedBox(width: 8),
              _buildPresetButton(
                label: l10n.speakerModelPresetSeparation,
                preset: SettingsProvider.speaker3dPresetSeparation,
                settings: settings,
              ),
            ],
          ),
          const SizedBox(height: 16),
          _buildThresholdSlider(
            label: l10n.speakerModelOnlineBaseThreshold,
            tooltip: l10n.speakerModelOnlineBaseThresholdDesc,
            value: settings.speaker3dOnlineBaseThreshold,
            min: 0.50,
            max: 0.95,
            divisions: 45,
            enabled: enabled,
            onChanged: settings.setSpeaker3dOnlineBaseThreshold,
          ),
          const SizedBox(height: 16),
          _buildThresholdSlider(
            label: l10n.speakerModelTop1Top2Margin,
            tooltip: l10n.speakerModelTop1Top2MarginDesc,
            value: settings.speaker3dTop1Top2Margin,
            min: 0.00,
            max: 0.20,
            divisions: 20,
            enabled: enabled,
            onChanged: settings.setSpeaker3dTop1Top2Margin,
          ),
          const SizedBox(height: 16),
          _buildThresholdSlider(
            label: l10n.speakerModelOfflineMergeThreshold,
            tooltip: l10n.speakerModelOfflineMergeThresholdDesc,
            value: settings.speaker3dOfflineMergeThreshold,
            min: 0.50,
            max: 0.95,
            divisions: 45,
            enabled: enabled,
            onChanged: settings.setSpeaker3dOfflineMergeThreshold,
          ),
          const SizedBox(height: 24),
          // ── 声纹模型管理 ──
          Row(
            children: [
              Text(
                l10n.speakerModelManagement,
                style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: _cs.onSurface,
                ),
              ),
              const Spacer(),
              OutlinedButton.icon(
                onPressed: enabled && !_downloadingSpeakerModel
                    ? () => _downloadSpeakerModel(settings)
                    : null,
                icon: const Icon(Icons.download_outlined, size: 16),
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: Size.zero,
                ),
                label: Text(
                  _downloadingSpeakerModel
                      ? l10n.speakerModelDownloading
                      : l10n.speakerModelDownloadDefault,
                ),
              ),
              const SizedBox(width: 8),
              FilledButton.icon(
                onPressed: enabled
                    ? () => _pickSpeakerModelFile(settings)
                    : null,
                icon: const Icon(Icons.file_upload_outlined, size: 16),
                style: FilledButton.styleFrom(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 6,
                  ),
                  textStyle: const TextStyle(fontSize: 12),
                  minimumSize: Size.zero,
                ),
                label: Text(l10n.speakerModelImportLocal),
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (modelPaths.isNotEmpty) ...[
            ...modelPaths.map((path) {
              final isActive = path == modelPath;
              final exists = File(path).existsSync();
              final name = p.basename(path);
              String? sizeText;
              if (exists) {
                try {
                  sizeText = LogService.formatFileSize(File(path).lengthSync());
                } catch (_) {}
              }
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: isActive
                        ? _cs.secondaryContainer.withValues(alpha: 0.3)
                        : _cs.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isActive
                          ? _cs.secondary.withValues(alpha: 0.4)
                          : _cs.outlineVariant.withValues(alpha: 0.22),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        width: 36,
                        height: 36,
                        decoration: BoxDecoration(
                          color: _cs.surfaceContainerHighest.withValues(
                            alpha: 0.5,
                          ),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          Icons.settings_outlined,
                          size: 18,
                          color: _cs.onSurfaceVariant,
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Flexible(
                                  child: Text(
                                    name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w600,
                                      color: exists
                                          ? _cs.onSurface
                                          : Colors.red,
                                    ),
                                  ),
                                ),
                                if (isActive) ...[
                                  const SizedBox(width: 8),
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: Colors.green.withValues(
                                        alpha: 0.12,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: Text(
                                      '✓ ${l10n.currentlyInUse}',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        color: Colors.green,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ),
                                ],
                              ],
                            ),
                            if (exists)
                              Text(
                                '${l10n.speakerModelReady}${sizeText != null ? ' · $sizeText' : ''}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: _cs.onSurfaceVariant,
                                ),
                              ),
                            if (!exists)
                              Text(
                                l10n.speakerModelMissing,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: Colors.red,
                                ),
                              ),
                          ],
                        ),
                      ),
                      if (!isActive)
                        IconButton(
                          tooltip: l10n.useThisModel,
                          onPressed: enabled
                              ? () => settings.setActiveSpeaker3dModelPath(path)
                              : null,
                          icon: Icon(
                            Icons.check_circle_outline,
                            size: 18,
                            color: _cs.onSurfaceVariant,
                          ),
                          visualDensity: VisualDensity.compact,
                        ),
                      IconButton(
                        tooltip: l10n.openModelDir,
                        onPressed: () => _openModelDirectory(settings),
                        icon: Icon(
                          Icons.folder_open_outlined,
                          size: 18,
                          color: _cs.onSurfaceVariant,
                        ),
                        visualDensity: VisualDensity.compact,
                      ),
                      IconButton(
                        tooltip: l10n.delete,
                        onPressed: enabled
                            ? () => settings.removeSpeaker3dModelPath(path)
                            : null,
                        icon: const Icon(Icons.delete_outline, size: 18),
                        visualDensity: VisualDensity.compact,
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
          if (_downloadingSpeakerModel) ...[
            const SizedBox(height: 10),
            LinearProgressIndicator(value: _speakerModelDownloadProgress),
            const SizedBox(height: 6),
            Text(
              _formatSpeakerDownloadStatus(),
              style: TextStyle(fontSize: 12, color: _cs.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThresholdSlider({
    required String label,
    required String tooltip,
    required double value,
    required double min,
    required double max,
    required int divisions,
    required bool enabled,
    required ValueChanged<double> onChanged,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(
              label,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w500,
                color: _cs.onSurface,
              ),
            ),
            const SizedBox(width: 4),
            Tooltip(
              message: tooltip,
              child: Icon(
                Icons.info_outline,
                size: 16,
                color: _cs.onSurfaceVariant,
              ),
            ),
            const Spacer(),
            Text(
              value.toStringAsFixed(2),
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: _cs.primary,
              ),
            ),
          ],
        ),
        Slider(
          value: value.clamp(min, max),
          min: min,
          max: max,
          divisions: divisions,
          onChanged: enabled ? onChanged : null,
        ),
      ],
    );
  }

  Widget _buildPresetButton({
    required String label,
    required String preset,
    required SettingsProvider settings,
  }) {
    final isActive = _isPresetActive(preset, settings);
    final isEnabled = settings.speaker3dEnabled;
    if (isActive) {
      return FilledButton.tonal(
        onPressed: isEnabled
            ? () => settings.applySpeaker3dPreset(preset)
            : null,
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          textStyle: const TextStyle(fontSize: 12),
          minimumSize: Size.zero,
        ),
        child: Text(label),
      );
    }
    return OutlinedButton(
      onPressed: isEnabled ? () => settings.applySpeaker3dPreset(preset) : null,
      style: OutlinedButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        textStyle: const TextStyle(fontSize: 12),
        minimumSize: Size.zero,
      ),
      child: Text(label),
    );
  }

  bool _isPresetActive(String preset, SettingsProvider settings) {
    switch (preset) {
      case SettingsProvider.speaker3dPresetConsistency:
        return settings.speaker3dOnlineBaseThreshold == 0.72 &&
            settings.speaker3dTop1Top2Margin == 0.01 &&
            settings.speaker3dOfflineMergeThreshold == 0.72;
      case SettingsProvider.speaker3dPresetBalanced:
        return settings.speaker3dOnlineBaseThreshold == 0.78 &&
            settings.speaker3dTop1Top2Margin == 0.04 &&
            settings.speaker3dOfflineMergeThreshold == 0.80;
      case SettingsProvider.speaker3dPresetSeparation:
        return settings.speaker3dOnlineBaseThreshold == 0.84 &&
            settings.speaker3dTop1Top2Margin == 0.06 &&
            settings.speaker3dOfflineMergeThreshold == 0.84;
      default:
        return false;
    }
  }

  Future<void> _pickSpeakerModelFile(SettingsProvider settings) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context)!;
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['onnx'],
      allowMultiple: false,
    );
    final path = result?.files.single.path;
    if (path == null || path.trim().isEmpty) return;

    try {
      final importedPath = await ThreeDSpeakerModelService.importModelFile(
        path,
      );
      await settings.setSpeaker3dModelPath(importedPath);
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.speakerModelDownloaded),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (_) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(
          content: Text(l10n.speakerModelDownloadFailed),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
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
