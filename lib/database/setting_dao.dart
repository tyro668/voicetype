import 'package:floor/floor.dart';
import 'setting_entity.dart';

/// 配置表的 DAO（数据访问对象）。
@dao
abstract class SettingDao {
  @Query('SELECT * FROM settings WHERE `key` = :key')
  Future<SettingEntity?> findByKey(String key);

  @Query('SELECT * FROM settings')
  Future<List<SettingEntity>> getAll();

  @Insert(onConflict: OnConflictStrategy.replace)
  Future<void> insertSetting(SettingEntity setting);

  @Query('DELETE FROM settings WHERE `key` = :key')
  Future<void> deleteByKey(String key);
}
