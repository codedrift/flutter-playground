
import 'package:flutter/material.dart';
import 'constants.dart';
import 'transcribe.dart';
import 'theme.dart';

void main() => runApp(const MainApp());


class MainApp extends StatelessWidget {
  const MainApp({Key? key}) : super(key: key);
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: appTitle,
      theme: appTheme,
      home: const TranscribeView(),
    );
  }
}

