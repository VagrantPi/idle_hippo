.PHONY: test re-pub build-apk build-ios build-prd

# Test Target
test:
	flutter test -j 5

# Re-pub Target
re-pub:
	flutter clean
	flutter pub get

# Build APK Target
build-apk:
	flutter build apk

# Build iOS Target
build-ios:
	flutter build ios

# Build Production (App Bundle) Target
build-prd:
	flutter clean
	flutter pub get
	flutter build appbundle --release
