// import 'dart:async';
// // ignore: avoid_web_libraries_in_flutter
// import 'dart:html' as html;
// import 'dart:typed_data';

// class WebSupport {
//   static Future<String> toBlob() async {
//     final canvas = html.CanvasElement();
//     canvas.innerHtml = """
//     <!DOCTYPE html>
//       <html>
//       <head>
//       <style>
//       body{
//         width: 300px;
//         height:300px;
//         background-color:blue;
//       }
//       </style>
//       </head>
//       <body>


//       <h1>My First Heading</h1>

//       <p>My first paragraph.</p>

//       </body>
//       </html>
//     """;
//     canvas.context2D;
//     final image = canvas.toDataUrl('image/png');
//     // var img = new html.ImageElement();
//     // img.src = image;
//     // html.document.body.children.add(img);
//     return image;

//     // final blob = await canvas.toBlob('image/jpeg', 1);
//     // return blob;
//   }

//   static Future<Uint8List> getBlobData(html.Blob blob) async {
//     final completer = Completer<Uint8List>();
//     final reader = html.FileReader();
//     reader.readAsArrayBuffer(blob);
//     reader.onLoad.listen((_) => completer.complete(reader.result));
//     return (await completer.future);
//   }
// }
