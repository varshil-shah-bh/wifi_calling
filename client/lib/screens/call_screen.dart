import 'package:flutter/material.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:provider/provider.dart';

import '../services/call_service.dart';

class CallScreen extends StatelessWidget {
  const CallScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final calls = context.watch<CallService>();
    final peer = calls.peer;
    final scheme = Theme.of(context).colorScheme;

    if (calls.state == CallState.ended) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        final message = calls.statusMessage;
        calls.reset();
        Navigator.of(context).maybePop();
        if (message != null) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
        }
      });
    }

    return PopScope(
      canPop: !calls.inCall,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) calls.hangUp();
      },
      child: Scaffold(
        backgroundColor: scheme.surfaceContainerHighest,
        body: SafeArea(
          child: Column(
            children: [
              // Carries the remote audio track; sized to zero since this is a voice call.
              SizedBox(
                height: 0,
                width: 0,
                child: RTCVideoView(calls.remoteRenderer),
              ),
              const Spacer(),
              CircleAvatar(
                radius: 56,
                backgroundColor: scheme.primaryContainer,
                child: Text(
                  peer?.initials ?? '?',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.w600,
                    color: scheme.onPrimaryContainer,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                peer?.name ?? 'Unknown',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                calls.statusMessage ?? '',
                style: TextStyle(color: scheme.onSurfaceVariant),
              ),
              const Spacer(),
              if (calls.state == CallState.incoming)
                _IncomingControls(calls: calls)
              else
                _ActiveControls(calls: calls),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }
}

class _IncomingControls extends StatelessWidget {
  const _IncomingControls({required this.calls});

  final CallService calls;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: Icons.call_end_rounded,
          color: Colors.red,
          label: 'Decline',
          onPressed: calls.rejectCall,
        ),
        _RoundButton(
          icon: Icons.call_rounded,
          color: Colors.green,
          label: 'Accept',
          onPressed: calls.acceptCall,
        ),
      ],
    );
  }
}

class _ActiveControls extends StatelessWidget {
  const _ActiveControls({required this.calls});

  final CallService calls;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _RoundButton(
          icon: calls.muted ? Icons.mic_off_rounded : Icons.mic_rounded,
          color: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          label: calls.muted ? 'Unmute' : 'Mute',
          onPressed: calls.toggleMute,
        ),
        _RoundButton(
          icon: Icons.call_end_rounded,
          color: Colors.red,
          label: 'End',
          onPressed: calls.hangUp,
        ),
        _RoundButton(
          icon: calls.speakerOn ? Icons.volume_up_rounded : Icons.volume_down_rounded,
          color: scheme.secondaryContainer,
          foreground: scheme.onSecondaryContainer,
          label: 'Speaker',
          onPressed: calls.toggleSpeaker,
        ),
      ],
    );
  }
}

class _RoundButton extends StatelessWidget {
  const _RoundButton({
    required this.icon,
    required this.color,
    required this.label,
    required this.onPressed,
    this.foreground = Colors.white,
  });

  final IconData icon;
  final Color color;
  final Color foreground;
  final String label;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Material(
          color: color,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onPressed,
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Icon(icon, color: foreground, size: 28),
            ),
          ),
        ),
        const SizedBox(height: 8),
        Text(label, style: Theme.of(context).textTheme.labelMedium),
      ],
    );
  }
}
