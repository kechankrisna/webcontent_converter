import 'dart:typed_data';

// import 'package:esc_pos_printer/esc_pos_printer.dart';
// import 'package:esc_pos_utils/esc_pos_utils.dart';
// import 'package:image/image.dart' as img;

class PrinterService {
  final Uint8List image;

  PrinterService(this.image);

  startPrint() async {
    // const PaperSize paper = PaperSize.mm80;
    // final profile = await CapabilityProfile.load();
    // final printer = NetworkPrinter(paper, profile);
    // final PosPrintResult res =
    //     await printer.connect('192.168.10.10', port: 9100);

    // if (res == PosPrintResult.success) {
    //   testReceipt(printer);
    //   printer.disconnect();
    // }
  }

  void testReceipt(printer) {
    // final img.Image _image = img.decodeImage(image);
    // final img.Image resize = img.copyResize(_image, width: 576);
    // printer.image(resize);
    // printer.feed(2);
    // printer.cut();
  }
}
