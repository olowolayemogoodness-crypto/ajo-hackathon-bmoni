import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';

typedef IdTokenProvider = Future<String?> Function();

class CircleApiException implements Exception {
	const CircleApiException(this.statusCode, this.message);

	final int? statusCode;
	final String message;

	@override
	String toString() => message;
}

class DemoRules {
	const DemoRules({required this.version, required this.text});

	final String version;
	final String text;

	factory DemoRules.fromJson(Map<String, dynamic> json) => DemoRules(
		version: json['version'] as String,
		text: json['text'] as String,
	);
}

class DemoCircleCreated {
	const DemoCircleCreated({
		required this.id,
		required this.name,
		required this.invitationCode,
		required this.maxMembers,
		required this.contributionKobo,
		required this.organizerMembershipId,
		required this.rulesVersion,
		required this.invitationExpiresAt,
	});

	final String id;
	final String name;
	final String invitationCode;
	final int maxMembers;
	final int contributionKobo;
	final String organizerMembershipId;
	final String rulesVersion;
	final DateTime invitationExpiresAt;

	factory DemoCircleCreated.fromJson(Map<String, dynamic> json) =>
			DemoCircleCreated(
				id: json['circleId'] as String,
				name: json['name'] as String,
				invitationCode: json['invitationCode'] as String,
				maxMembers: json['maxMembers'] as int,
				contributionKobo: json['contributionKobo'] as int,
				organizerMembershipId: json['organizerMembershipId'] as String,
				rulesVersion: json['rulesVersion'] as String,
				invitationExpiresAt: DateTime.parse(json['invitationExpiresAt'] as String),
			);
}

class DemoInvitationPreview {
	const DemoInvitationPreview({
		required this.circleId,
		required this.name,
		required this.contributionKobo,
		required this.activeMemberCount,
		required this.maxMembers,
		required this.rulesVersion,
		required this.rulesText,
		required this.expiresAt,
	});

	final String circleId;
	final String name;
	final int contributionKobo;
	final int activeMemberCount;
	final int maxMembers;
	final String rulesVersion;
	final String rulesText;
	final DateTime expiresAt;

	factory DemoInvitationPreview.fromJson(Map<String, dynamic> json) =>
			DemoInvitationPreview(
				circleId: json['circleId'] as String,
				name: json['name'] as String,
				contributionKobo: json['contributionKobo'] as int,
				activeMemberCount: json['activeMemberCount'] as int,
				maxMembers: json['maxMembers'] as int,
				rulesVersion: json['rulesVersion'] as String,
				rulesText: json['rulesText'] as String,
				expiresAt: DateTime.parse(json['invitationExpiresAt'] as String),
			);
}

class DemoCircleMember {
	const DemoCircleMember({
		required this.membershipId,
		required this.role,
		required this.label,
	});

	final String membershipId;
	final String role;
	final String label;

	factory DemoCircleMember.fromJson(Map<String, dynamic> json) => DemoCircleMember(
		membershipId: json['membershipId'] as String,
		role: json['role'] as String,
		label: json['label'] as String,
	);
}

class DemoCircleSetup {
	const DemoCircleSetup({
		required this.circleId,
		required this.name,
		required this.status,
		required this.maxMembers,
		required this.contributionKobo,
		required this.rulesVersion,
		required this.currentRole,
		required this.canManageCircle,
		required this.canOperateDemo,
		required this.members,
	});

	final String circleId;
	final String name;
	final String status;
	final int maxMembers;
	final int contributionKobo;
	final String rulesVersion;
	final String currentRole;
	final bool canManageCircle;
	final bool canOperateDemo;
	final List<DemoCircleMember> members;

	factory DemoCircleSetup.fromJson(Map<String, dynamic> json) => DemoCircleSetup(
		circleId: json['circleId'] as String,
		name: json['name'] as String,
		status: json['status'] as String,
		maxMembers: json['maxMembers'] as int,
		contributionKobo: json['contributionKobo'] as int,
		rulesVersion: json['rulesVersion'] as String,
		currentRole: json['currentRole'] as String,
		canManageCircle: json['canManageCircle'] as bool? ?? false,
		canOperateDemo: json['canOperateDemo'] as bool? ?? false,
		members: (json['members'] as List<dynamic>)
				.map((item) => DemoCircleMember.fromJson(item as Map<String, dynamic>))
				.toList(growable: false),
	);
}

