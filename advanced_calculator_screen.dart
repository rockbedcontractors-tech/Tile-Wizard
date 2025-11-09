// lib/screens/advanced_calculator_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:tile_wizard/models/client_model.dart'; // Import this
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/material_package_model.dart';
import 'package:tile_wizard/providers/job_provider.dart';
import 'package:tile_wizard/providers/material_provider.dart';
import 'package:tile_wizard/utils/parsers.dart';
import 'package:intl/intl.dart';

// Trowel Size to Coverage Map
final Map<String, double> thinsetTrowelCoverage = {
  '1/4" x 1/4"': 100.0,
  '1/4" x 3/8"': 75.0,
  '1/2" x 1/2"': 50.0,
  '3/4" x 9/16"': 40.0,
};

class AdvancedCalculatorScreen extends StatefulWidget {
  final int jobId;
  const AdvancedCalculatorScreen({super.key, required this.jobId});

  @override
  State<AdvancedCalculatorScreen> createState() =>
      _AdvancedCalculatorScreenState();
}

class _AdvancedCalculatorScreenState extends State<AdvancedCalculatorScreen> {
  final _formKey = GlobalKey<FormState>();
  late Job _job; // This will be our unmanaged copy

  // --- FIX: Local variables for links ---
  Client? _localSelectedClient;
  MaterialPackage? _localSelectedPackage;
  // --- END OF FIX ---

  BackerboardType _backerboardType = BackerboardType.none;
  WaterproofingType _wallWaterproofingType = WaterproofingType.none;
  ShowerBaseType _showerBaseType = ShowerBaseType.none;
  WaterproofingType _floorWaterproofingType = WaterproofingType.none;
  late String _thinsetTrowelSize;

  late TextEditingController _levelerYieldController;
  late TextEditingController _levelerThicknessController;
  late TextEditingController _clipSpacingController;
  late TextEditingController _tileThicknessController;

  final _format = NumberFormat("0.##");

  @override
  void initState() {
    super.initState();
    // --- FIX: Use Clean Object pattern ---
    // 1. Get the original managed job
    final originalJob = context
        .read<JobProvider>()
        .jobs
        .firstWhere((j) => j.id == widget.jobId);

    // 2. Make a clean, unmanaged copy
    _job = originalJob.copyWith(); // This is now clean

    // 3. Store the links locally
    _localSelectedClient = originalJob.client.value;
    _localSelectedPackage = originalJob.selectedPackage.value;

    // 4. Set state from the unmanaged copy
    _backerboardType = _job.backerboardType;
    _wallWaterproofingType = _job.wallWaterproofingType;
    _showerBaseType = _job.showerBaseType;
    _floorWaterproofingType = _job.floorWaterproofingType;

    _thinsetTrowelSize = thinsetTrowelCoverage.entries
        .firstWhere(
          (entry) => entry.value == _job.thinsetCoverage,
          orElse: () => thinsetTrowelCoverage.entries.first,
        )
        .key;

    _levelerYieldController = TextEditingController(
        text: _job.selfLevelerYield?.toString() ?? '0.45');
    _levelerThicknessController = TextEditingController(
        text: _job.selfLevelerThickness?.toString() ?? '0.125');
    _clipSpacingController =
        TextEditingController(text: _job.clipSpacing?.toString() ?? '4');
    _tileThicknessController =
        TextEditingController(text: _job.tileThickness?.toString() ?? '0.25');
    // --- END OF FIX ---
  }

  @override
  void dispose() {
    _levelerYieldController.dispose();
    _levelerThicknessController.dispose();
    _clipSpacingController.dispose();
    _tileThicknessController.dispose();
    super.dispose();
  }

