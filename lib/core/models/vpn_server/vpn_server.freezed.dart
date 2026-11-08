// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'vpn_server.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$VpnServer {

 String get id; String get subscriptionId; String get countryCode; String get title; String get configJson;
/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VpnServerCopyWith<VpnServer> get copyWith => _$VpnServerCopyWithImpl<VpnServer>(this as VpnServer, _$identity);

  /// Serializes this VpnServer to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VpnServer&&(identical(other.id, id) || other.id == id)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.configJson, configJson) || other.configJson == configJson));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subscriptionId,countryCode,title,configJson);

@override
String toString() {
  return 'VpnServer(id: $id, subscriptionId: $subscriptionId, countryCode: $countryCode, title: $title, configJson: $configJson)';
}


}

/// @nodoc
abstract mixin class $VpnServerCopyWith<$Res>  {
  factory $VpnServerCopyWith(VpnServer value, $Res Function(VpnServer) _then) = _$VpnServerCopyWithImpl;
@useResult
$Res call({
 String id, String subscriptionId, String countryCode, String title, String configJson
});




}
/// @nodoc
class _$VpnServerCopyWithImpl<$Res>
    implements $VpnServerCopyWith<$Res> {
  _$VpnServerCopyWithImpl(this._self, this._then);

  final VpnServer _self;
  final $Res Function(VpnServer) _then;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? id = null,Object? subscriptionId = null,Object? countryCode = null,Object? title = null,Object? configJson = null,}) {
  return _then(_self.copyWith(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,configJson: null == configJson ? _self.configJson : configJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}

}


/// Adds pattern-matching-related methods to [VpnServer].
extension VpnServerPatterns on VpnServer {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VpnServer value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VpnServer value)  $default,){
final _that = this;
switch (_that) {
case _VpnServer():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VpnServer value)?  $default,){
final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String id,  String subscriptionId,  String countryCode,  String title,  String configJson)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
return $default(_that.id,_that.subscriptionId,_that.countryCode,_that.title,_that.configJson);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String id,  String subscriptionId,  String countryCode,  String title,  String configJson)  $default,) {final _that = this;
switch (_that) {
case _VpnServer():
return $default(_that.id,_that.subscriptionId,_that.countryCode,_that.title,_that.configJson);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String id,  String subscriptionId,  String countryCode,  String title,  String configJson)?  $default,) {final _that = this;
switch (_that) {
case _VpnServer() when $default != null:
return $default(_that.id,_that.subscriptionId,_that.countryCode,_that.title,_that.configJson);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _VpnServer implements VpnServer {
  const _VpnServer({required this.id, required this.subscriptionId, required this.countryCode, required this.title, required this.configJson});
  factory _VpnServer.fromJson(Map<String, dynamic> json) => _$VpnServerFromJson(json);

@override final  String id;
@override final  String subscriptionId;
@override final  String countryCode;
@override final  String title;
@override final  String configJson;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VpnServerCopyWith<_VpnServer> get copyWith => __$VpnServerCopyWithImpl<_VpnServer>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$VpnServerToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VpnServer&&(identical(other.id, id) || other.id == id)&&(identical(other.subscriptionId, subscriptionId) || other.subscriptionId == subscriptionId)&&(identical(other.countryCode, countryCode) || other.countryCode == countryCode)&&(identical(other.title, title) || other.title == title)&&(identical(other.configJson, configJson) || other.configJson == configJson));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,id,subscriptionId,countryCode,title,configJson);

@override
String toString() {
  return 'VpnServer(id: $id, subscriptionId: $subscriptionId, countryCode: $countryCode, title: $title, configJson: $configJson)';
}


}

/// @nodoc
abstract mixin class _$VpnServerCopyWith<$Res> implements $VpnServerCopyWith<$Res> {
  factory _$VpnServerCopyWith(_VpnServer value, $Res Function(_VpnServer) _then) = __$VpnServerCopyWithImpl;
@override @useResult
$Res call({
 String id, String subscriptionId, String countryCode, String title, String configJson
});




}
/// @nodoc
class __$VpnServerCopyWithImpl<$Res>
    implements _$VpnServerCopyWith<$Res> {
  __$VpnServerCopyWithImpl(this._self, this._then);

  final _VpnServer _self;
  final $Res Function(_VpnServer) _then;

/// Create a copy of VpnServer
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? id = null,Object? subscriptionId = null,Object? countryCode = null,Object? title = null,Object? configJson = null,}) {
  return _then(_VpnServer(
id: null == id ? _self.id : id // ignore: cast_nullable_to_non_nullable
as String,subscriptionId: null == subscriptionId ? _self.subscriptionId : subscriptionId // ignore: cast_nullable_to_non_nullable
as String,countryCode: null == countryCode ? _self.countryCode : countryCode // ignore: cast_nullable_to_non_nullable
as String,title: null == title ? _self.title : title // ignore: cast_nullable_to_non_nullable
as String,configJson: null == configJson ? _self.configJson : configJson // ignore: cast_nullable_to_non_nullable
as String,
  ));
}


}

// dart format on
