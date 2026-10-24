import 'package:finora/app/theme.dart';
import 'package:finora/application/health.dart';
import 'package:finora/application/providers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/assets.dart';
import 'package:finora/domain/models.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

IconData assetIcon(ManualAssetKind kind) => switch (kind) {
  ManualAssetKind.property => Icons.home_outlined,
  ManualAssetKind.vehicle => Icons.directions_car_outlined,
  ManualAssetKind.crypto => Icons.currency_bitcoin,
  ManualAssetKind.other => Icons.category_outlined,
};

/// Property, vehicles, crypto and other assets valued by the user.
class AssetsScreen extends ConsumerWidget {
  const AssetsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final assets = ref.watch(manualAssetsProvider);
    final now = ref.watch(clockProvider)();
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.assetsTitle),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => showAssetEditor(context),
        icon: const Icon(Icons.add),
        label: Text(l10n.addAsset),
      ),
      body: FinoraPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 96),
          children: [
            Card(
              color: finoraInk,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      l10n.assetsTotal,
                      style: const TextStyle(color: finoraSilver),
                    ),
                    const SizedBox(height: 6),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        formatMoney(assets.total),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      l10n.assetsNote,
                      style: const TextStyle(
                        color: finoraSilver,
                        fontSize: 12,
                        height: 1.35,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            if (assets.isEmpty)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Text(
                    l10n.assetsEmpty,
                    style: const TextStyle(color: finoraMutedInk, height: 1.4),
                  ),
                ),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var index = 0; index < assets.length; index++) ...[
                      _AssetTile(asset: assets[index], now: now),
                      if (index != assets.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _AssetTile extends StatelessWidget {
  const _AssetTile({required this.asset, required this.now});
  final ManualAsset asset;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final outdated = asset.isOutdated(now);
    return ListTile(
      leading: CircleAvatar(
        backgroundColor: finoraSoftBlue,
        foregroundColor: finoraBlueText,
        child: Icon(assetIcon(asset.kind), size: 20),
      ),
      title: Text(
        asset.name,
        style: const TextStyle(fontWeight: FontWeight.w700),
      ),
      subtitle: Text(
        outdated
            ? l10n.assetOutdated
            : '${l10n.assetKind(asset.kind)} · ${l10n.assetValuedOn(DateFormat.yMMMd(l10n.localeName).format(asset.valuedAt))}',
        style: TextStyle(color: outdated ? finoraWarning : finoraMutedInk),
      ),
      trailing: Text(
        formatMoneyWhole(asset.value),
        style: const TextStyle(fontWeight: FontWeight.w800),
      ),
      onTap: () => showAssetEditor(context, asset: asset),
    );
  }
}

/// Adds a new asset, or edits [asset] when given.
Future<void> showAssetEditor(BuildContext context, {ManualAsset? asset}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _AssetEditor(asset: asset),
  );
}

class _AssetEditor extends ConsumerStatefulWidget {
  const _AssetEditor({this.asset});
  final ManualAsset? asset;

  @override
  ConsumerState<_AssetEditor> createState() => _AssetEditorState();
}

class _AssetEditorState extends ConsumerState<_AssetEditor> {
  late ManualAssetKind _kind = widget.asset?.kind ?? ManualAssetKind.property;
  late final TextEditingController _name = TextEditingController(
    text: widget.asset?.name ?? '',
  );
  late final TextEditingController _value = TextEditingController(
    text: widget.asset == null
        ? ''
        : widget.asset!.value.amount.round().toString(),
  );
  bool _submitted = false;

  @override
  void dispose() {
    _name.dispose();
    _value.dispose();
    super.dispose();
  }

  int get _francs => int.tryParse(_value.text) ?? 0;
  bool get _nameValid => _name.text.trim().isNotEmpty;
  bool get _valueValid => _francs > 0;

  void _save() {
    setState(() => _submitted = true);
    if (!_nameValid || !_valueValid) return;
    final now = ref.read(clockProvider)();
    final existing = widget.asset;
    final value = Money.cents(_francs * 100);
    ref
        .read(sessionProvider.notifier)
        .saveAsset(
          existing == null
              ? ManualAsset(
                  id: 'asset-${DateTime.now().microsecondsSinceEpoch}',
                  kind: _kind,
                  name: _name.text.trim(),
                  value: value,
                  valuedAt: now,
                )
              : existing.copyWith(
                  kind: _kind,
                  name: _name.text.trim(),
                  value: value,
                  // Saving the form confirms the value is current.
                  valuedAt: now,
                ),
        );
    Navigator.pop(context);
  }

  void _delete() {
    ref.read(sessionProvider.notifier).deleteAsset(widget.asset!.id);
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                widget.asset == null ? l10n.addAsset : l10n.editAsset,
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final kind in ManualAssetKind.values)
                    ChoiceChip(
                      avatar: Icon(assetIcon(kind), size: 18),
                      label: Text(l10n.assetKind(kind)),
                      selected: _kind == kind,
                      onSelected: (_) => setState(() => _kind = kind),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              TextField(
                controller: _name,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(
                  labelText: l10n.assetNameLabel,
                  errorText: _submitted && !_nameValid
                      ? l10n.assetNameRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _value,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  labelText: l10n.assetValueLabel,
                  prefixText: 'CHF ',
                  helperText: _kind == ManualAssetKind.property
                      ? l10n.assetPropertyHelp
                      : null,
                  helperMaxLines: 3,
                  errorText: _submitted && !_valueValid
                      ? l10n.assetValueRequired
                      : null,
                ),
                onChanged: (_) => setState(() {}),
              ),
              const SizedBox(height: 20),
              FilledButton(onPressed: _save, child: Text(l10n.saveAsset)),
              if (widget.asset != null)
                TextButton(
                  style: TextButton.styleFrom(foregroundColor: finoraDanger),
                  onPressed: _delete,
                  child: Text(l10n.deleteAsset),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
