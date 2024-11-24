import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_foreground_task/flutter_foreground_task.dart';
import 'package:just_audio/just_audio.dart';

void main() {
  //  initializes a communication port between the app and the foreground task.
  FlutterForegroundTask.initCommunicationPort();
  runApp(const ExampleApp());
}

// The callback function for foreground task
@pragma('vm:entry-point')
// associate task handler with audio task
void startCallback() {
  FlutterForegroundTask.setTaskHandler(AudioTaskHandler());
}

class AudioTaskHandler extends TaskHandler {
  final AudioPlayer _audioPlayer = AudioPlayer();

  // Called when the task is started.
  @override
  Future<void> onStart(DateTime timestamp, TaskStarter starter) async {
    print('Foreground task started');
    await _audioPlayer.setAsset('assets/audio/hamster.mp3');
    _audioPlayer.setLoopMode(LoopMode.one); // Loop the audio
    _audioPlayer.play();
  }

  // Called when the task is destroyed.
  @override
  // stop the audio task, clean ressrcs ...
  Future<void> onDestroy(DateTime timestamp) async {
    print('Foreground task destroyed');
    await _audioPlayer.stop();
    _audioPlayer.dispose();
  }

  //we dont need them but dart do, so we keep em empty
  @override
  void onRepeatEvent(DateTime timestamp) {}

  // Not handling data transfer for this task
  @override
  void onReceiveData(Object data) {}

// when user clicks on notif it takes him back to app
  @override
  void onNotificationPressed() {
    FlutterForegroundTask.launchApp('/');
    print('Notification pressed');
  }
}

class ExampleApp extends StatelessWidget {
  const ExampleApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      routes: {
        '/': (context) => const ExamplePage(),
      },
      initialRoute: '/',
    );
  }
}

class ExamplePage extends StatefulWidget {
  const ExamplePage({super.key});

  @override
  State<StatefulWidget> createState() => _ExamplePageState();
}

class _ExamplePageState extends State<ExamplePage> {
  // asks for user permission b4 launchin the app
  Future<void> _requestPermissions() async {
    final NotificationPermission notificationPermission =
        await FlutterForegroundTask.checkNotificationPermission();
    if (notificationPermission != NotificationPermission.granted) {
      await FlutterForegroundTask.requestNotificationPermission();
    }

// permission to draw over other apps
    if (Platform.isAndroid) {
      if (!await FlutterForegroundTask.canDrawOverlays) {
        await FlutterForegroundTask.openSystemAlertWindowSettings();
      }
// battery opt
      if (!await FlutterForegroundTask.isIgnoringBatteryOptimizations) {
        await FlutterForegroundTask.requestIgnoreBatteryOptimization();
      }
    }
  }

  void _initService() {
    FlutterForegroundTask.init(
      androidNotificationOptions: AndroidNotificationOptions(
        channelId: 'foreground_service',
        channelName: 'Audio Foreground Service',
        channelDescription: 'This service plays audio in the background.',
        onlyAlertOnce: true,
      ),
      iosNotificationOptions: const IOSNotificationOptions(
        showNotification: true,
        playSound: false,
      ),
      foregroundTaskOptions: ForegroundTaskOptions(
        eventAction: ForegroundTaskEventAction.nothing(),
        autoRunOnBoot: false,
        autoRunOnMyPackageReplaced: true,
        allowWakeLock: true,
        allowWifiLock: true,
      ),
    );
  }

  Future<ServiceRequestResult> _startService() async {
    if (await FlutterForegroundTask.isRunningService) {
      return FlutterForegroundTask.restartService();
    } else {
      return FlutterForegroundTask.startService(
        serviceId: 1,
        notificationTitle: 'Playing Audio',
        notificationText: 'Tap to return to the app',
        callback: startCallback,
      );
    }
  }

// is called within the button
  Future<ServiceRequestResult> _stopService() async {
    return FlutterForegroundTask.stopService();
  }

  @override
  // intialize the app
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      await _requestPermissions();
      _initService();
    });
  }

  @override
  Widget build(BuildContext context) {
    return WithForegroundTask(
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Audio Foreground Task'),
        ),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ElevatedButton(
                onPressed: _startService,
                child: const Text('Start Audio Service'),
              ),
              ElevatedButton(
                onPressed: _stopService,
                child: const Text('Stop Audio Service'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
