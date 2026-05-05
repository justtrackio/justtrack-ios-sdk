.PHONY: all clean generate

all: generate

generate:
	@echo "Generating Xcode project for JustTrackSDKFirebaseAdapter..."
	@xcodegen generate

clean:
	@echo "Cleaning generated files..."
	@rm -rf JustTrackSDKFirebaseAdapter.xcodeproj
	@rm -rf JustTrackSDKFirebaseAdapter.xcworkspace
	@find . -name "*.xcworkspace" -type d -exec rm -rf {} +
	@find . -name "*.xcodeproj" -type d -exec rm -rf {} +