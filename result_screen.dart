// lib/screens/result_screen.dart

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/line_item_group.dart';
import 'package:tile_wizard/providers/job_provider.dart';
import 'package:tile_wizard/providers/profile_provider.dart';
import 'package:tile_wizard/screens/advanced_calculator_screen.dart';
import 'package:tile_wizard/screens/client_list_screen.dart';
import 'package:tile_wizard/screens/pdf_preview_screen.dart';
import 'package:tile_wizard/screens/project_editor_screen.dart';
import 'package:tile_wizard/screens/widgets/add_payment_dialog.dart';
import 'package:tile_wizard/screens/widgets/advanced_materials_results_card.dart';
import 'package:tile_wizard/screens/widgets/app_drawer.dart';
import 'package:tile_wizard/screens/widgets/document_details_card.dart';
import 'package:tile_wizard/screens/widgets/financial_summary_card.dart';
import 'package:tile_wizard/screens/widgets/floating_action_buttons.dart';
import 'package:tile_wizard/screens/widgets/material_breakdown_card.dart';
import 'package:tile_wizard/screens/widgets/payments_card.dart';
import 'package:tile_wizard/screens/widgets/pdf_options_card.dart';
import 'package:tile_wizard/models/material_package_model.dart';

enum ResultView { overview, details }

class FinancialEditResult {
  final double value;
  final FinancialType type;
  FinancialEditResult({required this.value, required this.type});
}

class ResultScreen extends StatefulWidget {
  final int jobId;
  const ResultScreen({super.key, required this.jobId});

  @override
  State<ResultScreen> createState() => _ResultScreenState();
}

class _ResultScreenState extends State<ResultScreen> {
  late TextEditingController _poNumberController;
  late TextEditingController _quoteNumberController;
  late TextEditingController _invoiceNumberController;
  late TextEditingController _publicNotesController;

  final NumberFormat _currencyFormat =
      NumberFormat.currency(locale: 'en_US', symbol: '\$');

  ResultView _selectedView = ResultView.overview;