class DemoObligationSummary {
	const DemoObligationSummary({
		required this.membershipId,
		required this.memberLabel,
		required this.amountKobo,
		required this.paidKobo,
		required this.remainingKobo,
		required this.fullyFunded,
	});

	final String membershipId;
	final String memberLabel;
	final int amountKobo;
	final int paidKobo;
	final int remainingKobo;
	final bool fullyFunded;

	factory DemoObligationSummary.fromJson(Map<String, dynamic> json) =>
			DemoObligationSummary(
				membershipId: json['membershipId'] as String,
				memberLabel: json['memberLabel'] as String,
				amountKobo: json['amountKobo'] as int,
				paidKobo: json['paidKobo'] as int,
				remainingKobo: json['remainingKobo'] as int,
				fullyFunded: json['fullyFunded'] as bool,
			);
}

class DemoCircleSummary {
	const DemoCircleSummary({
		required this.circleId,
		required this.name,
		required this.status,
		required this.contributionKobo,
		required this.currentRole,
		required this.canOperateDemo,
		required this.obligations,
		required this.collectedKobo,
		required this.shortfallKobo,
		required this.payoutId,
		required this.payoutAmountKobo,
		required this.payoutStatus,
		required this.payoutEligible,
		required this.recipientLabel,
		required this.explanation,
	});

	final String circleId;
	final String name;
	final String status;
	final int contributionKobo;
	final String currentRole;
	final bool canOperateDemo;
	final List<DemoObligationSummary> obligations;
	final int collectedKobo;
	final int shortfallKobo;
	final String? payoutId;
	final int payoutAmountKobo;
	final String payoutStatus;
	final bool payoutEligible;
	final String? recipientLabel;
	final String explanation;

	factory DemoCircleSummary.fromJson(Map<String, dynamic> json) {
		final circle = json['circle'] as Map<String, dynamic>;
		final payout = json['payout'] as Map<String, dynamic>;
		return DemoCircleSummary(
			circleId: circle['circleId'] as String,
			name: circle['name'] as String,
			status: circle['status'] as String,
			contributionKobo: circle['contributionKobo'] as int,
			currentRole: json['currentRole'] as String,
			canOperateDemo: json['canOperateDemo'] as bool? ?? false,
			obligations: (json['obligations'] as List<dynamic>)
					.map((item) => DemoObligationSummary.fromJson(item as Map<String, dynamic>))
					.toList(growable: false),
			collectedKobo: json['collectedKobo'] as int,
			shortfallKobo: json['shortfallKobo'] as int,
			payoutId: payout['payoutId'] as String?,
			payoutAmountKobo: payout['amountKobo'] as int,
			payoutStatus: payout['status'] as String,
			payoutEligible: payout['eligible'] as bool,
			recipientLabel: payout['recipientLabel'] as String?,
			explanation: json['explanation'] as String,
		);
	}
}

class DemoAssistantAnswer {
	const DemoAssistantAnswer({required this.answer, required this.facts});

	final String answer;
	final Map<String, dynamic> facts;

	factory DemoAssistantAnswer.fromJson(Map<String, dynamic> json) =>
			DemoAssistantAnswer(
				answer: json['answer'] as String,
				facts: Map<String, dynamic>.from(json['facts'] as Map),
			);
}

class CircleRepository {
	CircleRepository({Dio? dio, IdTokenProvider? tokenProvider})
		: _dio = dio ?? Dio(BaseOptions(baseUrl: _apiBaseUrl)),
			_tokenProvider = tokenProvider ?? _firebaseToken;

	static const _apiBaseUrl = String.fromEnvironment(
		'AJO_API_BASE_URL',
		defaultValue: 'http://127.0.0.1:8000',
	);

	static final instance = CircleRepository();

	final Dio _dio;
	final IdTokenProvider _tokenProvider;

	static Future<String?> _firebaseToken() async =>
			FirebaseAuth.instance.currentUser?.getIdToken();

