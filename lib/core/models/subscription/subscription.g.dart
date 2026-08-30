// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subscription.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

_Subscription _$SubscriptionFromJson(Map<String, dynamic> json) =>
    _Subscription(
      id: json['id'] as String,
      url: json['url'] as String?,
      name: json['name'] as String,
      lastUpdatedAt: DateTime.parse(json['lastUpdatedAt'] as String),
      announce: json['announce'] as String?,
      expiresAt: json['expiresAt'] == null
          ? null
          : DateTime.parse(json['expiresAt'] as String),
      updateIntervalHours: (json['updateIntervalHours'] as num?)?.toInt(),
      usedBytes: (json['usedBytes'] as num?)?.toInt(),
      dataLimitBytes: (json['dataLimitBytes'] as num?)?.toInt(),
    );

Map<String, dynamic> _$SubscriptionToJson(_Subscription instance) =>
    <String, dynamic>{
      'id': instance.id,
      'url': instance.url,
      'name': instance.name,
      'lastUpdatedAt': instance.lastUpdatedAt.toIso8601String(),
      'announce': instance.announce,
      'expiresAt': instance.expiresAt?.toIso8601String(),
      'updateIntervalHours': instance.updateIntervalHours,
      'usedBytes': instance.usedBytes,
      'dataLimitBytes': instance.dataLimitBytes,
    };
