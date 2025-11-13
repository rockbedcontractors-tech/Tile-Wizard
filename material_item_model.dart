// lib/models/material_item_model.dart

import 'package:isar/isar.dart';

part 'material_item_model.g.dart';

enum MaterialCategory {
  thinset,
  grout,
  backerboard,
  membrane,
  sealant,
  fastener, // Screws, washers
  leveler,
  clips,
  other,
}

@collection
class MaterialItem {
  Id id = Isar.autoIncrement;

  @Index(type: IndexType.value)
  String? name;

  @enumerated
  MaterialCategory category;

  double? cost;
  String? size;
  double? coverageSqft;
  double? coverageLinearFt;
  String? coverageUnit;

  // --- NEW FIELD ---
  int? itemsPerUnit; // e.g., 400 (for clips), 700 (for screws)
  // --- END NEW FIELD ---

  MaterialItem({
    this.name,
    this.category = MaterialCategory.other,
    this.cost,
    this.size,
    this.coverageSqft,
    this.coverageLinearFt,
    this.coverageUnit,
    this.itemsPerUnit, // <-- Add to constructor
  });
}
