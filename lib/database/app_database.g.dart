// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// **************************************************************************
// FloorGenerator
// **************************************************************************

abstract class $AppDatabaseBuilderContract {
  /// Adds migrations to the builder.
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations);

  /// Adds a database [Callback] to the builder.
  $AppDatabaseBuilderContract addCallback(Callback callback);

  /// Creates the database and initializes it.
  Future<AppDatabase> build();
}

// ignore: avoid_classes_with_only_static_members
class $FloorAppDatabase {
  /// Creates a database builder for a persistent database.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract databaseBuilder(String name) =>
      _$AppDatabaseBuilder(name);

  /// Creates a database builder for an in memory database.
  /// Information stored in an in memory database disappears when the process is killed.
  /// Once a database is built, you should keep a reference to it and re-use it.
  static $AppDatabaseBuilderContract inMemoryDatabaseBuilder() =>
      _$AppDatabaseBuilder(null);
}

class _$AppDatabaseBuilder implements $AppDatabaseBuilderContract {
  _$AppDatabaseBuilder(this.name);

  final String? name;

  final List<Migration> _migrations = [];

  Callback? _callback;

  @override
  $AppDatabaseBuilderContract addMigrations(List<Migration> migrations) {
    _migrations.addAll(migrations);
    return this;
  }

  @override
  $AppDatabaseBuilderContract addCallback(Callback callback) {
    _callback = callback;
    return this;
  }

  @override
  Future<AppDatabase> build() async {
    final path = name != null
        ? await sqfliteDatabaseFactory.getDatabasePath(name!)
        : ':memory:';
    final database = _$AppDatabase();
    database.database = await database.open(
      path,
      _migrations,
      _callback,
    );
    return database;
  }
}

class _$AppDatabase extends AppDatabase {
  _$AppDatabase([StreamController<String>? listener]) {
    changeListener = listener ?? StreamController<String>.broadcast();
  }

  SettingDao? _settingDaoInstance;

  TranscriptionDao? _transcriptionDaoInstance;

  MeetingDao? _meetingDaoInstance;

  MeetingSegmentDao? _meetingSegmentDaoInstance;

