import 'package:besprotoritsa_app/besprotoritsa_app.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

void main() {
  runApp(
    const ProviderScope(
      child: BesprotoritsaApp(),
    ),
  );
}
