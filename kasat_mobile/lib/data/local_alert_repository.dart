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
  LocalAlertRepository({
    AlertReviewer? reviewer,
    String Function()? callerIdProvider,
  })  : _reviewer = reviewer ??
            AnthropicAlertReviewer(callerIdProvider: callerIdProvider),
        _callerIdProvider = callerIdProvider;

  // v2 drops invented missing-person / neighbourhood seed notices.
  static const _alertsKey = 'kasat.alerts.v2';
  static const _tipsKey = 'kasat.alert_tips.v2';

  final AlertReviewer _reviewer;
  final String Function()? _callerIdProvider;
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

    final review = await _reviewer.review(
      title: title,
      body: body,
      callerId: _callerIdProvider?.call(),
    );
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

    // General safety tips only. No invented missing-person or neighbourhood notices.
    // Home renders these via i18n so Amharic swaps with the language toggle;
    // the seed keeps the alerts feed and repository tests non-empty.
    const tips = <(String, String, String)>[
      (
        'ALT-TIP01',
        'Use Quick exit',
        'If someone comes near, tap Quick exit at the top. Kasat closes straight away.',
      ),
      (
        'ALT-TIP02',
        'Keep your code safe',
        'Your case code is the only way back to your report. Write it somewhere only you will find it.',
      ),
      (
        'ALT-TIP03',
        'You can save a draft',
        'Not ready to send? Save your report on your phone and decide later.',
      ),
    ];

    for (final country in const ['ET', 'US']) {
      for (var i = 0; i < tips.length; i++) {
        final tip = tips[i];
        put(
          CommunityAlert(
            id: '${tip.$1}-$country',
            kind: AlertKind.safetyNotice,
            title: tip.$2,
            body: tip.$3,
            countryCode: country,
            postedAt: now.subtract(Duration(hours: 3 + i)),
            expiresAt: now.add(const Duration(days: 3650)),
            visibility: AlertVisibility.live,
            verifiedSource: true,
            posterToken: 'SEED-$country',
            seenCount: 0,
            reviewNote: 'Seeded safety tip.',
          ),
        );
      }
    }
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
