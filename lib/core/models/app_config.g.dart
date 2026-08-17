// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_config.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class AppConfigAdapter extends TypeAdapter<AppConfig> {
  @override
  final int typeId = 0;

  @override
  AppConfig read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return AppConfig(
      repoOwner: fields[0] as String,
      repoName: fields[1] as String,
      branch: fields[2] as String,
      assetsPath: fields[3] as String,
      defaultLayout: fields[8] as String?,
    )
      ..postsPathRaw = fields[4] as String?
      ..draftsPathRaw = fields[5] as String?
      ..siteUrlRaw = fields[6] as String?
      ..baseurlRaw = fields[7] as String?
      ..defaultCategoriesRaw = (fields[9] as List?)?.cast<String>()
      ..defaultTagsRaw = (fields[10] as List?)?.cast<String>()
      ..contentDirsRaw = (fields[11] as List?)?.cast<String>()
      ..activeContentDirRaw = fields[12] as String?;
  }

  @override
  void write(BinaryWriter writer, AppConfig obj) {
    writer
      ..writeByte(13)
      ..writeByte(0)
      ..write(obj.repoOwner)
      ..writeByte(1)
      ..write(obj.repoName)
      ..writeByte(2)
      ..write(obj.branch)
      ..writeByte(3)
      ..write(obj.assetsPath)
      ..writeByte(4)
      ..write(obj.postsPathRaw)
      ..writeByte(5)
      ..write(obj.draftsPathRaw)
      ..writeByte(6)
      ..write(obj.siteUrlRaw)
      ..writeByte(7)
      ..write(obj.baseurlRaw)
      ..writeByte(8)
      ..write(obj.defaultLayout)
      ..writeByte(9)
      ..write(obj.defaultCategoriesRaw)
      ..writeByte(10)
      ..write(obj.defaultTagsRaw)
      ..writeByte(11)
      ..write(obj.contentDirsRaw)
      ..writeByte(12)
      ..write(obj.activeContentDirRaw);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AppConfigAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