	Future<DemoCircleCreated> createCircle({
		required String name,
		required int maxMembers,
		required int contributionKobo,
		required String acceptedRulesVersion,
	}) async => DemoCircleCreated.fromJson(
		await _request(
			'POST',
			'/v1/circles',
			data: {
				'name': name,
				'maxMembers': maxMembers,
				'contributionKobo': contributionKobo,
				'acceptedRulesVersion': acceptedRulesVersion,
			},
		),
	);

	Future<DemoRules> getDemoRules() async => DemoRules.fromJson(
		await _request('GET', '/v1/demo/rules'),
	);

	Future<DemoInvitationPreview> inspectInvitation(String invitationCode) async =>
			DemoInvitationPreview.fromJson(
				await _request(
					'POST',
					'/v1/invitations/inspect',
					data: {'invitationCode': invitationCode},
				),
			);

	Future<String> acceptInvitation({
		required String invitationCode,
		required String acceptedRulesVersion,
	}) async {
		final result = await _request(
			'POST',
			'/v1/invitations/accept',
			data: {
				'invitationCode': invitationCode,
				'acceptedRulesVersion': acceptedRulesVersion,
			},
		);
		return result['circleId'] as String;
	}

	Future<DemoCircleSetup> getSetup(String circleId) async =>
			DemoCircleSetup.fromJson(
				await _request('GET', '/v1/circles/${Uri.encodeComponent(circleId)}/demo-setup'),
			);

	Future<void> activateCircle({
		required String circleId,
		required String payoutRecipientMembershipId,
		required DateTime firstDueDate,
	}) async {
		final date =
				'${firstDueDate.year.toString().padLeft(4, '0')}-'
				'${firstDueDate.month.toString().padLeft(2, '0')}-'
				'${firstDueDate.day.toString().padLeft(2, '0')}';
		await _request(
			'POST',
			'/v1/circles/${Uri.encodeComponent(circleId)}/activate',
			data: {
				'payoutRecipientMembershipId': payoutRecipientMembershipId,
				'firstDueDate': date,
			},
		);
	}

	Future<DemoCircleSummary> getSummary(String circleId) async =>
			DemoCircleSummary.fromJson(
				await _request(
					'GET',
					'/v1/circles/${Uri.encodeComponent(circleId)}/demo-summary',
				),
			);

	Future<DemoAssistantAnswer> askDemoAssistant({
		required String circleId,
		required String question,
	}) async =>
			DemoAssistantAnswer.fromJson(
				await _request(
					'POST',
					'/v1/assistant/queries',
					data: {'circleId': circleId, 'question': question},
				),
			);

	Future<void> recordSimulatedContribution({
		required String circleId,
		required String membershipId,
		required int amountKobo,
		required String idempotencyKey,
	}) async {
		await _request(
			'POST',
			'/v1/circles/${Uri.encodeComponent(circleId)}/demo/contributions/'
					'${Uri.encodeComponent(membershipId)}',
			data: {'amountKobo': amountKobo},
			headers: {'Idempotency-Key': idempotencyKey},
		);
	}

	Future<void> approvePayout(String circleId) async {
		await _request(
			'POST',
			'/v1/circles/${Uri.encodeComponent(circleId)}/payout/approve',
		);
	}

	Future<void> settleSimulatedPayout(String circleId) async {
		await _request(
			'POST',
			'/v1/circles/${Uri.encodeComponent(circleId)}/demo/payout/settle',
		);
	}

	Future<Map<String, dynamic>> _request(
		String method,
		String path, {
		Object? data,
		Map<String, String> headers = const {},
	}) async {
		final token = await _tokenProvider();
		if (token == null || token.isEmpty) {
			throw const CircleApiException(401, 'Sign in before using the circle API.');
		}
		try {
			final response = await _dio.request<Object?>(
				path,
				data: data,
				options: Options(
					method: method,
					headers: {
						'Authorization': 'Bearer $token',
						...headers,
					},
				),
			);
			if (response.data is Map<String, dynamic>) {
				return response.data! as Map<String, dynamic>;
			}
			throw const CircleApiException(null, 'The circle API returned an invalid response.');
		} on DioException catch (error) {
			final responseData = error.response?.data;
			final envelope = responseData is Map ? responseData['error'] : null;
			final message = envelope is Map && envelope['message'] is String
					? envelope['message'] as String
					: 'The circle service is unavailable. Check the local API connection and try again.';
			throw CircleApiException(error.response?.statusCode, message);
		}
	}
}
