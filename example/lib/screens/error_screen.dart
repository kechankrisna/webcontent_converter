import 'package:flutter/material.dart';

/// [ErrorScreen] will be respresented on eror route not found
class ErrorScreen extends StatelessWidget {
  /// [name] will be route name
  final String name;

  /// [arguments] will be the route arguments object
  final dynamic arguments;

  ///
  const ErrorScreen({Key? key, required this.name, this.arguments})
      : super(key: key);

  @override
  Widget build(BuildContext context) {
    // print(arguments);
    return Scaffold(
      appBar: AppBar(
        title: Text("ERROR"),
      ),
      body: Center(
        child: Text("error: not found $name ${arguments.toString()}"),
      ),
    );
  }
}
