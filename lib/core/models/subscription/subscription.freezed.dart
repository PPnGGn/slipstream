// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$Subscription {

 String get id; String? get url; String get name; DateTime get lastUpdatedAt; String? get announce; DateTime? get expiresAt; int? get updateIntervalHours; int? get usedBytes; int? get dataLimitBytes;
/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<Subscription> get copyWith => _$SubscriptionCopyWithImpl<Subscription>(this as Subscription, _$identity);

  /// Serializes this Subscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.name, name) || other.name == name)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&(identical(other.announce, announce) || other.announce == announce)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.updateIntervalHours, updateIntervalHours) || other.updateIntervalHours == updateIntervalHours)&&(identical(other.usedBytes, usedBytes) || other.usedBytes == usedBytes)&&(identical(other.dataLimitBytes, dataLimitBytes) || other.dataLimitBytes == dataLimitBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,name,lastUpdatedAt,announce,expiresAt,updateIntervalHours,usedBytes,dataLimitBytes);

@override
String toString() {
  return 'Subscription(id: $id, url: $url, name: $name, lastUpdatedAt: $lastUpdatedAt, announce: $announce, expiresAt: $expiresAt, updateIntervalHours: $updateIntervalHours, usedBytes: $usedBytes, dataLimitBytes: $dataLimitBytes)';
}


}

/// @nodoc
abstract mixin class $SubscriptionCopyWith<$Res>  {
  factory $SubscriptionCopyWith(Subscription value, $Res Function(Subscription) _then) = _$SubscriptionCopyWithImpl;
@useResult
$Res call({
 String id, String? url, String name, DateTime lastUpdatedAt, String? announce, DateTime? expiresAt, int? updateIntervalHours, int? usedBytes, int? dataLimitBytes
});




}
/// @nodoc
class _$SubscriptionCopyWithImpl<$Res>
    implements $SubscriptionCopyWith<$Res> {
  _$SubscriptionCopyWithImpl(this._self, this._then);

  final Subscription _self;
  final $Res Function(Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? url = freezed,Object? name = null,Object? lastUpdatedAt = null,Object? announce = freezed,Object? expiresAt = freezed,Object? updateIntervalHours = freezed,Object? usedBytes = freezed,Object? dataLimitBytes = freezed,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,announce: freezed == announce ? _self.announce : announce // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updateIntervalHours: freezed == updateIntervalHours ? _self.updateIntervalHours : updateIntervalHours // ignore: cast_nullable_to_non_nullable
as int?,usedBytes: freezed == usedBytes ? _self.usedBytes : usedBytes // ignore: cast_nullable_to_non_nullable
as int?,dataLimitBytes: freezed == dataLimitBytes ? _self.dataLimitBytes : dataLimitBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}

}


