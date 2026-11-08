// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'stored_subscription.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$StoredSubscription {

 Subscription get subscription; List<VpnServer> get servers;
/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$StoredSubscriptionCopyWith<StoredSubscription> get copyWith => _$StoredSubscriptionCopyWithImpl<StoredSubscription>(this as StoredSubscription, _$identity);

  /// Serializes this StoredSubscription to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is StoredSubscription&&(identical(other.subscription, subscription) || other.subscription == subscription)&&const DeepCollectionEquality().equals(other.servers, servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subscription,const DeepCollectionEquality().hash(servers));

@override
String toString() {
  return 'StoredSubscription(subscription: $subscription, servers: $servers)';
}


}

/// @nodoc
abstract mixin class $StoredSubscriptionCopyWith<$Res>  {
  factory $StoredSubscriptionCopyWith(StoredSubscription value, $Res Function(StoredSubscription) _then) = _$StoredSubscriptionCopyWithImpl;
@useResult
$Res call({
 Subscription subscription, List<VpnServer> servers
});


$SubscriptionCopyWith<$Res> get subscription;

}
/// @nodoc
class _$StoredSubscriptionCopyWithImpl<$Res>
    implements $StoredSubscriptionCopyWith<$Res> {
  _$StoredSubscriptionCopyWithImpl(this._self, this._then);

  final StoredSubscription _self;
  final $Res Function(StoredSubscription) _then;

/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? subscription = null,Object? servers = null,}) {
  return _then(_self.copyWith(
subscription: null == subscription ? _self.subscription : subscription // ignore: cast_nullable_to_non_nullable
as Subscription,servers: null == servers ? _self.servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,
  ));
}
/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<$Res> get subscription {
  
  return $SubscriptionCopyWith<$Res>(_self.subscription, (value) {
    return _then(_self.copyWith(subscription: value));
  });
}
}


/// Adds pattern-matching-related methods to [StoredSubscription].
extension StoredSubscriptionPatterns on StoredSubscription {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _StoredSubscription value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _StoredSubscription() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _StoredSubscription value)  $default,){
final _that = this;
switch (_that) {
case _StoredSubscription():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _StoredSubscription value)?  $default,){
final _that = this;
switch (_that) {
case _StoredSubscription() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Subscription subscription,  List<VpnServer> servers)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _StoredSubscription() when $default != null:
return $default(_that.subscription,_that.servers);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Subscription subscription,  List<VpnServer> servers)  $default,) {final _that = this;
switch (_that) {
case _StoredSubscription():
return $default(_that.subscription,_that.servers);case _:
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Subscription subscription,  List<VpnServer> servers)?  $default,) {final _that = this;
switch (_that) {
case _StoredSubscription() when $default != null:
return $default(_that.subscription,_that.servers);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _StoredSubscription implements StoredSubscription {
  const _StoredSubscription({required this.subscription, required final  List<VpnServer> servers}): _servers = servers;
  factory _StoredSubscription.fromJson(Map<String, dynamic> json) => _$StoredSubscriptionFromJson(json);

@override final  Subscription subscription;
 final  List<VpnServer> _servers;
@override List<VpnServer> get servers {
  if (_servers is EqualUnmodifiableListView) return _servers;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_servers);
}


/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$StoredSubscriptionCopyWith<_StoredSubscription> get copyWith => __$StoredSubscriptionCopyWithImpl<_StoredSubscription>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$StoredSubscriptionToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _StoredSubscription&&(identical(other.subscription, subscription) || other.subscription == subscription)&&const DeepCollectionEquality().equals(other._servers, _servers));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,subscription,const DeepCollectionEquality().hash(_servers));

@override
String toString() {
  return 'StoredSubscription(subscription: $subscription, servers: $servers)';
}


}

/// @nodoc
abstract mixin class _$StoredSubscriptionCopyWith<$Res> implements $StoredSubscriptionCopyWith<$Res> {
  factory _$StoredSubscriptionCopyWith(_StoredSubscription value, $Res Function(_StoredSubscription) _then) = __$StoredSubscriptionCopyWithImpl;
@override @useResult
$Res call({
 Subscription subscription, List<VpnServer> servers
});


@override $SubscriptionCopyWith<$Res> get subscription;

}
/// @nodoc
class __$StoredSubscriptionCopyWithImpl<$Res>
    implements _$StoredSubscriptionCopyWith<$Res> {
  __$StoredSubscriptionCopyWithImpl(this._self, this._then);

  final _StoredSubscription _self;
  final $Res Function(_StoredSubscription) _then;

/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? subscription = null,Object? servers = null,}) {
  return _then(_StoredSubscription(
subscription: null == subscription ? _self.subscription : subscription // ignore: cast_nullable_to_non_nullable
as Subscription,servers: null == servers ? _self._servers : servers // ignore: cast_nullable_to_non_nullable
as List<VpnServer>,
  ));
}

/// Create a copy of StoredSubscription
/// with the given fields replaced by the non-null parameter values.
@override
@pragma('vm:prefer-inline')
$SubscriptionCopyWith<$Res> get subscription {
  
  return $SubscriptionCopyWith<$Res>(_self.subscription, (value) {
    return _then(_self.copyWith(subscription: value));
  });
}
}

// dart format on
