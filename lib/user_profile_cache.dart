import 'package:cloud_firestore/cloud_firestore.dart';

/// অন্য ব্যবহারকারীর নাম/ছবি/অনলাইন অবস্থা একবার এনে মনে রাখা।
/// - একই মানুষের প্রোফাইল বারবার সার্ভার থেকে আনা হয় না (তালিকা নতুন করে আঁকলেও)।
/// - অনেকজনকে একসাথে আনা হয় (৩০ জন করে এক অনুরোধে)।
/// - ২ মিনিট পর আবার আনা হয়, যাতে "অনলাইন" সবুজ বিন্দু খুব পুরনো না থাকে।
class UserProfileCache {
  static const _maxAge = Duration(minutes: 2);
  static final Map<String, Map<String, dynamic>> _data = {};
  static final Map<String, DateTime> _fetchedAt = {};
  static final Map<String, Future<Map<String, dynamic>>> _inFlight = {};

  static CollectionReference<Map<String, dynamic>> get _users => FirebaseFirestore.instance.collection('users');

  static bool _fresh(String uid) {
    final t = _fetchedAt[uid];
    return t != null && DateTime.now().difference(t) < _maxAge;
  }

  /// যা মনে আছে তা সাথে সাথে (না থাকলে null)
  static Map<String, dynamic>? peek(String uid) => _data[uid];

  /// একজনের প্রোফাইল; মনে থাকলে সার্ভারে যায় না
  static Future<Map<String, dynamic>> get(String uid) {
    if (uid.isEmpty) return Future.value(const {});
    if (_fresh(uid)) return Future.value(_data[uid]!);
    return _inFlight[uid] ??= _users.doc(uid).get().then((d) {
      final m = d.data() ?? <String, dynamic>{};
      _data[uid] = m;
      _fetchedAt[uid] = DateTime.now();
      return m;
    }).whenComplete(() => _inFlight.remove(uid));
  }

  /// অনেকজনকে একসাথে আগেই এনে রাখা (তালিকা দেখানোর আগে)
  static Future<void> prefetch(Iterable<String> uids) async {
    final need = uids.where((u) => u.isNotEmpty && !_fresh(u) && !_inFlight.containsKey(u)).toSet().toList();
    if (need.isEmpty) return;
    final futures = <Future>[];
    for (var i = 0; i < need.length; i += 30) {
      final ids = need.skip(i).take(30).toList();
      final f = _users.where(FieldPath.documentId, whereIn: ids).get().then((snap) {
        final now = DateTime.now();
        for (final d in snap.docs) {
          _data[d.id] = d.data();
          _fetchedAt[d.id] = now;
        }
      });
      for (final id in ids) {
        _inFlight[id] = f.then((_) => _data[id] ?? <String, dynamic>{}).whenComplete(() => _inFlight.remove(id));
      }
      futures.add(f);
    }
    try {
      await Future.wait(futures);
    } catch (_) {}
  }
}
