import 'package:ajo/data/repositories/circle_repository.dart';
import 'package:ajo/features/circles/presentation/demo_circle_screen.dart';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('renders the backend next action in the circle screen', (
    tester,
  ) async {
    await _pumpCircleScreen(
      tester,
      _summary(nextAction: 'Review the eligible payout.'),
    );

    expect(find.text('Next step'), findsOneWidget);
    expect(find.text('Review the eligible payout.'), findsOneWidget);
  });

  testWidgets('renders a fallback for a legacy summary without nextAction', (
    tester,
  ) async {
    await _pumpCircleScreen(tester, _summary());

    expect(find.text('Next step'), findsOneWidget);
    expect(
      find.text('No next action is available from the current summary.'),
      findsOneWidget,
    );
  });
}

Future<void> _pumpCircleScreen(
  WidgetTester tester,
  Map<String, dynamic> summary,
) async {
  final dio = Dio(BaseOptions(baseUrl: 'http://ajo.test'))
    ..interceptors.add(
      InterceptorsWrapper(
        onRequest: (options, handler) {
          handler.resolve(
            Response<Object?>(
              requestOptions: options,
              statusCode: 200,
              data: summary,
            ),
          );
        },
      ),
    );
  final repository = CircleRepository(
    dio: dio,
    tokenProvider: () async => 'test-token',
  );

  await tester.pumpWidget(
    MaterialApp(
      home: DemoCircleScreen(circleId: 'circle-1', repository: repository),
    ),
  );
  await tester.pumpAndSettle();
}

Map<String, dynamic> _summary({String? nextAction}) {
  final summary = <String, dynamic>{
    'circle': {
      'circleId': 'circle-1',
      'name': 'Test circle',
      'status': 'active',
      'contributionKobo': 100000,
    },
    'currentRole': 'member',
    'canOperateDemo': false,
    'obligations': <Object>[],
    'collectedKobo': 0,
    'shortfallKobo': 100000,
    'payout': {
      'payoutId': 'payout-1',
      'amountKobo': 100000,
      'status': 'scheduled',
      'eligible': false,
      'recipientMembershipId': 'member-1',
      'recipientLabel': 'Member 1',
    },
    'explanation': 'One obligation remains outstanding.',
  };
  if (nextAction != null) summary['nextAction'] = nextAction;
  return summary;
}