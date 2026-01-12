// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_draft.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LocalDraftAdapter extends TypeAdapter<LocalDraft> {
  @override
  final int typeId = 2;

  @override
  LocalDraft read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LocalDraft(
      id: fields[0] as String,
      title: fields[1] as String,
      bodyContent: fields[2] as String,
      lastModified: fields[3] as DateTime,
      createdAt: fields[4] as DateTime,
      originalSha: fields[5] as String?,
      originalFileName: fields[6] as String?,
      originalDate: fields[7] as String?,
      originalFrontmatter: fields[8] as String?,
    );
  }

  @override
  void write(BinaryWriter writer, LocalDraft obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.bodyContent)
      ..writeByte(3)
      ..write(obj.lastModified)
      ..writeByte(4)
      ..write(obj.createdAt)
      ..writeByte(5)
      ..write(obj.originalSha)
      ..writeByte(6)
      ..write(obj.originalFileName)
      ..writeByte(7)
      ..write(obj.originalDate)
      ..writeByte(8)
      ..write(obj.originalFrontmatter);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LocalDraftAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
