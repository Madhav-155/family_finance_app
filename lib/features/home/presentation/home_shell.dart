import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import '../../../core/time/ist_time.dart';
import '../../../core/theme/app_theme.dart';
import '../../onboarding/application/setup_controller.dart';
import '../../../l10n/app_strings.dart';
import '../../../services/notification_service.dart';
import '../../../shared/domain/finance_models.dart';
import '../../../shared/providers/app_providers.dart';
import '../../../sync/google_sheets_sync_service.dart';
import '../../../sync/sync_contracts.dart';

enum EntryKind { expense, income, emi, budget }

class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key});

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  int _index = 0;

  @override
  Widget build(BuildContext context) {
    final strings = AppStrings.of(context);
    final titles = [
      strings.text('dashboard'),
      strings.text('transactions'),
      strings.text('emis'),
      strings.text('reports'),
      strings.text('settings'),
    ];
    const pages = [
      DashboardPage(),
      TransactionsPage(),
      EmiPage(),
      ReportsPage(),
      SettingsPage(),
    ];
    return Scaffold(
      appBar: AppBar(
        title: Text(titles[_index]),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: () => ref.read(financeProvider.notifier).refresh(),
            icon: const Icon(LucideIcons.refreshCw),
          ),
        ],
      ),
      body: SafeArea(
        child: IndexedStack(index: _index, children: pages),
      ),
      floatingActionButton: _index < 3
          ? FloatingActionButton.extended(
              onPressed: () => showEntrySheet(
                context,
                ref,
                _index == 2 ? EntryKind.emi : EntryKind.expense,
              ),
              icon: const Icon(LucideIcons.plus),
              label: Text(_index == 2 ? 'Add EMI' : strings.text('addExpense')),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (value) => setState(() => _index = value),
        destinations: [
          NavigationDestination(
            icon: const Icon(LucideIcons.layoutDashboard),
            label: strings.text('home'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.receiptText),
            label: strings.text('history'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.calendarClock),
            label: strings.text('emis'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.chartPie),
            label: strings.text('reports'),
          ),
          NavigationDestination(
            icon: const Icon(LucideIcons.settings),
            label: strings.text('settings'),
          ),
        ],
      ),
    );
  }
}

class DashboardPage extends ConsumerWidget {
  const DashboardPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final strings = AppStrings.of(context);
    return ref
        .watch(financeProvider)
        .when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (error, stack) => ErrorState(
            message: '$error',
            retry: () => ref.read(financeProvider.notifier).refresh(),
          ),
          data: (snapshot) => RefreshIndicator(
            onRefresh: () => ref.read(financeProvider.notifier).refresh(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
              children: [
                Semantics(
                  label:
                      '${strings.text('moneyLeft')}: ${formatMoney(snapshot.moneyLeft)}',
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF087F5B), Color(0xFF20C997)],
                      ),
                      borderRadius: BorderRadius.circular(28),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          strings.text('moneyLeft'),
                          style: const TextStyle(color: Colors.white70),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          formatMoney(snapshot.moneyLeft),
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w800,
                              ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                GridView.count(
                  crossAxisCount: 2,
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.65,
                  children: [
                    SummaryCard(
                      title: strings.text('income'),
                      value: snapshot.monthlyIncome,
                      color: AppTheme.incomeBlue,
                      icon: LucideIcons.walletCards,
                    ),
                    SummaryCard(
                      title: strings.text('expenses'),
                      value: snapshot.monthlyExpenses,
                      color: AppTheme.softRed,
                      icon: LucideIcons.shoppingCart,
                    ),
                    SummaryCard(
                      title: strings.text('emiDue'),
                      value: snapshot.emiDue,
                      color: AppTheme.amber,
                      icon: LucideIcons.calendarClock,
                    ),
                    SummaryCard(
                      title: 'Saved',
                      value: snapshot.moneyLeft > 0 ? snapshot.moneyLeft : 0,
                      color: AppTheme.emerald,
                      icon: LucideIcons.piggyBank,
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  'Quick actions',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    ActionChip(
                      avatar: const Icon(LucideIcons.minus, size: 18),
                      label: Text(strings.text('addExpense')),
                      onPressed: () =>
                          showEntrySheet(context, ref, EntryKind.expense),
                    ),
                    ActionChip(
                      avatar: const Icon(LucideIcons.plus, size: 18),
                      label: Text(strings.text('addIncome')),
                      onPressed: () =>
                          showEntrySheet(context, ref, EntryKind.income),
                    ),
                    ActionChip(
                      avatar: const Icon(LucideIcons.landmark, size: 18),
                      label: const Text('Set budget'),
                      onPressed: () =>
                          showEntrySheet(context, ref, EntryKind.budget),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
                Text(
                  "Today's expenses",
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 8),
                ...snapshot.expenses
                    .where(
                      (item) => !item.deleted && IstTime.isToday(item.date),
                    )
                    .take(5)
                    .map((item) => ExpenseTile(expense: item)),
                if (!snapshot.expenses.any(
                  (item) => !item.deleted && IstTime.isToday(item.date),
                ))
                  EmptyState(message: strings.text('noActivity')),
              ],
            ),
          ),
        );
  }
}

