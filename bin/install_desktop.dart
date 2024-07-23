import 'package:webcontent_converter/logger.dart';
import 'package:webcontent_converter/revision_info.dart';
import 'chromium_helper.dart';

void main(List<String> args) async {
  final revision = await ChromiumHelper.downloadChrome(
    cachePath: ChromiumInfoConfig.localChromiumDirectory,
  );
  println('path ${revision.executablePath}');
}
