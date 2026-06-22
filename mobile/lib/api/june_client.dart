import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

import '../auth/auth_service.dart';
import '../models/chat.dart';
import '../models/checkin.dart';

// Phase 0 backend lives on the host machine. iOS sim sees the Mac at 127.0.0.1;
// Android emulator uses 10.0.2.2. Override JUNE_API_BASE with --dart-define
// when running on a real device on the same Wi-Fi.
String _defaultBase() {
  const fromEnv = String.fromEnvironment('JUNE_API_BASE');
  if (fromEnv.isNotEmpty) return fromEnv;
  if (Platform.isAndroid) return 'http://10.0.2.2:4000';
  return 'http://127.0.0.1:4000';
}

// Phase 1: until real auth ships, the mobile app treats every linked account as
// belonging to this stable demo user. The same UUID is seeded by the
// 20260622000000_plaid.sql migration.
const String demoUserId = '00000000-0000-0000-0000-000000000001';

class JuneClient {
  final String baseUrl;
  JuneClient({String? baseUrl}) : baseUrl = baseUrl ?? _defaultBase();

  // Returns content-type plus, if a Supabase session exists, an
  // `Authorization: Bearer <jwt>` header. The backend uses the JWT to identify
  // the user and load their persisted context.
  Map<String, String> _authHeaders({Map<String, String>? extra}) {
    final headers = <String, String>{'content-type': 'application/json'};
    final session = AuthService.currentSession;
    if (session != null) {
      headers['authorization'] = 'Bearer ${session.accessToken}';
    }
    if (extra != null) headers.addAll(extra);
    return headers;
  }

  Future<CheckIn> generateCheckIn({
    required DateTime today,
    required Map<String, dynamic>? context,
  }) async {
    final url = Uri.parse('$baseUrl/checkin/generate');
    final body = <String, dynamic>{
      'today':
          '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
    };
    // Null context means "load from DB" — omit the key so the backend doesn't
    // see a stale local snapshot. Pass an explicit empty map if you really
    // want an empty context.
    if (context != null) {
      body['context'] = context;
    }
    final res = await http.post(
      url,
      headers: _authHeaders(),
      body: jsonEncode(body),
    );

    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }

    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return CheckIn.fromJson(json);
  }

  // ---------------- Account ----------------

  // POSTs to /account/delete. Requires an auth session — the backend uses the
  // JWT to identify the user whose data should be wiped.
  Future<void> deleteMyData() async {
    final res = await http.post(
      Uri.parse('$baseUrl/account/delete'),
      headers: _authHeaders(),
    );
    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }
  }

  // ---------------- Plaid ----------------

  Future<({String linkToken, String expiration})> plaidLinkToken({
    required String userId,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/plaid/link-token'),
      headers: _authHeaders(),
      body: jsonEncode({'user_id': userId}),
    );
    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }
    final json = jsonDecode(res.body) as Map<String, dynamic>;
    return (
      linkToken: json['link_token'] as String,
      expiration: (json['expiration'] as String?) ?? '',
    );
  }

  Future<void> plaidExchange({
    required String userId,
    required String publicToken,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/plaid/exchange'),
      headers: _authHeaders(),
      body: jsonEncode({'user_id': userId, 'public_token': publicToken}),
    );
    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }
  }

  Future<void> plaidSync({required String userId}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/plaid/sync'),
      headers: _authHeaders(),
      body: jsonEncode({'user_id': userId}),
    );
    if (res.statusCode != 200) {
      throw JuneApiException(res.statusCode, res.body);
    }
  }

  // ---------------- Chat (streaming) ----------------

  // POSTs to /chat and yields ChatStreamEvents as SSE frames arrive.
  // We can't use http.post here — it buffers the whole response — so we open
  // a Request via http.Client.send() to read the raw byte stream incrementally.
  //
  // Wire shape (locked with backend):
  //   data: {"type":"delta","text":"..."}\n\n
  //   data: {"type":"done"}\n\n
  //   data: {"type":"error","message":"..."}\n\n
  Stream<ChatStreamEvent> streamChat({
    required String userId,
    required DateTime today,
    required Map<String, dynamic>? context,
    required List<ChatMessage> history,
    required String message,
  }) async* {
    final controller = StreamController<ChatStreamEvent>();
    final client = http.Client();

    // Run the network work in the background; pipe events into the controller.
    // We use an inner async closure so we can `await` the streamed response
    // without blocking the outer generator's first yield.
    Future<void> run() async {
      try {
        final req = http.Request('POST', Uri.parse('$baseUrl/chat'));
        // SSE-specific header layered on top of the standard auth headers.
        _authHeaders(extra: {'accept': 'text/event-stream'})
            .forEach((k, v) => req.headers[k] = v);
        final body = <String, dynamic>{
          'user_id': userId,
          'today':
              '${today.year.toString().padLeft(4, '0')}-${today.month.toString().padLeft(2, '0')}-${today.day.toString().padLeft(2, '0')}',
          'history': history
              .map((m) => {
                    'role': m.role == ChatRole.user ? 'user' : 'assistant',
                    'text': m.text,
                  })
              .toList(),
          'message': message,
        };
        // Mirror generateCheckIn: omit `context` entirely when null so the
        // backend loads from DB.
        if (context != null) {
          body['context'] = context;
        }
        req.body = jsonEncode(body);

        final res = await client.send(req);
        if (res.statusCode != 200) {
          final body = await res.stream.bytesToString();
          throw JuneApiException(res.statusCode, body);
        }

        // SSE frames are separated by a blank line (\n\n). The chunk
        // boundaries from the network do NOT line up with frame boundaries,
        // so we buffer bytes -> string and split on \n\n, keeping any tail
        // for the next chunk.
        final utf8Stream = res.stream.transform(utf8.decoder);
        var buffer = '';

        await for (final chunk in utf8Stream) {
          buffer += chunk;
          while (true) {
            final sep = buffer.indexOf('\n\n');
            if (sep < 0) break;
            final frame = buffer.substring(0, sep);
            buffer = buffer.substring(sep + 2);
            final evt = _parseSseFrame(frame);
            if (evt == null) continue;
            controller.add(evt);
            if (evt is ChatDone || evt is ChatErrorEvent) {
              await controller.close();
              return;
            }
          }
        }

        // Stream ended without an explicit done frame — treat as done so the
        // UI flips streaming=false. Better than hanging the bubble forever.
        if (!controller.isClosed) {
          controller.add(ChatDone());
          await controller.close();
        }
      } catch (e) {
        if (!controller.isClosed) {
          controller.add(ChatErrorEvent(e.toString()));
          await controller.close();
        }
      } finally {
        client.close();
      }
    }

    // Fire and forget; the stream below will surface anything that goes wrong.
    unawaited(run());

    yield* controller.stream;
  }
}

