// lib/screens/project_editor_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_area_model.dart';
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/line_item_group.dart';
import 'package:tile_wizard/providers/job_provider.dart';
import 'package:tile_wizard/screens/client_list_screen.dart';
import 'package:tile_wizard/screens/result_screen.dart';
import 'package:tile_wizard/screens/widgets/add_edit_area_dialog.dart';
import 'package:tile_wizard/screens/widgets/add_edit_line_item_dialog.dart';
import 'package:tile_wizard/screens/widgets/app_drawer.dart';
import 'package:uuid/uuid.dart';

class ProjectEditorScreen extends StatefulWidget {
  final int? jobId;
  const ProjectEditorScreen({super.key, this.jobId});
  @override
  State<ProjectEditorScreen> createState() => _ProjectEditorScreenState();
}

class _ProjectEditorScreenState extends State<ProjectEditorScreen> {
  final _formKey = GlobalKey<FormState>();
  late Job _currentJob;
  bool _isLoading = true;

  // We no longer need _localSelectedClient
  // Client? _localSelectedClient;

  late TextEditingController _projectNameController;
  late TextEditingController _wastagePercentController;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  @override
  void initState() {
    super.initState();
    _projectNameController = TextEditingController();
    _wastagePercentController = TextEditingController();
    _initializeEditor();
  }

  Future<void> _initializeEditor() async {
    List<LineItemGroup> initialGroups = [];
    if (widget.jobId != null) {
      final existingJob = context
          .read<JobProvider>()
          .jobs
          .firstWhere((j) => j.id == widget.jobId);
      _currentJob = existingJob.copyWith();

      // We don't need _localSelectedClient, the client is already
      // part of the _currentJob.client link

      initialGroups = (_currentJob.itemGroups ?? [])
          .map((group) => LineItemGroup(
                name: group.name,
                items: List<CustomLineItem>.from(group.items ?? []),
                areas: List<JobArea>.from(group.areas ?? []),
              ))
          .toList();
    } else {
      _currentJob = Job(
        jobUUID: const Uuid().v4(),
        creationDate: DateTime.now(),
        itemGroups: [],
        payments: [],
        taxRate: 0.0,
        wastagePercent: 10.0,
      );
      initialGroups = [];
    }
    _currentJob.itemGroups = initialGroups;

    _projectNameController.text = _currentJob.projectName ?? '';
    _wastagePercentController.text =
        _currentJob.wastagePercent?.toString() ?? '10.0';

    _projectNameController.removeListener(_updateProjectName);
    _wastagePercentController.removeListener(_updateWastage);
    _projectNameController.addListener(_updateProjectName);
    _wastagePercentController.addListener(_updateWastage);

    setState(() {
      _isLoading = false;
    });
  }

  void _updateProjectName() {
    if (mounted) {
      setState(() {
        _currentJob.projectName = _projectNameController.text;
      });
      _updateTotal();
    }
  }

  void _updateWastage() {
    if (mounted) {
      setState(() {
        _currentJob.wastagePercent =
            double.tryParse(_wastagePercentController.text);
      });
      _updateTotal();
    }
  }

  void _updateTotal() {
    if (mounted) {
      setState(() {});
    }
  }

  @override
  void dispose() {
    _projectNameController.removeListener(_updateProjectName);
    _wastagePercentController.removeListener(_updateWastage);
    _projectNameController.dispose();
    _wastagePercentController.dispose();
    super.dispose();
  }

