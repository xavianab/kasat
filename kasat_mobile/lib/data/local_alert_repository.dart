import 'dart:async';
import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../core/alert_id.dart';
import '../core/alert_review.dart';
import '../core/kasat_config.dart';
import '../models/community_alert.dart';
import 'alert_repository.dart';

class LocalAlertRepository implements AlertRepository {
  LocalAlertRepository({AlertReviewer? reviewer})
      : _reviewer = reviewer ?? AnthropicAlertReviewer();

  static const _alertsKey = 'kasat.alerts.v1';
  static const _tipsKey = 'kasat.alert_tips.v1';

  final AlertReviewer _reviewer;
  final _changes = StreamController<void>.broadcast();
  final _random = Random.secure();

  late SharedPreferences _prefs;
  final _alerts = <String, CommunityAlert>{};
  final _tips = <AlertTip>[];

  Future<void> init() async {
    _prefs = await SharedPreferences.getInstance();
    final rawAlerts = _prefs.getString(_alertsKey);
    if (rawAlerts != null) {
      for (final entry in (jsonDecode(rawAlerts) as Map<String, dynamic>).entries) {
        _alerts[entry.key] = CommunityAlert.fromJson(entry.value as Map<String, dynamic>);
      }
    }
    final rawTips = _prefs.getString(_tipsKey);
    if (rawTips != null) {
      _tips.addAll(
        (jsonDecode(rawTips) as List<dynamic>)
            .map((e) => AlertTip.fromJson(e as Map<String, dynamic>)),
      );
    }
    if (_alerts.isEmpty) await _seed();
  }

  @override
  Future<List<CommunityAlert>> liveForCountry(String countryCode) async {
    final now = DateTime.now();
    return _alerts.values
        .where(
          (a) =>
              a.countryCode == countryCode &&
              a.visibility == AlertVisibility.live &&
              a.expiresAt.isAfter(now),
        )
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  @override
  Future<List<CommunityAlert>> pending() async {
    return _alerts.values
        .where((a) => a.visibility == AlertVisibility.pending)
        .toList()
      ..sort((a, b) => b.postedAt.compareTo(a.postedAt));
  }

  @override
  Stream<void> watch() => _changes.stream;

  @override
  Future<CommunityAlert> submit({
    required AlertKind kind,
    required String title,
    required String body,
    required String countryCode,
    required String posterToken,
    required bool verifiedSource,
  }) async {
    if (!verifiedSource) {
      throw StateError('Only a verified source can post an alert.');
    }

    final review = await _reviewer.review(title: title, body: body);
    final now = DateTime.now();
    final alert = CommunityAlert(
      id: AlertId.generate(),
      kind: kind,
      title: title.trim(),
      body: body.trim(),
      countryCode: countryCode,
      postedAt: now,
      expiresAt: now.add(KasatConfig.alertTtl),
      visibility: review.verdict == ReviewVerdict.publish
          ? AlertVisibility.live
          : AlertVisibility.pending,
      verifiedSource: true,
      posterToken: posterToken,
      reviewNote: review.note,
    );

    _alerts[alert.id] = alert;
    await _persist();
    _changes.add(null);
    return alert;
  }

  @override
  Future<void> markSeen(String alertId) async {
    final current = _alerts[alertId];
    if (current == null) return;
    _alerts[alertId] = current.copyWith(seenCount: current.seenCount + 1);
    await _persist();
    _changes.add(null);
  }

  @override
  Future<void> close(String alertId, {required String posterToken}) async {
    final current = _alerts[alertId];
    if (current == null || current.posterToken != posterToken) return;
    _alerts[alertId] = current.copyWith(visibility: AlertVisibility.closed);
    await _persist();
    _changes.add(null);
  }

  @override
  Future<void> sendTip({required String alertId, required String body}) async {
    final trimmed = body.trim();
    if (trimmed.isEmpty || !_alerts.containsKey(alertId)) return;
    _tips.add(
      AlertTip(
        id: _token(),
        alertId: alertId,
        body: trimmed,
        sentAt: DateTime.now(),
      ),
    );
    await _persist();
    _changes.add(null);
  }

  @override
  Future<List<AlertTip>> tipsForPoster(String posterToken) async {
    final mine = _alerts.values.where((a) => a.posterToken == posterToken).map((a) => a.id).toSet();
    return _tips.where((t) => mine.contains(t.alertId)).toList()
      ..sort((a, b) => b.sentAt.compareTo(a.sentAt));
  }

  Future<void> _persist() async {
    await _prefs.setString(
      _alertsKey,
      jsonEncode(_alerts.map((k, v) => MapEntry(k, v.toJson()))),
    );
    await _prefs.setString(
      _tipsKey,
      jsonEncode(_tips.map((t) => t.toJson()).toList()),
    );
  }

  Future<void> _seed() async {
    final now = DateTime.now();
    void put(CommunityAlert alert) => _alerts[alert.id] = alert;

    put(
      CommunityAlert(
        id: 'ALT-4M7KQ',
        kind: AlertKind.missingPerson,
        title: 'Have you seen Tigist, 16?',
        body:
            'Last seen near the Merkato bus park on Monday afternoon, wearing a '
            'green school sweater. Family is asking neighbours to look, not to '
            'approach. Call the posted line if you recognise her.',
        countryCode: 'ET',
        postedAt: now.subtract(const Duration(hours: 11)),
        expiresAt: now.add(const Duration(days: 13)),
        visibility: AlertVisibility.live,
        verifiedSource: true,
        posterToken: 'SEED-ET',
        seenCount: 14,
        reviewNote: 'Seeded. Passed first-pass review.',
      ),
    );
    put(
      CommunityAlert(
        id: 'ALT-9WP2H',
        kind: AlertKind.safetyNotice,
        title: 'Street lights out on the north road',
        body:
            'The stretch past the clinic has been dark for three nights. Walk '
            'in pairs if you can, and use the inner path until it is repaired.',
        countryCode: 'ET',
        postedAt: now.subtract(const Duration(days: 2)),
        expiresAt: now.add(const Duration(days: 12)),
        visibility: AlertVisibility.live,
        verifiedSource: true,
        posterToken: 'SEED-ET',
        seenCount: 31,
      ),
    );
    put(
      CommunityAlert(
        id: 'ALT-2C8NR',
        kind: AlertKind.communityWatch,
        title: 'Evening walk group, Capitol Hill',
        body:
            'Neighbours are meeting at 7 at the library steps if anyone wants '
            'company walking home after dusk this week.',
        countryCode: 'US',
        postedAt: now.subtract(const Duration(hours: 6)),
        expiresAt: now.add(const Duration(days: 13)),
        visibility: AlertVisibility.live,
        verifiedSource: true,
        posterToken: 'SEED-US',
        seenCount: 8,
      ),
    );
    await _persist();
  }

  String _token() {
    const chars = 'abcdef0123456789';
    return List.generate(16, (_) => chars[_random.nextInt(chars.length)]).join();
  }

  void dispose() {
    _changes.close();
  }
}
