import 'package:webcontent_converter/revision_info.dart';
import 'chromium_helper.dart';

void main(List<String> args) async {
  var revision = await ChromiumHelper.downloadChrome(
      cachePath: ChromiumInfoConfig.localChromiumDirectory);
  print("path ${revision.executablePath}");
}
