import 'dart:async';

import 'package:flutter/material.dart';

import '../auth/account_gateway.dart';
import '../auth/app_session.dart';
import '../cloud/cloud_cart_storage.dart';
import '../widgets/cloud_snapshot_preview.dart';

String cloudStatusText(CloudSyncStatus status) => switch (status) {
  CloudSyncStatus.idle => 'Checking your cloud copy…',
  CloudSyncStatus.syncing => 'Syncing your shopping data…',
  CloudSyncStatus.synced => 'Your shopping data is up to date.',
  CloudSyncStatus.pending => 'Saved on this device. Cloud sync is pending.',
  CloudSyncStatus.conflict => 'This device and the cloud both have changes.',
  CloudSyncStatus.error =>
    'Cloud sync couldn’t finish. Your data is kept on this device.',
};

class AccountScreen extends StatefulWidget {
  const AccountScreen({super.key, required this.session});
  final AppSession session;
  @override
  State<AccountScreen> createState() => _AccountScreenState();
}

class _AccountScreenState extends State<AccountScreen> {
  final _email = TextEditingController();
  final _name = TextEditingController();
  final _emailForm = GlobalKey<FormState>();
  final _profileForm = GlobalKey<FormState>();
  bool _busy = false;
  bool _sent = false;
  bool _canResend = false;
  bool _nameChanged = false;
  String? _message;
  Timer? _resend;
  AppSession get session => widget.session;

