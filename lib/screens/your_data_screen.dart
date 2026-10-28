import 'package:flutter/material.dart';

import '../auth/app_session.dart';
import '../state/cart_store.dart';
import 'account_screen.dart';
import 'data_management_screen.dart';

/// Explains the app's actual data flows without promising a store privacy policy.
class YourDataScreen extends StatelessWidget {
  const YourDataScreen({super.key, required this.store});
  final CartStore store;

  @override
  Widget build(BuildContext context) {
    final session = AccountScope.maybeOf(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Your data')),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 680),
            child: ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Your lists. Your choices.',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                const SizedBox(height: 12),
                const Text(
                  'You can shop without an account. Here’s what stays on your device, what goes online and how to manage it.',
                ),
                const SizedBox(height: 20),
                const _DataSection(
                  icon: Icons.phone_iphone_outlined,
                  title: 'On this device',
                  paragraphs: [
                    'Carty saves your basket, budget, lists, history and product preferences in the app’s storage. Saved lists do not automatically become files in Documents.',
                    'Item suggestions and recommendations use your shopping data and built-in product names. They do not send your typed names to an AI service.',
                    'Uninstalling Carty, clearing app data or losing the device can lose changes that have not synced or been exported.',
                  ],
                ),
                const _DataSection(
                  icon: Icons.cloud_outlined,
                  title: 'When you sign in',
                  paragraphs: [
                    'Supabase handles your email sign-in and profile name. Your signed-in basket, budget, saved lists, history and preferences sync to your private cloud workspace. Guest lists are copied to it only when you choose to import them.',
                    'Account and guest workspaces are kept separate. Signing out closes the account workspace but does not erase its saved device data.',
                  ],
                ),
                const _DataSection(
                  icon: Icons.people_outline_rounded,
                  title: 'When you share a list',
                  paragraphs: [
                    'Household members can see the selected shared list’s products, prices, quantities, budget and progress. Owners and editors can change it; viewers can read it. Your other private lists, history and recommendation choices are not included.',
                    'Invitations use the recipient’s verified email. Owners manage access. Removing access cannot erase copies someone already saved offline or exported.',
                  ],
                ),
                const _DataSection(
                  icon: Icons.qr_code_scanner_rounded,
                  title: 'When you scan a barcode',
                  paragraphs: [
                    'Camera images are processed on your device. Online lookups send the barcode to the open Facts catalogs: Food, Beauty, Pet Food and Products (openfoodfacts.org). UPCitemdb (upcitemdb.com) is a limited free fallback, used only if needed. These providers do not receive your basket, budget or typed item names.',
                    'Online services receive ordinary network request information, including your IP address. Product matches are cached on the device; you can also enter product details manually.',
                  ],
                ),
                const _DataSection(
                  icon: Icons.file_download_outlined,
                  title: 'Files you export',
                  paragraphs: [
                    'Backups go to the location you choose. They include shopping data and are readable JSON files, not encrypted files. Anyone with access to a backup can read it. Sign-in credentials are excluded.',
                    'A household-copy export includes only the selected shopping copy, without membership or sign-in details. You control exported files and must remove unwanted copies yourself.',
                  ],
                ),
                const _DataSection(
                  icon: Icons.delete_outline_rounded,
                  title: 'Deleting an account',
                  paragraphs: [
                    'Delete account removes your private cloud workspace, profile and owned shared lists after a warning. Owned shared lists disappear for everyone. Lists owned by someone else remain.',
                    'Carty also removes that account’s saved data on this device. Exported files and offline copies on other devices cannot be remotely erased. Guest data and other accounts are kept.',
                  ],
                ),
                const SizedBox(height: 8),
                FilledButton.icon(
                  key: const Key('your-data-backups'),
                  onPressed: () => Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => DataManagementScreen(store: store),
                    ),
                  ),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Manage data & backups'),
                ),
                if (session != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const Key('your-data-account'),
                    onPressed: () => Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountScreen(session: session),
                      ),
                    ),
                    icon: const Icon(Icons.account_circle_outlined),
                    label: const Text('Account and sync'),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DataSection extends StatelessWidget {
  const _DataSection({
    required this.icon,
    required this.title,
    required this.paragraphs,
  });
  final IconData icon;
  final String title;
  final List<String> paragraphs;

  @override
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 16),
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: Theme.of(context).colorScheme.primary),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          for (final paragraph in paragraphs) ...[
            const SizedBox(height: 12),
            Text(paragraph),
          ],
        ],
      ),
    ),
  );
}
