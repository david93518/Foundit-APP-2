import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:foundit/presentation/screens/item/location_picker_screen.dart';

GoRoute locationPickerStub() => GoRoute(
  path: '/location-picker',
  builder: (context, state) => Scaffold(
    body: Center(
      child: FilledButton(
        onPressed: () => context.pop(
          LocationPickedResult(
            latitude: 25.033,
            longitude: 121.535,
            address: (state.extra as Map)['query'] as String,
          ),
        ),
        child: const Text('使用此位置'),
      ),
    ),
  ),
);
