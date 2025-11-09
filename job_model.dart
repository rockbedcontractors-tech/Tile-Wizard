// lib/models/job_model.dart

import 'package:isar/isar.dart';
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_area_model.dart';
import 'package:tile_wizard/models/line_item_group.dart';
import 'package:tile_wizard/models/material_package_model.dart';
import 'package:tile_wizard/models/sub_measurement.dart'; // For embedded
import 'package:tile_wizard/models/material_item_model.dart'; // For cost calculation

part 'job_model.g.dart';

// --- ENUMS ---
enum PaymentMethod { cash, check, card, ach, other }

extension PaymentMethodExtension on PaymentMethod {
  String get displayName {
    return switch (this) {
      PaymentMethod.cash => 'Cash',
      PaymentMethod.check => 'Check',
      PaymentMethod.card => 'Credit Card',
      PaymentMethod.ach => 'ACH Transfer',
      PaymentMethod.other => 'Other',
    };
  }
}

enum FinancialType { percentage, dollar }

enum ActivityType { supplyAndInstall, removeAndReplace, remove, install }

extension ActivityTypeExtension on ActivityType {
  String get displayName {
    return switch (this) {
      ActivityType.supplyAndInstall => 'Supply and Install',
      ActivityType.removeAndReplace => 'Remove and Replace',
      ActivityType.remove => 'Remove',
      ActivityType.install => 'Install',
    };
  }
}

enum JobStatus { draft, sent, paid, overdue }

enum BackerboardType { none, cementBoard, foamBoard, greenboard }

extension BackerboardTypeExtension on BackerboardType {
  String get displayName {
    return switch (this) {
      BackerboardType.none => 'None',
      BackerboardType.cementBoard => 'Cement Board',
      BackerboardType.foamBoard => 'Foam Board',
      BackerboardType.greenboard => 'Greenboard (Moisture-Resistant)',
    };
  }
}

enum WaterproofingType { none, liquidMembrane, sheetMembrane }

extension WaterproofingTypeExtension on WaterproofingType {
  String get displayName {
    return switch (this) {
      WaterproofingType.none => 'None',
      WaterproofingType.liquidMembrane => 'Liquid Membrane',
      WaterproofingType.sheetMembrane => 'Sheet Membrane',
    };
  }
}

enum ShowerBaseType { none, acrylic, mortarBed, preslopedFoam }

extension ShowerBaseTypeExtension on ShowerBaseType {
  String get displayName {
    return switch (this) {
      ShowerBaseType.none => 'None',
      ShowerBaseType.acrylic => 'Acrylic Base',
      ShowerBaseType.mortarBed => 'Mortar Bed',
      ShowerBaseType.preslopedFoam => 'Pre-Sloped Foam Tray',
    };
  }
}

// --- EMBEDDED OBJECTS ---
@embedded
class CustomLineItem {
  String? description;
  String? subtext;
  double? quantity;
  double? rate;
  String? unit;
  @enumerated
  ActivityType activity;
  bool? isTaxable;
  CustomLineItem(
      {this.description,
      this.subtext,
      this.quantity,
      this.rate,
      this.unit,
      this.activity = ActivityType.supplyAndInstall,
      this.isTaxable = true});
  double get total => (quantity ?? 0) * (rate ?? 0);
}

@embedded
class Payment {
  double? amount;
  DateTime? date;
  @enumerated
  PaymentMethod method;
  Payment({this.amount, this.date, this.method = PaymentMethod.other});
}

// --- MAIN COLLECTION ---
@collection
class Job {
  Id id = Isar.autoIncrement;
  @Index(unique: true, replace: true)
  String? jobUUID;
  final client = IsarLink<Client>();
  DateTime? creationDate;
  String? publicNotes;
  List<LineItemGroup>? itemGroups;
  List<Payment>? payments;
  @Index()
  String? quoteNumber;
  @Index()
  String? invoiceNumber;
  bool? hidePrice;
  double? tilesPerBox;
  double? pricePerSF;
  double? wastagePercent;
  double? taxRate;
  String? projectName;
  String? internalNotes;
  @enumerated
  FinancialType markupType;
  double? markupValue;
  @enumerated
  FinancialType discountType;
  double? discountValue;
  bool? showMarkupOnPDF;
  bool? showDiscountOnPDF;
  bool? showTaxOnPDF;
  String? customMarkupLabel;
  bool? showMaterialSupplyOnPDF;
  bool? isInvoice;
  String? poNumber;
  DateTime? dueDate;
  DateTime? expirationDate;
  String? contractFilePath;
  @Index()
  @enumerated
  JobStatus status;
  final selectedPackage = IsarLink<MaterialPackage>();
  @enumerated
  BackerboardType backerboardType;
  @enumerated
  WaterproofingType wallWaterproofingType;
  @enumerated
  ShowerBaseType showerBaseType;
  @enumerated
  WaterproofingType floorWaterproofingType;