  void _selectClient() async {
    final selectedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const ClientListScreen()),
    );
    if (selectedClient != null && mounted) {
      setState(() {
        // --- THIS IS THE FIX ---
        // Attach the client directly to the _currentJob object
        _currentJob.client.value = selectedClient;
        // --- END OF FIX ---
      });
    }
  }

  void _saveAndNavigate() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) {
      return;
    }

    final jobProvider = context.read<JobProvider>();
    int jobIdToNavigate;

    _currentJob.projectName = _projectNameController.text;
    _currentJob.wastagePercent =
        double.tryParse(_wastagePercentController.text);

    // --- THIS IS THE FIX ---
    // The provider's deep-copy logic will handle the links
    // We just pass the single _currentJob object
    if (widget.jobId != null) {
      await jobProvider.updateJob(_currentJob);
      jobIdToNavigate = _currentJob.id;
    } else {
      // The addJob method returns the new, managed job
      final newManagedJob = await jobProvider.addJob(_currentJob);
      jobIdToNavigate = newManagedJob.id;
    }
    // --- END OF FIX ---

    if (mounted) {
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (context) => ResultScreen(jobId: jobIdToNavigate),
        ),
      );
    }
  }

  // --- Group/Area/Item Methods (No Changes) ---
  void _addGroup() {
    final nameController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add New Group'),
        content: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Group Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && mounted) {
                setState(() {
                  _currentJob.itemGroups!.add(LineItemGroup(
                    name: nameController.text,
                    items: [],
                    areas: [],
                  ));
                });
                _updateTotal();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Add'),
          ),
        ],
      ),
    );
  }

  void _editGroup(int groupIndex) {
    final group = _currentJob.itemGroups![groupIndex];
    final nameController = TextEditingController(text: group.name ?? '');
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Edit Group Name'),
        content: TextFormField(
            controller: nameController,
            decoration: const InputDecoration(labelText: 'Group Name')),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () {
              if (nameController.text.isNotEmpty && mounted) {
                setState(() {
                  _currentJob.itemGroups![groupIndex].name =
                      nameController.text;
                });
                _updateTotal();
                Navigator.of(context).pop();
              }
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  void _deleteGroup(int groupIndex) {
    setState(() {
      _currentJob.itemGroups!.removeAt(groupIndex);
    });
    _updateTotal();
  }

  void _addArea(int groupIndex) async {
    final newArea = await showDialog<JobArea>(
      context: context,
      builder: (context) => const AddEditAreaDialog(),
    );
    if (newArea != null && mounted) {
      setState(() {
        _currentJob.itemGroups![groupIndex].areas ??= [];
        _currentJob.itemGroups![groupIndex].areas!.add(newArea);
      });
      _updateTotal();
    }
  }

  void _editArea(int groupIndex, int areaIndex) async {
    final existingArea = _currentJob.itemGroups![groupIndex].areas![areaIndex];
    final updatedArea = await showDialog<JobArea>(
      context: context,
      builder: (context) => AddEditAreaDialog(area: existingArea),
    );
    if (updatedArea != null && mounted) {
      setState(() {
        _currentJob.itemGroups![groupIndex].areas![areaIndex] = updatedArea;
      });
      _updateTotal();
    }
  }

  void _deleteArea(int groupIndex, int areaIndex) {
    setState(() {
      _currentJob.itemGroups![groupIndex].areas!.removeAt(areaIndex);
    });
    _updateTotal();
  }

  void _addItem(int groupIndex) async {
    final newItem = await showDialog<CustomLineItem>(
      context: context,
      builder: (context) => const AddEditLineItemDialog(),
    );
    if (newItem != null && mounted) {
      setState(() {
        _currentJob.itemGroups![groupIndex].items ??= [];
        _currentJob.itemGroups![groupIndex].items!.add(newItem);
      });
      _updateTotal();
    }
  }

  void _editItem(int groupIndex, int itemIndex) async {
    final existingItem = _currentJob.itemGroups![groupIndex].items![itemIndex];
    final updatedItem = await showDialog<CustomLineItem>(
      context: context,
      builder: (context) => AddEditLineItemDialog(item: existingItem),
    );
    if (updatedItem != null && mounted) {
      setState(() {
        _currentJob.itemGroups![groupIndex].items![itemIndex] = updatedItem;
      });
      _updateTotal();
    }
  }

  void _deleteItem(int groupIndex, int itemIndex) {
    setState(() {
      _currentJob.itemGroups![groupIndex].items!.removeAt(itemIndex);
    });
    _updateTotal();
  }
  // --- End Group/Area/Item Methods ---

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.jobId == null ? 'New Project' : 'Edit Project'),
        actions: [
          IconButton(
            icon: const Icon(Icons.summarize_outlined),
            tooltip: 'View Summary',
            onPressed: _saveAndNavigate,
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(30.0),
          child: Padding(
            padding: const EdgeInsets.only(bottom: 8.0, right: 16.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Text('Estimated Total: ',
                    style: Theme.of(context).textTheme.titleSmall),
                Text(
                  _currencyFormat.format(_currentJob.grandTotal),
                  style: Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(fontWeight: FontWeight.bold),
                ),
              ],
            ),
          ),
        ),
      ),
      drawer: const AppDrawer(),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildProjectSetupCard(),
              const SizedBox(height: 16),
              _buildGroupsSection(),
              const SizedBox(height: 16),
              OutlinedButton.icon(
                icon: const Icon(Icons.add_box_outlined),
                label: const Text('Add Group'),
                onPressed: _addGroup,
              ),
              const SizedBox(height: 80),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildProjectSetupCard() {
    // --- THIS IS THE FIX ---
    // Read from the job's client link value
    final clientName = _currentJob.client.value?.name ?? 'Select Client';
    // --- END OF FIX ---
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextFormField(
              controller: _projectNameController,
              decoration: InputDecoration(
                labelText: 'PROJECT NAME',
                labelStyle: TextStyle(
                  color: primaryColor,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 1.2,
                ),
                hintText: 'e.g., Master Bath Remodel',
              ),
              validator: (value) =>
                  value!.isEmpty ? 'Project name required' : null,
            ),
            const SizedBox(height: 16),
            ListTile(
              leading: const Icon(Icons.person_outline),
              title: Text(clientName),
              trailing:
                  Icon(Icons.arrow_forward_ios, size: 16, color: primaryColor),
              contentPadding: EdgeInsets.zero,
              onTap: _selectClient,
            ),
            const Divider(),
            Text('Default Job Wastage',
                style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            _buildNumericTextField(_wastagePercentController, 'Wastage', '%'),
          ],
        ),
      ),
    );
  }

  // --- All other helper methods (_buildGroupsSection, etc.) are correct ---

  Widget _buildGroupsSection() {
    final groups = _currentJob.itemGroups ?? [];
    if (groups.isEmpty) {
      return const Card(
        elevation: 0,
        color: Colors.transparent,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 40.0),
          child: Center(
              child: Text(
                  'Add a group to get started\n(e.g., "Master Bathroom").',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: Colors.grey))),
        ),
      );
    }
    return Column(
      children: groups.asMap().entries.map((entry) {
        int groupIndex = entry.key;
        LineItemGroup group = entry.value;
        return _buildGroupExpansionTile(context, group, groupIndex);
      }).toList(),
    );
  }

  Widget _buildGroupExpansionTile(
      BuildContext context, LineItemGroup group, int groupIndex) {
    final areas = group.areas ?? [];
    final items = group.items ?? [];
    final theme = Theme.of(context);
    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      child: ExpansionTile(
        key: PageStorageKey('group_$groupIndex'),
        initiallyExpanded: true,
        backgroundColor: theme.colorScheme.surfaceVariant.withAlpha(77),
        collapsedBackgroundColor: theme.colorScheme.surface,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        collapsedShape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
        title: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Flexible(
              child: Text(
                group.name ?? 'Unnamed Group',
                style: theme.textTheme.titleMedium
                    ?.copyWith(fontWeight: FontWeight.bold),
                overflow: TextOverflow.ellipsis,
              ),
            ),
            Text(
              _currencyFormat.format(group.groupTotal),
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.bold,
                color: theme.colorScheme.primary,
              ),
            ),
          ],
        ),
        subtitle: Text('${areas.length} areas, ${items.length} items'),
        childrenPadding:
            const EdgeInsets.symmetric(horizontal: 8.0).copyWith(bottom: 8.0),
        children: [
          _buildSectionHeader(
              context,
              'Areas (${group.groupAreaTotal.toStringAsFixed(2)} sqft)',
              () => _addArea(groupIndex)),
          areas.isEmpty
              ? const ListTile(
                  dense: true,
                  title: Text('No areas added...',
                      style: TextStyle(fontStyle: FontStyle.italic)))
              : Container(
                  constraints: const BoxConstraints(
                    maxHeight: 200.0,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: areas.length,
                    itemBuilder: (context, index) {
                      return _buildAreaTile(
                          context, areas[index], groupIndex, index);
                    },
                  ),
                ),
          const Divider(),
          _buildSectionHeader(
              context,
              'Line Items (${_currencyFormat.format(group.groupTotal)})',
              () => _addItem(groupIndex)),
          items.isEmpty
              ? const ListTile(
                  dense: true,
                  title: Text('No line items added...',
                      style: TextStyle(fontStyle: FontStyle.italic)))
              : Container(
                  constraints: const BoxConstraints(
                    maxHeight: 300.0,
                  ),
                  child: ListView.builder(
                    shrinkWrap: true,
                    physics: const ClampingScrollPhysics(),
                    itemCount: items.length,
                    itemBuilder: (context, index) {
                      return _buildItemTile(
                          context, items[index], groupIndex, index);
                    },
                  ),
                ),
          const Divider(),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.edit_outlined,
                    size: 20, color: theme.colorScheme.secondary),
                tooltip: 'Edit Group Name',
                onPressed: () => _editGroup(groupIndex),
              ),
              IconButton(
                icon: Icon(Icons.delete_outline,
                    size: 20, color: theme.colorScheme.error),
                tooltip: 'Delete Group',
                onPressed: () => _deleteGroup(groupIndex),
              ),
            ],
          )
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
      BuildContext context, String title, VoidCallback onAddPressed) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 8.0),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          IconButton.filledTonal(
            icon: const Icon(Icons.add, size: 18),
            onPressed: onAddPressed,
            iconSize: 18,
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(minHeight: 28, minWidth: 28),
            tooltip: title.startsWith('Area') ? 'Add Area' : 'Add Line Item',
          ),
        ],
      ),
    );
  }

  Widget _buildAreaTile(
      BuildContext context, JobArea area, int groupIndex, int areaIndex) {
    final theme = Theme.of(context);
    String tileInfo = 'No tile info';
    if ((area.tileLength ?? 0) > 0 && (area.tileWidth ?? 0) > 0) {
      tileInfo =
          'Tile: ${area.tileLength}x${area.tileWidth}, Grout: ${area.groutSize ?? "N/A"}';
    }
    return ListTile(
      dense: true,
      leading: Icon(
          area.type == AreaType.floor || area.type == AreaType.showerFloor
              ? Icons.square_foot_outlined
              : Icons.grid_on_outlined,
          color: theme.colorScheme.secondary),
      title:
          Text(area.name ?? 'Unnamed Area', style: theme.textTheme.bodyMedium),
      subtitle: Text(tileInfo, style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('${area.sqft?.toStringAsFixed(2) ?? '0'} sqft',
              style: theme.textTheme.bodyMedium),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Area',
            onPressed: () => _editArea(groupIndex, areaIndex),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: 'Delete Area',
            onPressed: () => _deleteArea(groupIndex, areaIndex),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      onTap: () => _editArea(groupIndex, areaIndex),
    );
  }

  Widget _buildItemTile(BuildContext context, CustomLineItem item,
      int groupIndex, int itemIndex) {
    final theme = Theme.of(context);
    return ListTile(
      dense: true,
      leading:
          Icon(Icons.list_alt_outlined, color: theme.colorScheme.secondary),
      title: Text(item.description ?? 'No Description',
          style: theme.textTheme.bodyMedium),
      subtitle: Text(
          '${item.quantity} ${item.unit} @ ${_currencyFormat.format(item.rate ?? 0)}',
          style: theme.textTheme.bodySmall),
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            _currencyFormat.format(item.total),
            style: theme.textTheme.bodyMedium
                ?.copyWith(fontWeight: FontWeight.bold),
          ),
          IconButton(
            icon: const Icon(Icons.edit_outlined, size: 20),
            tooltip: 'Edit Item',
            onPressed: () => _editItem(groupIndex, itemIndex),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline,
                size: 20, color: theme.colorScheme.error),
            tooltip: 'Delete Item',
            onPressed: () => _deleteItem(groupIndex, itemIndex),
            padding: const EdgeInsets.all(4),
            constraints: const BoxConstraints(),
          ),
        ],
      ),
      onTap: () => _editItem(groupIndex, itemIndex),
    );
  }

  TextFormField _buildNumericTextField(
      TextEditingController controller, String label, String suffix) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: label,
        suffixText: suffix,
      ),
      keyboardType:
          const TextInputType.numberWithOptions(decimal: true, signed: false),
      validator: (value) {
        if (value == null || value.isEmpty) {
          return null; // Wastage can be empty
        }
        if (double.tryParse(value) == null) {
          return 'Invalid';
        }
        return null;
      },
    );
  }
}
