import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:livekit_client/livekit_client.dart' as livekit;
import 'package:permission_handler/permission_handler.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: Scaffold(
        appBar: AppBar(
          title: Text('Echo Cancellation Bug Repro'),
        ),
        body: Center(
          child: ElevatedButton(
            onPressed: initializeLivekitCall,
            child: Text('Start Call'),
          ),
        ),
      ),
    );
  }
}

livekit.Room? _room;
bool _connected = false;

Future<void> startCallFromToken(String accessToken, String url) async {
  print('starting call...');
  var status = await Permission.microphone.request();
  if (status != PermissionStatus.granted) {
    print('Microphone permission not granted');
    return;
  }

  try {
    _room = livekit.Room();
    await _room!.connect(
      url,
      accessToken,
      roomOptions: const livekit.RoomOptions(
        adaptiveStream: true,
        dynacast: true,
        defaultAudioCaptureOptions: livekit.AudioCaptureOptions(
          echoCancellation: true,
          autoGainControl: true,
          noiseSuppression: true,
        ),
      ),
    );
  } catch (error) {
    print('Error starting call: $error');
    stopCall();
    return;
  }

  await _room!.localParticipant?.setMicrophoneEnabled(true);
  _connected = true;
  print('connected to webrtc room: ${_room!.name}');

  handleRoomEvents();
  handleAudioEvents();
}

void stopCall() async {
  if (_connected) {
    await _room?.localParticipant?.setMicrophoneEnabled(false);
    _room?.disconnect();
    _connected = false;
    print('call ended via stopCall');
  }
}

void handleRoomEvents() {
  _room?.addListener(() {
    if (_room?.connectionState == livekit.ConnectionState.disconnected) {
      stopCall();
    }
  });
}

void handleAudioEvents() {
  _room?.addListener(() {
    for (var participant in _room!.remoteParticipants.values) {
      participant.getTrackPublications();
      for (var trackPublication in participant.trackPublications.values) {
        if (trackPublication.kind == livekit.TrackType.AUDIO) {
          if (trackPublication.subscribed == true) {
            if (trackPublication.track is livekit.RemoteAudioTrack) {
              livekit.RemoteAudioTrack audioTrack =
                  trackPublication.track as livekit.RemoteAudioTrack;
              audioTrack.addListener(() {});
            }
          }
        }
      }
    }
  });
}

void initializeLivekitCall() async {
  String accessToken;
  String url = 'https://kitt.livekit.io/api/token';
  var response = await http.post(
    Uri.parse(url),
  );
  var responseData = jsonDecode(response.body);
  accessToken = responseData['accessToken'];
  var roomUrl = 'wss://python-agents-kitt-idz0ds17.livekit.cloud';
  startCallFromToken(accessToken, roomUrl);
}