class SummaryCard extends StatelessWidget {
  const SummaryCard({
    super.key,
    required this.title,
    required this.value,
    required this.color,
    required this.icon,
  });

  final String title;
  final int value;
  final Color color;
  final IconData icon;

  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(14),
      child: Row(
        children: [
          CircleAvatar(
            backgroundColor: color.withValues(alpha: .12),
            foregroundColor: color,
            child: Icon(icon, size: 20),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, maxLines: 1, overflow: TextOverflow.ellipsis),
                Text(
                  formatMoney(value),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}

class TransactionsPage extends ConsumerStatefulWidget {
  const TransactionsPage({super.key});

  @override
  ConsumerState<TransactionsPage> createState() => _TransactionsPageState();
}

class _TransactionsPageState extends ConsumerState<TransactionsPage> {
  bool expenses = true;

  @override
  Widget build(BuildContext context) => ref
      .watch(financeProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: '$error',
          retry: () => ref.read(financeProvider.notifier).refresh(),
        ),
        data: (snapshot) {
          final items = expenses
              ? snapshot.expenses.where((item) => !item.deleted).toList()
              : snapshot.income.where((item) => !item.deleted).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
            children: [
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('Expenses')),
                  ButtonSegment(value: false, label: Text('Income')),
                ],
                selected: {expenses},
                onSelectionChanged: (value) =>
                    setState(() => expenses = value.first),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showEntrySheet(context, ref, EntryKind.income),
                      icon: const Icon(LucideIcons.badgeIndianRupee),
                      label: const Text('Add income'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () =>
                          showEntrySheet(context, ref, EntryKind.budget),
                      icon: const Icon(LucideIcons.gauge),
                      label: const Text('Set budget'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              if (items.isEmpty)
                const EmptyState(message: 'No transactions yet')
              else if (expenses)
                ...snapshot.expenses
                    .where((item) => !item.deleted)
                    .map((item) => ExpenseTile(expense: item))
              else
                ...snapshot.income
                    .where((item) => !item.deleted)
                    .map((item) => IncomeTile(income: item)),
              const SizedBox(height: 24),
              Text(
                'Monthly budgets',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 8),
              ...snapshot.budgets.where((item) => !item.deleted).map((budget) {
                final spent = snapshot.categoryTotals[budget.category] ?? 0;
                final progress = budget.limitMinor == 0
                    ? 0.0
                    : spent / budget.limitMinor;
                return Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Expanded(child: Text(budget.category)),
                            Text(
                              '${formatMoney(spent)} / ${formatMoney(budget.limitMinor)}',
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        LinearProgressIndicator(
                          value: progress.clamp(0, 1),
                          color: progress > 1
                              ? AppTheme.softRed
                              : AppTheme.emerald,
                        ),
                      ],
                    ),
                  ),
                );
              }),
            ],
          );
        },
      );
}

