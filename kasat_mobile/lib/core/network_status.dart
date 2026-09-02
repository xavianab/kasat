import 'package:connectivity_plus/connectivity_plus.dart';

/// Best-effort reachability. [connectivity_plus] reports interface state, not
/// whether packets actually land — that is the honest limit of this check.
class NetworkStatus {
  NetworkStatus({Connectivity? connectivity, bool? fakeOnline})
      : _connectivity = connectivity,
        _fakeOnline = fakeOnline;

  final Connectivity? _connectivity;
  final bool? _fakeOnline;

  Future<bool> isOnline() async {
    if (_fakeOnline != null) return _fakeOnline!;
    try {
      final results = await (_connectivity ?? Connectivity()).checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Stream<bool> get changes async* {
    if (_fakeOnline != null) {
      yield _fakeOnline!;
      return;
    }
    try {
      yield await isOnline();
      yield* (_connectivity ?? Connectivity()).onConnectivityChanged.map(
            (results) => results.any((r) => r != ConnectivityResult.none),
          );
    } catch (_) {
      yield true;
    }
  }
}
