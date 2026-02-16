import 'package:audioplayers/audioplayers.dart';
import 'package:vibration/vibration.dart';

class RingtoneService {
  static final AudioPlayer _audioPlayer = AudioPlayer();
  static bool _isPlaying = false;

  static Future<void> playRingtone() async {
    if (_isPlaying) return; // Don't start if already playing

    _isPlaying = true;
    // Set the release mode to loop so the sound repeats
    await _audioPlayer.setReleaseMode(ReleaseMode.loop);
    // Assuming you have a ringing.mp3 in your assets/audio/ folder
    await _audioPlayer.play(AssetSource('audio/beep-329314.mp3'));

    // Vibrate in a loop
    if (await Vibration.hasVibrator() ?? false) {
      // Pattern: Vibrate for 500ms, wait 1000ms, repeat
      Vibration.vibrate(pattern: [500, 1000, 500, 1000], repeat: 0);
    }
  }

  static Future<void> stopRingtone() async {
    if (!_isPlaying) return; // Nothing to stop

    await _audioPlayer.stop();
    if (await Vibration.hasVibrator() ?? false) {
      Vibration.cancel();
    }
    _isPlaying = false;
  }
}