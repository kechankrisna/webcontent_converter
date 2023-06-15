import 'dart:async';

import 'package:flutter/services.dart';

import 'webcontent_converter_platform_interface.dart';

const MethodChannel _channel =
    MethodChannel('plugins.mylekha.app/webcontent_converter');

class MethodChannelWebcontentConverter extends WebcontentConverterPlatform {}
