import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
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
          title: Text('Publish Data Bug Repro'),
        ),
        body: const Center(
          child: Row(
            children: [
              ElevatedButton(
                onPressed: initializeLivekitCall,
                child: Text('Start Call'),
              ),
              ElevatedButton(onPressed: sendOneBytePayload, child: Text('Send 1b Payload')),
              ElevatedButton(onPressed: sendTwoKbPayload, child: Text('Send 2kb Payload'))
            ],
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

void sendOneBytePayload() async {
  const bytes = 1;
    await _room?.localParticipant?.publishData(Uint8List.fromList(('a' * bytes).codeUnits));
}

void sendTwoKbPayload() async {
  const bytes = 1024 * 2;
    await _room?.localParticipant?.publishData(Uint8List.fromList(('a' * bytes).codeUnits));
}

void initializeLivekitCall() async {
    final response =
      await http.Client().get(Uri.parse('http://127.0.0.1:8081/token'));
  final responseData = jsonDecode(response.body);
  final accessToken = responseData['accessToken'];
  final url = responseData['url'];
  startCallFromToken(accessToken, url);
}