  void _saveAdvancedCalculations() {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final double selectedThinsetCoverage =
        thinsetTrowelCoverage[_thinsetTrowelSize] ?? 85.0;

    // --- FIX: Mutate the _job copy directly ---
    // (We removed the _job.copyWith call)
    _job.backerboardType = _backerboardType;
    _job.wallWaterproofingType = _wallWaterproofingType;
    _job.showerBaseType = _showerBaseType;
    _job.floorWaterproofingType = _floorWaterproofingType;
    _job.thinsetCoverage = selectedThinsetCoverage;
    _job.selfLevelerYield =
        double.tryParse(_levelerYieldController.text) ?? 0.45;
    _job.selfLevelerThickness =
        parseMixedNumber(_levelerThicknessController.text);
    _job.clipSpacing = parseMixedNumber(_clipSpacingController.text);
    _job.tileThickness = parseMixedNumber(_tileThicknessController.text);
    // --- END OF FIX ---

    // --- FIX: Call updateJob with all 3 arguments ---
    context.read<JobProvider>().updateJob(
          _job, // The mutated, clean copy
          _localSelectedClient, // The client link
          _localSelectedPackage, // The package link
        );
    // --- END OF FIX ---

    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final materialProvider = context.watch<MaterialProvider>();

    if (materialProvider.packages.isEmpty && !materialProvider.isLoading) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          context.read<MaterialProvider>().init();
        }
      });
    }

    // --- THIS IS THE FIX ---
    // Read from _localSelectedPackage
    MaterialPackage? validSelectedPackage;
    if (_localSelectedPackage != null) {
      try {
        validSelectedPackage = materialProvider.packages
            .firstWhere((pkg) => pkg.id == _localSelectedPackage!.id);
      } catch (e) {
        // Not found in the list, so set to null
        validSelectedPackage = null;
      }
    }
    // --- END OF FIX ---

    return Scaffold(
      appBar: AppBar(
        title: const Text('Advanced Calculator'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            tooltip: 'Save',
            onPressed: _saveAdvancedCalculations,
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // --- Package Selection ---
              DropdownButtonFormField<MaterialPackage>(
                initialValue:
                    validSelectedPackage, // Use the validated instance
                decoration: const InputDecoration(
                  labelText: 'Material Package',
                  border: OutlineInputBorder(),
                ),
                items: materialProvider.packages.map((pkg) {
                  return DropdownMenuItem(
                    value: pkg,
                    child: Text(pkg.name ?? 'Unnamed Package'),
                  );
                }).toList(),
                onChanged: (MaterialPackage? newValue) {
                  setState(() {
                    _localSelectedPackage = newValue; // Update local var
                  });
                },
              ),
              const SizedBox(height: 24),

              // --- Backerboard ---
              DropdownButtonFormField<BackerboardType>(
                initialValue:
                    _backerboardType, // Use value instead of initialValue
                decoration:
                    const InputDecoration(labelText: 'Backerboard Type'),
                items: BackerboardType.values.map((type) {
                  return DropdownMenuItem(
                      value: type, child: Text(type.displayName));
                }).toList(),
                onChanged: (value) => setState(() => _backerboardType = value!),
              ),
              const SizedBox(height: 24),

              // --- Waterproofing ---
              DropdownButtonFormField<WaterproofingType>(
                initialValue: _wallWaterproofingType, // Use value
                decoration:
                    const InputDecoration(labelText: 'Wall Waterproofing'),
                items: WaterproofingType.values.map((type) {
                  return DropdownMenuItem(
                      value: type, child: Text(type.displayName));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _wallWaterproofingType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<ShowerBaseType>(
                initialValue: _showerBaseType, // Use value
                decoration:
                    const InputDecoration(labelText: 'Shower Base Type'),
                items: ShowerBaseType.values.map((type) {
                  return DropdownMenuItem(
                      value: type, child: Text(type.displayName));
                }).toList(),
                onChanged: (value) => setState(() => _showerBaseType = value!),
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<WaterproofingType>(
                initialValue: _floorWaterproofingType, // Use value
                decoration: const InputDecoration(
                    labelText: 'Shower Floor Waterproofing'),
                items: WaterproofingType.values.map((type) {
                  return DropdownMenuItem(
                      value: type, child: Text(type.displayName));
                }).toList(),
                onChanged: (value) =>
                    setState(() => _floorWaterproofingType = value!),
              ),
              const SizedBox(height: 24),

              // --- Consumables ---
              DropdownButtonFormField<String>(
                initialValue: _thinsetTrowelSize, // Use value
                decoration:
                    const InputDecoration(labelText: 'Thinset Trowel Size'),
                items: thinsetTrowelCoverage.keys.map((trowelSize) {
                  final coverage =
                      _format.format(thinsetTrowelCoverage[trowelSize]);
                  return DropdownMenuItem(
                    value: trowelSize,
                    child: Text('$trowelSize (~$coverage sqft)'),
                  );
                }).toList(),
                onChanged: (String? value) {
                  setState(() {
                    _thinsetTrowelSize = value!;
                  });
                },
              ),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _tileThicknessController,
                  decoration: const InputDecoration(
                      labelText: 'Grout Depth (avg. Tile Thickness)',
                      suffixText: 'in',
                      hintText: 'e.g., 0.25 or 1/4'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return parseMixedNumber(value) < 0 ? 'Invalid' : null;
                  }),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _levelerYieldController,
                  decoration: const InputDecoration(
                      labelText: 'Self-Leveler Yield per Bag',
                      suffixText: 'cu ft',
                      hintText: 'e.g., 0.45'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return double.tryParse(value) == null ? 'Invalid' : null;
                  }),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _levelerThicknessController,
                  decoration: const InputDecoration(
                      labelText: 'Self-Leveler Avg. Thickness',
                      suffixText: 'in',
                      hintText: 'e.g., 0.125 or 1/8'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return parseMixedNumber(value) < 0 ? 'Invalid' : null;
                  }),
              const SizedBox(height: 16),
              TextFormField(
                  controller: _clipSpacingController,
                  decoration: const InputDecoration(
                      labelText: 'Leveling Clip Spacing',
                      suffixText: 'in',
                      hintText: 'e.g., 4 or 6'),
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  validator: (value) {
                    if (value == null || value.isEmpty) return null;
                    return parseMixedNumber(value) < 0 ? 'Invalid' : null;
                  }),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: _saveAdvancedCalculations,
                child: const Text('Save Calculations'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
