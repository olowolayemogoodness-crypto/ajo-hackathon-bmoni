import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:ajo/data/repositories/circle_repository.dart';
import 'package:ajo/features/home/presentation/home_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class _CircleListAdapter implements HttpClientAdapter {
  RequestOptions? requestOptions;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    requestOptions = options;
    return ResponseBody.fromString(
      jsonEncode({
        'circles': [
          {'id': 'circle-1', 'name': 'Weekend Circle'},
        ],
        'requestId': 'request-1',
      }),
      200,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  test(
    'repository requests active circles and parses the response envelope',
    () async {
      final adapter = _CircleListAdapter();
      final dio = Dio(BaseOptions(baseUrl: 'https://ajo.test'))
        ..httpClientAdapter = adapter;
      final repository = CircleRepository(
        dio: dio,
        tokenProvider: () async => 'firebase-test-token',
      );

      final circles = await repository.listActiveCircles();

      expect(circles, hasLength(1));
      expect(circles.single.id, 'circle-1');
      expect(circles.single.name, 'Weekend Circle');
      expect(adapter.requestOptions?.method, 'GET');
      expect(adapter.requestOptions?.uri.path, '/v1/circles');
      expect(adapter.requestOptions?.uri.queryParameters, {
        'membership': 'active',
      });
      expect(
        adapter.requestOptions?.headers['Authorization'],
        'Bearer firebase-test-token',
      );
      dio.close();
    },
  );

  testWidgets('circle section shows loading and empty states', (tester) async {
    final completer = Completer<List<ActiveCircle>>();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackendCirclesSection(loadCircles: () => completer.future),
        ),
      ),
    );

    expect(find.text('Loading your circles...'), findsOneWidget);
    completer.complete([]);
    await tester.pumpAndSettle();

    expect(find.textContaining('No active circles yet'), findsOneWidget);
  });

  testWidgets('circle section retries errors and opens the selected circle', (
    tester,
  ) async {
    var attempts = 0;
    String? selectedCircleId;
    Future<List<ActiveCircle>> loadCircles() async {
      attempts++;
      if (attempts == 1) {
        throw const CircleApiException(503, 'Circle service unavailable.');
      }
      return const [ActiveCircle(id: 'circle-2', name: 'Family Circle')];
    }

    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: BackendCirclesSection(
            loadCircles: loadCircles,
            onCircleSelected: (circleId) => selectedCircleId = circleId,
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Circle service unavailable.'), findsOneWidget);
    await tester.tap(find.text('Retry'));
    await tester.pumpAndSettle();

    expect(find.text('Family Circle'), findsOneWidget);
    await tester.tap(find.text('Family Circle'));
    expect(selectedCircleId, 'circle-2');
  });
}
