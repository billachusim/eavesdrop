import 'dart:async';
import 'package:agora_rtc_engine/agora_rtc_engine.dart';
import 'package:path_provider/path_provider.dart';

// Replace with your Agora App ID
const String agoraAppId = '7cbfdc57592f47b2a939e2838238f066';

class AgoraService {
  late RtcEngine _engine;
  String? _recordingPath;
  Completer<void> _joinChannelCompleter = Completer<void>();

  // Initialize Agora
  Future<void> initialize() async {
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
        onUserJoined: (RtcConnection connection, int remoteUid, int elapsed) {
          // print('userJoined $remoteUid');
        },
        onUserOffline: (RtcConnection connection, int remoteUid, UserOfflineReasonType reason) {
          // print('userOffline $remoteUid');
        },
      ),
    );
  }

  // Join a channel
  Future<void> joinChannel(String token, String channelName, int uid, ClientRoleType role) async {
    await _engine.setClientRole(role: role);
    await _engine.joinChannel(
      token: token,
      channelId: channelName,
      uid: uid,
      options: const ChannelMediaOptions(),
    );
    return _joinChannelCompleter.future;
  }

  // Leave a channel
  Future<void> leaveChannel() async {
    await _engine.leaveChannel();
    await _engine.release();
  }

  // Mute/unmute all remote audio streams
  Future<void> muteAllRemoteAudioStreams(bool muted) async {
    await _engine.muteAllRemoteAudioStreams(muted);
  }

  // Mute/unmute local audio stream
  Future<void> muteLocalAudioStream(bool muted) async {
    await _engine.muteLocalAudioStream(muted);
  }

  // Start recording
  Future<void> startRecording() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = '${DateTime.now().millisecondsSinceEpoch}.aac';
    _recordingPath = '${directory.path}/$fileName';
    await _engine.startAudioRecording(
      AudioRecordingConfiguration(
        filePath: _recordingPath!,
        // This was the missing parameter causing the error
        fileRecordingType: AudioFileRecordingType.audioFileRecordingMixed,
        quality: AudioRecordingQualityType.audioRecordingQualityMedium,
      ),
    );
  }

  // Stop recording
  Future<String?> stopRecording() async {
    await _engine.stopAudioRecording();
    return _recordingPath;
  }
}
