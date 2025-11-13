// lib/providers/job_provider.dart

import 'package:flutter/material.dart';
import 'package:isar/isar.dart';
import 'package:tile_wizard/models/job_model.dart';

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

  Future<void> loadJobs() async {
    final allJobs = await isar.jobs.where().sortByCreationDateDesc().findAll();
    _jobs = allJobs;
    notifyListeners(); // Notify here in case init isn't the only caller
  }

  Future<Job> addJob(Job job) async {
    await isar.writeTxn(() async {
      await isar.jobs.put(job);
      // On creation, we also need to save any links (like package)
      await job.client.save();
      await job.selectedPackage.save();
    });
    _jobs.insert(0, job);
    notifyListeners();
    return job;
  }

  Future<void> updateJob(Job job) async {
    await isar.writeTxn(() async {
      await isar.jobs.put(job);
      // --- THIS IS THE FIX ---
      await job.client.save();
      await job.selectedPackage.save(); // <-- This line was missing
      // --- END OF FIX ---
    });

    final index = _jobs.indexWhere((j) => j.id == job.id);
    if (index != -1) {
      _jobs[index] = job;
      notifyListeners();
    }
  }

  Future<void> deleteJob(int jobId) async {
    await isar.writeTxn(() async {
      await isar.jobs.delete(jobId);
    });
    _jobs.removeWhere((j) => j.id == jobId);
    notifyListeners();
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
