// lib/screens/result_screen.dart

// ignore_for_file: deprecated_member_use, use_build_context_synchronously, unused_element, no_leading_underscores_for_local_identifiers, unused_local_variable

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
// --- MODELS ---
import 'package:tile_wizard/models/client_model.dart';
import 'package:tile_wizard/models/job_attachment_model.dart';
import 'package:tile_wizard/models/job_model.dart';
import 'package:tile_wizard/models/line_item_group.dart';
import '../models/job_expense_model.dart';
// --- PROVIDERS ---
import 'package:tile_wizard/providers/job_provider.dart';
import 'package:tile_wizard/providers/profile_provider.dart';
import 'package:tile_wizard/providers/settings_provider.dart'; // Ensure Settings is imported
// --- SCREENS ---
import 'package:tile_wizard/screens/advanced_calculator_screen.dart';
import 'package:tile_wizard/screens/client_list_screen.dart';
import 'package:tile_wizard/screens/pdf_preview_screen.dart';
import 'package:tile_wizard/screens/project_editor_screen.dart';
import 'package:tile_wizard/screens/signature_screen.dart';
// --- WIDGETS ---
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
// --- UTILS ---
import 'package:tile_wizard/utils/change_order_pdf.dart';
import 'package:tile_wizard/utils/tutorial_helper.dart';
import 'package:uuid/uuid.dart';

