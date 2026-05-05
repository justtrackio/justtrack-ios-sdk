.PHONY: all clean generate

all: generate

generate:
	@echo "Generating Xcode project for JustTrackSDKIronSourceAdapter..."
	@xcodegen generate

clean:
	@echo "Cleaning generated files..."
	@rm -rf JustTrackSDKIronSourceAdapter.xcodeproj
	@rm -rf JustTrackSDKIronSourceAdapter.xcworkspace
	@find . -name "*.xcworkspace" -type d -exec rm -rf {} +
	@find . -name "*.xcodeproj" -type d -exec rm -rf {} +