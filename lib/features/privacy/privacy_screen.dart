import 'package:finora/app/theme.dart';
import 'package:finora/application/offers.dart';
import 'package:finora/application/session_controller.dart';
import 'package:finora/domain/trust.dart';
import 'package:finora/l10n/l10n.dart';
import 'package:finora/l10n/labels.dart';
import 'package:finora/shared/widgets.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

/// How Finora handles data, every consent the user gave, and a single place
/// to withdraw them (revised FADP: transparency and the right to withdraw).
class PrivacyScreen extends ConsumerWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final consent = ref.watch(
      sessionProvider.select((session) => session.offersConsent),
    );
    final log = ref.watch(consentLogProvider);
    final hasOfferData =
        consent == true ||
        log.any(
          (record) =>
              record.purpose == ConsentPurpose.partnerSharing && record.granted,
        );

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        title: Text(l10n.privacySecurity),
      ),
      body: FinoraPage(
        child: ListView(
          children: [
            SectionTitle(l10n.privacyHowSection),
            Card(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                child: Column(
                  children: [
                    _PrivacyLine(
                      icon: Icons.visibility_outlined,
                      text: l10n.privacyReadOnly,
                    ),
                    _PrivacyLine(
                      icon: Icons.phone_iphone,
                      text: l10n.privacyDeviceOnly,
                    ),
                    _PrivacyLine(
                      icon: Icons.key_off_outlined,
                      text: l10n.privacyNoCredentials,
                    ),
                    _PrivacyLine(
                      icon: Icons.handshake_outlined,
                      text: l10n.privacyPartnersOnlyWithConsent,
                    ),
                  ],
                ),
              ),
            ),
            SectionTitle(l10n.privacyConsentsSection),
            Card(
              child: SwitchListTile(
                value: consent ?? false,
                onChanged: ref.read(sessionProvider.notifier).setOffersConsent,
                secondary: const Icon(Icons.savings_outlined),
                title: Text(l10n.offersSetting),
                subtitle: Text(l10n.offersSettingBody),
              ),
            ),
            if (ref.watch(sessionProvider.select((s) => s.hasAccount))) ...[
              const SizedBox(height: 10),
              Card(
                child: SwitchListTile(
                  value: ref.watch(
                    sessionProvider.select((s) => s.marketingOptIn),
                  ),
                  onChanged: ref
                      .read(sessionProvider.notifier)
                      .setMarketingOptIn,
                  secondary: const Icon(Icons.mail_outline),
                  title: Text(l10n.consentPurposeMarketing),
                ),
              ),
            ],
            SectionTitle(l10n.consentHistorySection),
            if (log.isEmpty)
              Text(
                l10n.consentHistoryEmpty,
                style: const TextStyle(color: finoraMutedInk),
              )
            else
              Card(
                child: Column(
                  children: [
                    for (var index = 0; index < log.length; index++) ...[
                      _ConsentTile(record: log[index]),
                      if (index != log.length - 1) const Divider(height: 1),
                    ],
                  ],
                ),
              ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              style: OutlinedButton.styleFrom(foregroundColor: finoraDanger),
              onPressed: hasOfferData ? () => _confirmWithdraw(context, ref) : null,
              icon: const Icon(Icons.delete_outline),
              label: Text(l10n.withdrawAllConsents),
            ),
            const SizedBox(height: 12),
            Text(
              l10n.partnerDataNote,
              style: const TextStyle(
                color: finoraMutedInk,
                fontSize: 12,
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmWithdraw(BuildContext context, WidgetRef ref) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(dialogContext.l10n.withdrawAllTitle),
        content: Text(dialogContext.l10n.withdrawAllBody),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(dialogContext.l10n.commonCancel),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(dialogContext.l10n.withdrawAction),
          ),
        ],
      ),
    );
    if (confirmed != true || !context.mounted) return;
    ref.read(sessionProvider.notifier).withdrawOfferConsents();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text(context.l10n.consentsWithdrawn)));
  }
}

class _ConsentTile extends StatelessWidget {
  const _ConsentTile({required this.record});
  final ConsentRecord record;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final kind = record.offerKind;
    final title = switch (record.purpose) {
      ConsentPurpose.offersAnalysis => l10n.consentPurposeAnalysis,
      ConsentPurpose.partnerSharing => l10n.consentPurposePartner(
        kind == null ? '' : l10n.offerKindTitle(kind),
      ),
      ConsentPurpose.terms => l10n.consentPurposeTerms,
      ConsentPurpose.marketing => l10n.consentPurposeMarketing,
    };
    final when = DateFormat.yMMMd(
      l10n.localeName,
    ).add_Hm().format(record.at);
    return ListTile(
      leading: Icon(
        record.granted ? Icons.check_circle_outline : Icons.remove_circle_outline,
        color: record.granted ? finoraGreen : finoraMutedInk,
      ),
      title: Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
      subtitle: Text(
        l10n.consentRecordDetail(
          record.granted ? l10n.consentGranted : l10n.consentWithdrawn,
          when,
          record.textVersion,
        ),
      ),
    );
  }
}

class _PrivacyLine extends StatelessWidget {
  const _PrivacyLine({required this.icon, required this.text});
  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, color: finoraBlue, size: 20),
        const SizedBox(width: 12),
        Expanded(child: Text(text, style: const TextStyle(height: 1.4))),
      ],
    ),
  );
}
