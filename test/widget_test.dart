import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:vegbox_driver_app/main.dart';

void main() {
  test('constructs the rider application', () {
    const app = MyApp();

    expect(app, isA<StatelessWidget>());
  });
}
