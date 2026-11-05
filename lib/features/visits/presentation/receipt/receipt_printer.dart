import 'dart:typed_data';

import 'package:printing/printing.dart';

/// Hands a PDF to the platform print dialog (browser print on web, share
/// sheet on mobile). Abstract so tests record the bytes instead.
abstract class ReceiptPrinter {
  Future<void> print({required Uint8List bytes, required String name});
}

class PrintingReceiptPrinter implements ReceiptPrinter {
  const PrintingReceiptPrinter();

  @override
  Future<void> print({required Uint8List bytes, required String name}) async {
    await Printing.layoutPdf(onLayout: (_) async => bytes, name: name);
  }
}
