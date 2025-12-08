// lib/screens/result_screen.dart

// ignore_for_file: deprecated_member_use

import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:photo_view/photo_view.dart';
import 'package:printing/printing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_attachment_model.dart';
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/line_item_group.dart';
import 'package:tile_wizard/providers/job_provider.dart';
import 'package:tile_wizard/providers/profile_provider.dart';
import 'package:tile_wizard/providers/template_provider.dart';
import 'package:tile_wizard/screens/advanced_calculator_screen.dart';
import 'package:tile_wizard/screens/client_list_screen.dart';
import 'package:tile_wizard/screens/pdf_preview_screen.dart';
import 'package:tile_wizard/screens/project_editor_screen.dart';
import 'package:tile_wizard/screens/signature_screen.dart';
import 'package:tile_wizard/screens/widgets/add_change_order_dialog.dart';
import 'package:tile_wizard/screens/widgets/add_payment_dialog.dart';
import 'package:tile_wizard/screens/widgets/advanced_materials_results_card.dart';
import 'package:tile_wizard/screens/widgets/app_drawer.dart';
import 'package:tile_wizard/screens/widgets/document_details_card.dart';
import 'package:tile_wizard/screens/widgets/expenses_breakdown_card.dart';
import 'package:tile_wizard/screens/widgets/financial_summary_card.dart';
import 'package:tile_wizard/screens/widgets/material_breakdown_card.dart';
import 'package:tile_wizard/screens/widgets/payments_card.dart';
import 'package:tile_wizard/screens/widgets/pdf_options_card.dart';
import 'package:tile_wizard/screens/widgets/profitability_card.dart';
import 'package:tile_wizard/screens/widgets/tasks_progress_card.dart';
import 'package:tile_wizard/utils/change_order_pdf.dart';
import 'package:tile_wizard/utils/tutorial_helper.dart';
import 'package:uuid/uuid.dart';

