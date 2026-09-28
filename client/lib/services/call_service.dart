import 'package:flutter/foundation.dart';
import 'package:flutter_webrtc/flutter_webrtc.dart';
import 'package:permission_handler/permission_handler.dart';

import '../config.dart';
import '../models/app_user.dart';
import 'signaling_service.dart';

enum CallState { idle, outgoing, incoming, connecting, connected, ended }

/// Audio-only peer-to-peer call. The server only relays SDP/ICE, media goes direct.
class CallService extends ChangeNotifier {
  CallService(this._signaling) {
    _signaling
      ..on('call:invite', _onInvite)
      ..on('call:accept', _onAccept)
      ..on('call:reject', (_) => _finish('Call declined'))
      ..on('call:end', (_) => _finish('Call ended'))
      ..on('webrtc:ice-candidate', _onRemoteCandidate)
      ..on('peer:unavailable', (_) => _finish('User is offline'));
  }

  final SignalingService _signaling;

  RTCPeerConnection? _pc;
  MediaStream? _localStream;
  final RTCVideoRenderer remoteRenderer = RTCVideoRenderer();
  bool _rendererReady = false;

  final List<RTCIceCandidate> _pendingCandidates = [];
  Map<String, dynamic>? _pendingOffer;

  CallState _state = CallState.idle;
  AppUser? _peer;
  String? _statusMessage;
  bool _muted = false;
  bool _speakerOn = true;

  CallState get state => _state;
  AppUser? get peer => _peer;
  String? get statusMessage => _statusMessage;
  bool get muted => _muted;
  bool get speakerOn => _speakerOn;
  bool get inCall => _state != CallState.idle && _state != CallState.ended;

  /// Fired when a call arrives while the app is not already on the call screen.
  void Function(AppUser caller)? onIncomingCall;

  /// Display name sent with an invite so the callee knows who is ringing.
  String myName = '';

  Future<void> startCall(AppUser peer) async {
    if (inCall) return;
    if (!await _ensureMicPermission()) {
      _finish('Microphone permission denied');
      return;
    }

    _peer = peer;
    _set(CallState.outgoing, 'Ringing…');

    await _createPeerConnection();
    final offer = await _pc!.createOffer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(offer);

    _signaling.emit('call:invite', {
      'to': peer.id,
      'sdp': offer.sdp,
      'type': offer.type,
      'callerName': myName,
    });
  }

  Future<void> acceptCall() async {
    final offer = _pendingOffer;
    if (offer == null || _peer == null) return;
    if (!await _ensureMicPermission()) {
      rejectCall();
      return;
    }

    _set(CallState.connecting, 'Connecting…');
    await _createPeerConnection();
    await _pc!.setRemoteDescription(
      RTCSessionDescription(offer['sdp'] as String, offer['type'] as String),
    );
    await _drainPendingCandidates();

    final answer = await _pc!.createAnswer({'offerToReceiveAudio': true});
    await _pc!.setLocalDescription(answer);

    _signaling.emit('call:accept', {
      'to': _peer!.id,
      'sdp': answer.sdp,
      'type': answer.type,
    });
    _pendingOffer = null;
  }

  void rejectCall() {
    if (_peer != null) _signaling.emit('call:reject', {'to': _peer!.id});
    _finish('Call declined');
  }

  void hangUp() {
    if (_peer != null && inCall) _signaling.emit('call:end', {'to': _peer!.id});
    _finish('Call ended');
  }

  Future<void> toggleMute() async {
    final tracks = _localStream?.getAudioTracks() ?? const <MediaStreamTrack>[];
    if (tracks.isEmpty) return;
    _muted = !_muted;
    await Helper.setMicrophoneMute(_muted, tracks.first);
    notifyListeners();
  }

  Future<void> toggleSpeaker() async {
    _speakerOn = !_speakerOn;
    await Helper.setSpeakerphoneOn(_speakerOn);
    notifyListeners();
  }

