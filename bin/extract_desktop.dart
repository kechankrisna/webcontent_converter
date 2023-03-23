import 'package:webcontent_converter/revision_info.dart';
import 'chromium_helper.dart';

/// just extract the chromium in asset directory which can be shipped with application
void main(List<String> args) async {
  var revision = await ChromiumHelper.justExtractChrome(
      cachePath: ChromiumInfoConfig.localChromiumDirectory);
  print("path ${revision.executablePath}");
}
