import 'package:flutter/foundation.dart';

num _pxToInches(num px) => px / 96;

num _cmToInches(num cm) => _pxToInches(cm / 37.8);

num _mmToInches(num mm) => _cmToInches(mm / 10);

class PaperFormat {
  static const letter = PaperFormat.inches(width: 8.5, height: 11);
  static const legal = PaperFormat.inches(width: 8.5, height: 14);
  static const tabloid = PaperFormat.inches(width: 11, height: 17);
  static const ledger = PaperFormat.inches(width: 17, height: 11);
  static const a0 = PaperFormat.inches(width: 33.1, height: 46.8);
  static const a1 = PaperFormat.inches(width: 23.4, height: 33.1);
  static const a2 = PaperFormat.inches(width: 16.54, height: 23.4);
  static const a3 = PaperFormat.inches(width: 11.7, height: 16.54);
  static const a4 = PaperFormat.inches(width: 8.27, height: 11.7);
  static const a5 = PaperFormat.inches(width: 5.83, height: 8.27);
  static const a6 = PaperFormat.inches(width: 4.13, height: 5.83);

  /// [value] is paper size in string | default: a4
  /// Example : `PaperFormat.fromString("a4")`
  factory PaperFormat.fromString(String value) {
    switch (value.toLowerCase()) {
      case "letter":
        return PaperFormat.letter;
        break;
      case "legal":
        return PaperFormat.legal;
        break;
      case "tabloid":
        return PaperFormat.tabloid;
        break;
      case "ledger":
        return PaperFormat.ledger;
        break;
      case "a0":
        return PaperFormat.a0;
        break;
      case "a1":
        return PaperFormat.a1;
        break;
      case "a2":
        return PaperFormat.a2;
        break;
      case "a3":
        return PaperFormat.a3;
        break;
      case "a4":
        return PaperFormat.a4;
        break;
      case "a5":
        return PaperFormat.a5;
        break;
      case "a6":
        return PaperFormat.a6;
        break;
      default:
        return PaperFormat.a4;
    }
  }

  final num width, height;

  const PaperFormat.inches({required this.width, required this.height});

  PaperFormat.px({required int width, required int height})
      : width = _pxToInches(width),
        height = _pxToInches(height);

  PaperFormat.cm({required num width, required num height})
      : width = _cmToInches(width),
        height = _cmToInches(height);

  PaperFormat.mm({required num width, required num height})
      : width = _mmToInches(width),
        height = _mmToInches(height);

  Map<String, num> toMap() {
    return {
      "width": width,
      "height": height,
    };
  }

  @override
  String toString() => 'PaperFormat.inches(width: $width, height: $height)';
}

class PdfMargins {
  num top, bottom, left, right;

  static final PdfMargins zero = PdfMargins.inches();

  PdfMargins({this.top: 0, this.bottom: 0, this.left: 0, this.right: 0});

  PdfMargins.inches({num? top, num? bottom, num? left, num? right})
      : top = top ?? 0,
        bottom = bottom ?? 0,
        left = left ?? 0,
        right = right ?? 0;

  /// [PdfMargins.px] then return in Inches
  factory PdfMargins.px(
      {int top: 0, int bottom: 0, int left: 0, int right: 0}) {
    return PdfMargins.inches(
      top: _pxToInches(top),
      bottom: _pxToInches(bottom),
      left: _pxToInches(left),
      right: _pxToInches(right),
    );
  }

  /// [PdfMargins.cm] then return in Inches
  factory PdfMargins.cm(
      {num top: 0, num bottom: 0, num left: 0, num right: 0}) {
    return PdfMargins.inches(
      top: _cmToInches(top),
      bottom: _cmToInches(bottom),
      left: _cmToInches(left),
      right: _cmToInches(right),
    );
  }

  /// [PdfMargins.mm] then return in Inches
  factory PdfMargins.mm(
      {num top: 0, num bottom: 0, num left: 0, num right: 0}) {
    return PdfMargins.inches(
      top: _mmToInches(top),
      bottom: _mmToInches(bottom),
      left: _mmToInches(left),
      right: _mmToInches(right),
    );
  }

  Map<String, num> toMap() {
    return {
      "top": top,
      "bottom": bottom,
      "left": left,
      "right": right,
    };
  }

  @override
  String toString() =>
      'PdfMargins.inches(top: $top, bottom: $bottom, left: $left, right: $right)';
}
