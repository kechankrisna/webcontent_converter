import 'package:webcontent_converter/revision_info.dart';
import 'chromium_helper.dart';

/// just download
void main(List<String> args) async {
  var revision = await ChromiumHelper.justDownloadChrome(
      cachePath: ChromiumInfoConfig.localChromiumDirectory);
  print("path ${revision.executablePath}");
}
