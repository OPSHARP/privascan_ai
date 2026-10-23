// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'document_model.dart';

class DocumentModelAdapter extends TypeAdapter<DocumentModel> {
  @override
  final int typeId = 0;

  @override
  DocumentModel read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return DocumentModel()
      ..id = fields[0] as String
      ..name = fields[1] as String
      ..imagePaths = (fields[2] as List).cast<String>()
      ..extractedText = fields[3] as String?
      ..summary = fields[4] as String?
      ..tags = (fields[5] as List).cast<String>()
      ..createdAt = fields[6] as DateTime
      ..updatedAt = fields[7] as DateTime
      ..isFavorite = fields[8] as bool;
  }

  @override
  void write(BinaryWriter writer, DocumentModel obj) {
    writer
      ..writeByte(9)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.imagePaths)
      ..writeByte(3)
      ..write(obj.extractedText)
      ..writeByte(4)
      ..write(obj.summary)
      ..writeByte(5)
      ..write(obj.tags)
      ..writeByte(6)
      ..write(obj.createdAt)
      ..writeByte(7)
      ..write(obj.updatedAt)
      ..writeByte(8)
      ..write(obj.isFavorite);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DocumentModelAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
