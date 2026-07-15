// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'customer_models.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$BinModel {

 String get id; String get serialNumber; String get type; String get size; double get fillLevelPercentage; String? get scheduleFrequency; List<String>? get pickupDays; String? get verificationPhotoUrl; DateTime get registeredDate;
/// Create a copy of BinModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$BinModelCopyWith<BinModel> get copyWith => _$BinModelCopyWithImpl<BinModel>(this as BinModel, _$identity);

  /// Serializes this BinModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is BinModel&&(identical(other.id, id) || other.id == id)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.type, type) || other.type == type)&&(identical(other.size, size) || other.size == size)&&(identical(other.fillLevelPercentage, fillLevelPercentage) || other.fillLevelPercentage == fillLevelPercentage)&&(identical(other.scheduleFrequency, scheduleFrequency) || other.scheduleFrequency == scheduleFrequency)&&const DeepCollectionEquality().equals(other.pickupDays, pickupDays)&&(identical(other.verificationPhotoUrl, verificationPhotoUrl) || other.verificationPhotoUrl == verificationPhotoUrl)&&(identical(other.registeredDate, registeredDate) || other.registeredDate == registeredDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serialNumber,type,size,fillLevelPercentage,scheduleFrequency,const DeepCollectionEquality().hash(pickupDays),verificationPhotoUrl,registeredDate);

@override
String toString() {
  return 'BinModel(id: $id, serialNumber: $serialNumber, type: $type, size: $size, fillLevelPercentage: $fillLevelPercentage, scheduleFrequency: $scheduleFrequency, pickupDays: $pickupDays, verificationPhotoUrl: $verificationPhotoUrl, registeredDate: $registeredDate)';
}


}

/// @nodoc
abstract mixin class $BinModelCopyWith<$Res>  {
  factory $BinModelCopyWith(BinModel value, $Res Function(BinModel) _then) = _$BinModelCopyWithImpl;
@useResult
$Res call({
 String id, String serialNumber, String type, String size, double fillLevelPercentage, String? scheduleFrequency, List<String>? pickupDays, String? verificationPhotoUrl, DateTime registeredDate
});




}
/// @nodoc
class _$BinModelCopyWithImpl<$Res>
    implements $BinModelCopyWith<$Res> {
  _$BinModelCopyWithImpl(this._self, this._then);

  final BinModel _self;
  final $Res Function(BinModel) _then;

/// Create a copy of BinModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? serialNumber = null,Object? type = null,Object? size = null,Object? fillLevelPercentage = null,Object? scheduleFrequency = freezed,Object? pickupDays = freezed,Object? verificationPhotoUrl = freezed,Object? registeredDate = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,fillLevelPercentage: null == fillLevelPercentage ? _self.fillLevelPercentage : fillLevelPercentage // ignore: cast_nullable_to_non_nullable
as double,scheduleFrequency: freezed == scheduleFrequency ? _self.scheduleFrequency : scheduleFrequency // ignore: cast_nullable_to_non_nullable
as String?,pickupDays: freezed == pickupDays ? _self.pickupDays : pickupDays // ignore: cast_nullable_to_non_nullable
as List<String>?,verificationPhotoUrl: freezed == verificationPhotoUrl ? _self.verificationPhotoUrl : verificationPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,registeredDate: null == registeredDate ? _self.registeredDate : registeredDate // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}

}


