import 'dart:io';

const findString = '<body>';

const _template = """$findString
  <script src="https://html2canvas.hertzen.com/dist/html2canvas.min.js" type="text/javascript"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/jspdf/2.5.1/jspdf.umd.min.js"></script>
  <script src="https://cdn.jsdelivr.net/npm/es6-promise@4/dist/es6-promise.auto.min.js"></script>
  <script src="https://cdnjs.cloudflare.com/ajax/libs/html2pdf.js/0.10.1/html2pdf.bundle.min.js" type="text/javascript"></script>
  """;

void main(List<String> args) async {
  stdout.writeln('[Modify web/index.hml by addition html2pdf]');

  final htmlFile = File('web/index.html');

  if (!await htmlFile.exists()) {
    stdout.writeln('Cannot find web/index.html');
    exit(1);
  }

  final document = await htmlFile.readAsString();

  if (document.contains('html2canvas') || document.contains('html2pdf')) {
    stdout.writeln('Already installed, operation aborted');
    exit(2);
  }

  final resultDocument = document.replaceFirst(findString, _template);
  await htmlFile.writeAsString(resultDocument);

  stdout.writeln('installation successfully');
}