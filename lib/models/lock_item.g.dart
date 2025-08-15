// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lock_item.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class LockItemAdapter extends TypeAdapter<LockItem> {
  @override
  final int typeId = 0;

  @override
  LockItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return LockItem(
      id: fields[0] as String,
      name: fields[1] as String,
      isLocked: fields[2] as bool,
      lockedAt: fields[3] as DateTime?,
      photoPath: fields[4] as String?,
      unlockedAt: fields[5] as DateTime?,
    );
  }

  @override
  void write(BinaryWriter writer, LockItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.name)
      ..writeByte(2)
      ..write(obj.isLocked)
      ..writeByte(3)
      ..write(obj.lockedAt)
      ..writeByte(4)
      ..write(obj.photoPath)
      ..writeByte(5)
      ..write(obj.unlockedAt);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is LockItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
