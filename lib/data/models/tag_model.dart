import 'package:hive/hive.dart';
import '../../domain/entities/tag.dart';

part 'tag_model.g.dart';

@HiveType(typeId: 1)
class TagModel extends HiveObject {
  @HiveField(0)
  late String id;

  @HiveField(1)
  late String name;

  @HiveField(2)
  late int colorValue;

  TagModel();

  factory TagModel.fromEntity(Tag tag) {
    return TagModel()
      ..id = tag.id
      ..name = tag.name
      ..colorValue = tag.colorValue;
  }

  Tag toEntity() {
    return Tag(id: id, name: name, colorValue: colorValue);
  }
}
