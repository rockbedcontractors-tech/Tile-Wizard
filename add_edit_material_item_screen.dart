// lib/screens/add_edit_material_item_screen.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/material_item_model.dart';
import '../providers/material_provider.dart';

class AddEditMaterialItemScreen extends StatefulWidget {
  final MaterialItem? item;
  const AddEditMaterialItemScreen({super.key, this.item});

  @override
  State<AddEditMaterialItemScreen> createState() =>
      _AddEditMaterialItemScreenState();
}

class _AddEditMaterialItemScreenState extends State<AddEditMaterialItemScreen> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _nameController;
  late TextEditingController _costController;
  late TextEditingController _sizeController;
  late TextEditingController _coverageSqftController;
  late TextEditingController _coverageLinearFtController;
  late TextEditingController _coverageUnitController;
  // --- NEW CONTROLLER ---
  late TextEditingController _itemsPerUnitController;

  late MaterialCategory _selectedCategory;
  bool get _isEditing => widget.item != null;

  @override
  void initState() {
    super.initState();
    final item = widget.item;
    _nameController = TextEditingController(text: item?.name ?? '');
    _costController = TextEditingController(text: item?.cost?.toString() ?? '');
    _sizeController = TextEditingController(text: item?.size ?? '');
    _coverageSqftController =
        TextEditingController(text: item?.coverageSqft?.toString() ?? '');
    _coverageLinearFtController =
        TextEditingController(text: item?.coverageLinearFt?.toString() ?? '');
    _coverageUnitController =
        TextEditingController(text: item?.coverageUnit ?? '');
    _selectedCategory = item?.category ?? MaterialCategory.other;

    // --- INITIALIZE CONTROLLER ---
    _itemsPerUnitController =
        TextEditingController(text: item?.itemsPerUnit?.toString() ?? '');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _costController.dispose();
    _sizeController.dispose();
    _coverageSqftController.dispose();
    _coverageLinearFtController.dispose();
    _coverageUnitController.dispose();
    _itemsPerUnitController.dispose(); // --- DISPOSE CONTROLLER ---
    super.dispose();
  }

  void _saveItem() {
    if (_formKey.currentState!.validate()) {
      final materialProvider = context.read<MaterialProvider>();
      final cost = double.tryParse(_costController.text);
      final coverageSqft = double.tryParse(_coverageSqftController.text);
      final coverageLinearFt =
          double.tryParse(_coverageLinearFtController.text);
      // --- READ FROM CONTROLLER ---
      final itemsPerUnit = int.tryParse(_itemsPerUnitController.text);

      if (_isEditing) {
        final updatedItem = MaterialItem(
          name: _nameController.text,
          category: _selectedCategory,
          cost: cost,
          size: _sizeController.text,
          coverageSqft: coverageSqft,
          coverageLinearFt: coverageLinearFt,
          coverageUnit: _coverageUnitController.text,
          itemsPerUnit: itemsPerUnit, // <-- Add to update
        );
        updatedItem.id = widget.item!.id;
        materialProvider.updateMaterialItem(updatedItem);
      } else {
        final newItem = MaterialItem(
          name: _nameController.text,
          category: _selectedCategory,
          cost: cost,
          size: _sizeController.text,
          coverageSqft: coverageSqft,
          coverageLinearFt: coverageLinearFt,
          coverageUnit: _coverageUnitController.text,
          itemsPerUnit: itemsPerUnit, // <-- Add to new
        );
        materialProvider.addMaterialItem(newItem);
      }
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_isEditing ? 'Edit Material' : 'Add Material'),
        actions: [
          IconButton(
            icon: const Icon(Icons.save),
            onPressed: _saveItem,
            tooltip: 'Save Material',
          ),
        ],
      ),
      body: Form(
        key: _formKey,
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: 'Material Name *'),
                validator: (value) => (value == null || value.isEmpty)
                    ? 'Name is required'
                    : null,
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<MaterialCategory>(
                value: _selectedCategory, // Use value, not initialValue
                items: MaterialCategory.values
                    .map((category) => DropdownMenuItem(
                          value: category,
                          child: Text(category.toString().split('.').last),
                        ))
                    .toList(),
                onChanged: (value) {
                  if (value != null) {
                    setState(() {
                      _selectedCategory = value;
                    });
                  }
                },
                decoration: const InputDecoration(labelText: 'Category *'),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _costController,
                decoration: const InputDecoration(
                    labelText: 'Cost (\$)', hintText: 'e.g., 24.99'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _sizeController,
                decoration: const InputDecoration(
                    labelText: 'Size / Unit',
                    hintText: 'e.g., 50lb Bag, 1 Gallon'),
              ),

              // --- NEW TEXT FIELD ---
              const SizedBox(height: 16),
              TextFormField(
                controller: _itemsPerUnitController,
                decoration: const InputDecoration(
                    labelText: 'Items per Unit (for Clips/Screws)',
                    hintText: 'e.g., 400, 700'),
                keyboardType: TextInputType.number,
              ),
              // --- END NEW TEXT FIELD ---

              const SizedBox(height: 24),
              const Divider(),
              const SizedBox(height: 16),
              Text('Coverage (Optional)',
                  style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coverageSqftController,
                decoration: const InputDecoration(labelText: 'Coverage (sqft)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coverageLinearFtController,
                decoration:
                    const InputDecoration(labelText: 'Coverage (linear ft)'),
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _coverageUnitController,
                decoration: const InputDecoration(
                    labelText: 'Coverage Unit',
                    hintText: 'e.g., per Bag, per Roll'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
