.PHONY: all clean generate

all: generate

generate:
	@echo "Generating Xcode project for JustTrackSDKUnityAdsAdapter..."
	@xcodegen generate

clean:
	@echo "Cleaning generated files..."
	@rm -rf JustTrackSDKUnityAdsAdapter.xcodeproj
	@rm -rf JustTrackSDKUnityAdsAdapter.xcworkspace
	@find . -name "*.xcworkspace" -type d -exec rm -rf {} +
	@find . -name "*.xcodeproj" -type d -exec rm -rf {} +