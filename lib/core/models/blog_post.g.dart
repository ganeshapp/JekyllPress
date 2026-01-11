// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'blog_post.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class BlogPostAdapter extends TypeAdapter<BlogPost> {
  @override
  final int typeId = 1;

  @override
  BlogPost read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return BlogPost(
      sha: fields[0] as String?,
      fileName: fields[1] as String?,
      title: fields[2] as String,
      date: fields[3] as String,
      rawFrontmatter: fields[4] as String?,
      bodyContent: fields[5] as String,
      isLocalDraft: fields[6] as bool,
      lastSynced: fields[7] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, BlogPost obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.sha)
      ..writeByte(1)
      ..write(obj.fileName)
      ..writeByte(2)
      ..write(obj.title)
      ..writeByte(3)
      ..write(obj.date)
      ..writeByte(4)
      ..write(obj.rawFrontmatter)
      ..writeByte(5)
      ..write(obj.bodyContent)
      ..writeByte(6)
      ..write(obj.isLocalDraft)
      ..writeByte(7)
      ..write(obj.lastSynced);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is BlogPostAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
