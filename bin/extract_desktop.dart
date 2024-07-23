import 'package:webcontent_converter/logger.dart';
import 'package:webcontent_converter/revision_info.dart';
import 'chromium_helper.dart';

/// just extract the chromium in asset directory which can be shipped with application
void main(List<String> args) async {
  final revision = await ChromiumHelper.justExtractChrome(
    cachePath: ChromiumInfoConfig.localChromiumDirectory,
  );
  println('path ${revision.executablePath}');
}
