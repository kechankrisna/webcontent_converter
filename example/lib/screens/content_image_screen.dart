import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'controllers/content_image_screen_controller.dart';
// import 'package:webcontent_converter_example/services/webview_helper.dart';

class ContentToImageScreen extends StatefulWidget {
  @override
  _ContentToImageScreenState createState() => _ContentToImageScreenState();
}

class _ContentToImageScreenState extends State<ContentToImageScreen> {
  late ContentImageScreenController controller = ContentImageScreenController();

  @override
  void dispose() {
    controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider.value(
      value: controller,
      child: ContentToImageScreenScaffold(),
    );
  }
}

class ContentToImageScreenScaffold extends StatelessWidget {
  const ContentToImageScreenScaffold({super.key});

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final controller = Provider.of<ContentImageScreenController>(context);
    return Scaffold(
      key: controller.scaffoldKey,
      appBar: AppBar(
        title: Text("Content to Image"),
        actions: [
          IconButton(
            icon: Icon(Icons.image),
            onPressed: () {
              Future.forEach(
                  List.generate(controller.counter, (index) => null).toList(),
                  (i) async {
                try {
                  await controller.convert();
                  await Future.delayed(Duration(seconds: 5));
                } catch (e) {
                  ///
                }
              });
            },
          ),
          IconButton(
            icon: Icon(Icons.wifi_rounded),
            onPressed: controller.startPrintWireless,
          ),
          IconButton(
            icon: Icon(Icons.bluetooth),
            onPressed: controller.startPrintBluetooth,
          ),
          IconButton(
              onPressed: () {
                if (controller.scaffoldKey.currentState == null) return;
                controller.scaffoldKey.currentState!.openEndDrawer();
              },
              icon: Icon(Icons.menu))
        ],
      ),
      endDrawer: Drawer(
        child: ListView(
          children: [
            ListTile(
              title: Text("counter is ${controller.counter}"),
              subtitle: Row(
                children: [
                  IconButton(
                      onPressed: () {
                        controller.changeCounter(1);
                      },
                      icon: Icon(Icons.refresh)),
                  IconButton(
                      onPressed: () {
                        controller.changeCounter(controller.counter - 1);
                      },
                      icon: Icon(Icons.remove)),
                  IconButton(
                      onPressed: () {
                        controller.changeCounter(controller.counter + 1);
                      },
                      icon: Icon(Icons.add)),
                ],
              ),
            ),
          ],
        ),
      ),
      body: Container(
        color: Colors.white,
        alignment: Alignment.topCenter,
        child: Row(
          children: [
            if (size.width > 600)
              Expanded(
                child: Container(
                  padding: EdgeInsets.all(8),
                  constraints: BoxConstraints(
                    maxWidth: size.width / 2,
                    maxHeight: size.height,
                  ),
                  child: TextFormField(
                    maxLines: null,
                    controller: controller.textEditingController,
                  ),
                ),
              ),
            Expanded(
              child: Container(
                constraints: BoxConstraints(
                  maxWidth: size.width / 2,
                  maxHeight: size.height,
                ),
                child: SingleChildScrollView(
                  primary: false,
                  child: Column(
                    children: [
                      if (controller.file != null)
                        Container(
                          width: 400,
                          alignment: Alignment.topCenter,
                          child:
                              Image.memory(controller.file!.readAsBytesSync()),
                        ),
                      if (controller.file != null) Divider(),
                      if (controller.bytes?.isNotEmpty == true)
                        Container(
                          width: 400,
                          alignment: Alignment.topCenter,
                          decoration: BoxDecoration(
                              border: Border.all(color: Colors.blue)),
                          child: Image.memory(controller.bytes!),
                        )
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: controller.pickContent,
        child: Icon(Icons.file_open),
      ),
    );
  }
}