  // --- Advanced Calculator Fields ---
  double? thinsetCoverage; // Stored as sqft/bag (derived from Trowel)
  double? tileThickness; // For grout calculation (inches)
  double? clipSpacing;
  double? selfLevelerYield; // e.g., 0.45
  double? selfLevelerThickness; // e.g., 0.125

  Job({
    this.jobUUID,
    this.creationDate,
    this.publicNotes,
    this.itemGroups,
    this.payments,
    this.quoteNumber,
    this.invoiceNumber,
    this.hidePrice = false,
    this.tilesPerBox,
    this.pricePerSF,
    this.wastagePercent,
    this.taxRate,
    this.projectName = '',
    this.internalNotes = '',
    this.markupType = FinancialType.percentage,
    this.markupValue = 0.0,
    this.discountType = FinancialType.percentage,
    this.discountValue = 0.0,
    this.showMarkupOnPDF = true,
    this.showDiscountOnPDF = true,
    this.showTaxOnPDF = true,
    this.customMarkupLabel = 'Markup',
    this.showMaterialSupplyOnPDF = true,
    this.isInvoice = false,
    this.poNumber,
    this.dueDate,
    this.expirationDate,
    this.contractFilePath,
    this.status = JobStatus.draft,
    this.backerboardType = BackerboardType.none,
    this.wallWaterproofingType = WaterproofingType.none,
    this.showerBaseType = ShowerBaseType.none,
    this.floorWaterproofingType = WaterproofingType.none,
    this.thinsetCoverage,
    this.tileThickness,
    this.clipSpacing,
    this.selfLevelerYield,
    this.selfLevelerThickness,
  });

  Job copyWith({
    String? jobUUID,
    IsarLink<Client>? client,
    DateTime? creationDate,
    String? publicNotes,
    List<LineItemGroup>? itemGroups,
    List<Payment>? payments,
    String? quoteNumber,
    String? invoiceNumber,
    bool? hidePrice,
    double? tilesPerBox,
    double? pricePerSF,
    double? wastagePercent,
    double? taxRate,
    String? projectName,
    String? internalNotes,
    FinancialType? markupType,
    double? markupValue,
    FinancialType? discountType,
    double? discountValue,
    bool? showMarkupOnPDF,
    bool? showDiscountOnPDF,
    bool? showTaxOnPDF,
    String? customMarkupLabel,
    bool? showMaterialSupplyOnPDF,
    bool? isInvoice,
    String? poNumber,
    DateTime? dueDate,
    DateTime? expirationDate,
    String? contractFilePath,
    JobStatus? status,
    MaterialPackage? selectedPackageValue,
    BackerboardType? backerboardType,
    WaterproofingType? wallWaterproofingType,
    ShowerBaseType? showerBaseType,
    WaterproofingType? floorWaterproofingType,
    double? thinsetCoverage,
    double? tileThickness,
    double? clipSpacing,
    double? selfLevelerYield,
    double? selfLevelerThickness,
  }) {
    final newJob = Job(
      jobUUID: jobUUID ?? this.jobUUID,
      creationDate: creationDate ?? this.creationDate,
      publicNotes: publicNotes ?? this.publicNotes,
      itemGroups: itemGroups ?? this.itemGroups,
      payments: payments ?? this.payments,
      quoteNumber: quoteNumber ?? this.quoteNumber,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      hidePrice: hidePrice ?? this.hidePrice,
      tilesPerBox: tilesPerBox ?? this.tilesPerBox,
      pricePerSF: pricePerSF ?? this.pricePerSF,
      wastagePercent: wastagePercent ?? this.wastagePercent,
      taxRate: taxRate ?? this.taxRate,
      projectName: projectName ?? this.projectName,
      internalNotes: internalNotes ?? this.internalNotes,
      markupType: markupType ?? this.markupType,
      markupValue: markupValue ?? this.markupValue,
      discountType: discountType ?? this.discountType,
      discountValue: discountValue ?? this.discountValue,
      showMarkupOnPDF: showMarkupOnPDF ?? this.showMarkupOnPDF,
      showDiscountOnPDF: showDiscountOnPDF ?? this.showDiscountOnPDF,
      showTaxOnPDF: showTaxOnPDF ?? this.showTaxOnPDF,
      customMarkupLabel: customMarkupLabel ?? this.customMarkupLabel,
      showMaterialSupplyOnPDF:
          showMaterialSupplyOnPDF ?? this.showMaterialSupplyOnPDF,
      isInvoice: isInvoice ?? this.isInvoice,
      poNumber: poNumber ?? this.poNumber,
      dueDate: dueDate ?? this.dueDate,
      expirationDate: expirationDate ?? this.expirationDate,
      contractFilePath: contractFilePath ?? this.contractFilePath,
      status: status ?? this.status,
      backerboardType: backerboardType ?? this.backerboardType,
      wallWaterproofingType:
          wallWaterproofingType ?? this.wallWaterproofingType,
      showerBaseType: showerBaseType ?? this.showerBaseType,
      floorWaterproofingType:
          floorWaterproofingType ?? this.floorWaterproofingType,
      thinsetCoverage: thinsetCoverage ?? this.thinsetCoverage,
      tileThickness: tileThickness ?? this.tileThickness,
      clipSpacing: clipSpacing ?? this.clipSpacing,
      selfLevelerYield: selfLevelerYield ?? this.selfLevelerYield,
      selfLevelerThickness: selfLevelerThickness ?? this.selfLevelerThickness,
    );
    newJob.id = id;
    newJob.client.value = client?.value ?? this.client.value;
    newJob.selectedPackage.value =
        selectedPackageValue ?? selectedPackage.value;
    return newJob;
  }

