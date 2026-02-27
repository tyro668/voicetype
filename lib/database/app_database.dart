import 'dart:async';
import 'dart:io';
import 'package:floor/floor.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' as sqflite;
import '../models/meeting.dart';
import '../models/transcription.dart';
import 'meeting_dao.dart';
import 'meeting_entity.dart';
import 'meeting_segment_dao.dart';
import 'meeting_segment_entity.dart';
import 'setting_dao.dart';
import 'setting_entity.dart';
import 'transcription_dao.dart';
import 'transcription_entity.dart';

part 'app_database.g.dart';

/// 统一的 SQLite 数据库，使用 Floor ORM 管理历史记录和所有配置数据。
@Database(
  version: 6,
  entities: [
    SettingEntity,
    TranscriptionEntity,
    MeetingEntity,
    MeetingSegmentEntity,
  ],
)
abstract class AppDatabase extends FloorDatabase {
  SettingDao get settingDao;
  TranscriptionDao get transcriptionDao;
  MeetingDao get meetingDao;
  MeetingSegmentDao get meetingSegmentDao;

  // ==================== 单例管理 ====================

  static AppDatabase? _instance;
  static bool _useInMemory = false;

  static Future<String> _resolveDatabaseNameOrPath() async {
    if (kIsWeb) return 'voicetype.db';
    if (Platform.isMacOS || Platform.isLinux || Platform.isWindows) {
      final appSupportDir = await getApplicationSupportDirectory();
      final dbDir = Directory(
        p.join(appSupportDir.path, 'voicetype', 'databases'),
      );
      if (!await dbDir.exists()) {
        await dbDir.create(recursive: true);
      }
      return p.join(dbDir.path, 'voicetype.db');
    }
    return 'voicetype.db';
  }

  /// 获取数据库单例（首次调用会异步初始化）。
  static Future<AppDatabase> getInstance() async {
    if (_instance != null) return _instance!;
    if (_useInMemory) {
      _instance = await $FloorAppDatabase
          .inMemoryDatabaseBuilder()
          .addMigrations(_migrations)
          .build();
    } else {
      final dbPath = await _resolveDatabaseNameOrPath();
      _instance = await $FloorAppDatabase
          .databaseBuilder(dbPath)
          .addMigrations(_migrations)
          .build();
    }
    return _instance!;
  }

  /// 同步访问已初始化的数据库实例。
  /// 必须先调用 [getInstance] 完成初始化。
  static AppDatabase get instance {
    assert(
      _instance != null,
      'AppDatabase not initialized. Call getInstance() first.',
    );
    return _instance!;
  }

  /// 仅限测试使用：重置为内存数据库，避免文件锁冲突。
  @visibleForTesting
  static Future<void> resetForTest() async {
    await _instance?.close();
    _instance = null;
    _useInMemory = true;
    // 预建内存数据库，以便测试中可同步使用 instance。
    await getInstance();
  }

  // ==================== 配置项便捷方法 ====================

  /// 读取配置值。
  Future<String?> getSetting(String key) async {
    return (await settingDao.findByKey(key))?.value;
  }

  /// 写入配置值。
  Future<void> setSetting(String key, String value) async {
    await settingDao.insertSetting(SettingEntity(key, value));
  }

  /// 删除配置值。
  Future<void> removeSetting(String key) async {
    await settingDao.deleteByKey(key);
  }

  /// 读取所有配置。
  Future<Map<String, String>> getAllSettings() async {
    final entities = await settingDao.getAll();
    return {for (final e in entities) e.key: e.value};
  }

  // ==================== 历史记录便捷方法 ====================

  Future<List<Transcription>> getAllHistory() async {
    final entities = await transcriptionDao.getAll();
    return entities.map((e) => e.toModel()).toList();
  }

  Future<void> insertHistory(Transcription item) async {
    await transcriptionDao.insertItem(TranscriptionEntity.fromModel(item));
  }

  Future<void> deleteHistoryById(String id) async {
    await transcriptionDao.deleteById(id);
  }

