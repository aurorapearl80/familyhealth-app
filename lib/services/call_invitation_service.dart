import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'auth_service.dart';

/// Accept/decline an incoming video-call invitation raised by the admin side.
class CallInvitationService {
  static const _baseUrl = 'https://familywatchtoday.com';

  static Future<void> respond(int callInvitationId, String status) async {
    final token = await AuthService.getToken();
    try {
      final response = await http
          .patch(
            Uri.parse('$_baseUrl/api/patient/call-invitations/$callInvitationId'),
            headers: {
              'Authorization': 'Bearer $token',
              'Accept': 'application/json',
              'Content-Type': 'application/json',
            },
            body: '{"status":"$status"}',
          )
          .timeout(const Duration(seconds: 15));
      debugPrint('[CallInvitationService] respond($status) status: ${response.statusCode}');
    } catch (e) {
      debugPrint('[CallInvitationService] respond error: $e');
    }
  }
}
