# Pigeon VPN bridge
generate-vpn-api:
	dart run pigeon \
	--input pigeons/vpn_api.dart \
	--copyright_header pigeons/copyright_header.txt \
	--dart_out lib/features/vpn/data/vpn_api.g.dart \
	--kotlin_out android/app/src/main/kotlin/com/slipstream/VpnApi.g.kt \
	--kotlin_package "com.slipstream" \
	--swift_out ios/Runner/VpnApi.g.swift

# Remove generated Pigeon outputs
clean-vpn-api:
	rm -f lib/features/vpn/data/vpn_api.g.dart
	rm -f android/app/src/main/kotlin/com/slipstream/VpnApi.g.kt
	rm -f ios/Runner/VpnApi.g.swift


# Pigeon updater bridge (Android-only). Own Kotlin package: Pigeon emits a
# top-level FlutterError class per file, which clashes with VpnApi.g.kt if
# both sit in the same package.
generate-updater-api:
	dart run pigeon \
	--input pigeons/updater_api.dart \
	--copyright_header pigeons/copyright_header.txt \
	--dart_out lib/features/update/data/updater_api.g.dart \
	--kotlin_out android/app/src/main/kotlin/com/slipstream/updater/UpdaterApi.g.kt \
	--kotlin_package "com.slipstream.updater"

# Remove generated Pigeon outputs
clean-updater-api:
	rm -f lib/features/update/data/updater_api.g.dart
	rm -f android/app/src/main/kotlin/com/slipstream/updater/UpdaterApi.g.kt


# Pigeon device info bridge. Own Kotlin package for the same FlutterError reason
# as above; the Swift output skips PigeonError (declared in VpnApi.g.swift).
generate-device-info-api:
	dart run pigeon \
	--input pigeons/device_info_api.dart \
	--copyright_header pigeons/copyright_header.txt \
	--dart_out lib/features/client_identity/data/device_info_api.g.dart \
	--kotlin_out android/app/src/main/kotlin/com/slipstream/device/DeviceInfoApi.g.kt \
	--kotlin_package "com.slipstream.device" \
	--swift_out ios/Runner/DeviceInfoApi.g.swift

# Remove generated Pigeon outputs
clean-device-info-api:
	rm -f lib/features/client_identity/data/device_info_api.g.dart
	rm -f android/app/src/main/kotlin/com/slipstream/device/DeviceInfoApi.g.kt
	rm -f ios/Runner/DeviceInfoApi.g.swift


build-core-android:
	$(MAKE) -C ../slipstream-core bind-android


build-core-ios:
	$(MAKE) -C ../slipstream-core bind-ios
	rm -rf ios/Frameworks/slipstreamcore.xcframework
	mkdir -p ios/Frameworks
	cp -R ../slipstream-core/slipstreamcore-ios.xcframework ios/Frameworks/slipstreamcore.xcframework
