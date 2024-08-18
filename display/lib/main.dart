import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Serial Example',
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  UsbPort? _port;
  String _buffer = "";
  String _time = "";
  String _distance = "";
  String _message = "データを待っています...";
  FlutterTts flutterTts = FlutterTts();

  @override
  void initState() {
    super.initState();
    _getUsbDevices();
    flutterTts.setLanguage("ja-JP");
  }

  Future<void> _getUsbDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isNotEmpty) {
      UsbDevice device = devices[0];
      _connectToDevice(device);
    } else {
      setState(() {
        _message = "USB デバイスへのアクセスが許可されていません";
      });
    }
  }

  Future<void> _connectToDevice(UsbDevice device) async {
    _port = await device.create();
    final port = _port;
    if (port == null) {
      setState(() {
        _message = "デバイスがありません";
      });
      return;
    }
    bool openResult = await port.open();
    if (!openResult) {
      setState(() {
        _message = "デバイスに接続できませんでした";
      });
      return;
    }

    port.setDTR(true);
    port.setRTS(true);
    await port.setPortParameters(
      9600, // ボーレート (Arduino の設定に合わせる)
      UsbPort.DATABITS_8,
      UsbPort.STOPBITS_1,
      UsbPort.PARITY_NONE,
    );

    port.inputStream!.listen((Uint8List data) {
      _buffer += String.fromCharCodes(data);
      if (_buffer.contains("\n")) {
        final List<String> dataFromDevice =
            _buffer.replaceAll("\n", "").split(",");
        setState(() {
          _time = dataFromDevice[0];
          _distance = dataFromDevice[1];
          _message = "";
        });
        _speak(_time);
        _buffer = "";
      }
    });
  }

  String formatDuration(String milliseconds) {
    final ms = int.tryParse(milliseconds);
    if (ms == null) {
      return "";
    }
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    int millis = ms % 1000;

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    String millisStr = millis.toString().padLeft(3, '0');

    return "$minutesStr:$secondsStr:$millisStr";
  }

  String formatDurationToSpeak(String milliseconds) {
    final ms = int.tryParse(milliseconds);
    if (ms == null) {
      return "";
    }
    int minutes = (ms ~/ 60000);
    int seconds = (ms % 60000) ~/ 1000;
    int millis = ms % 1000;

    String minutesStr = minutes.toString().padLeft(2, '0');
    String secondsStr = seconds.toString().padLeft(2, '0');
    String millisStr = millis.toString().padLeft(3, '0');

    return '$minutesStr分 $secondsStr秒 $millisStr';
  }

  Future _speak(String ms) async {
    var japaneseTime = formatDurationToSpeak(ms);
    await flutterTts.speak(japaneseTime);
  }

  @override
  void dispose() {
    _port?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('USBデータ受信'),
      ),
      body: Center(
        child: _message.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center, // 垂直方向の中央配置
                crossAxisAlignment: CrossAxisAlignment.center, // 水平方向の中央配置
                children: <Widget>[
                    Text(
                      formatDuration(_time),
                      style: TextStyle(fontSize: 144),
                    ),
                    Text(
                      "distance: $_distance cm",
                      style: TextStyle(fontSize: 24),
                    ),
                  ])
            : Text(
                _message,
                style: TextStyle(fontSize: 24),
              ),
      ),
    );
  }
}