  // --- Calculation getters ---

  double _getAreaSumByType(List<AreaType> types) {
    return (itemGroups ?? []).fold(0.0, (groupSum, group) {
      final groupAreaSum = (group.areas ?? []).fold(0.0, (areaSum, area) {
        if (types.contains(area.type)) {
          return areaSum + (area.sqft ?? 0.0);
        }
        return areaSum;
      });
      return groupSum + groupAreaSum;
    });
  }

  double get totalArea =>
      (itemGroups ?? []).fold(0.0, (sum, group) => sum + group.groupAreaTotal);
  double get totalFloorArea =>
      _getAreaSumByType([AreaType.floor, AreaType.showerFloor]);
  double get totalWallArea =>
      _getAreaSumByType([AreaType.wall, AreaType.showerWall]);
  double get totalShowerWallArea => _getAreaSumByType([AreaType.showerWall]);
  double get totalShowerFloorArea => _getAreaSumByType([AreaType.showerFloor]);

  // --- Financial Getters ---
  int get tilesNeeded {
    int totalTiles = 0;
    final groups = itemGroups ?? [];
    for (final group in groups) {
      for (final area in group.areas ?? []) {
        final double tileL = area.tileLength ?? 0.0;
        final double tileW = area.tileWidth ?? 0.0;
        final double areaSqft = area.sqft ?? 0.0;

        if (tileL > 0 && tileW > 0 && areaSqft > 0) {
          final double tileAreaInSqFt = (tileL * tileW) / 144.0;
          final double areaWithWastage =
              areaSqft * (1 + ((wastagePercent ?? 15.0) / 100));
          totalTiles += (areaWithWastage / tileAreaInSqFt).ceil();
        }
      }
    }
    return totalTiles;
  }

  double get materialCost => totalArea * (pricePerSF ?? 0.0);
  double get customItemsSubtotal => (itemGroups ?? [])
      .fold(0.0, (groupSum, group) => groupSum + group.groupTotal);
  double get initialSubtotal => materialCost + customItemsSubtotal;

  double get markupAmount {
    if (markupType == FinancialType.percentage) {
      return initialSubtotal * ((markupValue ?? 0.0) / 100);
    } else {
      return markupValue ?? 0.0;
    }
  }

  double get subtotalAfterMarkup => initialSubtotal + markupAmount;

  double get discountAmount {
    if (discountType == FinancialType.percentage) {
      return subtotalAfterMarkup * ((discountValue ?? 0.0) / 100);
    } else {
      return discountValue ?? 0.0;
    }
  }

  double get subtotalAfterDiscount => subtotalAfterMarkup - discountAmount;

