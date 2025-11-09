// lib/models/job_area_model.dart

import 'package:isar/isar.dart';
import 'package:tile_wizard/models/sub_measurement.dart'; // <-- IMPORT NEW MODEL

part 'job_area_model.g.dart';

enum AreaType {
  floor,
  wall,
  showerWall,
  showerFloor,
}

extension AreaTypeExtension on AreaType {
  String get displayName {
    return switch (this) {
      AreaType.floor => 'Floor',
      AreaType.wall => 'Wall (General)',
      AreaType.showerWall => 'Shower Wall',
      AreaType.showerFloor => 'Shower Floor',
    };
  }
}

@embedded
class JobArea {
  String? name;
  double? sqft; // This will store the *total* sqft (sum of sub-measurements)
  @enumerated
  AreaType type;

  // --- NEW FIELDS ---
  List<SubMeasurement>? subMeasurements;
  double? tileLength;
  double? tileWidth;
  double? groutSize;
  // --- END NEW FIELDS ---

  JobArea({
    this.name,
    this.sqft,
    this.type = AreaType.floor,
    // --- ADD TO CONSTRUCTOR ---
    this.subMeasurements,
    this.tileLength,
    this.tileWidth,
    this.groutSize,
  });
}
