import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:tile_wizard/screens/profile_screen.dart';
import 'package:tile_wizard/screens/result_screen.dart';
import 'package:tile_wizard/screens/widgets/financial_snapshot_card.dart';
import 'package:tile_wizard/screens/widgets/job_status_badge.dart';
import 'package:tile_wizard/screens/widgets/needs_attention_card.dart';
import 'package:uuid/uuid.dart';
import '../models/client_model.dart';
import '../models/job_model.dart';
import '../providers/job_provider.dart';
import 'project_editor_screen.dart';
import 'client_list_screen.dart';
import 'filtered_jobs_screen.dart';
import 'materials_dashboard_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  void _createNewInvoice(BuildContext context) async {
    final selectedClient = await Navigator.push<Client>(
      context,
      MaterialPageRoute(builder: (_) => const ClientListScreen()),
    );

    if (selectedClient != null && context.mounted) {
      final jobProvider = context.read<JobProvider>();
      final allJobs = jobProvider.jobs;
      int highestInvoiceNumber = 1000;
      if (allJobs.isNotEmpty) {
        highestInvoiceNumber = allJobs
            .map((j) => int.tryParse(j.invoiceNumber ?? '0') ?? 0)
            .where((n) => n > 0)
            .fold(1000, (max, current) => max > current ? max : current);
      }
      final newInvoiceNumber = (highestInvoiceNumber + 1).toString();
      final newJob = Job(
        jobUUID: const Uuid().v4(),
        creationDate: DateTime.now(),
        isInvoice: true,
        invoiceNumber: newInvoiceNumber,
        quoteNumber: '',
        projectName: 'New Invoice',
      );
      final savedJob = await jobProvider.addJob(newJob);
      if (context.mounted) {
        Navigator.push(
          context,
          MaterialPageRoute(
              builder: (context) => ResultScreen(jobId: savedJob.id)),
        );
      }
    }
  }

  Widget _buildNavItem({
    required BuildContext context,
    required IconData icon,
    required String label,
    required VoidCallback onTap,
  }) {
    final primaryColor = Theme.of(context).colorScheme.primary;
    return Expanded(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(8),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: primaryColor, size: 26),
              Text(
                label,
                style: TextStyle(
                  color: primaryColor,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<JobProvider>(
      builder: (context, jobProvider, child) {
        final recentJobs = jobProvider.jobs.take(5).toList();
        final currencyFormat =
            NumberFormat.currency(locale: 'en_US', symbol: '\$');
        final primaryColor = Theme.of(context).colorScheme.primary;

        return Scaffold(
          drawer: Drawer(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                DrawerHeader(
                  decoration: BoxDecoration(color: primaryColor),
                  child: const Text('TileWizard',
                      style: TextStyle(color: Colors.white, fontSize: 24)),
                ),
                ListTile(
                  leading: const Icon(Icons.business),
                  title: const Text('Company Profile'),
                  onTap: () {
                    Navigator.pop(context);
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => const ProfileScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(
                      Icons.inventory_2_outlined), // Choose an appropriate icon
                  title: const Text('Materials Library'),
                  onTap: () {
                    Navigator.pop(context); // Close the drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const MaterialsDashboardScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
          appBar: AppBar(
            title: const Text('Dashboard'),
          ),
          bottomNavigationBar: BottomAppBar(
            elevation: 8,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: <Widget>[
                _buildNavItem(
                  context: context,
                  icon: Icons.calculate_outlined,
                  label: 'New Quote',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ProjectEditorScreen())),
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.receipt_long_outlined,
                  label: 'New Invoice',
                  onTap: () => _createNewInvoice(context),
                ),
                _buildNavItem(
                  context: context,
                  icon: Icons.people_outline,
                  label: 'Clients',
                  onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                          builder: (_) => const ClientListScreen())),
                ),
              ],
            ),
          ),
          body: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SizedBox(
                    height: 150,
                    child: Row(
                      children: [
                        FinancialSnapshotCard(
                          title: 'OUTSTANDING',
                          amount: jobProvider.totalOutstanding,
                          icon: Icons.monetization_on_outlined,
                          color: primaryColor,
                          onTap: () {
                            final outstandingJobs = jobProvider.jobs
                                .where((job) =>
                                    (job.isInvoice ?? false) &&
                                    job.balanceDue > 0.01)
                                .toList();
                            Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => FilteredJobsScreen(
                                        title: 'Outstanding Invoices',
                                        jobs: outstandingJobs)));
                          },
                        ),
                        const SizedBox(width: 16),
                        FinancialSnapshotCard(
                          title: 'OVERDUE',
                          amount: jobProvider.totalOverdue,
                          icon: Icons.warning_amber_rounded,
                          color: Colors.redAccent,
                          onTap: () => Navigator.push(
                              context,
                              MaterialPageRoute(
                                  builder: (_) => FilteredJobsScreen(
                                      title: 'Overdue Invoices',
                                      jobs: jobProvider.overdueJobs))),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  const NeedsAttentionCard(),
                  const Divider(height: 48),
                  Text(
                    'RECENT ACTIVITY',
                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                          color: primaryColor,
                          letterSpacing: 1.2,
                          fontWeight: FontWeight.bold,
                        ),
                  ),
                  const SizedBox(height: 16),
                  if (recentJobs.isEmpty)
                    const Center(
                        child: Padding(
                            padding: EdgeInsets.all(32.0),
                            child: Text('No recent jobs to display.')))
                  else
                    ListView.builder(
                      shrinkWrap: true,
                      physics: const NeverScrollableScrollPhysics(),
                      itemCount: recentJobs.length,
                      itemBuilder: (context, index) {
                        final job = recentJobs[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 8.0),
                          child: ListTile(
                            title: Text(job.projectName ?? 'Untitled Job'),
                            subtitle:
                                Text(job.client.value?.name ?? 'No Client'),
                            trailing: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                JobStatusBadge(status: job.status),
                                const SizedBox(height: 4),
                                Text(currencyFormat.format(job.grandTotal)),
                              ],
                            ),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (context) =>
                                        ResultScreen(jobId: job.id))),
                          ),
                        );
                      },
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