  void reset() {
    if (_state == CallState.ended) {
      _state = CallState.idle;
      _peer = null;
      _statusMessage = null;
      notifyListeners();
    }
  }

  Future<void> _createPeerConnection() async {
    if (!_rendererReady) {
      await remoteRenderer.initialize();
      _rendererReady = true;
    }

    _localStream = await navigator.mediaDevices.getUserMedia({
      'audio': true,
      'video': false,
    });

    final pc = await createPeerConnection(iceServers);

    for (final track in _localStream!.getTracks()) {
      await pc.addTrack(track, _localStream!);
    }

    pc.onIceCandidate = (candidate) {
      if (_peer == null) return;
      _signaling.emit('webrtc:ice-candidate', {
        'to': _peer!.id,
        'candidate': candidate.candidate,
        'sdpMid': candidate.sdpMid,
        'sdpMLineIndex': candidate.sdpMLineIndex,
      });
    };

    pc.onTrack = (event) {
      if (event.streams.isNotEmpty) {
        remoteRenderer.srcObject = event.streams.first;
        notifyListeners();
      }
    };

    pc.onConnectionState = (state) {
      if (state == RTCPeerConnectionState.RTCPeerConnectionStateConnected) {
        _set(CallState.connected, 'Connected');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateFailed) {
        _finish('Connection failed');
      } else if (state == RTCPeerConnectionState.RTCPeerConnectionStateDisconnected ||
          state == RTCPeerConnectionState.RTCPeerConnectionStateClosed) {
        if (_state == CallState.connected) _finish('Call ended');
      }
    };

    _pc = pc;
    await Helper.setSpeakerphoneOn(_speakerOn);
  }

  void _onInvite(Map<String, dynamic> data) {
    if (inCall) {
      _signaling.emit('call:reject', {'to': data['from']});
      return;
    }
    _pendingOffer = {'sdp': data['sdp'], 'type': data['type']};
    _peer = AppUser(
      id: data['from'] as String,
      name: (data['callerName'] as String?) ?? 'Unknown',
      email: '',
      online: true,
    );
    _set(CallState.incoming, 'Incoming call');
    onIncomingCall?.call(_peer!);
  }

  Future<void> _onAccept(Map<String, dynamic> data) async {
    if (_pc == null) return;
    _set(CallState.connecting, 'Connecting…');
    await _pc!.setRemoteDescription(
      RTCSessionDescription(data['sdp'] as String, data['type'] as String),
    );
    await _drainPendingCandidates();
  }

  Future<void> _onRemoteCandidate(Map<String, dynamic> data) async {
    final candidate = RTCIceCandidate(
      data['candidate'] as String?,
      data['sdpMid'] as String?,
      data['sdpMLineIndex'] as int?,
    );

    // Candidates can arrive before the remote description is set.
    if (_pc == null || await _pc!.getRemoteDescription() == null) {
      _pendingCandidates.add(candidate);
      return;
    }
    await _pc!.addCandidate(candidate);
  }

  Future<void> _drainPendingCandidates() async {
    for (final candidate in _pendingCandidates) {
      await _pc?.addCandidate(candidate);
    }
    _pendingCandidates.clear();
  }

  Future<bool> _ensureMicPermission() async {
    if (kIsWeb) return true;
    final status = await Permission.microphone.request();
    return status.isGranted;
  }

  void _finish(String message) {
    _cleanup();
    _set(CallState.ended, message);
  }

  void _cleanup() {
    _pendingCandidates.clear();
    _pendingOffer = null;
    remoteRenderer.srcObject = null;
    _localStream?.getTracks().forEach((t) => t.stop());
    _localStream?.dispose();
    _localStream = null;
    _pc?.close();
    _pc = null;
    _muted = false;
  }

  void _set(CallState state, String? message) {
    _state = state;
    _statusMessage = message;
    notifyListeners();
  }

  @override
  void dispose() {
    _cleanup();
    remoteRenderer.dispose();
    super.dispose();
  }
}
