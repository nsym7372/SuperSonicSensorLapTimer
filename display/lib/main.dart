import 'package:camera/camera.dart';
import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:image_gallery_saver/image_gallery_saver.dart';
import 'package:usb_serial/usb_serial.dart';
import 'dart:typed_data';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final cameras = await availableCameras();
  final frontCamera = cameras.firstWhere(
      (camera) => camera.lensDirection == CameraLensDirection.front);

  runApp(MyApp(camera: frontCamera));
}

class MyApp extends StatelessWidget {
  final CameraDescription camera;
  const MyApp({super.key, required this.camera});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'USB Serial Example',
      home: MyHomePage(camera: camera),
    );
  }
}

class MyHomePage extends StatefulWidget {
  final CameraDescription camera;
  const MyHomePage({required this.camera});

  @override
  // ignore: library_private_types_in_public_api
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  UsbPort? _port;
  String _buffer = "";
  String _ms = "";
  String _distance = "";
  String _message = "データを待っています...";
  String _photoMessage = "";
  final FlutterTts _flutterTts = FlutterTts();
  CameraController? _cameraController;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    if (await _isEmulator()) {
      _initializeEmulator();
    } else {
      _initializeRealDevice();
    }
  }

  void _initializeEmulator() {
    setState(() {
      _ms = "5999999"; // 99:59.999
      _distance = "9999";
      _message = "";
    });
  }

  void _initializeRealDevice() async {
    _flutterTts.setLanguage("ja-JP");
    _flutterTts.setSpeechRate(0.4);
    UsbSerial.usbEventStream?.listen((UsbEvent event) {
      if (event.event == UsbEvent.ACTION_USB_ATTACHED ||
          event.event == UsbEvent.ACTION_USB_DETACHED) {
        _getUsbDevices();
      }
    });

    _cameraController = CameraController(widget.camera, ResolutionPreset.high);
    await _cameraController!.initialize();
  }

  Future<bool> _isEmulator() async {
    final info = DeviceInfoPlugin();
    final androidInfo = await info.androidInfo;
    return !androidInfo.isPhysicalDevice;
  }

  Future<void> _getUsbDevices() async {
    List<UsbDevice> devices = await UsbSerial.listDevices();
    if (devices.isNotEmpty) {
      UsbDevice device = devices[0];
      _connectToDevice(device);
    } else {
      _setUsbConnectionError();
    }
  }

  Future<void> _connectToDevice(UsbDevice device) async {
    _port = await device.create();
    final port = _port;
    if (port == null) {
      _setUsbConnectionError();
      return;
    }
    bool openResult = await port.open();
    if (!openResult) {
      _setUsbConnectionError();
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
      _receiveData(data);
    });
  }

  void _receiveData(Uint8List data) {
    _buffer += String.fromCharCodes(data);
    if (_buffer.contains("\n")) {
      final List<String> dataFromDevice =
          _buffer.replaceAll("\n", "").split(",");
      setState(() {
        _ms = dataFromDevice[0];
        _distance = dataFromDevice[1];
        _message = "";
      });
      _speak(_ms);
      _buffer = "";

      _takePicture();
    }
  }

  Map<String, int>? _parseDuration(String milliseconds) {
    final msValue = int.tryParse(milliseconds);
    if (msValue == null) {
      return null;
    }
    return {
      "min": (msValue ~/ 60000),
      "sec": (msValue % 60000) ~/ 1000,
      "ms": msValue % 1000
    };
  }

  String _formatDuration(String milliseconds) {
    var duration = _parseDuration(milliseconds);
    if (duration == null) {
      return "";
    }

    String minutesStr = duration["min"].toString().padLeft(2, '0');
    String secondsStr = duration["sec"].toString().padLeft(2, '0');
    String millisStr = duration["ms"].toString().padLeft(3, '0');

    return "$minutesStr:$secondsStr.$millisStr";
  }

  String _formatDurationToSpeak(String milliseconds) {
    var duration = _parseDuration(milliseconds);
    if (duration == null) {
      return "";
    }

    String minutesStr =
        duration["min"] == 0 ? "" : '${duration["min"].toString()}分';
    String secondsStr = duration["sec"].toString();
    String millisStr =
        duration["ms"].toString().padLeft(3, '0').replaceAll("", " ");

    return '$minutesStr $secondsStr秒 $millisStr';
  }

  void _setUsbConnectionError() {
    setState(() {
      _message = "USBデバイスに接続できません";
    });
  }

  Future _speak(String ms) async {
    var japaneseTime = _formatDurationToSpeak(ms);
    await _flutterTts.speak(japaneseTime);
  }

  Future<void> _takePicture() async {
    if (!_cameraController!.value.isInitialized) {
      return;
    }

    try {
      await Future.delayed(Duration(milliseconds: 500));
      final XFile pictrue = await _cameraController!.takePicture();
      final Uint8List imageData = await pictrue.readAsBytes();
      final ret = await ImageGallerySaver.saveImage(imageData);
      setState(() {
        _photoMessage = 'Picture saved to $ret';
      });
    } catch (e) {
      setState(() {
        _photoMessage = 'Error taking picture: $e';
      });
    }
  }

  @override
  void dispose() {
    _port?.close();
    _cameraController?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Center(
        child: _message.isEmpty
            ? Column(
                mainAxisAlignment: MainAxisAlignment.center, // 垂直方向の中央配置
                crossAxisAlignment: CrossAxisAlignment.center, // 水平方向の中央配置
                children: <Widget>[
                    Text(
                      _formatDuration(_ms),
                      style: TextStyle(fontSize: 144, color: Colors.white),
                    ),
                    Text(
                      "distance: $_distance cm",
                      style: TextStyle(fontSize: 24, color: Colors.white),
                    ),
                    Text(
                      "photo: $_photoMessage",
                      style: TextStyle(fontSize: 1, color: Colors.white),
                    ),
                  ])
            : Text(
                _message,
                style: TextStyle(fontSize: 24, color: Colors.white),
              ),
      ),
    );
  }
}