  Future<void> clearHistory() async {
    await transcriptionDao.deleteAll();
  }

  // ==================== 数据库迁移 ====================

  static final _migrations = [
    Migration(1, 2, (database) async {
      await database.execute(
        'ALTER TABLE transcriptions ADD COLUMN model TEXT NOT NULL DEFAULT ""',
      );
      await database.execute(
        'ALTER TABLE transcriptions ADD COLUMN provider_config TEXT NOT NULL DEFAULT "{}"',
      );
    }),
    Migration(2, 3, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `settings` '
        '(`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY (`key`))',
      );
    }),
    Migration(3, 4, (database) async {
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `meetings` '
        '(`id` TEXT NOT NULL, '
        '`title` TEXT NOT NULL, '
        '`created_at` TEXT NOT NULL, '
        '`updated_at` TEXT NOT NULL, '
        '`status` TEXT NOT NULL, '
        '`summary` TEXT, '
        '`total_duration_ms` INTEGER NOT NULL, '
        'PRIMARY KEY (`id`))',
      );
      await database.execute(
        'CREATE TABLE IF NOT EXISTS `meeting_segments` '
        '(`id` TEXT NOT NULL, '
        '`meeting_id` TEXT NOT NULL, '
        '`segment_index` INTEGER NOT NULL, '
        '`start_time` TEXT NOT NULL, '
        '`duration_ms` INTEGER NOT NULL, '
        '`audio_file_path` TEXT, '
        '`transcription` TEXT, '
        '`enhanced_text` TEXT, '
        '`status` TEXT NOT NULL, '
        '`error_message` TEXT, '
        'PRIMARY KEY (`id`), '
        'FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`) ON DELETE CASCADE)',
      );
    }),
    Migration(4, 5, (database) async {
      // Guard: only add column if it doesn't already exist
      final cols = await database.rawQuery('PRAGMA table_info(meetings)');
      final hasCol = cols.any((c) => c['name'] == 'full_transcription');
      if (!hasCol) {
        await database.execute(
          'ALTER TABLE meetings ADD COLUMN full_transcription TEXT',
        );
      }
    }),
    Migration(5, 6, (database) async {
      final cols = await database.rawQuery('PRAGMA table_info(transcriptions)');
      final hasCol = cols.any((c) => c['name'] == 'raw_text');
      if (!hasCol) {
        await database.execute(
          'ALTER TABLE transcriptions ADD COLUMN raw_text TEXT',
        );
      }
    }),
  ];

  // ==================== 会议记录便捷方法 ====================

  Future<List<MeetingRecord>> getAllMeetings() async {
    final entities = await meetingDao.getAll();
    return entities.map((e) => e.toModel()).toList();
  }

  Future<MeetingRecord?> getMeetingById(String id) async {
    final entity = await meetingDao.findById(id);
    return entity?.toModel();
  }

  Future<void> insertMeeting(MeetingRecord meeting) async {
    await meetingDao.insertMeeting(MeetingEntity.fromModel(meeting));
  }

  Future<void> updateMeeting(MeetingRecord meeting) async {
    await meetingDao.updateMeeting(MeetingEntity.fromModel(meeting));
  }

  Future<void> deleteMeetingById(String id) async {
    await meetingSegmentDao.deleteByMeetingId(id);
    await meetingDao.deleteById(id);
  }

  Future<void> clearMeetings() async {
    await meetingDao.deleteAll();
  }

  Future<List<MeetingSegment>> getMeetingSegments(String meetingId) async {
    final entities = await meetingSegmentDao.getByMeetingId(meetingId);
    return entities.map((e) => e.toModel()).toList();
  }

  Future<void> insertMeetingSegment(MeetingSegment segment) async {
    await meetingSegmentDao.insertSegment(
      MeetingSegmentEntity.fromModel(segment),
    );
  }

  Future<void> updateMeetingSegment(MeetingSegment segment) async {
    await meetingSegmentDao.updateSegment(
      MeetingSegmentEntity.fromModel(segment),
    );
  }
}
