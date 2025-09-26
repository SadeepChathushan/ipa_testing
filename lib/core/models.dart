/// Core data models for the app.
class Delivery {
  final String id;
  final String lorryName;
  final DateTime date;
  final String? notes;

  Delivery({
    required this.id,
    required this.lorryName,
    required this.date,
    this.notes,
  });
}

class WoodGroup {
  final String id;
  final String deliveryId;
  final double thickness; // x
  final double length;    // y

  WoodGroup({
    required this.id,
    required this.deliveryId,
    required this.thickness,
    required this.length,
  });
}

class WoodWidth {
  final String id;
  final String groupId;
  final double width; // z

  WoodWidth({
    required this.id,
    required this.groupId,
    required this.width,
  });
}
