import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../models/app_user.dart';
import '../services/auth_service.dart';
import '../services/call_service.dart';
import '../services/signaling_service.dart';
import 'call_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late Future<List<AppUser>> _usersFuture;

  @override
  void initState() {
    super.initState();
    _usersFuture = context.read<AuthService>().fetchUsers();
  }

  Future<void> _refresh() async {
    final future = context.read<AuthService>().fetchUsers();
    setState(() => _usersFuture = future);
    await future;
  }

  Future<void> _call(AppUser user) async {
    final calls = context.read<CallService>();
    await calls.startCall(user);
    if (!mounted) return;
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => const CallScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthService>();
    final signaling = context.watch<SignalingService>();

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 20,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(auth.user?.name ?? 'Contacts'),
            Text(
              signaling.connected ? 'Online' : 'Connecting…',
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: signaling.connected ? Colors.green : Colors.orange,
                  ),
            ),
          ],
        ),
        actions: [
          IconButton(
            tooltip: 'Sign out',
            icon: const Icon(Icons.logout_rounded),
            onPressed: () => context.read<AuthService>().logout(),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _refresh,
        child: FutureBuilder<List<AppUser>>(
          future: _usersFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return _Message(
                icon: Icons.cloud_off_rounded,
                title: 'Could not load contacts',
                subtitle: 'Pull down to try again.',
              );
            }

            final users = snapshot.data ?? const <AppUser>[];
            if (users.isEmpty) {
              return _Message(
                icon: Icons.person_add_alt_rounded,
                title: 'No one else here yet',
                subtitle: 'Register another account to start calling.',
              );
            }

            // Online contacts first so callable people are at the top.
            final sorted = [...users]..sort((a, b) {
                final aOnline = signaling.isOnline(a.id);
                final bOnline = signaling.isOnline(b.id);
                if (aOnline != bOnline) return aOnline ? -1 : 1;
                return a.name.toLowerCase().compareTo(b.name.toLowerCase());
              });

            return ListView.separated(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: sorted.length,
              separatorBuilder: (_, _) => const Divider(height: 1, indent: 76),
              itemBuilder: (context, index) {
                final user = sorted[index];
                final online = signaling.isOnline(user.id);
                return _UserTile(
                  user: user,
                  online: online,
                  onCall: online ? () => _call(user) : null,
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _UserTile extends StatelessWidget {
  const _UserTile({required this.user, required this.online, this.onCall});

  final AppUser user;
  final bool online;
  final VoidCallback? onCall;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      leading: Stack(
        clipBehavior: Clip.none,
        children: [
          CircleAvatar(
            radius: 24,
            backgroundColor: scheme.primaryContainer,
            child: Text(
              user.initials,
              style: TextStyle(
                color: scheme.onPrimaryContainer,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          Positioned(
            right: -1,
            bottom: -1,
            child: Container(
              height: 14,
              width: 14,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: online ? Colors.green : scheme.outlineVariant,
                border: Border.all(color: scheme.surface, width: 2),
              ),
            ),
          ),
        ],
      ),
      title: Text(user.name, style: const TextStyle(fontWeight: FontWeight.w600)),
      subtitle: Text(
        online ? 'Active now' : 'Offline',
        style: TextStyle(color: online ? Colors.green : scheme.onSurfaceVariant),
      ),
      trailing: IconButton.filledTonal(
        tooltip: online ? 'Call ${user.name}' : '${user.name} is offline',
        icon: const Icon(Icons.call_rounded),
        onPressed: onCall,
      ),
    );
  }
}

class _Message extends StatelessWidget {
  const _Message({required this.icon, required this.title, required this.subtitle});

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(icon, size: 56, color: scheme.outline),
        const SizedBox(height: 16),
        Text(title, textAlign: TextAlign.center, style: Theme.of(context).textTheme.titleMedium),
        const SizedBox(height: 6),
        Text(
          subtitle,
          textAlign: TextAlign.center,
          style: TextStyle(color: scheme.onSurfaceVariant),
        ),
      ],
    );
  }
}
