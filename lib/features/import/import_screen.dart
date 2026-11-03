import 'package:finora/app/theme.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/application/statement_import.dart';
import 'package:finora/domain/imported_accounts.dart';
import 'package:finora/domain/institution_catalogue.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/domain/statement_import.dart';
import 'package:finora/features/simulators/simulator_widgets.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// Reads a CSV export from e-banking into an account on the device.
class ImportScreen extends ConsumerStatefulWidget {
  const ImportScreen({super.key});

  @override
  ConsumerState<ImportScreen> createState() => _ImportScreenState();
}

class _ImportScreenState extends ConsumerState<ImportScreen> {
  final _paste = TextEditingController();
  TextEditingController? _name;
  String _institutionId = InstitutionCatalogue.offering({
    FinancialProductType.currentAccount,
  }).first.id;
  ParsedStatement? _statement;
  Money _balance = Money.zero;
  int _version = 0;
  bool _showPaste = false;

  @override
  void dispose() {
    _paste.dispose();
    _name?.dispose();
    super.dispose();
  }

  void _read(String text) {
    final l10n = context.l10n;
    try {
      final statement = StatementParser.parse(text);
      setState(() {
        _statement = statement;
        _balance = statement.closingBalance ?? Money.zero;
        _version++;
      });
    } on StatementFormatException catch (error) {
      setState(() => _statement = null);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(l10n.statementProblem(error.problem))),
      );
    }
  }

  Future<void> _pick() async {
    final l10n = context.l10n;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final text = await ref.read(statementFilePickerProvider).pick();
      if (text != null && mounted) _read(text);
    } on Object {
      messenger.showSnackBar(SnackBar(content: Text(l10n.importFileFailed)));
    }
  }

  void _import(ParsedStatement statement, String name) {
    final l10n = context.l10n;
    ref
        .read(sessionProvider.notifier)
        .importAccount(
          ImportedAccount.fromStatement(
            institutionId: _institutionId,
            name: name,
            statement: statement,
            balance: _balance,
            importedAt: ref.read(clockProvider)(),
          ),
        );
    setState(() {
      _statement = null;
      _paste.clear();
    });
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(l10n.importDone(statement.rows.length))),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final name = _name ??= TextEditingController(text: l10n.importNameDefault);
    final banks = InstitutionCatalogue.offering({
      FinancialProductType.currentAccount,
    });
    final imported = ref.watch(
      sessionProvider.select((session) => session.importedAccounts),
    );
    final statement = _statement;
    final dates = DateFormat.yMMMd(l10n.localeName);
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.importTitle),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            Text(l10n.importIntro, style: Theme.of(context).textTheme.bodyLarge),
            const SizedBox(height: 12),
            Card(
              color: finoraSoftBlue,
              child: ListTile(
                leading: const Icon(Icons.info_outline, color: finoraBlueText),
                title: Text(
                  l10n.importHowTitle,
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                subtitle: Text(l10n.importHowBody),
              ),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              initialValue: _institutionId,
              isExpanded: true,
              decoration: InputDecoration(labelText: l10n.importBankLabel),
              items: [
                for (final bank in banks)
                  DropdownMenuItem(value: bank.id, child: Text(bank.name)),
              ],
              onChanged: (value) {
                if (value != null) setState(() => _institutionId = value);
              },
            ),
            const SizedBox(height: 12),
            TextField(
              controller: name,
              decoration: InputDecoration(labelText: l10n.importNameLabel),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: _pick,
              icon: const Icon(Icons.upload_file),
              label: Text(l10n.importChooseFile),
            ),
            TextButton(
              onPressed: () => setState(() => _showPaste = !_showPaste),
              child: Text(l10n.importPasteToggle),
            ),
            if (_showPaste) ...[
              TextField(
                controller: _paste,
                minLines: 4,
                maxLines: 8,
                style: const TextStyle(fontSize: 12),
                decoration: InputDecoration(labelText: l10n.importPasteLabel),
              ),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _read(_paste.text),
                  child: Text(l10n.importPasteRead),
                ),
              ),
            ],
            if (statement != null) ...[
              const SizedBox(height: 8),
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        l10n.importPreviewTitle(
                          statement.rows.length,
                          dates.format(statement.firstDate),
                          dates.format(statement.lastDate),
                        ),
                        style: const TextStyle(fontWeight: FontWeight.w800),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        l10n.importPreviewTotals(
                          formatMoneyWhole(statement.income),
                          formatMoneyWhole(statement.spending),
                        ),
                        style: const TextStyle(color: finoraMutedInk),
                      ),
                      const SizedBox(height: 8),
                      for (final row in statement.rows.reversed.take(4))
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 2),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  row.text,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                formatMoney(row.amount, signed: true),
                                style: const TextStyle(
                                  fontSize: 13,
                                  fontFeatures: finoraTabular,
                                ),
                              ),
                            ],
                          ),
                        ),
                      const SizedBox(height: 12),
                      MoneyField(
                        key: ValueKey(_version),
                        label: l10n.importBalanceLabel,
                        helper: statement.closingBalance != null
                            ? l10n.importBalanceFromFile
                            : l10n.importBalanceHelp,
                        value: _balance,
                        onChanged: (value) => setState(() => _balance = value),
                      ),
                      SimulatorNote(l10n.importCategoryNote),
                      SimulatorNote(l10n.importReplaceNote),
                      const SizedBox(height: 8),
                      FilledButton(
                        onPressed: () => _import(
                          statement,
                          name.text.trim().isEmpty
                              ? l10n.importNameDefault
                              : name.text.trim(),
                        ),
                        child: Text(l10n.importConfirm),
                      ),
                    ],
                  ),
                ),
              ),
            ],
            if (imported.isNotEmpty) ...[
              SectionTitle(l10n.importExistingSection),
              Card(
                child: Column(
                  children: [
                    for (final account in imported)
                      ListTile(
                        title: Text(
                          '${InstitutionCatalogue.nameOf(account.institutionId)} · '
                          '${account.name}',
                        ),
                        subtitle: Text(
                          l10n.importExistingLine(
                            account.transactions.length,
                            dates.format(account.importedAt),
                          ),
                        ),
                        trailing: TextButton(
                          onPressed: () {
                            ref
                                .read(sessionProvider.notifier)
                                .removeImportedAccount(account.id);
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(content: Text(l10n.importRemoved)),
                            );
                          },
                          child: Text(l10n.importRemove),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