// --- SERVICES ---
import '../services/image_helper.dart';

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
    setState(() {
      // 1. Optimistically update the UI state immediately
      // This stops the "visual snap back" while the DB writes
    });

    // 2. Save to Database
    context.read<JobProvider>().updateJob(updatedJob);
  }

  void _showDueDateOptions(Job job) {
    final baseDate = job.creationDate ?? DateTime.now();
    showModalBottomSheet(
      context: context,
      builder: (context) {
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
      builder: (context) => AddPaymentDialog(job: currentJob),
    );

    if (!mounted || newPayment == null) return;

    final jobProvider = context.read<JobProvider>();

    final updatedPayments = List<Payment>.from(currentJob.payments ?? [])
      ..add(newPayment);
    final updatedJob = currentJob.copyWith(payments: updatedPayments);

    await jobProvider.updateJob(updatedJob);

    if (mounted) {
      setState(() {
        // UI refresh
      });
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
              autofocus: true, // Helpful for UX
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
              onPressed: () async {
                if (formKey.currentState!.validate()) {
                  final templateName = nameController.text.trim();

                  // --- NEW LOGIC: Use JobProvider ---
                  Navigator.pop(context); // Close dialog first

                  await context
                      .read<JobProvider>()
                      .saveJobAsTemplate(job, templateName);

                  // Show success message
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                          content: Text('Template "$templateName" saved!'),
                          backgroundColor: Colors.green),
                    );
                  }
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

  Future<void> _getSignatureForChangeOrder(Job job, dynamic co,
      {int? index}) async {
    if (!mounted) return;

    final profile = context.read<ProfileProvider>().profile;

    if (profile == null) return;

    // Use dynamic 'co' as ChangeOrder
    // Casting manually to avoid type mismatch if needed, but standard dart handles this fine usually.
    // Assuming 'co' has title, description etc.
    // If you have a specific ChangeOrder type, use it. Here I'll assume 'co' is effectively ChangeOrder.

    final Uint8List pdfData = await generateChangeOrderPdf(
      job,
      co,
      profile,
      signatureData: null,
    );

    if (!mounted) return;

    final Uint8List? signatureData = await Navigator.push<Uint8List>(
      context,
      MaterialPageRoute(
        builder: (context) => SignatureScreen(
          job: job, // Pass the Job object
          profile: profile, // Pass the Profile object
          title: 'Sign Completion Cert.',
        ),
      ),
    );

    if (signatureData != null && mounted) {
      final signedChangeOrder =
          co.copyWith(isSigned: true); // Assuming copyWith or construct new

      final Uint8List finalPdfData = await generateChangeOrderPdf(
        job,
        signedChangeOrder,
        profile,
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

        _updateJob(job.copyWith(
          attachments: updatedAttachments, // <--- MAKE SURE THIS IS HERE
          changeOrders: updatedChangeOrders,
        ));
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
    // 1. Ask User: Camera, Gallery, or Document?
    // 1. Ask User: Camera, Gallery, or Document?
    final String? selection = await showModalBottomSheet<String>(
      context: context,
      // DELETE the line that says 'backgroundColor: Colors.white,'
      // This allows it to use your app's dark theme (Grey background, White text)
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text('Take Photo'),
              onTap: () => Navigator.pop(context, 'camera'),
            ),
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text('Choose from Gallery'),
              onTap: () => Navigator.pop(context, 'gallery'),
            ),
            ListTile(
              leading: const Icon(Icons.description),
              title: const Text('Upload Document (PDF)'),
              onTap: () => Navigator.pop(context, 'file'),
            ),
          ],
        ),
      ),
    );

    if (selection == null) return; // User cancelled the bottom sheet

    String? sourcePath;
    String? originalFileName;

    // 2. Get the file based on selection
    if (selection == 'file') {
      // --- EXISTING PDF LOGIC ---
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: [
          'pdf'
        ], // Limit "Documents" to PDFs since photos go via Gallery
      );
      if (result == null || result.files.single.path == null) return;

      sourcePath = result.files.single.path;
      originalFileName = result.files.single.name;
    } else {
      // --- NEW CAMERA/GALLERY LOGIC (With Compression) ---
      final bool isCamera = (selection == 'camera');

      // Use the helper we just created
      sourcePath = await ImageHelper.pickAndSaveImage(
        isCamera: isCamera,
        jobId: job.id.toString(),
      );

      if (sourcePath == null) return; // User cancelled camera/gallery

      // Create a nice name for the file
      final dateStr = DateTime.now().millisecondsSinceEpoch.toString();
      originalFileName = 'photo_$dateStr.jpg';
    }

    // 3. Save to "job_files" (Your existing robust logic)
    try {
      final File sourceFile = File(sourcePath!);

      final Directory appDir = await getApplicationDocumentsDirectory();
      final String jobFilesPath = p.join(appDir.path, 'job_files');
      final Directory jobFilesDir = Directory(jobFilesPath);

      if (!await jobFilesDir.exists()) {
        await jobFilesDir.create();
      }

      // Generate unique name (UUID)
      final String uniqueFileName = '${const Uuid().v4()}_$originalFileName';
      final String newPath = p.join(jobFilesPath, uniqueFileName);

      // Copy the file to the permanent location
      await sourceFile.copy(newPath);

      // Optional: If it was a photo from ImageHelper, we can delete the temp copy
      // to save space, since we just copied it to 'job_files'.
      if (selection != 'file') {
        try {
          await sourceFile.delete();
        } catch (_) {}
      }

      // Determine type
      final attachmentType = originalFileName.toLowerCase().endsWith('.pdf')
          ? AttachmentType.pdf
          : AttachmentType.image;

      // Create Model
      final newAttachment = JobAttachment(
        filePath: newPath,
        description: originalFileName,
        type: attachmentType,
        created: DateTime.now(),
      );

      // Update Isar
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

  Future<void> _deleteAttachment(Job job, int index) async {
    // 1. Grab the attachment details BEFORE we remove it
    final attachmentToDelete = job.attachments![index];

    // 2. Delete the actual file from the phone's storage
    if (attachmentToDelete.filePath != null) {
      try {
        final file = File(attachmentToDelete.filePath!);

        // Check if it exists first to avoid errors
        if (await file.exists()) {
          await file.delete();
        }
      } catch (e) {
        // If the file is already gone or locked, just ignore it and proceed
        // to remove the list item so the user doesn't see a broken link.
        debugPrint("Error deleting file from disk: $e");
      }
    }

    // 3. Update the Database List (Your existing logic)
    final updatedAttachments = List<JobAttachment>.from(job.attachments ?? []);
    updatedAttachments.removeAt(index);

    // Save to Isar
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

    // Links loading
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
    final isPremium = profile?.isPremium ?? false;

    // --- CHECK MEASUREMENT SETTING ---
    final useMetric = context.watch<SettingsProvider>().useMetric;
    final unitLabel = useMetric ? 'm²' : 'sq ft';

    return Scaffold(
      appBar: AppBar(
        title: Text(isInvoice ? 'Invoice Summary' : 'Quote Summary'),
        actions: [
          IconButton(
            icon: const Icon(Icons.edit_note),
            tooltip: 'Edit Project',
            onPressed: () => _navigateToEditor(job.id),
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
              unitLabel: unitLabel, // PASS THE LABEL
            )
          else if (_selectedView == ResultView.details)
            _buildDetailsColumn(
              context,
              job: job,
              isPremium: isPremium,
              primaryColor: primaryColor,
              unitLabel: unitLabel, // PASS THE LABEL
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

  Widget _buildOverviewColumn(
    BuildContext context, {
    required Job job,
    required bool isInvoice,
    required Color primaryColor,
    required String unitLabel,
  }) {
    // Check if the job is empty
    final isJobEmpty = (job.projectRevenue) <= 0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TasksProgressCard(job: job),
        const SizedBox(height: 16),

        // --- THE NEW LOGIC ---
        if (isJobEmpty)
          _buildEmptyStateCard(context, job) // Show the Guide
        else
          FinancialSummaryCard(
            // Show the Data
            key: _financialKey,
            job: job,
            // 1. ADD THIS NEW CALLBACK FOR MATERIALS
            onMaterialTap: () {
              _showMaterialCostDialog(context, job);
            },
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
            onDiscountTap: () => _showDiscountDialog(context, job),
            // 2. UPDATED TAX LOGIC TO INCLUDE TEXAS TOGGLE
            onTaxTap: () {
              final taxController =
                  TextEditingController(text: job.taxRate?.toString() ?? '0');
              // Use a local variable to hold the toggle state inside the dialog
              bool tempTaxMaterialsOnly = job.taxMaterialsOnly ?? false;

              showDialog(
                  context: context,
                  builder: (context) =>
                      StatefulBuilder(builder: (context, setStateDialog) {
                        return AlertDialog(
                          title: const Text('Edit Tax Settings'),
                          content: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              TextFormField(
                                controller: taxController,
                                decoration: const InputDecoration(
                                    labelText: 'Rate (%)'),
                                keyboardType:
                                    const TextInputType.numberWithOptions(
                                        decimal: true),
                              ),
                              const SizedBox(height: 16),
                              SwitchListTile(
                                title: const Text("Tax Materials Only?"),
                                subtitle: const Text(
                                    "Enable for labor-free tax rules (e.g. Texas)"),
                                value: tempTaxMaterialsOnly,
                                activeColor: Colors.green, // Visual feedback
                                contentPadding: EdgeInsets.zero,
                                onChanged: (val) {
                                  setStateDialog(
                                      () => tempTaxMaterialsOnly = val);
                                },
                              ),
                            ],
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
                                    _updateJob(job.copyWith(
                                      taxRate: newRate,
                                      taxMaterialsOnly: tempTaxMaterialsOnly,
                                    ));
                                    Navigator.pop(context);
                                  }
                                },
                                child: const Text('Save')),
                          ],
                        );
                      }));
            },
          ),
        const SizedBox(height: 24),
        ProfitabilityCard(
          job: job,
          onExpensesTap: () => _showExpensesDialog(context, job),
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
            onShowGroupTotalsChanged: (val) =>
                _updateJob(job..showGroupTotals = val),
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
    required String unitLabel,
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
          // Use dynamic label here
          subtitle: '${job.totalArea.toStringAsFixed(1)} $unitLabel total',
          child: MaterialBreakdownCard(job: job),
          includePadding: false,
        ),
        const SizedBox(height: 24),

        // --- ADVANCED CALCULATOR ---
        Card(
          elevation: 2,
          color: Theme.of(context)
              .colorScheme
              .primaryContainer
              .withValues(alpha: 0.1),
          shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: BorderSide(color: primaryColor.withValues(alpha: 0.5))),
          child: Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.science_outlined, color: primaryColor),
                        const SizedBox(width: 8),
                        Text('Advanced Materials',
                            style: TextStyle(
                                color: primaryColor,
                                fontWeight: FontWeight.bold,
                                fontSize: 16)),
                      ],
                    ),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: primaryColor,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                      ),
                      icon: const Icon(Icons.settings_suggest, size: 16),
                      label: const Text('Configure'),
                      onPressed: () {
                        // Navigate to calculator
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                              builder: (_) =>
                                  AdvancedCalculatorScreen(jobId: job.id)),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  'Select packages and settings to calculate precise material needs.',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const Divider(height: 24),
                // Show results
                AdvancedMaterialsResultsCard(job: job),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),
        ExpensesBreakdownCard(job: job),
        const SizedBox(height: 24),
      ],
    );
  }

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

