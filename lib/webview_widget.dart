import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

class WebViewWidget extends StatelessWidget {
  final String content;
  final double? width;
  final double? height;

  const WebViewWidget(this.content, {Key? key, this.width, this.height})
      : super(key: key);
  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(builder: (_, ctn) {
      final _width = width ?? ctn.maxWidth;
      final _height = height ?? ctn.maxHeight;
      return SizedBox(
        width: _width,
        height: _height,
        child: child(_width, _height),
      );
    });
  }

  Widget child(double width, double height) {
    /// using [Hybrid Composition]
    /// ref: `https://flutter.dev/docs/development/platform-integration/platform-views`
    // This is used in the platform side to register the view.
    final String viewType = 'webview-view-type';
    // Pass parameters to the platform side.
    final Map<String, dynamic> creationParams = <String, dynamic>{};
    creationParams['width'] = width;
    creationParams['height'] = height;
    creationParams['content'] = content;
    // WebcontentConverter.logger("creationParams $creationParams");
    switch (defaultTargetPlatform) {
      case TargetPlatform.android:
        return PlatformViewLink(
          viewType: viewType,
          surfaceFactory:
              (BuildContext context, PlatformViewController controller) {
            return AndroidViewSurface(
              controller: controller as AndroidViewController,
              gestureRecognizers: const <
                  Factory<OneSequenceGestureRecognizer>>{},
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
            );
          },
          onCreatePlatformView: (PlatformViewCreationParams params) {
            return PlatformViewsService.initSurfaceAndroidView(
              id: params.id,
              viewType: viewType,
              layoutDirection: TextDirection.ltr,
              creationParams: creationParams,
              creationParamsCodec: StandardMessageCodec(),
            )
              ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
              ..create();
          },
        );
      case TargetPlatform.iOS:
        return UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        );

      default:
        throw UnsupportedError("Unsupported platform view");
    }
  }
}