// SSE frame may contain multiple `data: ` lines (per spec), comments (lines
// starting with `:`), and other field names. For our locked contract we only
// care about `data:` lines and concatenate them per frame before JSON decode.
ChatStreamEvent? _parseSseFrame(String frame) {
  final lines = frame.split('\n');
  final dataParts = <String>[];
  for (final raw in lines) {
    final line = raw.trimRight();
    if (line.isEmpty) continue;
    if (line.startsWith(':')) continue; // comment / keepalive
    if (line.startsWith('data:')) {
      // Strip the prefix and an optional single leading space.
      var value = line.substring(5);
      if (value.startsWith(' ')) value = value.substring(1);
      dataParts.add(value);
    }
  }
  if (dataParts.isEmpty) return null;
  final payload = dataParts.join('\n');
  try {
    final json = jsonDecode(payload);
    if (json is! Map<String, dynamic>) return null;
    final type = json['type'];
    switch (type) {
      case 'delta':
        final text = json['text'];
        if (text is String) return ChatDelta(text);
        return null;
      case 'done':
        return ChatDone();
      case 'error':
        final msg = json['message'];
        return ChatErrorEvent(msg is String ? msg : 'stream error');
      default:
        return null;
    }
  } catch (_) {
    // Tolerate malformed frames — keepalives or partial JSON shouldn't kill
    // the conversation.
    return null;
  }
}

sealed class ChatStreamEvent {}

class ChatDelta extends ChatStreamEvent {
  final String text;
  ChatDelta(this.text);
}

class ChatDone extends ChatStreamEvent {}

class ChatErrorEvent extends ChatStreamEvent {
  final String message;
  ChatErrorEvent(this.message);
}

class JuneApiException implements Exception {
  final int status;
  final String body;
  JuneApiException(this.status, this.body);
  @override
  String toString() => 'JuneApiException($status): $body';
}