class ExpenseTile extends ConsumerWidget {
  const ExpenseTile({super.key, required this.expense});

  final Expense expense;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
    key: ValueKey(expense.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) =>
        ref.read(financeProvider.notifier).deleteExpense(expense),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Icon(LucideIcons.trash2),
    ),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(LucideIcons.receipt)),
      title: Text(expense.category),
      subtitle: Text(
        '${DateFormat.MMMd().format(expense.date)} • ${expense.paymentMode}'
        '${expense.notes.isEmpty ? '' : ' • ${expense.notes}'}',
      ),
      trailing: Text(
        '-${formatMoney(expense.amountMinor)}',
        style: const TextStyle(
          color: AppTheme.softRed,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class IncomeTile extends ConsumerWidget {
  const IncomeTile({super.key, required this.income});

  final IncomeEntry income;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Dismissible(
    key: ValueKey(income.id),
    direction: DismissDirection.endToStart,
    onDismissed: (_) => ref.read(financeProvider.notifier).deleteIncome(income),
    background: Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      color: Theme.of(context).colorScheme.errorContainer,
      child: const Icon(LucideIcons.trash2),
    ),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const CircleAvatar(child: Icon(LucideIcons.wallet)),
      title: Text(income.source),
      subtitle: Text(DateFormat.yMMMd().format(income.receivedDate)),
      trailing: Text(
        '+${formatMoney(income.amountMinor)}',
        style: const TextStyle(
          color: AppTheme.emerald,
          fontWeight: FontWeight.w700,
        ),
      ),
    ),
  );
}

