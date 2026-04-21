abstract class AuthState {}

class AuthInitial extends AuthState {}

class AuthLoading extends AuthState {}

class AuthNeedsVerification extends AuthState {}

class AuthSuccess extends AuthState {
  final String uid;
  AuthSuccess(this.uid);
}

class AuthError extends AuthState {
  final String error; // 🔥 تم توحيد الاسم لـ error بدل message
  AuthError(this.error);
}

class GetUserLoading extends AuthState {}

class GetUserSuccess extends AuthState {}

class GetUserError extends AuthState {
  final String error;
  GetUserError(this.error);
}

class UpdateUserLoading extends AuthState {}

class UpdateUserSuccess extends AuthState {}

class UpdateUserError extends AuthState {
  final String error;
  UpdateUserError(this.error);
}

class ProfileImagePickedSuccess extends AuthState {}

class ProfileImagePickedError extends AuthState {
  final String error;
  ProfileImagePickedError(this.error);
}

// ==========================================
// الحالات الخاصة بالموقع (GPS)
// ==========================================
class LocationLoading extends AuthState {}

class LocationFetchedSuccess extends AuthState {
  final String location;
  LocationFetchedSuccess(this.location);
}

class LocationError extends AuthState {
  final String error;
  LocationError(this.error);
}

// ==========================================
// الحالات الخاصة بالاستبيان
// ==========================================
class AuthNeedsSurvey extends AuthState {
  final String uid;
  AuthNeedsSurvey(this.uid);
}