  double get taxAmount {
    if (initialSubtotal <= 0) return 0.0;
    final taxableCustomItems = (itemGroups ?? []).fold(0.0, (groupSum, group) {
      final groupTaxableTotal = (group.items ?? []).fold(0.0, (itemSum, item) {
        return (item.isTaxable ?? true) ? itemSum + item.total : itemSum;
      });
      return groupSum + groupTaxableTotal;
    });

    final taxableSubtotal = materialCost + taxableCustomItems;
    final taxableRatio =
        initialSubtotal == 0 ? 0 : taxableSubtotal / initialSubtotal;
    final finalTaxableValue = subtotalAfterDiscount * taxableRatio;
    return finalTaxableValue * ((taxRate ?? 0.0) / 100);
  }

  double get grandTotal => subtotalAfterDiscount + taxAmount;

  double get totalPayments => (payments ?? [])
      .fold(0.0, (sum, payment) => sum + (payment.amount ?? 0.0));

  double get balanceDue => grandTotal - totalPayments;

  // --- Advanced Material Getters ---
  int get bagsOfThinsetNeeded {
    final coverage = thinsetCoverage ?? 85.0;
    if (coverage <= 0 || totalArea <= 0) return 0;
    final areaWithWastage = totalArea * (1 + ((wastagePercent ?? 15.0) / 100));
    return (areaWithWastage / coverage).ceil();
  }

  int get bagsOfGroutNeeded {
    if (groutVolumeNeeded <= 0) return 0;
    final estimatedBags = (totalArea / 100).ceil();
    return estimatedBags > 0 ? estimatedBags : 1;
  }

  int get sheetsOfBackerboardNeeded {
    const double sheetSqft = 15.0;
    if (totalWallArea <= 0 || backerboardType == BackerboardType.none) return 0;
    final areaWithWastage =
        totalWallArea * (1 + ((wastagePercent ?? 15.0) / 100));
    return (areaWithWastage / sheetSqft).ceil();
  }

  int get gallonsOfLiquidWaterproofing {
    if (wallWaterproofingType != WaterproofingType.liquidMembrane &&
        floorWaterproofingType != WaterproofingType.liquidMembrane) {
      return 0;
    }
    const double coveragePerGallon = 50.0 / 2.0;
    double areaToWaterproof = 0;
    if (wallWaterproofingType == WaterproofingType.liquidMembrane) {
      areaToWaterproof += totalShowerWallArea;
    }
    if (floorWaterproofingType == WaterproofingType.liquidMembrane) {
      areaToWaterproof += totalShowerFloorArea;
    }
    if (areaToWaterproof <= 0) return 0;
    final areaWithWastage =
        areaToWaterproof * (1 + ((wastagePercent ?? 10.0) / 100));
    return (areaWithWastage / coveragePerGallon).ceil();
  }

  int get rollsOfSheetWaterproofing {
    if (wallWaterproofingType != WaterproofingType.sheetMembrane &&
        floorWaterproofingType != WaterproofingType.sheetMembrane) {
      return 0;
    }
    const double coveragePerRoll = 108.0;
    double areaToWaterproof = 0;
    if (wallWaterproofingType == WaterproofingType.sheetMembrane) {
      areaToWaterproof += totalShowerWallArea;
    }
    if (floorWaterproofingType == WaterproofingType.sheetMembrane) {
      areaToWaterproof += totalShowerFloorArea;
    }
    if (areaToWaterproof <= 0) return 0;
    final areaWithWastage =
        areaToWaterproof * (1 + ((wastagePercent ?? 15.0) / 100));
    return (areaWithWastage / coveragePerRoll).ceil();
  }

  int get screwsNeeded {
    if (backerboardType != BackerboardType.cementBoard &&
        backerboardType != BackerboardType.foamBoard) {
      return 0;
    }
    const double screwsPerSqft = 8.0;
    if (totalWallArea <= 0) return 0;
    return (totalWallArea * screwsPerSqft).ceil();
  }

  int get bagsOfSelfLevelerNeeded {
    final double yieldPerBag = selfLevelerYield ?? 0.0;
    final double thicknessInches = selfLevelerThickness ?? 0.0;

    if (yieldPerBag <= 0 || thicknessInches <= 0 || totalFloorArea <= 0) {
      return 0;
    }
    final double thicknessFeet = thicknessInches / 12.0;
    final double volumeNeeded = totalFloorArea * thicknessFeet;
    return (volumeNeeded / yieldPerBag).ceil();
  }

