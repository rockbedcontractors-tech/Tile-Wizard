// lib/models/line_item_group.dart

import 'package:isar/isar.dart';
import 'package:tile_wizard/models/job_model.dart'; // For CustomLineItem
import 'package:tile_wizard/models/job_area_model.dart'; // For JobArea

part 'line_item_group.g.dart';

@embedded
class LineItemGroup {
  String? name;
  List<CustomLineItem>? items;
  List<JobArea>? areas; // <-- ADDED THIS LIST

  LineItemGroup({
    this.name,
    this.items,
    this.areas, // <-- ADDED TO CONSTRUCTOR
  });

  // Group total calculation remains the same
  double get groupTotal =>
      (items ?? []).fold(0.0, (sum, item) => sum + item.total);

  // Helper getter for total area within this group
  double get groupAreaTotal =>
      (areas ?? []).fold(0.0, (sum, area) => sum + (area.sqft ?? 0.0));
}
