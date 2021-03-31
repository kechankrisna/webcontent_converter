import 'package:image/image.dart' as img;

extension on img.Image {
  List<img.Image> toList() {
    var images = <img.Image>[];
    var page = [height, width].uptoInt();
    int x = 0;
    int y = 0;
    for (var i = 0; i < page; i++) {
      var image = img.copyCrop(this, x, y, width, width);
      images.add(image);
      y += width;
    }
    return images;
  }
}

extension on List<num> {
  int uptoInt() {
    double result = first / last;
    if ((first ~/ last) > 0) {
      return result.toInt() + 1;
    }
    return result.toInt();
  }
}