  int get levelingClipsNeeded {
    final double spacing = clipSpacing ?? 0.0;
    if (spacing <= 0) return 0;
    double totalClips = 0;
    final groups = itemGroups ?? [];
    for (final group in groups) {
      for (final area in group.areas ?? []) {
        if (area.type == AreaType.showerFloor) {
          continue; // Skip shower floors
        }
        final double tileLengthIn = area.tileLength ?? 0.0;
        final double tileWidthIn = area.tileWidth ?? 0.0;
        final double areaSqFt = area.sqft ?? 0.0;
        if (tileLengthIn > 0 && tileWidthIn > 0 && areaSqFt > 0) {
          final clipsPerLength = (tileLengthIn / spacing).floor();
          final clipsPerWidth = (tileWidthIn / spacing).floor();
          final tilesPerSqft = 144.0 / (tileLengthIn * tileWidthIn);
          final estimatedClips =
              (clipsPerLength + clipsPerWidth) * tilesPerSqft * areaSqFt;
          totalClips += estimatedClips;
        }
      }
    }
    return totalClips.ceil();
  }

  double get groutVolumeNeeded {
    double totalVolumeCuIn = 0;
    final double jointDepthIn = tileThickness ?? 0.0;
    if (jointDepthIn <= 0) return 0.0;

    final groups = itemGroups ?? [];
    for (final group in groups) {
      for (final area in group.areas ?? []) {
        final double jointWidthIn = area.groutSize ?? 0.0;
        final double tileLengthIn = area.tileLength ?? 0.0;
        final double tileWidthIn = area.tileWidth ?? 0.0;
        final double areaSqFt = area.sqft ?? 0.0;

        if (jointWidthIn > 0 &&
            tileLengthIn > 0 &&
            tileWidthIn > 0 &&
            areaSqFt > 0) {
          final double volumeCuIn = areaSqFt *
              144 *
              jointWidthIn *
              jointDepthIn *
              (tileLengthIn + tileWidthIn) /
              (tileLengthIn * tileWidthIn);
          totalVolumeCuIn += volumeCuIn;
        }
      }
    }
    return totalVolumeCuIn * (1 + ((wastagePercent ?? 15.0) / 100));
  }

  // --- NEW: Advanced Material COST Getters ---

  /// Helper to get the cost of a single material.
  /// It multiplies the item's cost by the calculated quantity.
  double _getMaterialCost(IsarLink<MaterialItem> link, int quantity) {
    link.loadSync(); // Load the linked item
    final item = link.value;
    if (item == null || (item.cost ?? 0.0) <= 0 || quantity <= 0) {
      return 0.0;
    }

    final double cost = item.cost!;
    final int itemsPerUnit = item.itemsPerUnit ?? 0;

    // --- THIS IS THE NEW LOGIC ---
    if (itemsPerUnit > 0) {
      // This is for clips/screws.
      // (quantityNeeded / itemsPerUnit) = bagsNeeded
      // We use ceiling to round up to the next full bag/bucket.
      final bagsNeeded = (quantity / itemsPerUnit).ceil();
      return bagsNeeded * cost;
    }
    return (item.cost!) * quantity;
  }

  /// Calculates the total estimated cost of all advanced materials
  /// based on the selected package.
  double get totalAdvancedMaterialCost {
    // Ensure the package link itself is loaded
    selectedPackage.loadSync();
    final pkg = selectedPackage.value;
    if (pkg == null) {
      return 0.0;
    }

    double totalCost = 0.0;

    // Iterate over each material type, get its cost, and add to total
    totalCost += _getMaterialCost(pkg.thinset, bagsOfThinsetNeeded);
    totalCost += _getMaterialCost(pkg.grout, bagsOfGroutNeeded);
    totalCost += _getMaterialCost(pkg.backerboard, sheetsOfBackerboardNeeded);
    totalCost += _getMaterialCost(pkg.fasteners, screwsNeeded);
    totalCost += _getMaterialCost(pkg.wallMembrane, rollsOfSheetWaterproofing);
    totalCost += _getMaterialCost(pkg.floorMembrane, rollsOfSheetWaterproofing);
    totalCost += _getMaterialCost(pkg.leveler, bagsOfSelfLevelerNeeded);
    totalCost += _getMaterialCost(pkg.clips, levelingClipsNeeded);
    // Note: We're missing sealant. We can add it to the package model later if needed.

    return totalCost;
  }
}
