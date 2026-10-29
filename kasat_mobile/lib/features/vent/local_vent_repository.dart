import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

import '../../core/kasat_config.dart';
import 'vent_identities.dart';
import 'vent_models.dart';
import 'vent_repository.dart';

class LocalVentRepository implements VentRepository {
  LocalVentRepository();

  static const _postsKey = 'kasat.vent.posts.v1';
  static const _repliesKey = 'kasat.vent.replies.v1';
  static const _threadIdsKey = 'kasat.vent.thread_ids.v1';

  static const _uuid = Uuid();
  final _random = Random.secure();
  final _changes = StreamController<void>.broadcast();

  late SharedPreferences _prefs;
  final _posts = <String, VentPost>{};
  final _replies = <VentReply>[];

  /// Maps "$authorToken|$postId" → display identity for this thread.
  Map<String, String> _threadIds = {};

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    _load();
    await purgeExpired();
    if (_posts.isEmpty) await _seed();
  }

  void _load() {
    _posts.clear();
    final rawPosts = _prefs.getString(_postsKey);
    if (rawPosts != null) {
      final decoded = jsonDecode(rawPosts) as Map<String, dynamic>;
      for (final entry in decoded.entries) {
        _posts[entry.key] = VentPost.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    _replies
      ..clear()
      ..addAll(
        ((_prefs.getString(_repliesKey) != null)
                ? jsonDecode(_prefs.getString(_repliesKey)!) as List<dynamic>
                : const [])
            .map((e) => VentReply.fromJson(e as Map<String, dynamic>)),
      );
    final rawIds = _prefs.getString(_threadIdsKey);
    if (rawIds != null) {
      _threadIds = Map<String, String>.from(jsonDecode(rawIds) as Map);
    }
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _postsKey,
      jsonEncode(_posts.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.setString(
      _repliesKey,
      jsonEncode(_replies.map((r) => r.toJson()).toList()),
    );
    await _prefs.setString(_threadIdsKey, jsonEncode(_threadIds));
    _changes.add(null);
  }

  String _identityFor({required String authorToken, required String postId, String? otherThan}) {
    final key = '$authorToken|$postId';
    final existing = _threadIds[key];
    if (existing != null) return existing;
    final id = pickVentIdentity(otherThan: otherThan, random: _random);
    _threadIds[key] = id;
    return id;
  }

  @override
  Future<List<VentPost>> liveFeed() async {
    final live = _posts.values.where((p) => !p.expired).toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return List.unmodifiable(live);
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Future<VentPost> createPost({
    required String body,
    required String authorToken,
  }) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > KasatConfig.ventBodyMax) {
      throw ArgumentError('Vent body must be 1–${KasatConfig.ventBodyMax} characters.');
    }
    final now = DateTime.now();
    final id = _uuid.v4();
    final identity = pickVentIdentity(random: _random);
    _threadIds['$authorToken|$id'] = identity;
    final post = VentPost(
      id: id,
      displayIdentity: identity,
      body: trimmed,
      createdAt: now,
      expiresAt: now.add(KasatConfig.ventTtl),
      authorToken: authorToken,
    );
    _posts[id] = post;
    await _persist();
    return post;
  }

  @override
  Future<VentReply> reply({
    required String postId,
    required String fromAuthorToken,
    required String body,
  }) async {
    final post = _posts[postId];
    if (post == null || post.expired) {
      throw StateError('That post is gone.');
    }
    final trimmed = body.trim();
    if (trimmed.isEmpty || trimmed.length > KasatConfig.ventBodyMax) {
      throw ArgumentError('Reply body must be 1–${KasatConfig.ventBodyMax} characters.');
    }
    final identity = _identityFor(
      authorToken: fromAuthorToken,
      postId: postId,
      otherThan: post.displayIdentity,
    );
    final reply = VentReply(
      id: _uuid.v4(),
      postId: postId,
      fromDisplayIdentity: identity,
      body: trimmed,
      createdAt: DateTime.now(),
      isSupportTap: false,
    );
    _replies.add(reply);
    _posts[postId] = post.copyWith(replyCount: post.replyCount + 1);
    await _persist();
    return reply;
  }

  @override
  Future<void> support({
    required String postId,
    required String fromAuthorToken,
  }) async {
    final post = _posts[postId];
    if (post == null || post.expired) return;
    final identity = _identityFor(
      authorToken: fromAuthorToken,
      postId: postId,
      otherThan: post.displayIdentity,
    );
    final already = _replies.any(
      (r) => r.postId == postId && r.isSupportTap && r.fromDisplayIdentity == identity,
    );
    if (already) return;
    _replies.add(
      VentReply(
        id: _uuid.v4(),
        postId: postId,
        fromDisplayIdentity: identity,
        body: '',
        createdAt: DateTime.now(),
        isSupportTap: true,
      ),
    );
    _posts[postId] = post.copyWith(supportCount: post.supportCount + 1);
    await _persist();
  }

  @override
  Future<List<VentReply>> privateRepliesForPoster({
    required String postId,
    required String authorToken,
  }) async {
    final post = _posts[postId];
    if (post == null || post.authorToken != authorToken) {
      return const [];
    }
    final mine = _replies
        .where((r) => r.postId == postId && !r.isSupportTap)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return List.unmodifiable(mine);
  }

  @override
  Future<void> markAiCompanionPosted(String postId) async {
    final post = _posts[postId];
    if (post == null) return;
    _posts[postId] = post.copyWith(aiCompanionPosted: true);
    await _persist();
  }

  @override
  Future<void> addCompanionReply(VentReply reply) async {
    final post = _posts[reply.postId];
    _replies.add(reply);
    if (post != null) {
      _posts[reply.postId] = post.copyWith(
        replyCount: post.replyCount + 1,
        aiCompanionPosted: true,
      );
    }
    await _persist();
  }

  @override
  Future<int> purgeExpired() async {
    final gone = _posts.values.where((p) => p.expired).map((p) => p.id).toSet();
    if (gone.isEmpty) return 0;
    for (final id in gone) {
      _posts.remove(id);
    }
    _replies.removeWhere((r) => gone.contains(r.postId));
    _threadIds.removeWhere((key, _) => gone.any((id) => key.endsWith('|$id')));
    await _persist();
    return gone.length;
  }

  Future<void> _seed() async {
    final now = DateTime.now();
    void put({
      required String id,
      required String identity,
      required String body,
      required Duration age,
      int support = 0,
    }) {
      _posts[id] = VentPost(
        id: id,
        displayIdentity: identity,
        body: body,
        createdAt: now.subtract(age),
        expiresAt: now.subtract(age).add(KasatConfig.ventTtl),
        authorToken: 'seed-$id',
        supportCount: support,
      );
    }

    put(
      id: 'seed-a',
      identity: 'Owlet 🦉',
      body: 'I made it through today. That is all I have. That is enough.',
      age: const Duration(hours: 6),
      support: 4,
    );
    put(
      id: 'seed-b',
      identity: 'River 🌊',
      body: 'If anyone else is sitting with the lights off right now — me too.',
      age: const Duration(days: 1),
      support: 11,
    );
    await _persist();
  }

  void dispose() => _changes.close();
}