enum ResultView { overview, details, attachments }

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

  // --- TUTORIAL KEYS ---
  final GlobalKey _tabsKey = GlobalKey();
  final GlobalKey _financialKey = GlobalKey();
  final GlobalKey _fabKey = GlobalKey();

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

      WidgetsBinding.instance
          .addPostFrameCallback((_) => _checkAndShowTutorial());
    } catch (e) {
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

  Future<void> _checkAndShowTutorial() async {
    final prefs = await SharedPreferences.getInstance();
    final bool hasSeen = prefs.getBool('has_seen_result_tutorial') ?? false;

    if (!hasSeen && mounted) {
      await Future.delayed(const Duration(milliseconds: 500));

      if (!mounted) return;

      TutorialHelper.showResultTutorial(
        context: context,
        tabsKey: _tabsKey,
        financialKey: _financialKey,
        fabKey: _fabKey,
        onFinish: () {
          prefs.setBool('has_seen_result_tutorial', true);
        },
      );
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
    if (!mounted) return;
    context.read<JobProvider>().updateJob(updatedJob);
  }

  // ... [Helpers: _showDueDateOptions, _showExpirationDateOptions, _showEditFinancialDialog, _showAddPaymentDialog, etc.] ...

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

  void _showDeleteJobConfirmation(Job job) async {
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Project?'),
        content: Text(
            'Are you sure you want to permanently delete "${job.projectName ?? 'this project'}"? This cannot be undone.'),
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

    if (confirmed == true && mounted) {
      final jobProvider = context.read<JobProvider>();
      await jobProvider.deleteJob(job.id);
      if (mounted) {
        Navigator.of(context).popUntil((route) => route.isFirst);
      }
    }
  }

  void _showSaveAsTemplateDialog(Job job) {
    final nameController =
        TextEditingController(text: '${job.projectName ?? 'New'} Template');
    final formKey = GlobalKey<FormState>();

    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Save as Template'),
          content: Form(
            key: formKey,
            child: TextFormField(
              controller: nameController,
              decoration: const InputDecoration(labelText: 'Template Name'),
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return 'Please enter a name';
                }
                return null;
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                if (formKey.currentState!.validate()) {
                  final templateName = nameController.text.trim();
                  context
                      .read<TemplateProvider>()
                      .addTemplate(templateName, job);

                  Navigator.pop(context);
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text('"$templateName" saved.'),
                        backgroundColor: Colors.green),
                  );
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );
  }

  void _showEditChangeOrderDialog(Job job, int index) async {
    final originalCo = job.changeOrders![index];
    final dialogResult = await showDialog<ChangeOrderDialogResult>(
      context: context,
      builder: (context) =>
          AddChangeOrderDialog(existingChangeOrder: originalCo),
    );

    if (dialogResult == null || !mounted) return;

    final updatedCo = dialogResult.changeOrder;
    final updatedList = List<ChangeOrder>.from(job.changeOrders ?? []);
    updatedList[index] = updatedCo;
    final updatedJob = job.copyWith(changeOrders: updatedList);

    if (!dialogResult.getSignature) {
      _updateJob(updatedJob);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${updatedCo.title}" updated.'),
            backgroundColor: Colors.grey[700],
          ),
        );
      }
    } else {
      _updateJob(updatedJob);
      await _getSignatureForChangeOrder(updatedJob, updatedCo, index: index);
    }
  }

  void _showAddChangeOrderDialog(Job job) async {
    final dialogResult = await showDialog<ChangeOrderDialogResult>(
      context: context,
      builder: (context) => const AddChangeOrderDialog(),
    );

    if (dialogResult == null || !mounted) return;

    final newChangeOrder = dialogResult.changeOrder;

    if (!dialogResult.getSignature) {
      final updatedChangeOrders = List<ChangeOrder>.from(job.changeOrders ?? [])
        ..add(newChangeOrder);
      _updateJob(job.copyWith(changeOrders: updatedChangeOrders));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${newChangeOrder.title}" saved as draft.'),
            backgroundColor: Colors.grey[700],
          ),
        );
      }
      return;
    }

    await _getSignatureForChangeOrder(job, newChangeOrder);
  }

  Future<void> _getSignatureForChangeOrder(Job job, ChangeOrder changeOrder,
      {int? index}) async {
    if (!mounted) return;

    final profile = context.read<ProfileProvider>().profile;

    // FIX: Safety Check and Bang Operator
    if (profile == null) return;

    final Uint8List pdfData = await generateChangeOrderPdf(
      job,
      changeOrder,
      profile, // Dart now knows this is not null because of the check above
      signatureData: null,
    );

    if (!mounted) return;

    final Uint8List? signatureData = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureScreen(
          documentBytes: pdfData,
          title: changeOrder.title ?? 'Sign Change Order',
        ),
      ),
    );

    if (signatureData != null && mounted) {
      final signedChangeOrder = ChangeOrder(
        title: changeOrder.title,
        description: changeOrder.description,
        amount: changeOrder.amount,
        isTaxable: changeOrder.isTaxable,
        date: changeOrder.date,
        isSigned: true,
      );

      final Uint8List finalPdfData = await generateChangeOrderPdf(
        job,
        signedChangeOrder,
        profile, // Re-use the safe profile
        signatureData: signatureData,
      );

      final String fileName =
          '${signedChangeOrder.title ?? 'Change Order'}.pdf';
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String jobFilesPath = p.join(appDir.path, 'job_files');
      final Directory jobFilesDir = Directory(jobFilesPath);
      if (!await jobFilesDir.exists()) {
        await jobFilesDir.create();
      }
      final String uniqueFileName = '${const Uuid().v4()}_$fileName';
      final String newPath = p.join(jobFilesPath, uniqueFileName);
      final File finalPdfFile = File(newPath);
      await finalPdfFile.writeAsBytes(finalPdfData);

      final pdfAttachment = JobAttachment(
        filePath: newPath,
        description: 'Signed: ${signedChangeOrder.title}',
        type: AttachmentType.pdf,
        created: DateTime.now(),
      );

      final updatedAttachments = List<JobAttachment>.from(job.attachments ?? [])
        ..add(pdfAttachment);

      final updatedChangeOrders =
          List<ChangeOrder>.from(job.changeOrders ?? []);

      if (index != null && index >= 0 && index < updatedChangeOrders.length) {
        updatedChangeOrders[index] = signedChangeOrder;
      } else {
        updatedChangeOrders.add(signedChangeOrder);
      }

      _updateJob(job.copyWith(
        attachments: updatedAttachments,
        changeOrders: updatedChangeOrders,
      ));

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('"${signedChangeOrder.title}" saved and signed.'),
            backgroundColor: Colors.green,
          ),
        );

        setState(() {
          _selectedView = ResultView.attachments;
        });
      }
    }
  }

  void _showDeleteChangeOrderConfirmation(Job job, int index) async {
    final changeOrder = job.changeOrders![index];
    final bool? confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Change Order?'),
        content: Text(
            'Are you sure you want to delete "${changeOrder.title ?? 'this change order'}"? This cannot be undone.'),
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
      final updatedList = List<ChangeOrder>.from(job.changeOrders ?? []);
      updatedList.removeAt(index);
      _updateJob(job.copyWith(changeOrders: updatedList));
    }
  }

  void _showActionsMenu(Job job) {
    final isInvoice = job.isInvoice ?? false;

    showModalBottomSheet(
      context: context,
      builder: (context) {
        return SafeArea(
          child: Wrap(
            children: <Widget>[
              ListTile(
                leading: const Icon(Icons.picture_as_pdf_outlined),
                title: const Text('Preview PDF'),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => PdfPreviewScreen(jobId: job.id),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.copy_outlined),
                title: const Text('Save as Template'),
                onTap: () {
                  Navigator.pop(context);
                  _showSaveAsTemplateDialog(job);
                },
              ),
              ListTile(
                leading: const Icon(Icons.add_box_outlined),
                title: const Text('Add Change Order'),
                onTap: () {
                  Navigator.pop(context);
                  _showAddChangeOrderDialog(job);
                },
              ),
              if (isInvoice)
                ListTile(
                  leading: const Icon(Icons.payment_outlined),
                  title: const Text('Add Payment'),
                  onTap: () {
                    Navigator.pop(context);
                    _showAddPaymentDialog(job);
                  },
                ),
              ListTile(
                leading: isInvoice
                    ? const Icon(Icons.undo_outlined)
                    : const Icon(Icons.receipt_long_outlined),
                title:
                    Text(isInvoice ? 'Revert to Quote' : 'Convert to Invoice'),
                onTap: () {
                  Navigator.pop(context);
                  if (isInvoice) {
                    _updateJob(job.copyWith(isInvoice: false));
                  } else {
                    _convertToInvoice(job);
                  }
                },
              ),
              const Divider(),
              ListTile(
                leading: Icon(Icons.delete_outline,
                    color: Theme.of(context).colorScheme.error),
                title: Text('Delete Project',
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
                onTap: () {
                  Navigator.pop(context);
                  _showDeleteJobConfirmation(job);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  void _convertToInvoice(Job job) {
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
    _updateJob(job.copyWith(isInvoice: true, invoiceNumber: newInvoiceNumber));
  }

  Future<void> _addAttachment(Job job) async {
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['jpg', 'jpeg', 'png', 'pdf'],
    );

    if (result == null || result.files.single.path == null) return;

    final File sourceFile = File(result.files.single.path!);
    final String fileName = result.files.single.name;

    try {
      final Directory appDir = await getApplicationDocumentsDirectory();
      final String jobFilesPath = p.join(appDir.path, 'job_files');
      final Directory jobFilesDir = Directory(jobFilesPath);
      if (!await jobFilesDir.exists()) {
        await jobFilesDir.create();
      }

      final String uniqueFileName = '${const Uuid().v4()}_$fileName';
      final String newPath = p.join(jobFilesPath, uniqueFileName);
      await sourceFile.copy(newPath);

      final attachmentType = fileName.toLowerCase().endsWith('.pdf')
          ? AttachmentType.pdf
          : AttachmentType.image;

      final newAttachment = JobAttachment(
        filePath: newPath,
        description: fileName,
        type: attachmentType,
        created: DateTime.now(),
      );

      final updatedAttachments = List<JobAttachment>.from(job.attachments ?? [])
        ..add(newAttachment);
      _updateJob(job.copyWith(attachments: updatedAttachments));
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Error saving attachment: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _deleteAttachment(Job job, int index) {
    final updatedAttachments = List<JobAttachment>.from(job.attachments ?? []);
    updatedAttachments.removeAt(index);
    _updateJob(job.copyWith(attachments: updatedAttachments));
  }

  Future<void> _openAttachment(JobAttachment attachment) async {
    if (attachment.filePath == null) return;

    File file = File(attachment.filePath!);
    bool exists = await file.exists();

    if (!exists) {
      try {
        final appDir = await getApplicationDocumentsDirectory();
        final fileName = p.basename(attachment.filePath!);
        final fixedPath = p.join(appDir.path, 'job_files', fileName);
        final fixedFile = File(fixedPath);
        if (await fixedFile.exists()) {
          file = fixedFile;
          exists = true;
        }
      } catch (e) {
        // Ignored
      }
    }

    if (!exists) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('File not found. It may have been deleted or moved.'),
            backgroundColor: Colors.red,
            duration: Duration(seconds: 3),
          ),
        );
      }
      return;
    }

    if (!mounted) return;

    if (attachment.type == AttachmentType.image) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(attachment.description ?? 'Image'),
            ),
            body: PhotoView(
              imageProvider: FileImage(file),
              minScale: PhotoViewComputedScale.contained,
              maxScale: PhotoViewComputedScale.covered * 2.0,
            ),
          ),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => Scaffold(
            appBar: AppBar(
              title: Text(attachment.description ?? 'Document'),
            ),
            body: PdfPreview(
              build: (format) => file.readAsBytes(),
              allowPrinting: true,
              allowSharing: true,
              canChangePageFormat: false,
            ),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final Job job;
    try {
      job = context
          .watch<JobProvider>()
          .jobs
          .firstWhere((j) => j.id == widget.jobId);
    } catch (e) {
      return Scaffold(
          appBar: AppBar(title: const Text('Error')),
          body: const Center(child: Text('Job not found.')));
    }
    job.selectedPackage.loadSync();
    if (job.selectedPackage.value != null) {
      final pkg = job.selectedPackage.value!;
      pkg.thinset.loadSync();
      pkg.grout.loadSync();
      pkg.backerboard.loadSync();
      pkg.fasteners.loadSync();
      pkg.wallMembrane.loadSync();
      pkg.floorMembrane.loadSync();
      pkg.leveler.loadSync();
      pkg.clips.loadSync();
    }

    final isInvoice = job.isInvoice ?? false;
    final primaryColor = Theme.of(context).colorScheme.primary;
    final profile = context.watch<ProfileProvider>().profile;

    // FIX: Safe access to isPremium. If null, default to false.
    final isPremium = profile?.isPremium ?? false;

    return Scaffold(
      // ... (Scaffold body/layout)
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
      floatingActionButton: FloatingActionButton(
        key: _fabKey,
        onPressed: () => _showActionsMenu(job),
        tooltip: 'Actions',
        child: const Icon(Icons.more_vert),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0)
            .copyWith(bottom: 96.0),
        child:
            Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Padding(
            padding: const EdgeInsets.only(bottom: 16.0),
            child: Container(
              key: _tabsKey,
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
                  ButtonSegment(
                    value: ResultView.attachments,
                    label: Text('Attachments'),
                    icon: Icon(Icons.attach_file_outlined),
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
          ),
          if (_selectedView == ResultView.overview)
            _buildOverviewColumn(
              context,
              job: job,
              isInvoice: isInvoice,
              primaryColor: primaryColor,
            )
          else if (_selectedView == ResultView.details)
            _buildDetailsColumn(
              context,
              job: job,
              isPremium: isPremium, // Passing safe boolean
              primaryColor: primaryColor,
            )
          else
            _buildAttachmentsTab(
              context,
              job: job,
              primaryColor: primaryColor,
            )
        ]),
      ),
    );
  }

  // ... (Keep remaining build methods: _buildOverviewColumn, _buildDetailsColumn, etc.)
  // I'm keeping them in the output for clarity, but they are unchanged except for receiving the 'isPremium' parameter safely.

  Widget _buildOverviewColumn(
    BuildContext context, {
    required Job job,
    required bool isInvoice,
    required Color primaryColor,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TasksProgressCard(job: job),
        const SizedBox(height: 16),
        FinancialSummaryCard(
          key: _financialKey,
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
        ProfitabilityCard(job: job),
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
                final updatedJob = job.copyWith(clientValue: selectedClient);
                _updateJob(updatedJob);
              }
            }),
        const SizedBox(height: 24),
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
        if (job.changeOrders != null && job.changeOrders!.isNotEmpty) ...[
          _buildChangeOrderSummaryCard(context, job, job.changeOrders!),
          const SizedBox(height: 24),
        ],
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
        ExpensesBreakdownCard(job: job),
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
              subtitle: Text(
                'Est. Internal Cost: ${_currencyFormat.format(job.totalAdvancedMaterialCost)}',
              ),
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

  // ... (Attachments, ReadOnlyCard, LineItemSummary, ChangeOrderSummary)
  // [Include rest of file code here to ensure no brackets are missing]
  Widget _buildAttachmentsTab(
    BuildContext context, {
    required Job job,
    required Color primaryColor,
  }) {
    final attachments = job.attachments ?? [];
    final theme = Theme.of(context);

    return Column(
      children: [
        if (attachments.isEmpty)
          const Center(
            child: Padding(
              padding: EdgeInsets.symmetric(vertical: 48.0),
              child: Text('No attachments found.',
                  style: TextStyle(color: Colors.grey)),
            ),
          ),
        if (attachments.isNotEmpty)
          ListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            itemCount: attachments.length,
            itemBuilder: (context, index) {
              final attachment = attachments[index];
              final icon = attachment.type == AttachmentType.pdf
                  ? Icons.picture_as_pdf_outlined
                  : Icons.image_outlined;

              final bool isSignedChangeOrder =
                  attachment.description?.startsWith('Signed:') ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  leading: Icon(icon, color: theme.colorScheme.secondary),
                  title: Text(
                    attachment.description ?? 'File',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    'Added ${DateFormat.yMd().format(attachment.created ?? DateTime.now())}',
                  ),
                  trailing: isSignedChangeOrder
                      ? null
                      : IconButton(
                          icon: Icon(Icons.delete_outline,
                              color: theme.colorScheme.error),
                          onPressed: () => _deleteAttachment(job, index),
                          tooltip: 'Delete Attachment',
                        ),
                  onTap: () => _openAttachment(attachment),
                ),
              );
            },
          ),
        const SizedBox(height: 16),
        OutlinedButton.icon(
          icon: const Icon(Icons.add_photo_alternate_outlined),
          label: const Text('Add Attachment'),
          onPressed: () => _addAttachment(job),
        ),
      ],
    );
  }

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

  Widget _buildChangeOrderSummaryCard(
      BuildContext context, Job job, List<ChangeOrder> changeOrders) {
    final theme = Theme.of(context);
    return Card(
      elevation: 1.5,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.add_box_outlined,
                    size: 18, color: theme.colorScheme.primary),
                const SizedBox(width: 8),
                Text('Change Orders', style: theme.textTheme.titleMedium),
              ],
            ),
            const Divider(height: 24),
            ...changeOrders.asMap().entries.map((entry) {
              final int index = entry.key;
              final ChangeOrder co = entry.value;

              final bool isSigned = co.isSigned ?? false;
              final iconColor = isSigned ? Colors.green : Colors.grey[600];
              final icon =
                  isSigned ? Icons.check_circle : Icons.radio_button_unchecked;

              return ListTile(
                leading: Icon(icon, color: iconColor),
                title: Text(
                  co.title ?? 'Change Order',
                  style: theme.textTheme.bodyMedium,
                ),
                subtitle: Text(
                  isSigned ? 'Signed' : 'Draft - Tap to sign',
                  style: theme.textTheme.bodySmall
                      ?.copyWith(color: iconColor, fontStyle: FontStyle.italic),
                ),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      _currencyFormat.format(co.amount ?? 0.0),
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                    if (!isSigned) ...[
                      IconButton(
                        icon: Icon(Icons.edit_outlined,
                            color: theme.colorScheme.primary, size: 20),
                        onPressed: () => _showEditChangeOrderDialog(job, index),
                        tooltip: 'Edit Change Order',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      ),
                      IconButton(
                        icon: Icon(Icons.delete_outline,
                            color: theme.colorScheme.error, size: 20),
                        onPressed: () =>
                            _showDeleteChangeOrderConfirmation(job, index),
                        tooltip: 'Delete Change Order',
                        padding: const EdgeInsets.all(4),
                        constraints: const BoxConstraints(),
                      )
                    ] else
                      const SizedBox(width: 48, height: 48),
                  ],
                ),
                onTap: () {
                  if (!isSigned) {
                    _getSignatureForChangeOrder(job, co, index: index);
                  } else {
                    final signedPdf = job.attachments?.firstWhere(
                      (att) => att.description == 'Signed: ${co.title}',
                      orElse: () => JobAttachment(),
                    );
                    if (signedPdf?.filePath != null) {
                      _openAttachment(signedPdf!);
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Signed PDF not found.')),
                      );
                    }
                  }
                },
              );
            })
          ],
        ),
      ),
    );
  }
}
