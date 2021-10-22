import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_sound/flutter_sound.dart';
import 'package:http_parser/http_parser.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:sprintf/sprintf.dart';
import 'dart:developer' as developer;
import 'constants.dart';
import 'theme.dart';
import 'package:dio/dio.dart';

class TranscribeView extends StatefulWidget {
  const TranscribeView({Key? key}) : super(key: key);

  @override
  _TranscribeViewState createState() => _TranscribeViewState();
}

class _TranscribeViewState extends State<TranscribeView> {
  final _results = <String>[];
  var _recordings = <String>[];
  final _record = Record();
  var _isRecording = false;
  var _isTranscribing = false;
  final FlutterSoundPlayer? _mPlayer = FlutterSoundPlayer();
  bool _mPlayerIsInited = false;

  @override
  initState() {
    super.initState();
    _loadRecordings();
    _mPlayer!.openAudioSession().then((value) {
      setState(() {
        _mPlayerIsInited = true;
      });
    });
  }

  Widget _buildRow(String text) {
    return ListTile(
      title: Text(text),
      onTap: () { _playFile(text); },
    );
  }

  Future<void> _playFile(String file) async {
    await _mPlayer!.startPlayer(
    fromURI: file,
    codec: Codec.aacMP4,
    whenFinished: () {
    setState(() {});
    });
  }

  Widget _buildList() {
    return ListView.builder(
        key: ValueKey(_results),
        padding: const EdgeInsets.all(16.0),
        itemCount: _results.length * 2,
        itemBuilder: (context, i) {
          if (i.isOdd) return const Divider();
          final index = i ~/ 2;

          return _buildRow(_results[index]);
        });
  }

  Widget _recordButton() {
    return FloatingActionButton.extended(
      key: ValueKey(_isRecording),
      onPressed: () async {
        toggleRecord();
        // fetchSomething();
        // Add your onPressed code here!
        // bool result = await Record.hasPermission();
      },
      label: _isTranscribing ? const Text('Transcribing...') : _isRecording ? const Text('Recording...') : const Text('Record'),
      icon: _isTranscribing ? const CircularProgressIndicator(color: Colors.white) : const Icon(Icons.  mic),
      backgroundColor: Colors.red,
    );
    // return FutureBuilder<bool>(future: _record.isRecording(), key: ValueKey(_results),builder: (BuildContext context, AsyncSnapshot<bool> snapshot) {
    //   return FloatingActionButton.extended(
    //     onPressed: () {
    //       toggleRecord();
    //       // fetchSomething();
    //       // Add your onPressed code here!
    //       // bool result = await Record.hasPermission();
    //     },
    //     label: snapshot.data == true ? const Text('Recording...') : const Text('Record') ,
    //     icon: const Icon(Icons.mic),
    //     backgroundColor: Colors.red,
    //   );
    // });
  }

  Future<void> startRecord() async {
    developer.log("Start record");

    var record = Record();
    bool result = await record.hasPermission();
    if (!result) {
      developer.log("User denied permission");
      return;
    }
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;

    var now = DateTime.now().toUtc().millisecondsSinceEpoch;

    var recordingPath = sprintf('%s/recording_%s.m4a', [tempPath, now]);
    await record.start(
      path: recordingPath,
      encoder: AudioEncoder.AAC, // by default
    );
    setState(() {
      _isRecording = true;
    });
  }

  Future<void> stopRecord() async {
    developer.log("Stop record");
   var path = await _record.stop();
   if(path != null) {
    transcribeFile(path);
   }
    _loadRecordings();
    setState(() {
      _isRecording = false;
    });
  }

  Future<void> _clearRecordings() async {
    developer.log("Clear recordings");
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    final dir = Directory(tempPath);
    await for (var entity in dir.list(recursive: true)) {
      await entity.delete();
    }

    setState(() {
      _recordings = [];
    });
  }

  Future<void> _loadRecordings() async {
    developer.log("Load recordings");
    Directory tempDir = await getTemporaryDirectory();
    String tempPath = tempDir.path;
    final dir = Directory(tempPath);
    var items = <String>[];
    await for (var entity in dir.list(recursive: true)) {
      // await entity.delete();
      items.add(entity.path);
    }
    setState(() {
      _recordings = items;
    });
  }

  Future<void> toggleRecord() async {
    bool isRecording = await _record.isRecording();
    if (isRecording) {
      stopRecord();
    } else {
      startRecord();
    }
  }

  Future<void> transcribeFile(String filepath) async {
    setState(() {
      _isTranscribing = true;
    });
    var count = 0;
    var formData = FormData.fromMap({
    "locale":  "de-DE",
    "timestamp" : 0,
    'audio': await MultipartFile.fromFile(filepath, filename: 'file.m4a', contentType: MediaType("audio","mp4")),
    });

    var response = await Dio().post('https://api.sipgate.ai/speech/transcribe', data: formData, options: Options(
      headers: {
        Headers.contentTypeHeader: "multipart/form-data",
        "Authorization": sprintf("Bearer %s", [apiKey]),
      },
    ));
    var transcriptionId = response.data["transcriptionId"];
    developer.log('Response: ${response.data}');

    var done = false;

    while (count < 1000 && !done) {
      try {
        await Future.delayed(const Duration(seconds: 1));
        var url = sprintf("https://api.sipgate.ai/speech/transcriptions/%s", [transcriptionId]);
        developer.log("Checking " + url);
        var res = await Dio().get(url, options: Options(
          headers: {
            "Authorization": sprintf("Bearer %s", [apiKey]),
          },
        )).catchError((e) {
        developer.log('Error1: $e');
        });
        developer.log('Response: ${res.data}');
        
        var text = res.data["text"];
        var topics = res.data["topics"].join(", ");
        var fullText = sprintf("%s\nTopics: %s", [text, topics]);
        setState(() {
          _results.add(fullText);
        });
        done = true;
      } on DioError catch (e) {
        developer.log('Error2: $e');
      } catch (e) {
        developer.log('Error3: $e');
      }
    }
    setState(() {
      _isTranscribing = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: appTheme,
      home: Scaffold(
          appBar: AppBar(
            title: const Text(appTitle),
          ),
          floatingActionButton: _recordButton(),
          body: Column(
            children: <Widget>[
              ElevatedButton(
                onPressed: () {
                  _clearRecordings();
                },
                child: const Text('Clear recordings'),
              ),
              Expanded(
                child: _buildList(),
              )
            ],
          )),
    );
  }
}