/// Adds pattern-matching-related methods to [Subscription].
extension SubscriptionPatterns on Subscription {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _Subscription value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _Subscription value)  $default,){
final _that = this;
switch (_that) {
case _Subscription():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _Subscription value)?  $default,){
final _that = this;
switch (_that) {
case _Subscription() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String? url,  String name,  DateTime lastUpdatedAt,  String? announce,  DateTime? expiresAt,  int? updateIntervalHours,  int? usedBytes,  int? dataLimitBytes)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.url,_that.name,_that.lastUpdatedAt,_that.announce,_that.expiresAt,_that.updateIntervalHours,_that.usedBytes,_that.dataLimitBytes);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String? url,  String name,  DateTime lastUpdatedAt,  String? announce,  DateTime? expiresAt,  int? updateIntervalHours,  int? usedBytes,  int? dataLimitBytes)  $default,) {final _that = this;
switch (_that) {
case _Subscription():
return $default(_that.id,_that.url,_that.name,_that.lastUpdatedAt,_that.announce,_that.expiresAt,_that.updateIntervalHours,_that.usedBytes,_that.dataLimitBytes);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String? url,  String name,  DateTime lastUpdatedAt,  String? announce,  DateTime? expiresAt,  int? updateIntervalHours,  int? usedBytes,  int? dataLimitBytes)?  $default,) {final _that = this;
switch (_that) {
case _Subscription() when $default != null:
return $default(_that.id,_that.url,_that.name,_that.lastUpdatedAt,_that.announce,_that.expiresAt,_that.updateIntervalHours,_that.usedBytes,_that.dataLimitBytes);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _Subscription implements Subscription {
  const _Subscription({required this.id, required this.url, required this.name, required this.lastUpdatedAt, this.announce, this.expiresAt, this.updateIntervalHours, this.usedBytes, this.dataLimitBytes});
  factory _Subscription.fromJson(Map<String, dynamic> json) => _$SubscriptionFromJson(json);

@override final  String id;
@override final  String? url;
@override final  String name;
@override final  DateTime lastUpdatedAt;
@override final  String? announce;
@override final  DateTime? expiresAt;
@override final  int? updateIntervalHours;
@override final  int? usedBytes;
@override final  int? dataLimitBytes;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SubscriptionCopyWith<_Subscription> get copyWith => __$SubscriptionCopyWithImpl<_Subscription>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$SubscriptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _Subscription&&(identical(other.id, id) || other.id == id)&&(identical(other.url, url) || other.url == url)&&(identical(other.name, name) || other.name == name)&&(identical(other.lastUpdatedAt, lastUpdatedAt) || other.lastUpdatedAt == lastUpdatedAt)&&(identical(other.announce, announce) || other.announce == announce)&&(identical(other.expiresAt, expiresAt) || other.expiresAt == expiresAt)&&(identical(other.updateIntervalHours, updateIntervalHours) || other.updateIntervalHours == updateIntervalHours)&&(identical(other.usedBytes, usedBytes) || other.usedBytes == usedBytes)&&(identical(other.dataLimitBytes, dataLimitBytes) || other.dataLimitBytes == dataLimitBytes));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,url,name,lastUpdatedAt,announce,expiresAt,updateIntervalHours,usedBytes,dataLimitBytes);

@override
String toString() {
  return 'Subscription(id: $id, url: $url, name: $name, lastUpdatedAt: $lastUpdatedAt, announce: $announce, expiresAt: $expiresAt, updateIntervalHours: $updateIntervalHours, usedBytes: $usedBytes, dataLimitBytes: $dataLimitBytes)';
}


}

/// @nodoc
abstract mixin class _$SubscriptionCopyWith<$Res> implements $SubscriptionCopyWith<$Res> {
  factory _$SubscriptionCopyWith(_Subscription value, $Res Function(_Subscription) _then) = __$SubscriptionCopyWithImpl;
@override @useResult
$Res call({
 String id, String? url, String name, DateTime lastUpdatedAt, String? announce, DateTime? expiresAt, int? updateIntervalHours, int? usedBytes, int? dataLimitBytes
});




}
/// @nodoc
class __$SubscriptionCopyWithImpl<$Res>
    implements _$SubscriptionCopyWith<$Res> {
  __$SubscriptionCopyWithImpl(this._self, this._then);

  final _Subscription _self;
  final $Res Function(_Subscription) _then;

/// Create a copy of Subscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? url = freezed,Object? name = null,Object? lastUpdatedAt = null,Object? announce = freezed,Object? expiresAt = freezed,Object? updateIntervalHours = freezed,Object? usedBytes = freezed,Object? dataLimitBytes = freezed,}) {
  return _then(_Subscription(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,url: freezed == url ? _self.url : url // ignore: cast_nullable_to_non_nullable
as String?,name: null == name ? _self.name : name // ignore: cast_nullable_to_non_nullable
as String,lastUpdatedAt: null == lastUpdatedAt ? _self.lastUpdatedAt : lastUpdatedAt // ignore: cast_nullable_to_non_nullable
as DateTime,announce: freezed == announce ? _self.announce : announce // ignore: cast_nullable_to_non_nullable
as String?,expiresAt: freezed == expiresAt ? _self.expiresAt : expiresAt // ignore: cast_nullable_to_non_nullable
as DateTime?,updateIntervalHours: freezed == updateIntervalHours ? _self.updateIntervalHours : updateIntervalHours // ignore: cast_nullable_to_non_nullable
as int?,usedBytes: freezed == usedBytes ? _self.usedBytes : usedBytes // ignore: cast_nullable_to_non_nullable
as int?,dataLimitBytes: freezed == dataLimitBytes ? _self.dataLimitBytes : dataLimitBytes // ignore: cast_nullable_to_non_nullable
as int?,
  ));
}


}

// dart format on
