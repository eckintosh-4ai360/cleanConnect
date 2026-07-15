part of 'user_model.dart';

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserModel {

  String get id; String get fullName; String get email; String get phoneNumber; String? get address; String? get gpsLocation; String? get profilePictureUrl; String get role;
  // Create a copy of UserModel with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @pragma('vm:prefer-inline')
  $UserModelCopyWith<UserModel> get copyWith => _$UserModelCopyWithImpl<UserModel>(this as UserModel, _$identity);

    // Serializes this UserModel to a JSON map.
    Map<String, dynamic> toJson();


  @override
  bool operator ==(Object other) {
    return identical(this, other) || (other.runtimeType == runtimeType&&other is UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.gpsLocation, gpsLocation) || other.gpsLocation == gpsLocation)&&(identical(other.profilePictureUrl, profilePictureUrl) || other.profilePictureUrl == profilePictureUrl)&&(identical(other.role, role) || other.role == role));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType,id,fullName,email,phoneNumber,address,gpsLocation,profilePictureUrl,role);

  @override
  String toString() {
    return 'UserModel(id: $id, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, address: $address, gpsLocation: $gpsLocation, profilePictureUrl: $profilePictureUrl, role: $role)';
  }


}

/// @nodoc
abstract mixin class $UserModelCopyWith<$Res>  {
  factory $UserModelCopyWith(UserModel value, $Res Function(UserModel) _then) = _$UserModelCopyWithImpl;
@useResult
$Res call({
 String id, String fullName, String email, String phoneNumber, String? address, String? gpsLocation, String? profilePictureUrl, String role
});




}
/// @nodoc
class _$UserModelCopyWithImpl<$Res>
    implements $UserModelCopyWith<$Res> {
    _$UserModelCopyWithImpl(this._self, this._then);

    final UserModel _self;
    final $Res Function(UserModel) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? fullName = null,Object? email = null,Object? phoneNumber = null,Object? address = freezed,Object? gpsLocation = freezed,Object? profilePictureUrl = freezed,Object? role = null,}) {
    return _then(_self.copyWith(
  id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
  as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
  as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
  as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
  as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
  as String?,gpsLocation: freezed == gpsLocation ? _self.gpsLocation : gpsLocation // ignore: cast_nullable_to_non_nullable
  as String?,profilePictureUrl: freezed == profilePictureUrl ? _self.profilePictureUrl : profilePictureUrl // ignore: cast_nullable_to_non_nullable
  as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
  as String,
    ));
  }

}


/// Adds pattern-matching-related methods to [UserModel].
extension UserModelPatterns on UserModel {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserModel value)  $default,){
final _that = this;
switch (_that) {
case _UserModel():
return $default(_that);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserModel value)?  $default,){
final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String fullName,  String email,  String phoneNumber,  String? address,  String? gpsLocation,  String? profilePictureUrl,  String role)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.fullName,_that.email,_that.phoneNumber,_that.address,_that.gpsLocation,_that.profilePictureUrl,_that.role);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String fullName,  String email,  String phoneNumber,  String? address,  String? gpsLocation,  String? profilePictureUrl,  String role)  $default,) {final _that = this;
switch (_that) {
case _UserModel():
return $default(_that.id,_that.fullName,_that.email,_that.phoneNumber,_that.address,_that.gpsLocation,_that.profilePictureUrl,_that.role);case _:
  throw StateError('Unexpected subclass');

}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String fullName,  String email,  String phoneNumber,  String? address,  String? gpsLocation,  String? profilePictureUrl,  String role)?  $default,) {final _that = this;
switch (_that) {
case _UserModel() when $default != null:
return $default(_that.id,_that.fullName,_that.email,_that.phoneNumber,_that.address,_that.gpsLocation,_that.profilePictureUrl,_that.role);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserModel extends UserModel {
  const _UserModel({required this.id, required this.fullName, required this.email, required this.phoneNumber, this.address, this.gpsLocation, this.profilePictureUrl, required this.role}): super._();
  factory _UserModel.fromJson(Map<String, dynamic> json) => _$UserModelFromJson(json);

@override final  String id;
@override final  String fullName;
@override final  String email;
@override final  String phoneNumber;
@override final  String? address;
@override final  String? gpsLocation;
@override final  String? profilePictureUrl;
@override final  String role;

/// Create a copy of UserModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserModelCopyWith<_UserModel> get copyWith => __$UserModelCopyWithImpl<_UserModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserModel&&(identical(other.id, id) || other.id == id)&&(identical(other.fullName, fullName) || other.fullName == fullName)&&(identical(other.email, email) || other.email == email)&&(identical(other.phoneNumber, phoneNumber) || other.phoneNumber == phoneNumber)&&(identical(other.address, address) || other.address == address)&&(identical(other.gpsLocation, gpsLocation) || other.gpsLocation == gpsLocation)&&(identical(other.profilePictureUrl, profilePictureUrl) || other.profilePictureUrl == profilePictureUrl)&&(identical(other.role, role) || other.role == role));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,fullName,email,phoneNumber,address,gpsLocation,profilePictureUrl,role);

@override
String toString() {
  return 'UserModel(id: $id, fullName: $fullName, email: $email, phoneNumber: $phoneNumber, address: $address, gpsLocation: $gpsLocation, profilePictureUrl: $profilePictureUrl, role: $role)';
}


}

/// @nodoc
abstract mixin class _$UserModelCopyWith<$Res> implements $UserModelCopyWith<$Res> {
  factory _$UserModelCopyWith(_UserModel value, $Res Function(_UserModel) _then) = __$UserModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String fullName, String email, String phoneNumber, String? address, String? gpsLocation, String? profilePictureUrl, String role
});

}
/// @nodoc
class __$UserModelCopyWithImpl<$Res>
    implements _$UserModelCopyWith<$Res> {
    __$UserModelCopyWithImpl(this._self, this._then);

    final _UserModel _self;
    final $Res Function(_UserModel) _then;

  /// Create a copy of UserModel
  /// with the given fields replaced by the non-null parameter values.
  @override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? fullName = null,Object? email = null,Object? phoneNumber = null,Object? address = freezed,Object? gpsLocation = freezed,Object? profilePictureUrl = freezed,Object? role = null,}) {
    return _then(_UserModel(
  id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
  as String,fullName: null == fullName ? _self.fullName : fullName // ignore: cast_nullable_to_non_nullable
  as String,email: null == email ? _self.email : email // ignore: cast_nullable_to_non_nullable
  as String,phoneNumber: null == phoneNumber ? _self.phoneNumber : phoneNumber // ignore: cast_nullable_to_non_nullable
  as String,address: freezed == address ? _self.address : address // ignore: cast_nullable_to_non_nullable
  as String?,gpsLocation: freezed == gpsLocation ? _self.gpsLocation : gpsLocation // ignore: cast_nullable_to_non_nullable
  as String?,profilePictureUrl: freezed == profilePictureUrl ? _self.profilePictureUrl : profilePictureUrl // ignore: cast_nullable_to_non_nullable
  as String?,role: null == role ? _self.role : role // ignore: cast_nullable_to_non_nullable
  as String,
    ));
  }


}

// dart format on
