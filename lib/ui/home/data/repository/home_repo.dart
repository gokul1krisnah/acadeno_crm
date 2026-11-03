import '../model/home_user_model.dart';
import '../sources/home_rds.dart';

class HomeRepository {
  final HomeRds _rds;

  HomeRepository(this._rds);

  /// Immediate profile from Firebase Auth, shown until Firestore responds.
  HomeUserModel currentUserFallback() {
    final user = _rds.currentUser;
    if (user == null) return HomeUserModel.empty;
    return HomeUserModel(
      uid: user.uid,
      name: user.displayName ?? '',
      email: user.email ?? '',
      role: 'executive',
    );
  }

  /// Live profile from Firestore (name, role, phone, joined date).
  /// Empty stream when signed out; errors are ignored so the fallback stays.
  Stream<HomeUserModel> watchCurrentUser() {
    final stream = _rds.watchCurrentUserDoc();
    if (stream == null) return const Stream.empty();
    final authUser = currentUserFallback();
    return stream
        .where((doc) => doc.exists)
        .map(HomeUserModel.fromFirestore)
        .map(
          (u) => u.copyWith(
            name: u.name.trim().isEmpty ? authUser.name : u.name,
            email: u.email.trim().isEmpty ? authUser.email : u.email,
          ),
        )
        .handleError((_) {});
  }
}
