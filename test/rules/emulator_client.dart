import 'dart:convert';
import 'dart:io';

/// Minimal REST client for the Firebase Auth + Firestore emulators.
/// Requests carry real emulator ID tokens, so Firestore rules are fully enforced.
class EmulatorClient {
  EmulatorClient()
      : _authHost = Platform.environment['FIREBASE_AUTH_EMULATOR_HOST'],
        _fsHost = Platform.environment['FIRESTORE_EMULATOR_HOST'];

  final String? _authHost;
  final String? _fsHost;
  static const project = 'delivtrack-codewingz';

  bool get available => _authHost != null && _fsHost != null;

  Future<({String uid, String token})> signUp(String email) async {
    final r = await _send('POST', 'http://$_authHost/identitytoolkit.googleapis.com/v1/accounts:signUp?key=fake',
        body: {'email': email, 'password': 'secret123'});
    return (uid: r.json['localId'] as String, token: r.json['idToken'] as String);
  }

  String _docName(String path) => 'projects/$project/databases/(default)/documents/$path';

  /// Writes one document. [serverTimes] fields are set to request time; [fields] are plain Dart values.
  Future<int> set(String? token, String path, Map<String, Object?> fields, {List<String> serverTimes = const []}) async {
    final r = await _send(
      'POST',
      'http://$_fsHost/v1/projects/$project/databases/(default)/documents:commit',
      token: token,
      body: {
        'writes': [
          {
            'update': {'name': _docName(path), 'fields': fields.map((k, v) => MapEntry(k, _value(v)))},
            if (serverTimes.isNotEmpty)
              'updateTransforms': [
                for (final f in serverTimes) {'fieldPath': f, 'setToServerValue': 'REQUEST_TIME'},
              ],
          },
        ],
      },
    );
    return r.status;
  }

  Future<int> get(String? token, String path) async =>
      (await _send('GET', 'http://$_fsHost/v1/${_docName(path)}', token: token)).status;

  Future<DateTime> createdAt(String? token, String path) async {
    final r = await _send('GET', 'http://$_fsHost/v1/${_docName(path)}', token: token);
    return DateTime.parse(r.json['fields']['createdAt']['timestampValue'] as String);
  }

  Future<({int status, int count})> list(String? token, String parent) async {
    final r = await _send('GET', 'http://$_fsHost/v1/${_docName(parent)}', token: token);
    return (status: r.status, count: (r.json['documents'] as List?)?.length ?? 0);
  }

  Future<int> delete(String? token, String path) async {
    final r = await _send(
      'POST',
      'http://$_fsHost/v1/projects/$project/databases/(default)/documents:commit',
      token: token,
      body: {
        'writes': [
          {'delete': _docName(path)},
        ],
      },
    );
    return r.status;
  }

  Map<String, Object?> _value(Object? v) => switch (v) {
        String s => {'stringValue': s},
        bool b => {'booleanValue': b},
        int i => {'integerValue': '$i'},
        DateTime d => {'timestampValue': d.toUtc().toIso8601String()},
        _ => throw ArgumentError('unsupported $v'),
      };

  Future<({int status, Map<String, dynamic> json})> _send(String method, String url,
      {String? token, Map<String, Object?>? body}) async {
    final client = HttpClient();
    try {
      final request = await client.openUrl(method, Uri.parse(url));
      request.headers.set('Content-Type', 'application/json');
      if (token != null) request.headers.set('Authorization', 'Bearer $token');
      if (body != null) request.write(jsonEncode(body));
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      final decoded = text.isEmpty ? <String, dynamic>{} : jsonDecode(text);
      return (status: response.statusCode, json: decoded is Map<String, dynamic> ? decoded : <String, dynamic>{});
    } finally {
      client.close();
    }
  }
}
