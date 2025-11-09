// lib/providers/job_provider.dart

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/material_package_model.dart';
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

  // --- CREATE (Fixed with Deep Copy Pattern) ---
  Future<Job> addJob(Job unmanagedJob) async {
    // 1. Get the linked objects *before* the transaction
    final Client? clientToLink = unmanagedJob.client.value;
    final MaterialPackage? packageToLink = unmanagedJob.selectedPackage.value;

    late int newId;

    // --- Transaction 1: Create the job with deep-copied data ---
    await isar.writeTxn(() async {
      // Create a new, clean Job object and DEEP COPY all data
      final Job newJob = Job(
          jobUUID: unmanagedJob.jobUUID,
          creationDate: unmanagedJob.creationDate,
          projectName: unmanagedJob.projectName,
          publicNotes: unmanagedJob.publicNotes,

          // --- Deep copy embedded lists ---
          itemGroups: (unmanagedJob.itemGroups ?? [])
              .map((group) => LineItemGroup(
                  name: group.name,
                  areas: (group.areas ?? [])
                      .map((area) => JobArea(
                          name: area.name,
                          sqft: area.sqft,
                          type: area.type,
                          subMeasurements: (area.subMeasurements ?? [])
                              .map((sub) => SubMeasurement(
                                  length: sub.length,
                                  width: sub.width,
                                  unit: sub.unit))
                              .toList(),
                          tileLength: area.tileLength,
                          tileWidth: area.tileWidth,
                          groutSize: area.groutSize))
                      .toList(),
                  items: (group.items ?? [])
                      .map((item) => CustomLineItem(
                          description: item.description,
                          subtext: item.subtext,
                          quantity: item.quantity,
                          rate: item.rate,
                          unit: item.unit,
                          activity: item.activity,
                          isTaxable: item.isTaxable))
                      .toList()))
              .toList(),
          payments: (unmanagedJob.payments ?? [])
              .map((payment) => Payment(
                  amount: payment.amount,
                  date: payment.date,
                  method: payment.method))
              .toList(),
          // --- End deep copy ---

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
          selfLevelerThickness: unmanagedJob.selfLevelerThickness);

      // Save the clean, deep-copied job. This will work.
      newId = await isar.jobs.put(newJob);
    });

    // Now the job exists in the DB (managed).

    late Job newManagedJob;

    // --- Transaction 2: Fetch the new job and attach its links ---
    await isar.writeTxn(() async {
      newManagedJob = (await isar.jobs.get(newId))!;

      // Attach the objects
      newManagedJob.client.value = clientToLink;
      newManagedJob.selectedPackage.value = packageToLink;

      // Put the job AGAIN. This is what saves the link associations.
      await isar.jobs.put(newManagedJob);
    });

    await loadJobs(); // Refresh the provider's list

    // Return the fully managed job
    return _jobs.firstWhere((j) => j.id == newId);
  }

  // --- UPDATE (Fixed with Deep Copy) ---
  Future<void> updateJob(Job unmanagedJob) async {
    // 'unmanagedJob' is the copy from our editor.

    // Get the linked objects *before* the transaction
    final Client? client = unmanagedJob.client.value;
    final MaterialPackage? package = unmanagedJob.selectedPackage.value;

    await isar.writeTxn(() async {
      // Fetch the REAL, MANAGED job from the database
      final managedJob = await isar.jobs.get(unmanagedJob.id);
      if (managedJob == null) return;

      // Copy all non-link properties (Deep Copy)
      managedJob.projectName = unmanagedJob.projectName;
      managedJob.publicNotes = unmanagedJob.publicNotes;

      managedJob.itemGroups = (unmanagedJob.itemGroups ?? [])
          .map((group) => LineItemGroup(
              name: group.name,
              areas: (group.areas ?? [])
                  .map((area) => JobArea(
                      name: area.name,
                      sqft: area.sqft,
                      type: area.type,
                      subMeasurements: (area.subMeasurements ?? [])
                          .map((sub) => SubMeasurement(
                              length: sub.length,
                              width: sub.width,
                              unit: sub.unit))
                          .toList(),
                      tileLength: area.tileLength,
                      tileWidth: area.tileWidth,
                      groutSize: area.groutSize))
                  .toList(),
              items: (group.items ?? [])
                  .map((item) => CustomLineItem(
                      description: item.description,
                      subtext: item.subtext,
                      quantity: item.quantity,
                      rate: item.rate,
                      unit: item.unit,
                      activity: item.activity,
                      isTaxable: item.isTaxable))
                  .toList()))
          .toList();

      managedJob.payments = (unmanagedJob.payments ?? [])
          .map((payment) => Payment(
              amount: payment.amount,
              date: payment.date,
              method: payment.method))
          .toList();

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

      // Update the links on the managed object
      managedJob.client.value = client;
      managedJob.selectedPackage.value = package;

      // Put the MANAGED object back.
      await isar.jobs.put(managedJob);
    });

    await loadJobs(); // Refresh the provider's list
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
