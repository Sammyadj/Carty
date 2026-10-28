import 'package:flutter/material.dart';

import '../auth/app_session.dart';
import '../state/cart_store.dart';
import 'account_screen.dart';
import 'data_management_screen.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key, required this.store});
  final CartStore store;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Settings')),
    body: SafeArea(
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 680),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              ListTile(
                key: const Key('settings-data'),
                leading: const Icon(Icons.backup_outlined),
                title: const Text('Data & backups'),
                subtitle: const Text(
                  'Export, restore and recover your shopping data',
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.push<void>(
                  context,
                  MaterialPageRoute(
                    builder: (_) => DataManagementScreen(store: store),
                  ),
                ),
              ),
              ListTile(
                leading: const Icon(Icons.account_circle_outlined),
                title: const Text('Account and sync'),
                onTap: () {
                  final session = AccountScope.maybeOf(context);
                  if (session != null) {
                    Navigator.push<void>(
                      context,
                      MaterialPageRoute(
                        builder: (_) => AccountScreen(session: session),
                      ),
                    );
                  }
                },
              ),
              ListTile(
                leading: const Icon(Icons.info_outline_rounded),
                title: const Text('About Carty'),
                onTap: () => showAboutDialog(
                  context: context,
                  applicationName: 'Carty',
                  applicationVersion: '1.0.0',
                  children: const [
                    Text(
                      'Plan a basket, stay within budget and reuse your regular lists. Shopping data is saved on this device and synced privately when signed in.',
                    ),
                    SizedBox(height: 12),
                    Text(
                      'Barcode lookups use Open Food Facts (openfoodfacts.org), then UPCitemdb (upcitemdb.com) if needed. Open Food Facts data is under the Open Database License (opendatacommons.org/licenses/odbl/1-0/); UPCitemdb data has its own terms. Camera images stay on your device. Prices are entered by you.',
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
