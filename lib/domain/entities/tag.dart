import 'package:equatable/equatable.dart';

class Tag extends Equatable {
  final String id;
  final String name;
  final int colorValue;

  const Tag({required this.id, required this.name, required this.colorValue});

  Tag copyWith({String? id, String? name, int? colorValue}) {
    return Tag(
      id: id ?? this.id,
      name: name ?? this.name,
      colorValue: colorValue ?? this.colorValue,
    );
  }

  @override
  List<Object?> get props => [id, name, colorValue];
}