// 1. Determine what to show on the left
              Widget leadingWidget;

              if (attachment.type == AttachmentType.image &&
                  attachment.filePath != null) {
                // If it's a photo, show a tiny preview
                leadingWidget = ClipRRect(
                  borderRadius:
                      BorderRadius.circular(8.0), // Nice rounded corners
                  child: Image.file(
                    File(attachment.filePath!),
                    width: 50, // Square thumbnail
                    height: 50,
                    fit: BoxFit.cover, // Fill the square

                    // OPTIMIZATION: This prevents memory bloat!
                    // It tells Flutter to only decode a tiny version for the UI.
                    cacheWidth: 100,

                    // Fallback if the file is missing
                    errorBuilder: (ctx, err, stack) => Icon(Icons.broken_image,
                        color: theme.colorScheme.error),
                  ),
                );
              } else {
                // If it's a PDF or other file, keep the old Icon
                leadingWidget = Icon(
                  attachment.type == AttachmentType.pdf
                      ? Icons.picture_as_pdf_outlined
                      : Icons.insert_drive_file_outlined,
                  color: theme.colorScheme.secondary,
                  size: 32, // Match the visual weight of the image
                );
              }

              final bool isSignedChangeOrder =
                  attachment.description?.startsWith('Signed:') ?? false;

              return Card(
                margin: const EdgeInsets.only(bottom: 8.0),
                child: ListTile(
                  // 2. Use our new widget here
                  leading: SizedBox(
                      width: 50,
                      height: 50,
                      child: Center(child: leadingWidget)),
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

  Widget _buildEmptyStateCard(BuildContext context, Job job) {
    return Card(
      elevation: 0, // Flat look
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey.shade300),
      ),
      color: Colors.grey.shade50, // Slight off-white background
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 32.0, horizontal: 16),
        child: Column(
          children: [
            Icon(Icons.post_add, size: 48, color: Colors.grey.shade400),
            const SizedBox(height: 16),
            const Text(
              "Start Your Invoice",
              style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black54),
            ),
            const SizedBox(height: 8),
            const Text(
              "Add a service or item to calculate the total.",
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            FilledButton.icon(
              onPressed: () => _showQuickAddItemDialog(context, job),
              icon: const Icon(Icons.add),
              label: const Text("Add Line Item"),
              style: FilledButton.styleFrom(
                padding:
                    const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showMaterialCostDialog(BuildContext context, Job job) {
    final _costController = TextEditingController(
        text: job.additionalMaterialCost?.toStringAsFixed(2) ?? '');
    showDialog(
        context: context,
        builder: (ctx) => AlertDialog(
              title: const Text("Additional Materials"),
              content: TextField(
                controller: _costController,
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration:
                    const InputDecoration(labelText: "Cost", prefixText: "\$"),
              ),
              actions: [
                TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text("Cancel")),
                FilledButton(
                    onPressed: () {
                      final cost = double.tryParse(_costController.text) ?? 0.0;
                      _updateJob(job..additionalMaterialCost = cost);
                      Navigator.pop(ctx);
                    },
                    child: const Text("Save"))
              ],
            ));
  }

  void _showExpensesDialog(BuildContext context, Job job) {
    // Controllers for inputs
    final titleController = TextEditingController();
    final amountController = TextEditingController();

    // Default category state
    ExpenseCategory selectedCategory = ExpenseCategory.material;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          // Get current expenses
          final expenses = job.expenses?.toList() ?? [];

          return AlertDialog(
            title: const Text("Manage Expenses"),
            content: SizedBox(
              width: double.maxFinite,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- 1. EXPENSE LIST ---
                  if (expenses.isEmpty)
                    const Padding(
                      padding: EdgeInsets.all(16.0),
                      child: Center(
                        child: Text("No expenses yet.",
                            style: TextStyle(
                                fontStyle: FontStyle.italic,
                                color: Colors.grey)),
                      ),
                    )
                  else
                    Flexible(
                      child: Container(
                        constraints: const BoxConstraints(
                            maxHeight: 200), // Limit height
                        child: ListView.separated(
                          shrinkWrap: true,
                          itemCount: expenses.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (context, index) {
                            final exp = expenses[index];
                            return ListTile(
                              dense: true,
                              contentPadding: EdgeInsets.zero,
                              title: Text(exp.title ?? "Expense",
                                  style: const TextStyle(
                                      fontWeight: FontWeight.bold)),
                              subtitle: Text(exp.category.displayName,
                                  style: const TextStyle(fontSize: 10)),
                              trailing: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                      "\$${(exp.amount ?? 0).toStringAsFixed(2)}"),
                                  IconButton(
                                    icon: const Icon(Icons.delete,
                                        color: Colors.redAccent, size: 20),
                                    onPressed: () {
                                      expenses.removeAt(index);
                                      _updateJob(job..expenses = expenses);
                                      setStateDialog(() {}); // Refresh list
                                    },
                                  )
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                    ),

                  const Divider(thickness: 2),

                  // --- 2. ADD NEW FORM ---
                  const Text("Add New Expense",
                      style:
                          TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                  const SizedBox(height: 8),

                  // Row 1: Title & Amount
                  Row(
                    children: [
                      Expanded(
                        flex: 2,
                        child: TextField(
                          controller: titleController,
                          decoration: const InputDecoration(
                            labelText: "Description",
                            hintText: "e.g. Dumpster",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        flex: 1,
                        child: TextField(
                          controller: amountController,
                          keyboardType: const TextInputType.numberWithOptions(
                              decimal: true),
                          decoration: const InputDecoration(
                            labelText: "Cost",
                            prefixText: "\$",
                            isDense: true,
                            border: OutlineInputBorder(),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Row 2: Category Dropdown & Add Button
                  Row(
                    crossAxisAlignment: CrossAxisAlignment
                        .start, // Helps align the button with the input field
                    children: [
                      Expanded(
                        // FIX: Use DropdownButtonFormField directly.
                        // It handles the label animation and border gap automatically.
                        child: DropdownButtonFormField<ExpenseCategory>(
                          value: selectedCategory,
                          isExpanded: true, // Ensures text doesn't overflow
                          decoration: const InputDecoration(
                            labelText: "Category",
                            isDense: true,
                            border: OutlineInputBorder(),
                            // Slight vertical padding adjustment usually looks best with outlines
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 10, vertical: 12),
                          ),
                          items: ExpenseCategory.values.map((cat) {
                            return DropdownMenuItem(
                              value: cat,
                              child: Text(cat.displayName,
                                  style: const TextStyle(fontSize: 13)),
                            );
                          }).toList(),
                          onChanged: (val) {
                            if (val != null) {
                              setStateDialog(() => selectedCategory = val);
                            }
                          },
                        ),
                      ),
                      const SizedBox(width: 8),
                      // Wrapped the button in Padding to align perfectly with the input field
                      Padding(
                        padding: const EdgeInsets.only(top: 2.0),
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.green,
                            minimumSize:
                                const Size(0, 48), // Match default input height
                          ),
                          icon: const Icon(Icons.add, size: 16),
                          label: const Text("Add"),
                          onPressed: () {
                            final title = titleController.text;
                            final amount =
                                double.tryParse(amountController.text);

                            if (title.isNotEmpty && amount != null) {
                              final newExpense = JobExpense(
                                title: title,
                                amount: amount,
                                category: selectedCategory,
                                date: DateTime.now(),
                              );

                              expenses.add(newExpense);

                              _updateJob(job..expenses = expenses);

                              titleController.clear();
                              amountController.clear();
                              setStateDialog(() {});
                            }
                          },
                        ),
                      ), // End of Padding
                    ],
                  ), // End of Row (Category & Button)
                ], // 1. Close Column children
              ), // 2. Close Column
            ), // 3. Close SizedBox (content)

            // 4. Now we are back in AlertDialog, so actions works!
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Close"),
              ),
            ],
          ); // Close AlertDialog
        },
      ), // Close StatefulBuilder
    ); // Close showDialog
  }

  void _showQuickAddItemDialog(BuildContext context, Job job) {
    final descController = TextEditingController();
    final priceController = TextEditingController();

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Add Line Item"),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: descController,
              decoration: const InputDecoration(
                labelText: "Description",
                hintText: "e.g. Service Call / Labor",
                border: OutlineInputBorder(),
              ),
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
            ),
            const SizedBox(height: 12),
            TextField(
              controller: priceController,
              decoration: const InputDecoration(
                labelText: "Price",
                prefixText: "\$",
                border: OutlineInputBorder(),
              ),
              keyboardType:
                  const TextInputType.numberWithOptions(decimal: true),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("Cancel"),
          ),
          FilledButton(
            onPressed: () {
              final desc = descController.text.trim();
              final price = double.tryParse(priceController.text);

              if (desc.isNotEmpty && price != null) {
                // 1. Get existing groups or create new list
                final currentGroups = job.itemGroups?.toList() ?? [];

                // 2. Find "Services" group by Name (since IDs don't exist/matter here)
                LineItemGroup? targetGroup;
                int groupIndex = -1;

                try {
                  // Look for a group named "Services"
                  targetGroup =
                      currentGroups.firstWhere((g) => g.name == "Services");
                  groupIndex = currentGroups.indexOf(targetGroup);
                } catch (e) {
                  targetGroup = null;
                }

                // 3. Create the new Item using your CustomLineItem model
                final newItem = CustomLineItem(
                  description: desc,
                  quantity: 1.0,
                  rate: price, // 'rate' acts as price
                  unit: 'EA',
                  isTaxable: true,
                  activity: ActivityType.supplyAndInstall,
                );

                // 4. Add item to the group
                if (targetGroup != null) {
                  // Add to existing group
                  final currentItems = targetGroup.items?.toList() ?? [];
                  currentItems.add(newItem);

                  // Update the group's items
                  targetGroup.items = currentItems;

                  // Update the group in the main list
                  if (groupIndex != -1) {
                    currentGroups[groupIndex] = targetGroup;
                  }
                } else {
                  // Create NEW group if it doesn't exist
                  // NOTE: I am assuming your LineItemGroup constructor looks like this.
                  // If it requires other fields, let me know!
                  final newGroup = LineItemGroup(
                    name: "Services",
                    items: [newItem],
                    // type: AreaType.other, // Uncomment if your group requires a type
                  );
                  currentGroups.add(newGroup);
                }

                // 5. Save the Job
                _updateJob(job.copyWith(itemGroups: currentGroups));

                Navigator.pop(ctx);
              }
            },
            child: const Text("Add Item"),
          ),
        ],
      ),
    );
  }

  // --- ADD THIS NEW FUNCTION ---
  void _showDiscountDialog(BuildContext context, Job job) {
    final nameController = TextEditingController(text: job.discountName ?? "");
    final valueController = TextEditingController(
      text: (job.discountValue ?? 0).toString(),
    );
    FinancialType currentType = job.discountType;

    showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Add Discount"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: nameController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    labelText: "Discount Name",
                    hintText: "e.g. Winter Special",
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.label_outline),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  children: [
                    Expanded(
                      child: SegmentedButton<FinancialType>(
                        segments: const [
                          ButtonSegment(
                              value: FinancialType.percentage,
                              label: Text("%")),
                          ButtonSegment(
                              value: FinancialType.dollar, label: Text("\$")),
                        ],
                        selected: {currentType},
                        onSelectionChanged: (Set<FinancialType> newSelection) {
                          setStateDialog(() {
                            currentType = newSelection.first;
                          });
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: valueController,
                  keyboardType:
                      const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    labelText: "Value",
                    prefixText:
                        currentType == FinancialType.dollar ? "\$ " : null,
                    suffixText:
                        currentType == FinancialType.percentage ? "%" : null,
                    border: const OutlineInputBorder(),
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel"),
              ),
              FilledButton(
                onPressed: () {
                  final val = double.tryParse(valueController.text) ?? 0.0;
                  final name = nameController.text.trim();

                  // This saves it to the database
                  _updateJob(job.copyWith(
                    discountType: currentType,
                    discountValue: val,
                    discountName: name.isEmpty ? null : name,
                  ));

                  Navigator.pop(ctx);
                },
                child: const Text("Apply"),
              ),
            ],
          );
        },
      ),
    );
  }
}