/// Adds pattern-matching-related methods to [BinModel].
extension BinModelPatterns on BinModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _BinModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _BinModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _BinModel value)  $default,){
final _that = this;
switch (_that) {
case _BinModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _BinModel value)?  $default,){
final _that = this;
switch (_that) {
case _BinModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String serialNumber,  String type,  String size,  double fillLevelPercentage,  String? scheduleFrequency,  List<String>? pickupDays,  String? verificationPhotoUrl,  DateTime registeredDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _BinModel() when $default != null:
return $default(_that.id,_that.serialNumber,_that.type,_that.size,_that.fillLevelPercentage,_that.scheduleFrequency,_that.pickupDays,_that.verificationPhotoUrl,_that.registeredDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String serialNumber,  String type,  String size,  double fillLevelPercentage,  String? scheduleFrequency,  List<String>? pickupDays,  String? verificationPhotoUrl,  DateTime registeredDate)  $default,) {final _that = this;
switch (_that) {
case _BinModel():
return $default(_that.id,_that.serialNumber,_that.type,_that.size,_that.fillLevelPercentage,_that.scheduleFrequency,_that.pickupDays,_that.verificationPhotoUrl,_that.registeredDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String serialNumber,  String type,  String size,  double fillLevelPercentage,  String? scheduleFrequency,  List<String>? pickupDays,  String? verificationPhotoUrl,  DateTime registeredDate)?  $default,) {final _that = this;
switch (_that) {
case _BinModel() when $default != null:
return $default(_that.id,_that.serialNumber,_that.type,_that.size,_that.fillLevelPercentage,_that.scheduleFrequency,_that.pickupDays,_that.verificationPhotoUrl,_that.registeredDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _BinModel extends BinModel {
  const _BinModel({required this.id, required this.serialNumber, required this.type, required this.size, required this.fillLevelPercentage, this.scheduleFrequency, final  List<String>? pickupDays, this.verificationPhotoUrl, required this.registeredDate}): _pickupDays = pickupDays,super._();
  factory _BinModel.fromJson(Map<String, dynamic> json) => _$BinModelFromJson(json);

@override final  String id;
@override final  String serialNumber;
@override final  String type;
@override final  String size;
@override final  double fillLevelPercentage;
@override final  String? scheduleFrequency;
 final  List<String>? _pickupDays;
@override List<String>? get pickupDays {
  final value = _pickupDays;
  if (value == null) return null;
  if (_pickupDays is EqualUnmodifiableListView) return _pickupDays;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(value);
}

@override final  String? verificationPhotoUrl;
@override final  DateTime registeredDate;

/// Create a copy of BinModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$BinModelCopyWith<_BinModel> get copyWith => __$BinModelCopyWithImpl<_BinModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$BinModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _BinModel&&(identical(other.id, id) || other.id == id)&&(identical(other.serialNumber, serialNumber) || other.serialNumber == serialNumber)&&(identical(other.type, type) || other.type == type)&&(identical(other.size, size) || other.size == size)&&(identical(other.fillLevelPercentage, fillLevelPercentage) || other.fillLevelPercentage == fillLevelPercentage)&&(identical(other.scheduleFrequency, scheduleFrequency) || other.scheduleFrequency == scheduleFrequency)&&const DeepCollectionEquality().equals(other._pickupDays, _pickupDays)&&(identical(other.verificationPhotoUrl, verificationPhotoUrl) || other.verificationPhotoUrl == verificationPhotoUrl)&&(identical(other.registeredDate, registeredDate) || other.registeredDate == registeredDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,serialNumber,type,size,fillLevelPercentage,scheduleFrequency,const DeepCollectionEquality().hash(_pickupDays),verificationPhotoUrl,registeredDate);

@override
String toString() {
  return 'BinModel(id: $id, serialNumber: $serialNumber, type: $type, size: $size, fillLevelPercentage: $fillLevelPercentage, scheduleFrequency: $scheduleFrequency, pickupDays: $pickupDays, verificationPhotoUrl: $verificationPhotoUrl, registeredDate: $registeredDate)';
}


}

/// @nodoc
abstract mixin class _$BinModelCopyWith<$Res> implements $BinModelCopyWith<$Res> {
  factory _$BinModelCopyWith(_BinModel value, $Res Function(_BinModel) _then) = __$BinModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String serialNumber, String type, String size, double fillLevelPercentage, String? scheduleFrequency, List<String>? pickupDays, String? verificationPhotoUrl, DateTime registeredDate
});




}
/// @nodoc
class __$BinModelCopyWithImpl<$Res>
    implements _$BinModelCopyWith<$Res> {
  __$BinModelCopyWithImpl(this._self, this._then);

  final _BinModel _self;
  final $Res Function(_BinModel) _then;

/// Create a copy of BinModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? serialNumber = null,Object? type = null,Object? size = null,Object? fillLevelPercentage = null,Object? scheduleFrequency = freezed,Object? pickupDays = freezed,Object? verificationPhotoUrl = freezed,Object? registeredDate = null,}) {
  return _then(_BinModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,serialNumber: null == serialNumber ? _self.serialNumber : serialNumber // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,size: null == size ? _self.size : size // ignore: cast_nullable_to_non_nullable
as String,fillLevelPercentage: null == fillLevelPercentage ? _self.fillLevelPercentage : fillLevelPercentage // ignore: cast_nullable_to_non_nullable
as double,scheduleFrequency: freezed == scheduleFrequency ? _self.scheduleFrequency : scheduleFrequency // ignore: cast_nullable_to_non_nullable
as String?,pickupDays: freezed == pickupDays ? _self._pickupDays : pickupDays // ignore: cast_nullable_to_non_nullable
as List<String>?,verificationPhotoUrl: freezed == verificationPhotoUrl ? _self.verificationPhotoUrl : verificationPhotoUrl // ignore: cast_nullable_to_non_nullable
as String?,registeredDate: null == registeredDate ? _self.registeredDate : registeredDate // ignore: cast_nullable_to_non_nullable
as DateTime,
  ));
}


}


/// @nodoc
mixin _$PickupRequestModel {

 String get id; List<String> get binTypes; DateTime get date; String get timeSlot; String get location; String? get instructions; String get status;
/// Create a copy of PickupRequestModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$PickupRequestModelCopyWith<PickupRequestModel> get copyWith => _$PickupRequestModelCopyWithImpl<PickupRequestModel>(this as PickupRequestModel, _$identity);

  /// Serializes this PickupRequestModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is PickupRequestModel&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other.binTypes, binTypes)&&(identical(other.date, date) || other.date == date)&&(identical(other.timeSlot, timeSlot) || other.timeSlot == timeSlot)&&(identical(other.location, location) || other.location == location)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(binTypes),date,timeSlot,location,instructions,status);

@override
String toString() {
  return 'PickupRequestModel(id: $id, binTypes: $binTypes, date: $date, timeSlot: $timeSlot, location: $location, instructions: $instructions, status: $status)';
}


}

/// @nodoc
abstract mixin class $PickupRequestModelCopyWith<$Res>  {
  factory $PickupRequestModelCopyWith(PickupRequestModel value, $Res Function(PickupRequestModel) _then) = _$PickupRequestModelCopyWithImpl;
@useResult
$Res call({
 String id, List<String> binTypes, DateTime date, String timeSlot, String location, String? instructions, String status
});




}
/// @nodoc
class _$PickupRequestModelCopyWithImpl<$Res>
    implements $PickupRequestModelCopyWith<$Res> {
  _$PickupRequestModelCopyWithImpl(this._self, this._then);

  final PickupRequestModel _self;
  final $Res Function(PickupRequestModel) _then;

/// Create a copy of PickupRequestModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? binTypes = null,Object? date = null,Object? timeSlot = null,Object? location = null,Object? instructions = freezed,Object? status = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,binTypes: null == binTypes ? _self.binTypes : binTypes // ignore: cast_nullable_to_non_nullable
as List<String>,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,timeSlot: null == timeSlot ? _self.timeSlot : timeSlot // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,instructions: freezed == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [PickupRequestModel].
extension PickupRequestModelPatterns on PickupRequestModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _PickupRequestModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _PickupRequestModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _PickupRequestModel value)  $default,){
final _that = this;
switch (_that) {
case _PickupRequestModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _PickupRequestModel value)?  $default,){
final _that = this;
switch (_that) {
case _PickupRequestModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  List<String> binTypes,  DateTime date,  String timeSlot,  String location,  String? instructions,  String status)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _PickupRequestModel() when $default != null:
return $default(_that.id,_that.binTypes,_that.date,_that.timeSlot,_that.location,_that.instructions,_that.status);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  List<String> binTypes,  DateTime date,  String timeSlot,  String location,  String? instructions,  String status)  $default,) {final _that = this;
switch (_that) {
case _PickupRequestModel():
return $default(_that.id,_that.binTypes,_that.date,_that.timeSlot,_that.location,_that.instructions,_that.status);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  List<String> binTypes,  DateTime date,  String timeSlot,  String location,  String? instructions,  String status)?  $default,) {final _that = this;
switch (_that) {
case _PickupRequestModel() when $default != null:
return $default(_that.id,_that.binTypes,_that.date,_that.timeSlot,_that.location,_that.instructions,_that.status);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _PickupRequestModel extends PickupRequestModel {
  const _PickupRequestModel({required this.id, required final  List<String> binTypes, required this.date, required this.timeSlot, required this.location, this.instructions, required this.status}): _binTypes = binTypes,super._();
  factory _PickupRequestModel.fromJson(Map<String, dynamic> json) => _$PickupRequestModelFromJson(json);

@override final  String id;
 final  List<String> _binTypes;
@override List<String> get binTypes {
  if (_binTypes is EqualUnmodifiableListView) return _binTypes;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_binTypes);
}

@override final  DateTime date;
@override final  String timeSlot;
@override final  String location;
@override final  String? instructions;
@override final  String status;

/// Create a copy of PickupRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$PickupRequestModelCopyWith<_PickupRequestModel> get copyWith => __$PickupRequestModelCopyWithImpl<_PickupRequestModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$PickupRequestModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _PickupRequestModel&&(identical(other.id, id) || other.id == id)&&const DeepCollectionEquality().equals(other._binTypes, _binTypes)&&(identical(other.date, date) || other.date == date)&&(identical(other.timeSlot, timeSlot) || other.timeSlot == timeSlot)&&(identical(other.location, location) || other.location == location)&&(identical(other.instructions, instructions) || other.instructions == instructions)&&(identical(other.status, status) || other.status == status));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,const DeepCollectionEquality().hash(_binTypes),date,timeSlot,location,instructions,status);

@override
String toString() {
  return 'PickupRequestModel(id: $id, binTypes: $binTypes, date: $date, timeSlot: $timeSlot, location: $location, instructions: $instructions, status: $status)';
}


}

/// @nodoc
abstract mixin class _$PickupRequestModelCopyWith<$Res> implements $PickupRequestModelCopyWith<$Res> {
  factory _$PickupRequestModelCopyWith(_PickupRequestModel value, $Res Function(_PickupRequestModel) _then) = __$PickupRequestModelCopyWithImpl;
@override @useResult
$Res call({
 String id, List<String> binTypes, DateTime date, String timeSlot, String location, String? instructions, String status
});




}
/// @nodoc
class __$PickupRequestModelCopyWithImpl<$Res>
    implements _$PickupRequestModelCopyWith<$Res> {
  __$PickupRequestModelCopyWithImpl(this._self, this._then);

  final _PickupRequestModel _self;
  final $Res Function(_PickupRequestModel) _then;

/// Create a copy of PickupRequestModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? binTypes = null,Object? date = null,Object? timeSlot = null,Object? location = null,Object? instructions = freezed,Object? status = null,}) {
  return _then(_PickupRequestModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,binTypes: null == binTypes ? _self._binTypes : binTypes // ignore: cast_nullable_to_non_nullable
as List<String>,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,timeSlot: null == timeSlot ? _self.timeSlot : timeSlot // ignore: cast_nullable_to_non_nullable
as String,location: null == location ? _self.location : location // ignore: cast_nullable_to_non_nullable
as String,instructions: freezed == instructions ? _self.instructions : instructions // ignore: cast_nullable_to_non_nullable
as String?,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}


/// @nodoc
mixin _$ServiceRecordModel {

 String get id; String get title; String get type; DateTime get date; String get status; double? get weightKg; double? get co2OffsetKg; Map<String, double>? get compositionPercentages; double get amountPaid; String? get receiptNumber;
/// Create a copy of ServiceRecordModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$ServiceRecordModelCopyWith<ServiceRecordModel> get copyWith => _$ServiceRecordModelCopyWithImpl<ServiceRecordModel>(this as ServiceRecordModel, _$identity);

  /// Serializes this ServiceRecordModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is ServiceRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.date, date) || other.date == date)&&(identical(other.status, status) || other.status == status)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.co2OffsetKg, co2OffsetKg) || other.co2OffsetKg == co2OffsetKg)&&const DeepCollectionEquality().equals(other.compositionPercentages, compositionPercentages)&&(identical(other.amountPaid, amountPaid) || other.amountPaid == amountPaid)&&(identical(other.receiptNumber, receiptNumber) || other.receiptNumber == receiptNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,date,status,weightKg,co2OffsetKg,const DeepCollectionEquality().hash(compositionPercentages),amountPaid,receiptNumber);

@override
String toString() {
  return 'ServiceRecordModel(id: $id, title: $title, type: $type, date: $date, status: $status, weightKg: $weightKg, co2OffsetKg: $co2OffsetKg, compositionPercentages: $compositionPercentages, amountPaid: $amountPaid, receiptNumber: $receiptNumber)';
}


}

/// @nodoc
abstract mixin class $ServiceRecordModelCopyWith<$Res>  {
  factory $ServiceRecordModelCopyWith(ServiceRecordModel value, $Res Function(ServiceRecordModel) _then) = _$ServiceRecordModelCopyWithImpl;
@useResult
$Res call({
 String id, String title, String type, DateTime date, String status, double? weightKg, double? co2OffsetKg, Map<String, double>? compositionPercentages, double amountPaid, String? receiptNumber
});




}
/// @nodoc
class _$ServiceRecordModelCopyWithImpl<$Res>
    implements $ServiceRecordModelCopyWith<$Res> {
  _$ServiceRecordModelCopyWithImpl(this._self, this._then);

  final ServiceRecordModel _self;
  final $Res Function(ServiceRecordModel) _then;

/// Create a copy of ServiceRecordModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? title = null,Object? type = null,Object? date = null,Object? status = null,Object? weightKg = freezed,Object? co2OffsetKg = freezed,Object? compositionPercentages = freezed,Object? amountPaid = null,Object? receiptNumber = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,co2OffsetKg: freezed == co2OffsetKg ? _self.co2OffsetKg : co2OffsetKg // ignore: cast_nullable_to_non_nullable
as double?,compositionPercentages: freezed == compositionPercentages ? _self.compositionPercentages : compositionPercentages // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,amountPaid: null == amountPaid ? _self.amountPaid : amountPaid // ignore: cast_nullable_to_non_nullable
as double,receiptNumber: freezed == receiptNumber ? _self.receiptNumber : receiptNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [ServiceRecordModel].
extension ServiceRecordModelPatterns on ServiceRecordModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _ServiceRecordModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _ServiceRecordModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _ServiceRecordModel value)  $default,){
final _that = this;
switch (_that) {
case _ServiceRecordModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _ServiceRecordModel value)?  $default,){
final _that = this;
switch (_that) {
case _ServiceRecordModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String title,  String type,  DateTime date,  String status,  double? weightKg,  double? co2OffsetKg,  Map<String, double>? compositionPercentages,  double amountPaid,  String? receiptNumber)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _ServiceRecordModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.date,_that.status,_that.weightKg,_that.co2OffsetKg,_that.compositionPercentages,_that.amountPaid,_that.receiptNumber);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String title,  String type,  DateTime date,  String status,  double? weightKg,  double? co2OffsetKg,  Map<String, double>? compositionPercentages,  double amountPaid,  String? receiptNumber)  $default,) {final _that = this;
switch (_that) {
case _ServiceRecordModel():
return $default(_that.id,_that.title,_that.type,_that.date,_that.status,_that.weightKg,_that.co2OffsetKg,_that.compositionPercentages,_that.amountPaid,_that.receiptNumber);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String title,  String type,  DateTime date,  String status,  double? weightKg,  double? co2OffsetKg,  Map<String, double>? compositionPercentages,  double amountPaid,  String? receiptNumber)?  $default,) {final _that = this;
switch (_that) {
case _ServiceRecordModel() when $default != null:
return $default(_that.id,_that.title,_that.type,_that.date,_that.status,_that.weightKg,_that.co2OffsetKg,_that.compositionPercentages,_that.amountPaid,_that.receiptNumber);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _ServiceRecordModel extends ServiceRecordModel {
  const _ServiceRecordModel({required this.id, required this.title, required this.type, required this.date, required this.status, this.weightKg, this.co2OffsetKg, final  Map<String, double>? compositionPercentages, required this.amountPaid, this.receiptNumber}): _compositionPercentages = compositionPercentages,super._();
  factory _ServiceRecordModel.fromJson(Map<String, dynamic> json) => _$ServiceRecordModelFromJson(json);

@override final  String id;
@override final  String title;
@override final  String type;
@override final  DateTime date;
@override final  String status;
@override final  double? weightKg;
@override final  double? co2OffsetKg;
 final  Map<String, double>? _compositionPercentages;
@override Map<String, double>? get compositionPercentages {
  final value = _compositionPercentages;
  if (value == null) return null;
  if (_compositionPercentages is EqualUnmodifiableMapView) return _compositionPercentages;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(value);
}

@override final  double amountPaid;
@override final  String? receiptNumber;

/// Create a copy of ServiceRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$ServiceRecordModelCopyWith<_ServiceRecordModel> get copyWith => __$ServiceRecordModelCopyWithImpl<_ServiceRecordModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$ServiceRecordModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _ServiceRecordModel&&(identical(other.id, id) || other.id == id)&&(identical(other.title, title) || other.title == title)&&(identical(other.type, type) || other.type == type)&&(identical(other.date, date) || other.date == date)&&(identical(other.status, status) || other.status == status)&&(identical(other.weightKg, weightKg) || other.weightKg == weightKg)&&(identical(other.co2OffsetKg, co2OffsetKg) || other.co2OffsetKg == co2OffsetKg)&&const DeepCollectionEquality().equals(other._compositionPercentages, _compositionPercentages)&&(identical(other.amountPaid, amountPaid) || other.amountPaid == amountPaid)&&(identical(other.receiptNumber, receiptNumber) || other.receiptNumber == receiptNumber));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,title,type,date,status,weightKg,co2OffsetKg,const DeepCollectionEquality().hash(_compositionPercentages),amountPaid,receiptNumber);

@override
String toString() {
  return 'ServiceRecordModel(id: $id, title: $title, type: $type, date: $date, status: $status, weightKg: $weightKg, co2OffsetKg: $co2OffsetKg, compositionPercentages: $compositionPercentages, amountPaid: $amountPaid, receiptNumber: $receiptNumber)';
}


}

/// @nodoc
abstract mixin class _$ServiceRecordModelCopyWith<$Res> implements $ServiceRecordModelCopyWith<$Res> {
  factory _$ServiceRecordModelCopyWith(_ServiceRecordModel value, $Res Function(_ServiceRecordModel) _then) = __$ServiceRecordModelCopyWithImpl;
@override @useResult
$Res call({
 String id, String title, String type, DateTime date, String status, double? weightKg, double? co2OffsetKg, Map<String, double>? compositionPercentages, double amountPaid, String? receiptNumber
});




}
/// @nodoc
class __$ServiceRecordModelCopyWithImpl<$Res>
    implements _$ServiceRecordModelCopyWith<$Res> {
  __$ServiceRecordModelCopyWithImpl(this._self, this._then);

  final _ServiceRecordModel _self;
  final $Res Function(_ServiceRecordModel) _then;

/// Create a copy of ServiceRecordModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? title = null,Object? type = null,Object? date = null,Object? status = null,Object? weightKg = freezed,Object? co2OffsetKg = freezed,Object? compositionPercentages = freezed,Object? amountPaid = null,Object? receiptNumber = freezed,}) {
  return _then(_ServiceRecordModel(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,type: null == type ? _self.type : type // ignore: cast_nullable_to_non_nullable
as String,date: null == date ? _self.date : date // ignore: cast_nullable_to_non_nullable
as DateTime,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,weightKg: freezed == weightKg ? _self.weightKg : weightKg // ignore: cast_nullable_to_non_nullable
as double?,co2OffsetKg: freezed == co2OffsetKg ? _self.co2OffsetKg : co2OffsetKg // ignore: cast_nullable_to_non_nullable
as double?,compositionPercentages: freezed == compositionPercentages ? _self._compositionPercentages : compositionPercentages // ignore: cast_nullable_to_non_nullable
as Map<String, double>?,amountPaid: null == amountPaid ? _self.amountPaid : amountPaid // ignore: cast_nullable_to_non_nullable
as double,receiptNumber: freezed == receiptNumber ? _self.receiptNumber : receiptNumber // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}


/// @nodoc
mixin _$SubscriptionModel {

 String get currentPlan; double get fee; String get status; String get paymentMethod; double get outstandingBalance; DateTime? get nextPickupDate;
/// Create a copy of SubscriptionModel
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionModelCopyWith<SubscriptionModel> get copyWith => _$SubscriptionModelCopyWithImpl<SubscriptionModel>(this as SubscriptionModel, _$identity);

  /// Serializes this SubscriptionModel to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SubscriptionModel&&(identical(other.currentPlan, currentPlan) || other.currentPlan == currentPlan)&&(identical(other.fee, fee) || other.fee == fee)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.outstandingBalance, outstandingBalance) || other.outstandingBalance == outstandingBalance)&&(identical(other.nextPickupDate, nextPickupDate) || other.nextPickupDate == nextPickupDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPlan,fee,status,paymentMethod,outstandingBalance,nextPickupDate);

@override
String toString() {
  return 'SubscriptionModel(currentPlan: $currentPlan, fee: $fee, status: $status, paymentMethod: $paymentMethod, outstandingBalance: $outstandingBalance, nextPickupDate: $nextPickupDate)';
}


}

/// @nodoc
abstract mixin class $SubscriptionModelCopyWith<$Res>  {
  factory $SubscriptionModelCopyWith(SubscriptionModel value, $Res Function(SubscriptionModel) _then) = _$SubscriptionModelCopyWithImpl;
@useResult
$Res call({
 String currentPlan, double fee, String status, String paymentMethod, double outstandingBalance, DateTime? nextPickupDate
});




}
/// @nodoc
class _$SubscriptionModelCopyWithImpl<$Res>
    implements $SubscriptionModelCopyWith<$Res> {
  _$SubscriptionModelCopyWithImpl(this._self, this._then);

  final SubscriptionModel _self;
  final $Res Function(SubscriptionModel) _then;

/// Create a copy of SubscriptionModel
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? currentPlan = null,Object? fee = null,Object? status = null,Object? paymentMethod = null,Object? outstandingBalance = null,Object? nextPickupDate = freezed,}) {
  return _then(_self.copyWith(
currentPlan: null == currentPlan ? _self.currentPlan : currentPlan // ignore: cast_nullable_to_non_nullable
as String,fee: null == fee ? _self.fee : fee // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,outstandingBalance: null == outstandingBalance ? _self.outstandingBalance : outstandingBalance // ignore: cast_nullable_to_non_nullable
as double,nextPickupDate: freezed == nextPickupDate ? _self.nextPickupDate : nextPickupDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [SubscriptionModel].
extension SubscriptionModelPatterns on SubscriptionModel {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SubscriptionModel value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SubscriptionModel() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SubscriptionModel value)  $default,){
final _that = this;
switch (_that) {
case _SubscriptionModel():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SubscriptionModel value)?  $default,){
final _that = this;
switch (_that) {
case _SubscriptionModel() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String currentPlan,  double fee,  String status,  String paymentMethod,  double outstandingBalance,  DateTime? nextPickupDate)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SubscriptionModel() when $default != null:
return $default(_that.currentPlan,_that.fee,_that.status,_that.paymentMethod,_that.outstandingBalance,_that.nextPickupDate);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String currentPlan,  double fee,  String status,  String paymentMethod,  double outstandingBalance,  DateTime? nextPickupDate)  $default,) {final _that = this;
switch (_that) {
case _SubscriptionModel():
return $default(_that.currentPlan,_that.fee,_that.status,_that.paymentMethod,_that.outstandingBalance,_that.nextPickupDate);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String currentPlan,  double fee,  String status,  String paymentMethod,  double outstandingBalance,  DateTime? nextPickupDate)?  $default,) {final _that = this;
switch (_that) {
case _SubscriptionModel() when $default != null:
return $default(_that.currentPlan,_that.fee,_that.status,_that.paymentMethod,_that.outstandingBalance,_that.nextPickupDate);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _SubscriptionModel extends SubscriptionModel {
  const _SubscriptionModel({required this.currentPlan, required this.fee, required this.status, required this.paymentMethod, required this.outstandingBalance, this.nextPickupDate}): super._();
  factory _SubscriptionModel.fromJson(Map<String, dynamic> json) => _$SubscriptionModelFromJson(json);

@override final  String currentPlan;
@override final  double fee;
@override final  String status;
@override final  String paymentMethod;
@override final  double outstandingBalance;
@override final  DateTime? nextPickupDate;

/// Create a copy of SubscriptionModel
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionModelCopyWith<_SubscriptionModel> get copyWith => __$SubscriptionModelCopyWithImpl<_SubscriptionModel>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionModelToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SubscriptionModel&&(identical(other.currentPlan, currentPlan) || other.currentPlan == currentPlan)&&(identical(other.fee, fee) || other.fee == fee)&&(identical(other.status, status) || other.status == status)&&(identical(other.paymentMethod, paymentMethod) || other.paymentMethod == paymentMethod)&&(identical(other.outstandingBalance, outstandingBalance) || other.outstandingBalance == outstandingBalance)&&(identical(other.nextPickupDate, nextPickupDate) || other.nextPickupDate == nextPickupDate));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,currentPlan,fee,status,paymentMethod,outstandingBalance,nextPickupDate);

@override
String toString() {
  return 'SubscriptionModel(currentPlan: $currentPlan, fee: $fee, status: $status, paymentMethod: $paymentMethod, outstandingBalance: $outstandingBalance, nextPickupDate: $nextPickupDate)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionModelCopyWith<$Res> implements $SubscriptionModelCopyWith<$Res> {
  factory _$SubscriptionModelCopyWith(_SubscriptionModel value, $Res Function(_SubscriptionModel) _then) = __$SubscriptionModelCopyWithImpl;
@override @useResult
$Res call({
 String currentPlan, double fee, String status, String paymentMethod, double outstandingBalance, DateTime? nextPickupDate
});




}
/// @nodoc
class __$SubscriptionModelCopyWithImpl<$Res>
    implements _$SubscriptionModelCopyWith<$Res> {
  __$SubscriptionModelCopyWithImpl(this._self, this._then);

  final _SubscriptionModel _self;
  final $Res Function(_SubscriptionModel) _then;

/// Create a copy of SubscriptionModel
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? currentPlan = null,Object? fee = null,Object? status = null,Object? paymentMethod = null,Object? outstandingBalance = null,Object? nextPickupDate = freezed,}) {
  return _then(_SubscriptionModel(
currentPlan: null == currentPlan ? _self.currentPlan : currentPlan // ignore: cast_nullable_to_non_nullable
as String,fee: null == fee ? _self.fee : fee // ignore: cast_nullable_to_non_nullable
as double,status: null == status ? _self.status : status // ignore: cast_nullable_to_non_nullable
as String,paymentMethod: null == paymentMethod ? _self.paymentMethod : paymentMethod // ignore: cast_nullable_to_non_nullable
as String,outstandingBalance: null == outstandingBalance ? _self.outstandingBalance : outstandingBalance // ignore: cast_nullable_to_non_nullable
as double,nextPickupDate: freezed == nextPickupDate ? _self.nextPickupDate : nextPickupDate // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
