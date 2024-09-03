import 'package:display/views/laptime_display_view.dart';
import 'package:flutter/material.dart';

class LaptimerView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Serial Example',
      home: LaptimeDisplayView(),
    );
  }
}
