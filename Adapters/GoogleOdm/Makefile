.PHONY: all clean generate

all: generate

generate:
	@echo "Generating Xcode project for JustTrackSDKGoogleOdmAdapter..."
	@xcodegen generate

clean:
	@echo "Cleaning generated files..."
	@rm -rf JustTrackSDKGoogleOdmAdapter.xcodeproj
	@rm -rf JustTrackSDKGoogleOdmAdapter.xcworkspace
	@find . -name "*.xcworkspace" -type d -exec rm -rf {} +
	@find . -name "*.xcodeproj" -type d -exec rm -rf {} +
