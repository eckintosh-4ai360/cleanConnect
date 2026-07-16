// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'auth_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(authRepository)
final authRepositoryProvider = AuthRepositoryProvider._();

final class AuthRepositoryProvider
    extends $FunctionalProvider<AuthRepository, AuthRepository, AuthRepository>
    with $Provider<AuthRepository> {
  AuthRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authRepositoryProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authRepositoryHash();

  @$internal
  @override
  $ProviderElement<AuthRepository> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AuthRepository create(Ref ref) {
    return authRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthRepository>(value),
    );
  }
}

String _$authRepositoryHash() => r'a8767550d220ede9bb05149c073a651c4422d5ef';

@ProviderFor(AuthStateController)
final authStateControllerProvider = AuthStateControllerProvider._();

final class AuthStateControllerProvider
    extends $NotifierProvider<AuthStateController, AuthState> {
  AuthStateControllerProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'authStateControllerProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$authStateControllerHash();

  @$internal
  @override
  AuthStateController create() => AuthStateController();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AuthState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AuthState>(value),
    );
  }
}

String _$authStateControllerHash() =>
    r'3a422a52ef096f93e67d7c371eb1194203d8fca6';

abstract class _$AuthStateController extends $Notifier<AuthState> {
  AuthState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<AuthState, AuthState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AuthState, AuthState>,
              AuthState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}

@ProviderFor(currentUser)
final currentUserProvider = CurrentUserProvider._();

final class CurrentUserProvider
    extends $FunctionalProvider<UserEntity?, UserEntity?, UserEntity?>
    with $Provider<UserEntity?> {
  CurrentUserProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserHash();

  @$internal
  @override
  $ProviderElement<UserEntity?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserEntity? create(Ref ref) {
    return currentUser(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserEntity? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserEntity?>(value),
    );
  }
}

String _$currentUserHash() => r'32f5c0e106d4bc6a2c2210609c730aa6a59d8643';

@ProviderFor(currentUserRole)
final currentUserRoleProvider = CurrentUserRoleProvider._();

final class CurrentUserRoleProvider
    extends $FunctionalProvider<UserRole?, UserRole?, UserRole?>
    with $Provider<UserRole?> {
  CurrentUserRoleProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentUserRoleProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentUserRoleHash();

  @$internal
  @override
  $ProviderElement<UserRole?> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  UserRole? create(Ref ref) {
    return currentUserRole(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UserRole? value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UserRole?>(value),
    );
  }
}

String _$currentUserRoleHash() => r'0e33a95a6963c7c87434003fde4f909da4f3c486';
