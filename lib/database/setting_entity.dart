import 'package:floor/floor.dart';

/// 配置键值对实体，对应 `settings` 表。
@Entity(tableName: 'settings')
class SettingEntity {
  @primaryKey
  final String key;

  final String value;

  SettingEntity(this.key, this.value);
}