  @override
  void initState() {
    super.initState();
    try {
      final initialJob = context
          .read<JobProvider>()
          .jobs
          .firstWhere((j) => j.id == widget.jobId);

      _poNumberController =
          TextEditingController(text: initialJob.poNumber ?? '');
      _quoteNumberController =
          TextEditingController(text: initialJob.quoteNumber ?? '');
      _invoiceNumberController =
          TextEditingController(text: initialJob.invoiceNumber ?? '');
      _publicNotesController =
          TextEditingController(text: initialJob.publicNotes ?? '');
    } catch (e) {
      print("Error finding job with ID ${widget.jobId}: $e");
      _poNumberController = TextEditingController();
      _quoteNumberController = TextEditingController();
      _invoiceNumberController = TextEditingController();
      _publicNotesController = TextEditingController();

      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Error loading job details.'),
                backgroundColor: Colors.red),
          );
          Navigator.of(context).pop();
        }
      });
    }
  }

  @override
  void dispose() {
    _poNumberController.dispose();
    _quoteNumberController.dispose();
    _invoiceNumberController.dispose();
    _publicNotesController.dispose();
    super.dispose();
  }

  void _updateJob(Job updatedJob) {
    // 'updatedJob' is the unmanaged copy
    if (!mounted) return;

    final jobProvider = context.read<JobProvider>();

    // 1. Find the ORIGINAL managed job from the provider's list
    final originalJob =
        jobProvider.jobs.firstWhere((j) => j.id == updatedJob.id);

    // 2. Get the links from the ORIGINAL job
    final Client? client = originalJob.client.value;
    final MaterialPackage? package = originalJob.selectedPackage.value;

    // 3. Call updateJob with all 3 arguments
    jobProvider.updateJob(updatedJob, client, package);
  }

  // --- Helper Methods ---

  void _showDueDateOptions(Job job) {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        final baseDate = job.creationDate ?? DateTime.now();
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.today),
                title: const Text('Due Upon Receipt'),
                onTap: () {
                  _updateJob(job.copyWith(dueDate: baseDate));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('NET 15'),
                onTap: () {
                  final dueDate = baseDate.add(const Duration(days: 15));
                  _updateJob(job.copyWith(dueDate: dueDate));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.calendar_month),
                title: const Text('NET 30'),
                onTap: () {
                  final dueDate = baseDate.add(const Duration(days: 30));
                  _updateJob(job.copyWith(dueDate: dueDate));
                  Navigator.pop(context);
                },
              ),
              ListTile(
                leading: const Icon(Icons.edit_calendar),
                title: const Text('Choose Custom Date...'),
                onTap: () async {
                  Navigator.pop(context);
                  final pickedDate = await showDatePicker(
                    context: context,
                    initialDate: job.dueDate ?? DateTime.now(),
                    firstDate: DateTime(2020),
                    lastDate: DateTime(2030),
                  );
                  if (pickedDate != null) {
                    _updateJob(job.copyWith(dueDate: pickedDate));
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _showExpirationDateOptions(Job job) {
    final baseDate = job.creationDate ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Expires in 15 Days'),
                  onTap: () {
                    final expirationDate =
                        baseDate.add(const Duration(days: 15));
                    _updateJob(job.copyWith(expirationDate: expirationDate));
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.calendar_month),
                  title: const Text('Expires in 30 Days'),
                  onTap: () {
                    final expirationDate =
                        baseDate.add(const Duration(days: 30));
                    _updateJob(job.copyWith(expirationDate: expirationDate));
                    Navigator.pop(context);
                  }),
              ListTile(
                  leading: const Icon(Icons.edit_calendar),
                  title: const Text('Choose Custom Date...'),
                  onTap: () async {
                    Navigator.pop(context);
                    final pickedDate = await showDatePicker(
                        context: context,
                        initialDate: job.expirationDate ?? DateTime.now(),
                        firstDate: DateTime(2020),
                        lastDate: DateTime(2030));
                    if (pickedDate != null) {
                      _updateJob(job.copyWith(expirationDate: pickedDate));
                    }
                  }),
            ],
          ),
        );
      },
    );
  }

  void _showEditFinancialDialog(
      {required BuildContext context,
      required Job job,
      required String title,
      required double initialValue,
      required FinancialType initialType,
      required Function(FinancialEditResult result) onSave}) {
    final valueController =
        TextEditingController(text: initialValue.toString());
    var currentType = initialType;

    showDialog(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setState) {
            return AlertDialog(
              title: Text(title),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: valueController,
                    decoration: InputDecoration(
                        labelText: 'Value',
                        suffixText: currentType == FinancialType.percentage
                            ? '%'
                            : '\$'),
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                  ),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: RadioListTile<FinancialType>(
                          title: const Text('\$'),
                          value: FinancialType.dollar,
                          groupValue: currentType,
                          onChanged: (FinancialType? value) {
                            setState(() {
                              currentType = value!;
                            });
                          },
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<FinancialType>(
                          title: const Text('%'),
                          value: FinancialType.percentage,
                          groupValue: currentType,
                          onChanged: (FinancialType? value) {
                            setState(() {
                              currentType = value!;
                            });
                          },
                        ),
                      ),
                    ],
                  )
                ],
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel')),
                ElevatedButton(
                    onPressed: () {
                      final newValue = double.tryParse(valueController.text);
                      if (newValue != null) {
                        onSave(FinancialEditResult(
                            value: newValue, type: currentType));
                        Navigator.pop(context);
                      }
                    },
                    child: const Text('Save')),
              ],
            );
          },
        );
      },
    );
  }

  void _showAddPaymentDialog(Job currentJob) async {
    final newPayment = await showDialog<Payment>(
      context: context,
      builder: (context) => const AddPaymentDialog(),
    );

    if (newPayment != null) {
      final updatedPayments = List<Payment>.from(currentJob.payments ?? [])
        ..add(newPayment);
      _updateJob(currentJob.copyWith(payments: updatedPayments));
    }
  }

  void _showDeletePaymentConfirmation(Job job, int index) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Payment?'),
        content:
            const Text('Are you sure you want to delete this payment record?'),
        actions: [
          TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final updatedList = List<Payment>.from(job.payments ?? []);
      updatedList.removeAt(index);
      _updateJob(job.copyWith(payments: updatedList));
    }
  }

  void _navigateToEditor(int jobId) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ProjectEditorScreen(jobId: jobId)),
    );
  }

  // --- Main Build Method ---
  @override
  Widget build(BuildContext context) {
    final Job job;
    try {
      job = context
          .watch<JobProvider>()
          .jobs
          .firstWhere((j) => j.id == widget.jobId);
    } catch (e) {
      print("Error finding job with ID ${widget.jobId} in build: $e");
      return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Job not found.')));
    }

    final isInvoice = job.isInvoice ?? false;
    final hasPayments = (job.payments ?? []).isNotEmpty;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final profile = context.watch<ProfileProvider>().profile;
    final isPremium = profile.isPremium;

    void convertToInvoice() {
      final allJobs = context.read<JobProvider>().jobs;
      int highestInvoiceNumber = 1000;
      if (allJobs.isNotEmpty) {
        highestInvoiceNumber = allJobs
            .map((j) => int.tryParse(j.invoiceNumber ?? '0') ?? 0)
            .where((n) => n > 0)
            .fold(1000, (max, current) => max > current ? max : current);
      }
      final newInvoiceNumber = (highestInvoiceNumber + 1).toString();
      _invoiceNumberController.text = newInvoiceNumber;
      _updateJob(
          job.copyWith(isInvoice: true, invoiceNumber: newInvoiceNumber));
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(isInvoice ? 'Invoice Summary' : 'Quote Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit Project',
            onPressed: () => _navigateToEditor(job.id),
          ),
          IconButton(
            icon: const Icon(Icons.post_add_outlined),
            tooltip: 'New Project',
            onPressed: () {
              Navigator.pushAndRemoveUntil(
                context,
                MaterialPageRoute(builder: (_) => const ProjectEditorScreen()),
                (route) => false,
              );
            },
          ),
        ],
      ),
      drawer: const AppDrawer(),
      bottomNavigationBar: FloatingActionButtons(
        isInvoice: isInvoice,
        hasPayments: hasPayments,
        onSecondaryAction: () {
          if (isInvoice) {
            _updateJob(job.copyWith(isInvoice: false));
          } else {
            convertToInvoice();
          }
        },
        onPrimaryAction: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (context) => PdfPreviewScreen(jobId: job.id),
            ),
          );
        },
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: SegmentedButton<ResultView>(
              segments: const [
                ButtonSegment(
                  value: ResultView.overview,
                  label: Text('Overview'),
                  icon: Icon(Icons.business_center_outlined),
                ),
                ButtonSegment(
                  value: ResultView.details,
                  label: Text('Details'),
                  icon: Icon(Icons.calculate_outlined),
                ),
              ],
              selected: {_selectedView},
              onSelectionChanged: (Set<ResultView> newSelection) {
                setState(() {
                  _selectedView = newSelection.first;
                });
              },
            ),
          ),
          if (_selectedView == ResultView.overview)
            _buildOverviewColumn(
              context,
              job: job,
              isInvoice: isInvoice,
              primaryColor: primaryColor,
            )
          else
            _buildDetailsColumn(
              context,
              job: job,
              isPremium: isPremium,
              primaryColor: primaryColor,
            ),
        ]),
      ),
    );
  }

  // --- "Overview" cards column ---
  Widget _buildOverviewColumn(
    BuildContext context, {
    required Job job,
    required bool isInvoice,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        FinancialSummaryCard(
          job: job,
          onMarkupTap: () {
            _showEditFinancialDialog(
              context: context,
              job: job,
              title: 'Edit Markup',
              initialValue: job.markupValue ?? 0.0,
              initialType: job.markupType,
              onSave: (result) {
                _updateJob(job.copyWith(
                    markupValue: result.value, markupType: result.type));
              },
            );
          },
          onDiscountTap: () {
            _showEditFinancialDialog(
              context: context,
              job: job,
              title: 'Edit Discount',
              initialValue: job.discountValue ?? 0.0,
              initialType: job.discountType,
              onSave: (result) {
                _updateJob(job.copyWith(
                    discountValue: result.value, discountType: result.type));
              },
            );
          },
          onTaxTap: () {
            final taxController =
                TextEditingController(text: job.taxRate.toString());
            showDialog(
                context: context,
                builder: (context) => AlertDialog(
                      title: const Text('Edit Tax Rate'),
                      content: TextFormField(
                        controller: taxController,
                        decoration:
                            const InputDecoration(labelText: 'Rate (%)'),
                        keyboardType: const TextInputType.numberWithOptions(
                            decimal: true),
                      ),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context),
                            child: const Text('Cancel')),
                        ElevatedButton(
                            onPressed: () {
                              final newRate =
                                  double.tryParse(taxController.text);
                              if (newRate != null) {
                                _updateJob(job.copyWith(taxRate: newRate));
                                Navigator.pop(context);
                              }
                            },
                            child: const Text('Save')),
                      ],
                    ));
          },
        ),
        const SizedBox(height: 24),
        if (isInvoice) ...[
          PaymentsCard(
            job: job,
            onAddPaymentTap: () => _showAddPaymentDialog(job),
            onPaymentDeleted: (index) =>
                _showDeletePaymentConfirmation(job, index),
          ),
          const SizedBox(height: 24),
        ] else ...[
          PdfOptionsCard(
            job: job,
            onHidePricesChanged: (newValue) {
              _updateJob(job.copyWith(hidePrice: newValue));
            },
            onShowMarkupChanged: (newValue) {
              _updateJob(job.copyWith(showMarkupOnPDF: newValue));
            },
            onShowDiscountChanged: (newValue) {
              _updateJob(job.copyWith(showDiscountOnPDF: newValue));
            },
            onShowMaterialsChanged: (newValue) {
              _updateJob(job.copyWith(showMaterialSupplyOnPDF: newValue));
            },
          ),
          const SizedBox(height: 24),
        ],
        DocumentDetailsCard(
          isInvoice: isInvoice,
          documentNumberController:
              isInvoice ? _invoiceNumberController : _quoteNumberController,
          poNumberController: _poNumberController,
          onDocumentNumberChanged: (value) {
            if (isInvoice) {
              _updateJob(job.copyWith(invoiceNumber: value));
            } else {
              _updateJob(job.copyWith(quoteNumber: value));
            }
          },
          onPoNumberChanged: (value) {
            _updateJob(job.copyWith(poNumber: value));
          },
          onDueDateTap: () => _showDueDateOptions(job),
          onExpirationDateTap: () => _showExpirationDateOptions(job),
          dueDate: job.dueDate,
          expirationDate: job.expirationDate,
        ),
        const SizedBox(height: 16),

        // --- THIS IS THE ONLY CLIENT CARD ---
        _buildReadOnlyCardWithEdit(
            context: context,
            jobId: job.id,
            icon: Icons.person_outline,
            title: job.client.value?.name ?? 'No Client Selected',
            subtitle: job.client.value?.phone ?? 'Client Details',
            onTapOverride: () async {
              final selectedClient = await Navigator.push<Client>(
                context,
                MaterialPageRoute(builder: (_) => const ClientListScreen()),
              );
              if (selectedClient != null) {
                final updatedJob = job.copyWith();
                updatedJob.client.value = selectedClient;
                _updateJob(updatedJob);
              }
            }),
        const SizedBox(height: 24),

        // --- THIS IS THE NOTES TEXT FIELD ---
        TextField(
          controller: _publicNotesController,
          decoration: InputDecoration(
            labelText: 'NOTES FOR CLIENT',
            labelStyle: TextStyle(color: primaryColor),
            hintText: 'e.g., 50% deposit required...',
            border: const OutlineInputBorder(),
            filled: true,
          ),
          maxLines: null,
          minLines: 3,
          keyboardType: TextInputType.multiline,
          onChanged: (value) => _updateJob(job.copyWith(publicNotes: value)),
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  // --- "Details" cards column ---
  Widget _buildDetailsColumn(
    BuildContext context, {
    required Job job,
    required bool isPremium,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildReadOnlyCardWithEdit(
          context: context,
          jobId: job.id,
          icon: Icons.description_outlined,
          title: job.projectName ?? 'No Project Name',
          subtitle: 'Project Name',
        ),
        const SizedBox(height: 24),
        _buildReadOnlyCardWithEdit(
          context: context,
          jobId: job.id,
          icon: Icons.list_alt_outlined,
          title: 'Line Items Summary',
          subtitle: '${job.itemGroups?.length ?? 0} groups',
          child: _buildLineItemSummary(context, job.itemGroups ?? []),
          includePadding: true,
        ),
        const SizedBox(height: 24),
        _buildReadOnlyCardWithEdit(
          context: context,
          jobId: job.id,
          icon: Icons.grid_on_outlined,
          title: 'Material Breakdown',
          subtitle: '${job.totalArea.toStringAsFixed(1)} sqft total',
          child: MaterialBreakdownCard(job: job),
          includePadding: false,
        ),
        const SizedBox(height: 24),
        if (isPremium) ...[
          Card(
            elevation: 2,
            child: ListTile(
              leading: Icon(Icons.layers, color: primaryColor),
              title: Text(
                'Advanced Materials',
                style:
                    TextStyle(color: primaryColor, fontWeight: FontWeight.bold),
              ),
              subtitle: const Text('Calculate thinset, grout, etc.'),
              trailing: const Icon(Icons.arrow_forward_ios, size: 16),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                      builder: (_) => AdvancedCalculatorScreen(jobId: job.id)),
                );
              },
            ),
          ),
          const SizedBox(height: 24),
          AdvancedMaterialsResultsCard(job: job),
          const SizedBox(height: 24),
        ],
      ],
    );
  }

  // --- Helper: Read-only card ---
  Widget _buildReadOnlyCardWithEdit({
    required BuildContext context,
    required int jobId,
    required IconData icon,
    required String title,
    required String subtitle,
    Widget? child,
    bool showChildOnly = false,
    bool includePadding = true,
    VoidCallback? onTapOverride,
  }) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      child: InkWell(
        onTap: onTapOverride ?? () => _navigateToEditor(jobId),
        borderRadius: BorderRadius.circular(12.0),
        child: Padding(
          padding: (includePadding && !showChildOnly)
              ? const EdgeInsets.all(16.0)
              : EdgeInsets.zero,
          child: showChildOnly && child != null
              ? child
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Flexible(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Padding(
                                padding: EdgeInsets.only(
                                  top: includePadding ? 0 : 16.0,
                                  left: includePadding ? 0 : 16.0,
                                ),
                                child: Row(
                                  children: [
                                    Icon(icon,
                                        size: 18,
                                        color: theme.colorScheme.primary),
                                    const SizedBox(width: 8),
                                    Flexible(
                                      child: Text(title,
                                          style: theme.textTheme.titleMedium,
                                          overflow: TextOverflow.ellipsis),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(height: 4),
                              Padding(
                                padding: EdgeInsets.only(
                                  left: includePadding ? 26.0 : 42.0,
                                ),
                                child: Text(subtitle,
                                    style: theme.textTheme.bodySmall,
                                    overflow: TextOverflow.ellipsis),
                              ),
                            ],
                          ),
                        ),
                        Padding(
                          padding: const EdgeInsets.only(top: 8.0, right: 8.0),
                          child: IconButton(
                            icon: Icon(Icons.edit_outlined,
                                size: 20, color: theme.colorScheme.primary),
                            tooltip: 'Edit',
                            onPressed:
                                onTapOverride ?? () => _navigateToEditor(jobId),
                            padding: const EdgeInsets.all(8.0),
                            constraints: const BoxConstraints(),
                          ),
                        ),
                      ],
                    ),
                    if (child != null) ...[
                      const Divider(height: 24),
                      Padding(
                        padding: EdgeInsets.symmetric(
                            horizontal: includePadding ? 0 : 16.0),
                        child: child,
                      ),
                      if (!includePadding) const SizedBox(height: 16),
                    ]
                  ],
                ),
        ),
      ),
    );
  }

  // --- Helper: Line Item Summary ---
  Widget _buildLineItemSummary(
      BuildContext context, List<LineItemGroup> groups) {
    if (groups.isEmpty) {
      return const Padding(
        padding: EdgeInsets.only(bottom: 8.0),
        child: Text('No line items added yet.',
            style: TextStyle(fontStyle: FontStyle.italic)),
      );
    }
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8.0),
      child: Column(
        children: groups.map((group) {
          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 4.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Flexible(
                  child: Text(
                    group.name ?? 'Unnamed Group',
                    style: theme.textTheme.bodyMedium
                        ?.copyWith(fontWeight: FontWeight.bold),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                Text(
                  _currencyFormat.format(group.groupTotal),
                  style: theme.textTheme.bodyMedium,
                ),
              ],
            ),
          );
        }).toList(),
      ),
    );
  }
}
