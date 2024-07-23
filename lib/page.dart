num _pxToInches(num px) => px / 96;

num _cmToInches(num cm) => cm / 2.54;

num _mmToInches(num mm) => _cmToInches(mm / 10);

class PaperFormat {
  static PaperFormat a3({required bool isPortrait}) =>
      PaperFormat.inches(width: 11.69, height: 16.54, isPortrait: isPortrait);
  static PaperFormat a4({required bool isPortrait}) =>
      PaperFormat.inches(width: 8.27, height: 11.69, isPortrait: isPortrait);
  static PaperFormat a5({required bool isPortrait}) =>
      PaperFormat.inches(width: 5.83, height: 8.27, isPortrait: isPortrait);
  static PaperFormat b4({required bool isPortrait}) =>
      PaperFormat.inches(width: 9.84, height: 13.90, isPortrait: isPortrait);
  static PaperFormat b5({required bool isPortrait}) =>
      PaperFormat.inches(width: 6.93, height: 9.84, isPortrait: isPortrait);
  static PaperFormat executive({required bool isPortrait}) =>
      PaperFormat.inches(width: 7.25, height: 10.5, isPortrait: isPortrait);
  static PaperFormat legal({required bool isPortrait}) =>
      PaperFormat.inches(width: 8.5, height: 14, isPortrait: isPortrait);
  static PaperFormat letter({required bool isPortrait}) =>
      PaperFormat.inches(width: 8.5, height: 11, isPortrait: isPortrait);
  static PaperFormat tabloid({required bool isPortrait}) =>
      PaperFormat.inches(width: 11, height: 17, isPortrait: isPortrait);

  const PaperFormat.inches({
    required this.width,
    required this.height,
    required this.isPortrait,
  });

  final num width, height;
  final bool isPortrait;

  PaperFormat.px({
    required int width,
    required int height,
    required this.isPortrait,
  })  : width = _pxToInches(width),
        height = _pxToInches(height);

  PaperFormat.cm({
    required num width,
    required num height,
    required this.isPortrait,
  })  : width = _cmToInches(width),
        height = _cmToInches(height);

  PaperFormat.mm({
    required num width,
    required num height,
    required this.isPortrait,
  })  : width = _mmToInches(width),
        height = _mmToInches(height);

  Map<String, num> toMap() {
    return {
      "width": isPortrait ? width : height,
      "height": isPortrait ? height : width,
    };
  }

  @override
  String toString() => 'PaperFormat.inches(width: $width, height: $height)';
}

class PdfMargins {
  num top, bottom, left, right;

  static final PdfMargins zero = PdfMargins.inches();

  PdfMargins({this.top = 0, this.bottom = 0, this.left = 0, this.right = 0});

  PdfMargins.inches({num? top, num? bottom, num? left, num? right})
      : top = top ?? 0,
        bottom = bottom ?? 0,
        left = left ?? 0,
        right = right ?? 0;

  /// [PdfMargins.px] then return in Inches
  factory PdfMargins.px({int top = 0, int bottom = 0, int left = 0, int right = 0}) {
    return PdfMargins.inches(
      top: _pxToInches(top),
      bottom: _pxToInches(bottom),
      left: _pxToInches(left),
      right: _pxToInches(right),
    );
  }

  /// [PdfMargins.cm] then return in Inches
  factory PdfMargins.cm({num top = 0, num bottom = 0, num left = 0, num right = 0}) {
    return PdfMargins.inches(
      top: _cmToInches(top),
      bottom: _cmToInches(bottom),
      left: _cmToInches(left),
      right: _cmToInches(right),
    );
  }

  /// [PdfMargins.mm] then return in Inches
  factory PdfMargins.mm({num top = 0, num bottom = 0, num left = 0, num right = 0}) {
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
  String toString() => 'PdfMargins.inches(top: $top, bottom: $bottom, left: $left, right: $right)';
}