class EmiPage extends ConsumerWidget {
  const EmiPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(financeProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: '$error',
          retry: () => ref.read(financeProvider.notifier).refresh(),
        ),
        data: (snapshot) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    const Icon(
                      LucideIcons.calendarClock,
                      color: AppTheme.amber,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text('Due this month'),
                          Text(
                            formatMoney(snapshot.emiDue),
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            if (snapshot.emis.where((item) => !item.deleted).isEmpty)
              const EmptyState(message: 'No EMIs scheduled')
            else
              ...snapshot.emis
                  .where((item) => !item.deleted)
                  .map(
                    (emi) => Card(
                      child: ListTile(
                        leading: Icon(
                          emi.paid
                              ? LucideIcons.circleCheck
                              : LucideIcons.clock3,
                          color: emi.paid ? AppTheme.emerald : AppTheme.amber,
                        ),
                        title: Text(emi.loanName),
                        subtitle: Text(
                          'Due ${DateFormat.yMMMd().format(emi.dueDate)}',
                        ),
                        trailing: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              formatMoney(emi.amountMinor),
                              style: const TextStyle(
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                            if (!emi.paid)
                              TextButton(
                                onPressed: () => ref
                                    .read(financeProvider.notifier)
                                    .markEmiPaid(emi),
                                child: const Text('Mark paid'),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
          ],
        ),
      );
}

class ReportsPage extends ConsumerWidget {
  const ReportsPage({super.key});

  static const colors = [
    AppTheme.emerald,
    AppTheme.purple,
    AppTheme.amber,
    AppTheme.softRed,
    AppTheme.incomeBlue,
    Colors.teal,
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) => ref
      .watch(financeProvider)
      .when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stack) => ErrorState(
          message: '$error',
          retry: () => ref.read(financeProvider.notifier).refresh(),
        ),
        data: (snapshot) {
          final categories = snapshot.categoryTotals.entries.toList();
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                'Monthly cash flow',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    children: [
                      ReportRow(
                        label: 'Income',
                        amount: snapshot.monthlyIncome,
                        color: AppTheme.incomeBlue,
                      ),
                      ReportRow(
                        label: 'Expenses',
                        amount: snapshot.monthlyExpenses,
                        color: AppTheme.softRed,
                      ),
                      ReportRow(
                        label: 'EMIs due',
                        amount: snapshot.emiDue,
                        color: AppTheme.amber,
                      ),
                      const Divider(),
                      ReportRow(
                        label: 'Net cash',
                        amount: snapshot.moneyLeft,
                        color: AppTheme.emerald,
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Text(
                'Spending by category',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 12),
              if (categories.isEmpty)
                const EmptyState(message: 'Add expenses to see analytics')
              else
                SizedBox(
                  height: 280,
                  child: Semantics(
                    label: 'Expense category pie chart',
                    child: PieChart(
                      PieChartData(
                        centerSpaceRadius: 44,
                        sectionsSpace: 3,
                        sections: [
                          for (var i = 0; i < categories.length; i++)
                            PieChartSectionData(
                              value: categories[i].value.toDouble(),
                              title: categories[i].key,
                              radius: 72,
                              color: colors[i % colors.length],
                              titleStyle: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      );
}

class ReportRow extends StatelessWidget {
  const ReportRow({
    super.key,
    required this.label,
    required this.amount,
    required this.color,
  });

  final String label;
  final int amount;
  final Color color;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 8),
    child: Row(
      children: [
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Expanded(child: Text(label)),
        Text(
          formatMoney(amount),
          style: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class SettingsPage extends ConsumerWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final settings = ref.watch(appSettingsProvider);
    final sync = ref.watch(syncServiceProvider);
    final setup = ref.watch(householdSetupProvider).value;
    final setupRecord = setup?.record;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 40),
      children: [
        Text('Appearance', style: Theme.of(context).textTheme.titleLarge),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(LucideIcons.moon),
          title: const Text('Dark theme'),
          value: settings.themeMode == ThemeMode.dark,
          onChanged: ref.read(appSettingsProvider.notifier).toggleDarkMode,
        ),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          secondary: const Icon(LucideIcons.accessibility),
          title: const Text('Larger text'),
          value: settings.largeText,
          onChanged: ref.read(appSettingsProvider.notifier).toggleLargeText,
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.languages),
          title: const Text('Language'),
          trailing: DropdownButton<String>(
            value: settings.locale.languageCode,
            items: const [
              DropdownMenuItem(value: 'en', child: Text('English')),
              DropdownMenuItem(value: 'te', child: Text('తెలుగు')),
            ],
            onChanged: (value) {
              if (value != null) {
                ref.read(appSettingsProvider.notifier).setLocale(value);
              }
            },
          ),
        ),
        const Divider(height: 32),
        Text('Family sync', style: Theme.of(context).textTheme.titleLarge),
        StreamBuilder<SyncStatus>(
          stream: sync.statuses,
          initialData: sync.status,
          builder: (context, snapshot) {
            final status = snapshot.data ?? const SyncStatus();
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: const CircleAvatar(
                        child: Icon(LucideIcons.cloud),
                      ),
                      title: Text(status.signedInEmail ?? 'Google Drive'),
                      subtitle: Text(
                        status.message ??
                            setup?.syncHealth ??
                            (status.lastSyncedAt == null
                                ? 'Not synced'
                                : 'Synced ${IstTime.formatInstant(status.lastSyncedAt!)} IST'),
                      ),
                    ),
                    Row(
                      children: [
                        Expanded(
                          child: FilledButton.icon(
                            onPressed: status.syncing
                                ? null
                                : () => _run(context, ref, () async {
                                    await sync.syncNow(setup: setupRecord);
                                    await ref
                                        .read(financeProvider.notifier)
                                        .refresh();
                                  }),
                            icon: status.syncing
                                ? const SizedBox.square(
                                    dimension: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(LucideIcons.refreshCw),
                            label: const Text('Sync now'),
                          ),
                        ),
                        const SizedBox(width: 8),
                        IconButton.filledTonal(
                          tooltip: 'Invite family member',
                          onPressed:
                              setupRecord?.role == HouseholdSetupRole.owner
                              ? () => _invite(context, ref, sync)
                              : null,
                          icon: const Icon(LucideIcons.userPlus),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Roles are enforced in the app. Anyone with direct edit '
                      'access to the Sheet can alter its data.',
                      style: TextStyle(fontSize: 12),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
        const Divider(height: 32),
        Text('Backup & restore', style: Theme.of(context).textTheme.titleLarge),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.fileLock2),
          title: const Text('Create encrypted backup'),
          subtitle: const Text('Export and share a password-protected copy'),
          onTap: () => _run(
            context,
            ref,
            ref.read(backupServiceProvider).createAndShareBackup,
          ),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.history),
          title: const Text('Restore latest local backup'),
          onTap: () => _run(context, ref, () async {
            await ref.read(backupServiceProvider).restoreLatestBackup();
            await ref.read(financeProvider.notifier).refresh();
          }),
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(LucideIcons.unplug),
          title: const Text('Reconnect or change household'),
          subtitle: const Text(
            'Locks finance screens until Google setup succeeds again',
          ),
          onTap: () => ref.read(householdSetupProvider.notifier).reset(),
        ),
        const Divider(height: 32),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: CircleAvatar(
            child: Icon(
              setupRecord?.role == HouseholdSetupRole.owner
                  ? LucideIcons.crown
                  : LucideIcons.user,
            ),
          ),
          title: Text(
            setupRecord?.role == HouseholdSetupRole.owner
                ? 'Family Owner'
                : 'Family Member',
          ),
          subtitle: Text(setupRecord?.email ?? 'Local profile'),
        ),
      ],
    );
  }

  Future<void> _run(
    BuildContext context,
    WidgetRef ref,
    Future<void> Function() action,
  ) async {
    try {
      await action();
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Completed successfully')));
      }
    } on Object catch (error) {
      final failure = SyncFailure.from(error, operation: 'app action');
      if (failure.invalidatesCompletedSetup) {
        await ref
            .read(householdSetupProvider.notifier)
            .lockAfterRevocation(failure);
      }
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(failure.userMessage)));
      }
    }
  }

  Future<void> _invite(
    BuildContext context,
    WidgetRef ref,
    GoogleSheetsSyncService sync,
  ) async {
    final controller = TextEditingController();
    final email = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Invite family member'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Google email'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, controller.text.trim()),
            child: const Text('Invite'),
          ),
        ],
      ),
    );
    if (email != null && email.contains('@') && context.mounted) {
      await _run(context, ref, () => sync.shareWith(email));
    }
  }
}

