import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http_parser/http_parser.dart';

import '../config/api_config.dart';
import '../models/models.dart';
import '../utils/otp_validation.dart';

class ApiResult {
  const ApiResult({required this.ok, this.message, this.data, this.statusCode});
  final bool ok;
  final String? message;
  final Map<String, dynamic>? data;
  final int? statusCode;
}

class ApiService {
  ApiService({http.Client? client}) : _client = client ?? http.Client();

  final http.Client _client;

  Uri _uri(String path) => Uri.parse('${ApiConfig.baseUrl}$path');

  Future<ApiResult> sendOtp(String mobile) async {
    return _postJson('/api/otp/send', {'mobile': mobile});
  }

  Future<ApiResult> verifyOtp(String mobile, String otp) async {
    return _postOtpVerify('/api/otp/verify', {'mobile': mobile, 'otp': otp});
  }

  Future<ApiResult> sendLoginOtp(String mobile) async {
    return _postJson('/api/user/login/send-otp', {'mobile': mobile});
  }

  Future<ApiResult> verifyLoginOtp(String mobile, String otp) async {
    return _postOtpVerify('/api/user/login/verify', {'mobile': mobile, 'otp': otp});
  }

  Future<ApiResult> loginWithPassword(String mobile, String password) async {
    return _postJson('/api/user/login/password', {'mobile': mobile, 'password': password});
  }

  Future<ApiResult> signUp({
    required String fullName,
    required String mobile,
    required String email,
    required String password,
  }) async {
    return _postJson('/api/user/signup', {
      'fullName': fullName,
      'mobile': mobile,
      'email': email,
      'password': password,
    });
  }

  Future<ApiResult> getProfile(String token) async {
    try {
      final response = await _client.get(
        _uri('/api/user/profile'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _decode(response.body);
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : body,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> completeLoan(String token) async {
    try {
      final response = await _client.post(
        _uri('/api/user/loan/complete'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _decode(response.body);
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : null,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> getCibil(String token) async {
    try {
      final response = await _client.get(
        _uri('/api/user/cibil'),
        headers: {'Authorization': 'Bearer $token'},
      );
      final body = _decode(response.body);
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : null,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> requestCibil(String token) async {
    try {
      final response = await _client.post(
        _uri('/api/user/cibil/request'),
        headers: {
          'Authorization': 'Bearer $token',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({'consent': 'Y'}),
      );
      final body = _decode(response.body);
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : null,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> submitKyc({
    required Map<String, String> fields,
    required Map<String, PickedUpload?> files,
  }) async {
    try {
      final request = http.MultipartRequest('POST', _uri('/api/kyc/submit'));
      request.fields.addAll(fields);

      for (final entry in files.entries) {
        final file = entry.value;
        if (file == null) continue;
        if (file.bytes != null) {
          request.files.add(
            http.MultipartFile.fromBytes(
              entry.key,
              file.bytes!,
              filename: file.name,
              contentType: _guessMediaType(file.name),
            ),
          );
        } else if (file.path.isNotEmpty) {
          request.files.add(await http.MultipartFile.fromPath(entry.key, file.path, filename: file.name));
        }
      }

      final streamed = await _client.send(request);
      final response = await http.Response.fromStream(streamed);
      final body = _decode(response.body);
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString(),
        data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : null,
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> _postOtpVerify(String path, Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final body = _decode(response.body);
      final accepted = response.statusCode >= 200 &&
          response.statusCode < 300 &&
          isOtpVerifyAccepted(body);
      return ApiResult(
        ok: accepted,
        message: accepted ? body['message']?.toString() : otpFailureMessage(body),
        data: body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : (accepted && body.isNotEmpty ? body : null),
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Future<ApiResult> _postJson(String path, Map<String, dynamic> payload) async {
    try {
      final response = await _client.post(
        _uri(path),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode(payload),
      );
      final body = _decode(response.body);
      if (response.statusCode == 404 && path.contains('/login')) {
        return ApiResult(
          ok: false,
          message: path.contains('password') || path.endsWith('/login')
              ? 'Password sign-in is not available on the server yet. Deploy the latest backend, or sign in with OTP.'
              : (body['message']?.toString() ?? 'Account not found.'),
          data: body['data'] is Map<String, dynamic> ? body['data'] as Map<String, dynamic> : null,
          statusCode: response.statusCode,
        );
      }
      return ApiResult(
        ok: response.statusCode >= 200 && response.statusCode < 300 && body['success'] == true,
        message: body['message']?.toString() ??
            (response.statusCode >= 200 && response.statusCode < 300
                ? null
                : 'Sign in failed. Please try again.'),
        data: body['data'] is Map<String, dynamic>
            ? body['data'] as Map<String, dynamic>
            : (body.isNotEmpty ? body : null),
        statusCode: response.statusCode,
      );
    } catch (_) {
      return const ApiResult(ok: false, message: 'Could not reach the server. Please try again.');
    }
  }

  Map<String, dynamic> _decode(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is Map<String, dynamic>) return decoded;
      return {'success': false, 'message': 'Unexpected response'};
    } catch (_) {
      return {'success': false, 'message': 'Unexpected response'};
    }
  }

  MediaType? _guessMediaType(String name) {
    final lower = name.toLowerCase();
    if (lower.endsWith('.png')) return MediaType('image', 'png');
    if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return MediaType('image', 'jpeg');
    if (lower.endsWith('.pdf')) return MediaType('application', 'pdf');
    return null;
  }
}