  Future<sqflite.Database> open(
    String path,
    List<Migration> migrations, [
    Callback? callback,
  ]) async {
    final databaseOptions = sqflite.OpenDatabaseOptions(
      version: 6,
      onConfigure: (database) async {
        await database.execute('PRAGMA foreign_keys = ON');
        await callback?.onConfigure?.call(database);
      },
      onOpen: (database) async {
        await callback?.onOpen?.call(database);
      },
      onUpgrade: (database, startVersion, endVersion) async {
        await MigrationAdapter.runMigrations(
            database, startVersion, endVersion, migrations);

        await callback?.onUpgrade?.call(database, startVersion, endVersion);
      },
      onCreate: (database, version) async {
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `settings` (`key` TEXT NOT NULL, `value` TEXT NOT NULL, PRIMARY KEY (`key`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `transcriptions` (`id` TEXT NOT NULL, `text` TEXT NOT NULL, `raw_text` TEXT, `created_at` TEXT NOT NULL, `duration_ms` INTEGER NOT NULL, `provider` TEXT NOT NULL, `model` TEXT NOT NULL, `provider_config` TEXT NOT NULL, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `meetings` (`id` TEXT NOT NULL, `title` TEXT NOT NULL, `created_at` TEXT NOT NULL, `updated_at` TEXT NOT NULL, `status` TEXT NOT NULL, `summary` TEXT, `total_duration_ms` INTEGER NOT NULL, `full_transcription` TEXT, PRIMARY KEY (`id`))');
        await database.execute(
            'CREATE TABLE IF NOT EXISTS `meeting_segments` (`id` TEXT NOT NULL, `meeting_id` TEXT NOT NULL, `segment_index` INTEGER NOT NULL, `start_time` TEXT NOT NULL, `duration_ms` INTEGER NOT NULL, `audio_file_path` TEXT, `transcription` TEXT, `enhanced_text` TEXT, `status` TEXT NOT NULL, `error_message` TEXT, FOREIGN KEY (`meeting_id`) REFERENCES `meetings` (`id`) ON UPDATE NO ACTION ON DELETE CASCADE, PRIMARY KEY (`id`))');

        await callback?.onCreate?.call(database, version);
      },
    );
    return sqfliteDatabaseFactory.openDatabase(path, options: databaseOptions);
  }

  @override
  SettingDao get settingDao {
    return _settingDaoInstance ??= _$SettingDao(database, changeListener);
  }

  @override
  TranscriptionDao get transcriptionDao {
    return _transcriptionDaoInstance ??=
        _$TranscriptionDao(database, changeListener);
  }

  @override
  MeetingDao get meetingDao {
    return _meetingDaoInstance ??= _$MeetingDao(database, changeListener);
  }

  @override
  MeetingSegmentDao get meetingSegmentDao {
    return _meetingSegmentDaoInstance ??=
        _$MeetingSegmentDao(database, changeListener);
  }
}

class _$SettingDao extends SettingDao {
  _$SettingDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _settingEntityInsertionAdapter = InsertionAdapter(
            database,
            'settings',
            (SettingEntity item) =>
                <String, Object?>{'key': item.key, 'value': item.value});

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<SettingEntity> _settingEntityInsertionAdapter;

  @override
  Future<SettingEntity?> findByKey(String key) async {
    return _queryAdapter.query('SELECT * FROM settings WHERE `key` = ?1',
        mapper: (Map<String, Object?> row) =>
            SettingEntity(row['key'] as String, row['value'] as String),
        arguments: [key]);
  }

  @override
  Future<List<SettingEntity>> getAll() async {
    return _queryAdapter.queryList('SELECT * FROM settings',
        mapper: (Map<String, Object?> row) =>
            SettingEntity(row['key'] as String, row['value'] as String));
  }

  @override
  Future<void> deleteByKey(String key) async {
    await _queryAdapter.queryNoReturn('DELETE FROM settings WHERE `key` = ?1',
        arguments: [key]);
  }

  @override
  Future<void> insertSetting(SettingEntity setting) async {
    await _settingEntityInsertionAdapter.insert(
        setting, OnConflictStrategy.replace);
  }
}

class _$TranscriptionDao extends TranscriptionDao {
  _$TranscriptionDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _transcriptionEntityInsertionAdapter = InsertionAdapter(
            database,
            'transcriptions',
            (TranscriptionEntity item) => <String, Object?>{
                  'id': item.id,
                  'text': item.text,
                  'raw_text': item.rawText,
                  'created_at': item.createdAt,
                  'duration_ms': item.durationMs,
                  'provider': item.provider,
                  'model': item.model,
                  'provider_config': item.providerConfig
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<TranscriptionEntity>
      _transcriptionEntityInsertionAdapter;

  @override
  Future<List<TranscriptionEntity>> getAll() async {
    return _queryAdapter.queryList(
        'SELECT * FROM transcriptions ORDER BY created_at DESC',
        mapper: (Map<String, Object?> row) => TranscriptionEntity(
            id: row['id'] as String,
            text: row['text'] as String,
            rawText: row['raw_text'] as String?,
            createdAt: row['created_at'] as String,
            durationMs: row['duration_ms'] as int,
            provider: row['provider'] as String,
            model: row['model'] as String,
            providerConfig: row['provider_config'] as String));
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM transcriptions WHERE id = ?1',
        arguments: [id]);
  }

  @override
  Future<void> deleteAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM transcriptions');
  }

  @override
  Future<void> insertItem(TranscriptionEntity item) async {
    await _transcriptionEntityInsertionAdapter.insert(
        item, OnConflictStrategy.replace);
  }
}

class _$MeetingDao extends MeetingDao {
  _$MeetingDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _meetingEntityInsertionAdapter = InsertionAdapter(
            database,
            'meetings',
            (MeetingEntity item) => <String, Object?>{
                  'id': item.id,
                  'title': item.title,
                  'created_at': item.createdAt,
                  'updated_at': item.updatedAt,
                  'status': item.status,
                  'summary': item.summary,
                  'total_duration_ms': item.totalDurationMs,
                  'full_transcription': item.fullTranscription
                }),
        _meetingEntityUpdateAdapter = UpdateAdapter(
            database,
            'meetings',
            ['id'],
            (MeetingEntity item) => <String, Object?>{
                  'id': item.id,
                  'title': item.title,
                  'created_at': item.createdAt,
                  'updated_at': item.updatedAt,
                  'status': item.status,
                  'summary': item.summary,
                  'total_duration_ms': item.totalDurationMs,
                  'full_transcription': item.fullTranscription
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<MeetingEntity> _meetingEntityInsertionAdapter;

  final UpdateAdapter<MeetingEntity> _meetingEntityUpdateAdapter;

  @override
  Future<List<MeetingEntity>> getAll() async {
    return _queryAdapter.queryList(
        'SELECT * FROM meetings ORDER BY created_at DESC',
        mapper: (Map<String, Object?> row) => MeetingEntity(
            id: row['id'] as String,
            title: row['title'] as String,
            createdAt: row['created_at'] as String,
            updatedAt: row['updated_at'] as String,
            status: row['status'] as String,
            summary: row['summary'] as String?,
            totalDurationMs: row['total_duration_ms'] as int,
            fullTranscription: row['full_transcription'] as String?));
  }

  @override
  Future<MeetingEntity?> findById(String id) async {
    return _queryAdapter.query('SELECT * FROM meetings WHERE id = ?1',
        mapper: (Map<String, Object?> row) => MeetingEntity(
            id: row['id'] as String,
            title: row['title'] as String,
            createdAt: row['created_at'] as String,
            updatedAt: row['updated_at'] as String,
            status: row['status'] as String,
            summary: row['summary'] as String?,
            totalDurationMs: row['total_duration_ms'] as int,
            fullTranscription: row['full_transcription'] as String?),
        arguments: [id]);
  }

  @override
  Future<List<MeetingEntity>> findByStatus(String status) async {
    return _queryAdapter.queryList(
        'SELECT * FROM meetings WHERE status = ?1 ORDER BY created_at DESC',
        mapper: (Map<String, Object?> row) => MeetingEntity(
            id: row['id'] as String,
            title: row['title'] as String,
            createdAt: row['created_at'] as String,
            updatedAt: row['updated_at'] as String,
            status: row['status'] as String,
            summary: row['summary'] as String?,
            totalDurationMs: row['total_duration_ms'] as int,
            fullTranscription: row['full_transcription'] as String?),
        arguments: [status]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter
        .queryNoReturn('DELETE FROM meetings WHERE id = ?1', arguments: [id]);
  }

  @override
  Future<void> deleteAll() async {
    await _queryAdapter.queryNoReturn('DELETE FROM meetings');
  }

  @override
  Future<void> insertMeeting(MeetingEntity meeting) async {
    await _meetingEntityInsertionAdapter.insert(
        meeting, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateMeeting(MeetingEntity meeting) async {
    await _meetingEntityUpdateAdapter.update(
        meeting, OnConflictStrategy.replace);
  }
}

class _$MeetingSegmentDao extends MeetingSegmentDao {
  _$MeetingSegmentDao(
    this.database,
    this.changeListener,
  )   : _queryAdapter = QueryAdapter(database),
        _meetingSegmentEntityInsertionAdapter = InsertionAdapter(
            database,
            'meeting_segments',
            (MeetingSegmentEntity item) => <String, Object?>{
                  'id': item.id,
                  'meeting_id': item.meetingId,
                  'segment_index': item.segmentIndex,
                  'start_time': item.startTime,
                  'duration_ms': item.durationMs,
                  'audio_file_path': item.audioFilePath,
                  'transcription': item.transcription,
                  'enhanced_text': item.enhancedText,
                  'status': item.status,
                  'error_message': item.errorMessage
                }),
        _meetingSegmentEntityUpdateAdapter = UpdateAdapter(
            database,
            'meeting_segments',
            ['id'],
            (MeetingSegmentEntity item) => <String, Object?>{
                  'id': item.id,
                  'meeting_id': item.meetingId,
                  'segment_index': item.segmentIndex,
                  'start_time': item.startTime,
                  'duration_ms': item.durationMs,
                  'audio_file_path': item.audioFilePath,
                  'transcription': item.transcription,
                  'enhanced_text': item.enhancedText,
                  'status': item.status,
                  'error_message': item.errorMessage
                });

  final sqflite.DatabaseExecutor database;

  final StreamController<String> changeListener;

  final QueryAdapter _queryAdapter;

  final InsertionAdapter<MeetingSegmentEntity>
      _meetingSegmentEntityInsertionAdapter;

  final UpdateAdapter<MeetingSegmentEntity> _meetingSegmentEntityUpdateAdapter;

  @override
  Future<List<MeetingSegmentEntity>> getByMeetingId(String meetingId) async {
    return _queryAdapter.queryList(
        'SELECT * FROM meeting_segments WHERE meeting_id = ?1 ORDER BY segment_index ASC',
        mapper: (Map<String, Object?> row) => MeetingSegmentEntity(id: row['id'] as String, meetingId: row['meeting_id'] as String, segmentIndex: row['segment_index'] as int, startTime: row['start_time'] as String, durationMs: row['duration_ms'] as int, audioFilePath: row['audio_file_path'] as String?, transcription: row['transcription'] as String?, enhancedText: row['enhanced_text'] as String?, status: row['status'] as String, errorMessage: row['error_message'] as String?),
        arguments: [meetingId]);
  }

  @override
  Future<MeetingSegmentEntity?> findById(String id) async {
    return _queryAdapter.query('SELECT * FROM meeting_segments WHERE id = ?1',
        mapper: (Map<String, Object?> row) => MeetingSegmentEntity(
            id: row['id'] as String,
            meetingId: row['meeting_id'] as String,
            segmentIndex: row['segment_index'] as int,
            startTime: row['start_time'] as String,
            durationMs: row['duration_ms'] as int,
            audioFilePath: row['audio_file_path'] as String?,
            transcription: row['transcription'] as String?,
            enhancedText: row['enhanced_text'] as String?,
            status: row['status'] as String,
            errorMessage: row['error_message'] as String?),
        arguments: [id]);
  }

  @override
  Future<void> deleteByMeetingId(String meetingId) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM meeting_segments WHERE meeting_id = ?1',
        arguments: [meetingId]);
  }

  @override
  Future<void> deleteById(String id) async {
    await _queryAdapter.queryNoReturn(
        'DELETE FROM meeting_segments WHERE id = ?1',
        arguments: [id]);
  }

  @override
  Future<void> insertSegment(MeetingSegmentEntity segment) async {
    await _meetingSegmentEntityInsertionAdapter.insert(
        segment, OnConflictStrategy.replace);
  }

  @override
  Future<void> updateSegment(MeetingSegmentEntity segment) async {
    await _meetingSegmentEntityUpdateAdapter.update(
        segment, OnConflictStrategy.replace);
  }
}
