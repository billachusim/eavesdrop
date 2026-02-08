import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:path_provider/path_provider.dart';

// Replace with your Agora App ID
const String agoraAppId = '7cbfdc57592f47b2a939e2838238f066';

class AgoraService {
  late RtcEngine _engine;
  String? _recordingPath;
  Completer<void> _joinChannelCompleter = Completer<void>();
  bool _isInitialized = false;

  // Initialize Agora
  Future<void> initialize({
    void Function(RtcConnection, List<AudioVolumeInfo>, int, int)?
    onAudioVolumeIndication,
    void Function(RtcConnection, int, int)? onUserJoined,
    void Function(RtcConnection, int, UserOfflineReasonType)? onUserOffline,
  }) async {
    if (_isInitialized) return;
    _engine = createAgoraRtcEngine();
    await _engine.initialize(const RtcEngineContext(
      appId: agoraAppId,
      channelProfile: ChannelProfileType.channelProfileLiveBroadcasting,
    ));

    // Set up event handlers
    _engine.registerEventHandler(
      RtcEngineEventHandler(
        onJoinChannelSuccess: (RtcConnection connection, int elapsed) {
          if (!_joinChannelCompleter.isCompleted) {
            _joinChannelCompleter.complete();
          }
        },
        onLeaveChannel: (RtcConnection connection, RtcStats stats) {
          _joinChannelCompleter = Completer<void>();
        },
        onError: (err, msg) {
          // If there's an error and the completer is still waiting, complete it with an error.
          if (!_joinChannelCompleter.isCompleted) {
            _joinChannelCompleter.completeError(
                Exception('Agora Error: $err, Message: $msg'));
          }
        },
        onUserJoined: onUserJoined,
        onUserOffline: onUserOffline,
        onAudioVolumeIndication: onAudioVolumeIndication,
      ),
    );
    _isInitialized = true;
  }

  // Join a channel
  Future<void> joinChannel(String token, String channelName, int uid, ClientRoleType role) async {
    // Reset the completer before trying to join.
    if (_joinChannelCompleter.isCompleted) {
      _joinChannelCompleter = Completer<void>();
    }

    try {
      await _engine.setClientRole(role: role);
      await _engine.joinChannel(
        token: token,
        channelId: channelName,
        uid: uid,
        options: const ChannelMediaOptions(),
      );
      // Wait for onJoinChannelSuccess or an error
      return _joinChannelCompleter.future;
    } catch (e) {
      // Ensure the completer is handled in case of an immediate exception.
      if (!_joinChannelCompleter.isCompleted) {
        _joinChannelCompleter.completeError(e);
      }
      rethrow;
    }
  }

  // Leave a channel
  Future<void> leaveChannel() async {
    // Only leave the channel, do NOT release the engine here.
    await _engine.leaveChannel();
  }

  // Dispose the engine completely
  Future<void> dispose() async {
    if (!_isInitialized) return;
    await _engine.leaveChannel();
    await _engine.release();
    _isInitialized = false;
  }

  // Mute/unmute all remote audio streams
  Future<void> muteAllRemoteAudioStreams(bool muted) async {
    if (!_isInitialized) return;
    await _engine.muteAllRemoteAudioStreams(muted);
  }

  // Mute/unmute local audio stream
  Future<void> muteLocalAudioStream(bool muted) async {
    if (!_isInitialized) return;
    await _engine.muteLocalAudioStream(muted);
  }

  // Start recording
  Future<void> startRecording() async {
    if (!_isInitialized) return;
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingPath = '${directory.path}/$fileName';
    await _engine.startAudioRecording(
      AudioRecordingConfiguration(
        filePath: _recordingPath!,
        fileRecordingType: AudioFileRecordingType.audioFileRecordingMixed,
        quality: AudioRecordingQualityType.audioRecordingQualityMedium,
      ),
    );
  }

  // Stop recording
  Future<String?> stopRecording() async {
    if (!_isInitialized) return null;
    await _engine.stopAudioRecording();
    return _recordingPath;
  }
}