  @override
  void dispose() {
    _resend?.cancel();
    _email.dispose();
    _name.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action, String error) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await action();
    } catch (problem) {
      if (mounted) {
        setState(
          () => _message = problem is AccountProblem ? problem.message : error,
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<bool> _confirm(
    String title,
    String description,
    String action,
  ) async =>
      await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          scrollable: true,
          title: Text(title),
          content: Text(description),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              key: const Key('account-confirm'),
              onPressed: () => Navigator.pop(context, true),
              child: Text(action),
            ),
          ],
        ),
      ) ==
      true;

  Future<void> _sendLink() async {
    if (!_emailForm.currentState!.validate()) return;
    await _run(
      () async {
        if (!await session.store.waitForPendingSave()) {
          throw const AccountProblem(
            'Save changes on this device before signing in.',
          );
        }
        await session.gateway!.sendSignInLink(_email.text.trim());
        if (!mounted) return;
        setState(() {
          _sent = true;
          _canResend = false;
        });
        _resend?.cancel();
        _resend = Timer(const Duration(seconds: 60), () {
          if (mounted) setState(() => _canResend = true);
        });
      },
      'Couldn’t send the sign-in link. Check your email address and try again shortly.',
    );
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: session,
    builder: (context, _) {
      if (!_nameChanged) _name.text = session.displayName;
      return Scaffold(
        appBar: AppBar(title: const Text('Your account')),
        body: SafeArea(
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                padding: const EdgeInsets.fromLTRB(20, 12, 20, 32),
                children: [
                  if (session.user == null)
                    ..._signIn(context)
                  else
                    ..._profile(context),
                  if (_message != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 16),
                      child: Text(_message!, key: const Key('account-message')),
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    },
  );

  List<Widget> _signIn(BuildContext context) => [
    Text(
      'Your lists. Wherever you shop.',
      style: Theme.of(context).textTheme.headlineMedium,
    ),
    const SizedBox(height: 12),
    const Text(
      'Sign in to back up your lists and shopping history. You can keep shopping without an account. Guest data stays on this device until you choose to copy it.',
    ),
    const SizedBox(height: 24),
    if (!session.cloudAvailable)
      const Text(
        'Cloud sign-in is temporarily unavailable. Your lists are still saved on this device.',
      )
    else ...[
      Form(
        key: _emailForm,
        child: TextFormField(
          key: const Key('account-email'),
          controller: _email,
          enabled: !_busy && !_sent,
          keyboardType: TextInputType.emailAddress,
          autofillHints: const [AutofillHints.email],
          autocorrect: false,
          maxLength: 254,
          decoration: const InputDecoration(
            labelText: 'Email address',
            counterText: '',
          ),
          validator: (value) =>
              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                  .hasMatch(value?.trim() ?? '')
              ? null
              : 'Enter a valid email address',
          onFieldSubmitted: (_) => _sendLink(),
        ),
      ),
      const SizedBox(height: 16),
      if (!_sent)
        FilledButton(
          key: const Key('account-send-link'),
          onPressed: _busy ? null : _sendLink,
          child: Text(_busy ? 'Sending…' : 'Email me a sign-in link'),
        )
      else ...[
        Text(
          'Check your inbox at ${_email.text.trim()}. Open the sign-in link on this device to return to Carty.',
        ),
        const SizedBox(height: 12),
        TextButton(
          key: const Key('account-resend-link'),
          onPressed: _busy || !_canResend ? null : _sendLink,
          child: Text(
            _canResend
                ? 'Send another link'
                : 'You can request another link in a minute',
          ),
        ),
        TextButton(
          onPressed: _busy
              ? null
              : () {
                  _resend?.cancel();
                  setState(() => _sent = false);
                },
          child: const Text('Use another email address'),
        ),
      ],
    ],
    if (session.profileError != null)
      Padding(
        padding: const EdgeInsets.only(top: 12),
        child: Text(session.profileError!),
      ),
  ];

  List<Widget> _profile(BuildContext context) {
    final cloud = session.cloud;
    return [
      Text(session.user!.email, style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 20),
      Form(
        key: _profileForm,
        child: TextFormField(
          key: const Key('account-display-name'),
          controller: _name,
          enabled: !_busy,
          maxLength: 60,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(labelText: 'Display name'),
          onChanged: (_) => _nameChanged = true,
          validator: (value) => (value?.trim().length ?? 0) > 60
              ? 'Use 60 characters or fewer'
              : null,
        ),
      ),
      FilledButton(
        key: const Key('account-save-profile'),
        onPressed: _busy
            ? null
            : () {
                if (!_profileForm.currentState!.validate()) return;
                _run(() async {
                  await session.saveProfile(_name.text);
                  if (mounted) {
                    setState(() {
                      _nameChanged = false;
                      _message = 'Profile saved.';
                    });
                  }
                }, 'Couldn’t save your profile. Please try again.');
              },
        child: const Text('Save profile'),
      ),
      if (session.profileError != null)
        Padding(
          padding: const EdgeInsets.only(top: 12),
          child: Text(session.profileError!),
        ),
      const SizedBox(height: 28),
      Text('Cloud backup', style: Theme.of(context).textTheme.titleLarge),
      const SizedBox(height: 8),
      Text(
        cloudStatusText(cloud?.status ?? CloudSyncStatus.error),
        key: const Key('account-sync-status'),
      ),
      const SizedBox(height: 12),
      if (cloud?.status == CloudSyncStatus.conflict) ...[
        const Text(
          'Choose which version to continue with. The other version will be kept as a recovery copy on this device.',
        ),
        const SizedBox(height: 12),
        CloudSnapshotPreview(
          label: 'On this device',
          snapshot: session.store.exportSnapshot(),
        ),
        if (cloud!.conflict != null)
          CloudSnapshotPreview(
            label: 'In the cloud',
            snapshot: cloud.conflict!.snapshot,
          )
        else
          const Text('There is no cloud copy available to restore.'),
        const SizedBox(height: 12),
        for (final useCloud in [true, false])
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: OutlinedButton(
              key: Key(useCloud ? 'sync-use-cloud' : 'sync-use-device'),
              onPressed: _busy || (useCloud && cloud.conflict == null)
                  ? null
                  : () async {
                      if (!await _confirm(
                            'Choose this version?',
                            'This replaces ${useCloud ? 'this device’s' : 'the cloud’s'} current copy. A recovery copy will be kept.',
                            'Continue',
                          ) ||
                          !mounted) {
                        return;
                      }
                      await _run(() async {
                        if (!await session.store.waitForPendingSave()) {
                          throw const AccountProblem(
                            'Save changes on this device before resolving this conflict.',
                          );
                        }
                        if (!await cloud.resolveConflict(useCloud: useCloud)) {
                          throw const AccountProblem(
                            'Couldn’t finish. Review the sync status and try again.',
                          );
                        }
                      }, 'Couldn’t resolve this conflict. Please try again.');
                    },
              child: Text(
                useCloud ? 'Use cloud version' : 'Keep this device’s version',
              ),
            ),
          ),
      ] else
        OutlinedButton.icon(
          key: const Key('account-sync-now'),
          onPressed: _busy || cloud == null
              ? null
              : () => _run(
                  cloud.sync,
                  'Couldn’t sync. Try again when connected.',
                ),
          icon: const Icon(Icons.sync_rounded),
          label: const Text('Sync now'),
        ),
      if (cloud?.recoverySnapshot != null)
        TextButton(
          key: const Key('sync-restore-backup'),
          onPressed: _busy
              ? null
              : () async {
                  if (!await _confirm(
                        'Restore the previous version?',
                        'Your current version will be kept as a recovery copy.',
                        'Restore',
                      ) ||
                      !mounted) {
                    return;
                  }
                  await _run(() async {
                    if (!await session.store.waitForPendingSave()) {
                      throw const AccountProblem(
                        'Save changes on this device before restoring a previous version.',
                      );
                    }
                    await cloud!.restoreRecoveryCopy();
                  }, 'Couldn’t restore the recovery copy.');
                },
          child: const Text('Restore previous version'),
        ),
      if (session.guest.hasData) ...[
        const SizedBox(height: 16),
        OutlinedButton(
          key: const Key('account-import-guest'),
          onPressed: _busy
              ? null
              : () async {
                  if (!await _confirm(
                        'Copy guest shopping data?',
                        'Copy this device’s guest lists, basket, history, favourites and suggestion choices into this account. Existing account choices take precedence and the guest originals stay.',
                        'Copy data',
                      ) ||
                      !mounted) {
                    return;
                  }
                  await _run(
                    session.importGuestLists,
                    'Couldn’t copy guest data. Please try again.',
                  );
                },
          child: const Text('Copy guest lists and history'),
        ),
      ],
      const SizedBox(height: 24),
      OutlinedButton(
        key: const Key('account-sign-out'),
        onPressed: _busy
            ? null
            : () async {
                if (cloud?.status != CloudSyncStatus.synced &&
                    !await _confirm(
                      'Sign out before cloud sync finishes?',
                      'Your account data will remain saved on this device for your next sign-in.',
                      'Sign out',
                    )) {
                  return;
                }
                if (!mounted) return;
                await _run(
                  session.signOut,
                  'Couldn’t sign out. Please try again.',
                );
              },
        child: const Text('Sign out'),
      ),
      const SizedBox(height: 12),
      TextButton(
        key: const Key('account-delete'),
        onPressed: _busy
            ? null
            : () async {
                if (!await _confirm(
                      'Delete your account?',
                      'Permanently delete your account, profile, private cloud lists, shopping history and this account’s cache on this device. Shared lists you own will also be deleted for everyone, including their products, invitations and memberships. Lists owned by someone else and guest data stay. This cannot be undone.',
                      'Delete account',
                    ) ||
                    !mounted) {
                  return;
                }
                await _run(
                  session.deleteAccount,
                  'Couldn’t finish deleting your account. Please try again.',
                );
              },
        child: Text(
          'Delete account',
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
    ];
  }
}
