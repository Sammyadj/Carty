import 'package:flutter/material.dart';

import '../auth/app_session.dart';
import '../screens/account_screen.dart';

class CloudSyncNotice extends StatelessWidget {
  const CloudSyncNotice({super.key});
  @override
  Widget build(BuildContext context) {
    final session = AccountScope.maybeOf(context);
    final cloud = session?.cloud;
    if (cloud == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        key: const Key('cloud-sync-status'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => AccountScreen(session: session!)),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12),
          child: Row(
            children: [
              const Icon(Icons.cloud_outlined, size: 20),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  cloudStatusText(cloud.status),
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
              const Icon(Icons.chevron_right_rounded, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
