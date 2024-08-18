import 'package:usb_serial/usb_serial.dart';

abstract class DeviceProvider {
  Future<List<UsbDevice>> listDevices();
}
