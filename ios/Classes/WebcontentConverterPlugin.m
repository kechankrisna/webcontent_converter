#import "WebcontentConverterPlugin.h"
#if __has_include(<webcontent_converter/webcontent_converter-Swift.h>)
#import <webcontent_converter/webcontent_converter-Swift.h>
#else
// Support project import fallback if the generated compatibility header
// is not copied when this plugin is created as a library.
// https://forums.swift.org/t/swift-static-libraries-dont-copy-generated-objective-c-header/19816
#import "webcontent_converter-Swift.h"
#endif

@implementation WebcontentConverterPlugin
+ (void)registerWithRegistrar:(NSObject<FlutterPluginRegistrar>*)registrar {
  [SwiftWebcontentConverterPlugin registerWithRegistrar:registrar];
}
@end
