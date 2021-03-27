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

  final num width, height;

  const PaperFormat.inches({@required this.width, @required this.height});

  PaperFormat.px({@required int width, @required int height})
      : width = _pxToInches(width),
        height = _pxToInches(height);

  PaperFormat.cm({@required num width, @required num height})
      : width = _cmToInches(width),
        height = _cmToInches(height);

  PaperFormat.mm({@required num width, @required num height})
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

  PdfMargins.inches({num top, num bottom, num left, num right})
      : top = top ?? 0,
        bottom = bottom ?? 0,
        left = left ?? 0,
        right = right ?? 0;

  /// [PdfMargins.px] then return in Inches
  factory PdfMargins.px(
      {int top: 0, int bottom: 0, int left: 0, int right: 0}) {
    return PdfMargins.inches(
      top: _pxToInches(top ?? 0),
      bottom: _pxToInches(bottom ?? 0),
      left: _pxToInches(left ?? 0),
      right: _pxToInches(right ?? 0),
    );
  }

  /// [PdfMargins.cm] then return in Inches
  factory PdfMargins.cm(
      {num top: 0, num bottom: 0, num left: 0, num right: 0}) {
    return PdfMargins.inches(
      top: _cmToInches(top ?? 0),
      bottom: _cmToInches(bottom ?? 0),
      left: _cmToInches(left ?? 0),
      right: _cmToInches(right ?? 0),
    );
  }

  /// [PdfMargins.mm] then return in Inches
  factory PdfMargins.mm(
      {num top: 0, num bottom: 0, num left: 0, num right: 0}) {
    return PdfMargins.inches(
      top: _mmToInches(top ?? 0),
      bottom: _mmToInches(bottom ?? 0),
      left: _mmToInches(left ?? 0),
      right: _mmToInches(right ?? 0),
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
