// lib/providers/job_provider.dart

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:tile_wizard/models/client_model.dart'; // Import Client
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/material_package_model.dart'; // Import Package
// Import the models needed for deep copying
import 'package:tile_wizard/models/line_item_group.dart';
import 'package:tile_wizard/models/job_area_model.dart';
import 'package:tile_wizard/models/sub_measurement.dart';

class JobProvider extends ChangeNotifier {
  final Isar isar;
  List<Job> _jobs = [];
  bool _isLoading = true;

  List<Job> get jobs => _jobs;
  bool get isLoading => _isLoading;

  JobProvider({required this.isar});

  Future<void> init() async {
    await loadJobs();
    _isLoading = false;
    notifyListeners();
  }

  // --- READ ---
  Future<void> loadJobs() async {
    final allJobs = await isar.jobs.where().sortByCreationDateDesc().findAll();

    // Eager load links for the UI
    for (var job in allJobs) {
      job.client.loadSync();
      job.selectedPackage.loadSync();
    }
    _jobs = allJobs;
    notifyListeners();
  }

  // --- TYPE-SAFE DEEP COPY HELPER ---
  List<LineItemGroup> _deepCopyItemGroups(List<LineItemGroup>? groups) {
    if (groups == null) return [];
    return List<LineItemGroup>.from(groups.map((group) {
      final newAreas = List<JobArea>.from((group.areas ?? []).map((area) {
        return JobArea(
          name: area.name,
          sqft: area.sqft,
          type: area.type,
          subMeasurements: List<SubMeasurement>.from(
            (area.subMeasurements ?? []).map(
              (sub) => SubMeasurement(
                length: sub.length,
                width: sub.width,
                unit: sub.unit,
              ),
            ),
          ),
          tileLength: area.tileLength,
          tileWidth: area.tileWidth,
          groutSize: area.groutSize,
        );
      }));
      final newItems =
          List<CustomLineItem>.from((group.items ?? []).map((item) {
        return CustomLineItem(
          description: item.description,
          subtext: item.subtext,
          quantity: item.quantity,
          rate: item.rate,
          unit: item.unit,
          activity: item.activity,
          isTaxable: item.isTaxable,
        );
      }));
      return LineItemGroup(
        name: group.name,
        areas: newAreas,
        items: newItems,
      );
    }));
  }
  // --- END OF HELPER ---

  // --- CREATE (With Deep Copy) ---
  Future<Job> addJob(Job unmanagedJob) async {
    // Get links BEFORE the transaction
    final Client? clientToLink = unmanagedJob.client.value;
    final MaterialPackage? packageToLink = unmanagedJob.selectedPackage.value;

    // Perform the deep copy *before* the transaction
    final List<LineItemGroup> newGroups =
        _deepCopyItemGroups(unmanagedJob.itemGroups);
    final List<Payment> newPayments = List<Payment>.from(
      (unmanagedJob.payments ?? []).map(
        (payment) => Payment(
          amount: payment.amount,
          date: payment.date,
          method: payment.method,
        ),
      ),
    );

    late int newId;
    // Transaction 1: Save the clean, deep-copied job
    await isar.writeTxn(() async {
      final Job newJob = Job(
        jobUUID: unmanagedJob.jobUUID,
        creationDate: unmanagedJob.creationDate,
        projectName: unmanagedJob.projectName,
        publicNotes: unmanagedJob.publicNotes,
        itemGroups: newGroups, // Use the new clean list
        payments: newPayments, // Use the new clean list
        quoteNumber: unmanagedJob.quoteNumber,
        invoiceNumber: unmanagedJob.invoiceNumber,
        hidePrice: unmanagedJob.hidePrice,
        wastagePercent: unmanagedJob.wastagePercent,
        taxRate: unmanagedJob.taxRate,
        markupType: unmanagedJob.markupType,
        markupValue: unmanagedJob.markupValue,
        discountType: unmanagedJob.discountType,
        discountValue: unmanagedJob.discountValue,
        showMarkupOnPDF: unmanagedJob.showMarkupOnPDF,
        showDiscountOnPDF: unmanagedJob.showDiscountOnPDF,
        showTaxOnPDF: unmanagedJob.showTaxOnPDF,
        showMaterialSupplyOnPDF: unmanagedJob.showMaterialSupplyOnPDF,
        isInvoice: unmanagedJob.isInvoice,
        poNumber: unmanagedJob.poNumber,
        dueDate: unmanagedJob.dueDate,
        expirationDate: unmanagedJob.expirationDate,
        backerboardType: unmanagedJob.backerboardType,
        wallWaterproofingType: unmanagedJob.wallWaterproofingType,
        showerBaseType: unmanagedJob.showerBaseType,
        floorWaterproofingType: unmanagedJob.floorWaterproofingType,
        thinsetCoverage: unmanagedJob.thinsetCoverage,
        tileThickness: unmanagedJob.tileThickness,
        clipSpacing: unmanagedJob.clipSpacing,
        selfLevelerYield: unmanagedJob.selfLevelerYield,
        selfLevelerThickness: unmanagedJob.selfLevelerThickness,
      );
      newId = await isar.jobs.put(newJob);
    });

    // Transaction 2: Fetch the managed job and save its links
    late Job newManagedJob;
    await isar.writeTxn(() async {
      newManagedJob = (await isar.jobs.get(newId))!;
      newManagedJob.client.value = clientToLink;
      newManagedJob.selectedPackage.value = packageToLink;
      await isar.jobs.put(newManagedJob);
    });

    await loadJobs(); // Refresh the list
    return _jobs.firstWhere((j) => j.id == newId);
  }

