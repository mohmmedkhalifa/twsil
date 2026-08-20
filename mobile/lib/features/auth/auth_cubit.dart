import 'package:flutter_bloc/flutter_bloc.dart';
import '../../core/models.dart';
import '../../core/network/api_client.dart';
import '../../core/network/push_service.dart';
import '../../core/network/socket_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthState {
  final AuthStatus status;
  final User? user;
  final CaptainProfile? captainProfile;
  final String? error;

  const AuthState({
    this.status = AuthStatus.unknown,
    this.user,
    this.captainProfile,
    this.error,
  });

  AuthState copyWith({
    AuthStatus? status,
    User? user,
    CaptainProfile? captainProfile,
    String? error,
  }) =>
      AuthState(
        status: status ?? this.status,
        user: user ?? this.user,
        captainProfile: captainProfile ?? this.captainProfile,
        error: error,
      );
}

class AuthCubit extends Cubit<AuthState> {
  AuthCubit() : super(const AuthState());

  Future<void> bootstrap() async {
    await ApiClient.instance.init();
    if (!ApiClient.instance.isLoggedIn) {
      emit(state.copyWith(status: AuthStatus.unauthenticated));
      return;
    }
    // Instant splash transition if cached user exists
    if (ApiClient.instance.user != null) {
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: ApiClient.instance.user,
      ));
      SocketService.instance.connect();
      // Refresh user silently in background
      refreshMe().catchError((_) {});
    } else {
      try {
        await refreshMe();
      } catch (_) {
        emit(state.copyWith(status: AuthStatus.unauthenticated));
      }
    }
  }

  Future<void> refreshMe() async {
    try {
      final json = await ApiClient.instance.get('/auth/me');
      final user = User.fromJson(json as Map<String, dynamic>);
      await ApiClient.instance.saveAuth(ApiClient.instance.token, user);
      if (user.role == 'captain') {
        try {
          final p = await ApiClient.instance.get('/captains/me');
          emit(state.copyWith(
            status: AuthStatus.authenticated,
            user: user,
            captainProfile: CaptainProfile.fromJson(p as Map<String, dynamic>),
          ));
          return;
        } catch (_) {}
      }
      emit(state.copyWith(
        status: AuthStatus.authenticated,
        user: user,
        captainProfile: state.captainProfile,
      ));
    } catch (e) {
      emit(state.copyWith(error: ApiClient.errorMessage(e)));
      rethrow;
    }
  }

  /// Fills the captain profile in the background so login is never blocked.
  Future<void> hydrateCaptainProfile() async {
    if (state.user?.role != 'captain') return;
    try {
      final p = await ApiClient.instance.get('/captains/me');
      if (isClosed) return;
      emit(state.copyWith(
        captainProfile: CaptainProfile.fromJson(p as Map<String, dynamic>),
      ));
    } catch (_) {}
  }

  Future<String?> login(String phone, String password) async {
    try {
      final json = await ApiClient.instance.post('/auth/login', body: {
        'phone': phone,
        'password': password,
      }) as Map<String, dynamic>;
      ApiClient.instance.applyToken(json['accessToken'] as String);
      final user = ApiClient.instance.user;
      // Leave the screen immediately once we have the token + user.
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      SocketService.instance.connect();
      // Background work never blocks the UI.
      hydrateCaptainProfile();
      refreshMe().catchError((_) {});
      PushService.sync();
      return null;
    } catch (e) {
      return ApiClient.errorMessage(e);
    }
  }

  Future<String?> registerCustomer({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
  }) async {
    try {
      final json = await ApiClient.instance.post('/auth/register', body: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
      }) as Map<String, dynamic>;
      ApiClient.instance.applyToken(json['accessToken'] as String);
      final user = ApiClient.instance.user;
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      SocketService.instance.connect();
      hydrateCaptainProfile();
      refreshMe().catchError((_) {});
      PushService.sync();
      return null;
    } catch (e) {
      return ApiClient.errorMessage(e);
    }
  }

  Future<String?> registerCaptain({
    required String firstName,
    required String lastName,
    required String phone,
    required String password,
    required String transportType,
    String? plateNumber,
    String? city,
    String? nationalId,
  }) async {
    try {
      final json = await ApiClient.instance.post('/auth/register/captain', body: {
        'firstName': firstName,
        'lastName': lastName,
        'phone': phone,
        'password': password,
        'transportType': transportType,
        'plateNumber': plateNumber,
        'city': city,
        'nationalId': nationalId,
      }) as Map<String, dynamic>;
      ApiClient.instance.applyToken(json['accessToken'] as String);
      final user = ApiClient.instance.user;
      emit(state.copyWith(status: AuthStatus.authenticated, user: user));
      SocketService.instance.connect();
      hydrateCaptainProfile();
      refreshMe().catchError((_) {});
      PushService.sync();
      return null;
    } catch (e) {
      return ApiClient.errorMessage(e);
    }
  }

  Future<void> logout() async {
    SocketService.instance.disconnect();
    await ApiClient.instance.logout();
    emit(state.copyWith(status: AuthStatus.unauthenticated, user: null, captainProfile: null));
  }

  Future<void> setCaptainProfile(CaptainProfile profile) {
    emit(state.copyWith(captainProfile: profile));
    return Future.value();
  }

  Future<void> refreshCaptainProfile() async {
    if (state.user?.role != 'captain') return;
    try {
      final p = await ApiClient.instance.get('/captains/me');
      emit(state.copyWith(
        captainProfile: CaptainProfile.fromJson(p as Map<String, dynamic>),
      ));
    } catch (_) {}
  }
}