Future<void> showEntrySheet(
  BuildContext context,
  WidgetRef ref,
  EntryKind kind,
) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  builder: (context) => EntryForm(kind: kind),
);

class EntryForm extends ConsumerStatefulWidget {
  const EntryForm({super.key, required this.kind});

  final EntryKind kind;

  @override
  ConsumerState<EntryForm> createState() => _EntryFormState();
}

class _EntryFormState extends ConsumerState<EntryForm> {
  final _formKey = GlobalKey<FormState>();
  final _amount = TextEditingController();
  final _name = TextEditingController();
  final _notes = TextEditingController();
  String _category = 'Food';
  String _paymentMode = 'UPI';
  DateTime _date = IstTime.dateOnly(IstTime.now());
  bool _saving = false;

  @override
  void dispose() {
    _amount.dispose();
    _name.dispose();
    _notes.dispose();
    super.dispose();
  }

  String get _title => switch (widget.kind) {
    EntryKind.expense => 'Add expense',
    EntryKind.income => 'Add income',
    EntryKind.emi => 'Add EMI',
    EntryKind.budget => 'Set monthly budget',
  };

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      20,
      8,
      20,
      MediaQuery.viewInsetsOf(context).bottom + 20,
    ),
    child: Form(
      key: _formKey,
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(_title, style: Theme.of(context).textTheme.headlineSmall),
            const SizedBox(height: 20),
            if (widget.kind != EntryKind.expense &&
                widget.kind != EntryKind.budget)
              TextFormField(
                controller: _name,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(
                  labelText: widget.kind == EntryKind.income
                      ? 'Income source'
                      : 'Loan name',
                ),
                validator: (value) =>
                    value == null || value.trim().isEmpty ? 'Required' : null,
              ),
            if (widget.kind != EntryKind.expense &&
                widget.kind != EntryKind.budget)
              const SizedBox(height: 12),
            TextFormField(
              controller: _amount,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: InputDecoration(
                labelText: widget.kind == EntryKind.budget
                    ? 'Monthly limit'
                    : 'Amount',
                prefixText: '₹ ',
              ),
              validator: (value) => rupeesToMinor(value ?? '') <= 0
                  ? 'Enter an amount greater than zero'
                  : null,
            ),
            if (widget.kind == EntryKind.expense ||
                widget.kind == EntryKind.budget) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _category,
                decoration: const InputDecoration(labelText: 'Category'),
                items:
                    const [
                          'Food',
                          'Travel',
                          'Bills',
                          'Health',
                          'Shopping',
                          'Other',
                        ]
                        .map(
                          (value) => DropdownMenuItem(
                            value: value,
                            child: Text(value),
                          ),
                        )
                        .toList(),
                onChanged: (value) => _category = value ?? _category,
              ),
            ],
            if (widget.kind == EntryKind.expense) ...[
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                initialValue: _paymentMode,
                decoration: const InputDecoration(labelText: 'Payment mode'),
                items: const ['UPI', 'Cash', 'Card', 'Bank']
                    .map(
                      (value) =>
                          DropdownMenuItem(value: value, child: Text(value)),
                    )
                    .toList(),
                onChanged: (value) => _paymentMode = value ?? _paymentMode,
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _notes,
                decoration: const InputDecoration(
                  labelText: 'Notes (optional)',
                ),
              ),
            ],
            if (widget.kind != EntryKind.budget) ...[
              const SizedBox(height: 12),
              OutlinedButton.icon(
                onPressed: _pickDate,
                icon: const Icon(LucideIcons.calendar),
                label: Text(DateFormat.yMMMd().format(_date)),
              ),
            ],
            const SizedBox(height: 20),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Save'),
            ),
          ],
        ),
      ),
    ),
  );

  Future<void> _pickDate() async {
    final value = await showDatePicker(
      context: context,
      initialDate: _date,
      firstDate: DateTime(2020),
      lastDate: IstTime.now().add(const Duration(days: 3650)),
    );
    if (value != null) setState(() => _date = value);
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) return;
    setState(() => _saving = true);
    final controller = ref.read(financeProvider.notifier);
    try {
      switch (widget.kind) {
        case EntryKind.expense:
          await controller.addExpense(
            amountMinor: rupeesToMinor(_amount.text),
            category: _category,
            paidBy: 'Family Owner',
            paymentMode: _paymentMode,
            date: _date,
            notes: _notes.text.trim(),
          );
        case EntryKind.income:
          await controller.addIncome(
            source: _name.text.trim(),
            amountMinor: rupeesToMinor(_amount.text),
            receivedDate: _date,
          );
        case EntryKind.emi:
          final emi = await controller.addEmi(
            loanName: _name.text.trim(),
            amountMinor: rupeesToMinor(_amount.text),
            dueDate: _date,
          );
          await NotificationService.instance.scheduleEmiReminder(emi);
        case EntryKind.budget:
          await controller.addBudget(
            category: _category,
            limitMinor: rupeesToMinor(_amount.text),
            month: DateFormat('yyyy-MM').format(IstTime.now()),
          );
      }
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }
}

class EmptyState extends StatelessWidget {
  const EmptyState({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 32),
    child: Column(
      children: [
        Icon(
          LucideIcons.inbox,
          size: 44,
          color: Theme.of(context).colorScheme.outline,
        ),
        const SizedBox(height: 8),
        Text(message),
      ],
    ),
  );
}

class ErrorState extends StatelessWidget {
  const ErrorState({super.key, required this.message, required this.retry});

  final String message;
  final VoidCallback retry;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(LucideIcons.triangleAlert, size: 40),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
          const SizedBox(height: 12),
          FilledButton(onPressed: retry, child: const Text('Try again')),
        ],
      ),
    ),
  );
}