  // --- UPDATE (With Deep Copy) ---
  Future<void> updateJob(Job unmanagedJob) async {
    // Get links BEFORE the transaction
    final Client? client = unmanagedJob.client.value;
    final MaterialPackage? package = unmanagedJob.selectedPackage.value;

    // Perform the deep copy *before* the transaction
    final List<LineItemGroup> newGroups =
        _deepCopyItemGroups(unmanagedJob.itemGroups);
    final List<Payment> newPayments = List<Payment>.from(
      (unmanagedJob.payments ?? []).map(
        (payment) => Payment(
          amount: payment.amount,
          date: payment.date,
          method: payment.method,
        ),
      ),
    );

    await isar.writeTxn(() async {
      // Fetch the real, managed job
      final managedJob = await isar.jobs.get(unmanagedJob.id);
      if (managedJob == null) return;

      // Now, copy all properties from the unmanaged object
      managedJob.projectName = unmanagedJob.projectName;
      managedJob.publicNotes = unmanagedJob.publicNotes;
      managedJob.itemGroups = newGroups; // Use the new clean list
      managedJob.payments = newPayments; // Use the new clean list
      managedJob.quoteNumber = unmanagedJob.quoteNumber;
      managedJob.invoiceNumber = unmanagedJob.invoiceNumber;
      managedJob.hidePrice = unmanagedJob.hidePrice;
      managedJob.wastagePercent = unmanagedJob.wastagePercent;
      managedJob.taxRate = unmanagedJob.taxRate;
      managedJob.markupType = unmanagedJob.markupType;
      managedJob.markupValue = unmanagedJob.markupValue;
      managedJob.discountType = unmanagedJob.discountType;
      managedJob.discountValue = unmanagedJob.discountValue;
      managedJob.showMarkupOnPDF = unmanagedJob.showMarkupOnPDF;
      managedJob.showDiscountOnPDF = unmanagedJob.showDiscountOnPDF;
      managedJob.showTaxOnPDF = unmanagedJob.showTaxOnPDF;
      managedJob.showMaterialSupplyOnPDF = unmanagedJob.showMaterialSupplyOnPDF;
      managedJob.isInvoice = unmanagedJob.isInvoice;
      managedJob.poNumber = unmanagedJob.poNumber;
      managedJob.dueDate = unmanagedJob.dueDate;
      managedJob.expirationDate = unmanagedJob.expirationDate;
      managedJob.backerboardType = unmanagedJob.backerboardType;
      managedJob.wallWaterproofingType = unmanagedJob.wallWaterproofingType;
      managedJob.showerBaseType = unmanagedJob.showerBaseType;
      managedJob.floorWaterproofingType = unmanagedJob.floorWaterproofingType;
      managedJob.thinsetCoverage = unmanagedJob.thinsetCoverage;
      managedJob.tileThickness = unmanagedJob.tileThickness;
      managedJob.clipSpacing = unmanagedJob.clipSpacing;
      managedJob.selfLevelerYield = unmanagedJob.selfLevelerYield;
      managedJob.selfLevelerThickness = unmanagedJob.selfLevelerThickness;

      // Save the links
      managedJob.client.value = client;
      managedJob.selectedPackage.value = package;

      await isar.jobs.put(managedJob);
    });

    await loadJobs(); // Refresh the list
  }

  // --- DELETE ---
  Future<void> deleteJob(int jobId) async {
    await isar.writeTxn(() async {
      await isar.jobs.delete(jobId);
    });
    _jobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
  }

  // --- Getters (no changes) ---
  List<Job> get overdueJobs {
    final now = DateTime.now();
    return _jobs.where((job) {
      if (!(job.isInvoice ?? false) ||
          job.balanceDue <= 0.01 ||
          job.dueDate == null) {
        return false;
      }
      return DateUtils.isSameDay(job.dueDate, now)
          ? false
          : job.dueDate!.isBefore(now);
    }).toList();
  }

  List<Job> get expiringQuotes {
    final now = DateTime.now();
    final oneWeekFromNow = now.add(const Duration(days: 7));
    return _jobs.where((job) {
      if ((job.isInvoice ?? false) || job.expirationDate == null) {
        return false;
      }
      return job.expirationDate!.isAfter(now) &&
          job.expirationDate!.isBefore(oneWeekFromNow);
    }).toList();
  }

  double get totalOutstanding {
    return _jobs
        .where((job) => (job.isInvoice ?? false) && job.balanceDue > 0.01)
        .fold(0.0, (sum, job) => sum + job.balanceDue);
  }

  double get totalOverdue {
    final now = DateTime.now();
    return _jobs.where((job) {
      if (!(job.isInvoice ?? false) ||
          job.balanceDue <= 0.01 ||
          job.dueDate == null) {
        return false;
      }
      return DateUtils.isSameDay(job.dueDate, now)
          ? false
          : job.dueDate!.isBefore(now);
    }).fold(0.0, (sum, job) => sum + job.balanceDue);
  }
}
