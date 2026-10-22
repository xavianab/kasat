import 'package:connectivity_plus/connectivity_plus.dart';

/// Best-effort reachability. [connectivity_plus] reports interface state, not
/// whether packets actually land — that is the honest limit of this check.
class NetworkStatus {
  NetworkStatus({this.connectivity, this.fakeOnline});

  final Connectivity? connectivity;
  final bool? fakeOnline;

  Future<bool> isOnline() async {
    final fake = fakeOnline;
    if (fake != null) return fake;
    try {
      final results = await (connectivity ?? Connectivity()).checkConnectivity();
      return results.any((r) => r != ConnectivityResult.none);
    } catch (_) {
      return true;
    }
  }

  Stream<bool> get changes async* {
    final fake = fakeOnline;
    if (fake != null) {
      yield fake;
      return;
    }
    try {
      yield await isOnline();
      yield* (connectivity ?? Connectivity()).onConnectivityChanged.map(
            (results) => results.any((r) => r != ConnectivityResult.none),
          );
    } catch (_) {
      yield true;
    }
  }
}
