import 'package:flutter/foundation.dart';

void println(String message) {
  if (kDebugMode) {
    print(message);
  }
}
