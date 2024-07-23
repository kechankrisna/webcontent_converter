import 'package:flutter/material.dart';

/// [ErrorScreen] will be respresented on eror route not found
class ErrorScreen extends StatelessWidget {
  ///
  const ErrorScreen({required this.name, super.key, this.arguments});

  /// [name] will be route name
  final String name;

  /// [arguments] will be the route arguments object
  final dynamic arguments;

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          title: const Text('ERROR'),
        ),
        body: Center(
          child: Text('error: not found $name $arguments'),
        ),
      );
}
