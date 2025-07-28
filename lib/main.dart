import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:record/record.dart';
import 'package:just_audio/just_audio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:steganograph/steganograph.dart';
import 'package:path_provider/path_provider.dart';

void main() => runApp(MyApp());
class MyApp extends StatelessWidget {
  @override Widget build(_) => MaterialApp(home: Home());
}

class Home extends StatefulWidget { @override _HomeState createState() => _HomeState(); }
class _HomeState extends State<Home> {
  final recorder = AudioRecorder();
  final player = AudioPlayer();
  String? audioPath;
  File? coverImage, stegoImage;

  Future<void> _recordToggle() async {
    if (await recorder.isRecording()) {
      audioPath = await recorder.stop();
      setState(() {});
    } else {
      if (!await recorder.hasPermission()) return;
      await recorder.start( RecordConfig(
        encoder: AudioEncoder.wav,
        noiseSuppress: true
      ) , path: 'record.wav', );
      setState(() {});
    }
  }

  Future<void> _pickCoverImage() async {
    final img = await ImagePicker().pickImage(source: ImageSource.gallery);
    if (img != null) coverImage = File(img.path);
    setState(() {});
  }

  Future<void> _encodeStego() async {
    final bytes = await File(audioPath!).readAsBytes();
    final base64Audio = base64Encode(bytes);
    final Uint8List? stegoBytes = await Steganograph.cloakBytes(
      imageBytes: await coverImage!.readAsBytes(),
      message: base64Audio,
      outputFilePath: null,
    );
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/stego.png')..writeAsBytesSync(stegoBytes ?? []);
    stegoImage = file;
    setState(() {});
  }

  Future<void> _decodeStego() async {
    final extracted = Steganograph.uncloakBytes(await stegoImage!.readAsBytes());
    final bytes = base64Decode(extracted!);
    final dir = await getTemporaryDirectory();
    final f = File('${dir.path}/decoded.wav')..writeAsBytesSync(bytes);
    await player.setFilePath(f.path);
    player.play();
  }

  @override Widget build(BuildContext ctx) => Scaffold(
    appBar: AppBar(title: Text('Offline Audio ↔ Image Stego')),
    body: SingleChildScrollView(padding: EdgeInsets.all(16), child: Column(
      children: [
        ElevatedButton(onPressed: _recordToggle,
          child: Text((audioPath==null|| recorder.isRecording()==false) ? 'Start Recording' : 'Stop & Save')),
        if (audioPath != null) Text('Audio: $audioPath'),
        ElevatedButton(onPressed: _pickCoverImage, child: Text('Pick Cover Image')),
        if (coverImage != null) Image.file(coverImage!, height: 150),
        ElevatedButton(onPressed: (audioPath!=null && coverImage!=null) ? _encodeStego : null, child: Text('Encode Audio')),
        if (stegoImage != null) Image.file(stegoImage!, height: 150),
        ElevatedButton(onPressed: stegoImage!=null ? _decodeStego : null, child: Text('Decode & Play Audio')),
      ],
    )),
  );
}